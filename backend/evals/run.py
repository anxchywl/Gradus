from __future__ import annotations

import argparse
import asyncio
import json
import os
import time
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from app.config import Settings, SyllabusProvider
from app.domain.syllabus import require_supported_document
from app.infrastructure.syllabus import create_model_client
from app.infrastructure.syllabus.clients import StructuredModelClient
from app.infrastructure.syllabus.documents import SyllabusDocumentReader
from app.infrastructure.syllabus.extractor import (
    SYSTEM_PROMPT,
    ExtractedSyllabus,
    draft_from,
    request_for,
)
from evals.scoring import CaseScore, score_case

HERE = Path(__file__).parent
CASES = HERE / "cases"
CORPUS = HERE / "corpus"


@dataclass(frozen=True)
class Case:
    name: str
    document: Path
    template: str
    expected: dict[str, object]


def load_cases(only: str | None) -> tuple[list[Case], list[str]]:
    cases: list[Case] = []
    missing: list[str] = []
    for path in sorted(CASES.glob("*.json")):
        if only is not None and only not in path.stem:
            continue
        body = json.loads(path.read_text())
        document = CORPUS / str(body["document"])
        if not document.exists():
            # the corpus is deliberately not committed, so a fresh clone has the
            # expectations without the documents they describe
            missing.append(f"{path.stem} (no {body['document']} in corpus)")
            continue
        cases.append(
            Case(
                name=path.stem,
                document=document,
                template=str(body.get("template", "unlabelled")),
                expected=dict(body["expected"]),
            )
        )
    return cases, missing


# the same prompt, schema and cleaning the service uses; only the error
# handling differs, because here a failed call is a result worth printing
async def run_case(
    case: Case,
    *,
    reader: SyllabusDocumentReader,
    client: StructuredModelClient,
    maximum_output_tokens: int,
) -> CaseScore | None:
    content, kind = require_supported_document(
        case.document.read_bytes(), maximum_bytes=64 * 1_024 * 1_024
    )
    text = await reader.read(content, kind)
    started = time.monotonic()
    try:
        result = await client.complete(
            system=SYSTEM_PROMPT,
            user=request_for(text),
            schema=ExtractedSyllabus,
            maximum_output_tokens=maximum_output_tokens,
        )
    except Exception as error:  # noqa: BLE001 - a failed call is a result here
        print(f"  {case.name}: call failed ({type(error).__name__})")
        return None
    seconds = time.monotonic() - started

    if result.parsed is None:
        print(f"  {case.name}: nothing parsed, the schema was not honoured")
        return None

    return score_case(
        case=case.name,
        template=case.template,
        expected=case.expected,
        draft=draft_from(result.parsed),
        input_tokens=result.input_tokens,
        output_tokens=result.output_tokens,
        seconds=seconds,
    )


def report(
    scores: list[CaseScore], *, price_in: float | None, price_out: float | None
) -> None:
    if not scores:
        print("no cases ran")
        return

    by_template: dict[str, list[CaseScore]] = defaultdict(list)
    for score in scores:
        by_template[score.template].append(score)

    for template, group in sorted(by_template.items()):
        print(f"\n{template}")
        for score in group:
            table = score.table
            fields = "".join(
                field.field[0].upper() if field.matched else field.field[0]
                for field in score.fields
            )
            print(
                f"  {score.case:<28} {score.verdict:<12} "
                f"fields {fields}  rows {table.got_count}/{table.expected_count}  "
                f"weights {table.got_total:g}/{table.expected_total:g}  "
                f"names {table.name_match_rate:.0%}  {score.seconds:.1f}s"
            )

    total = len(scores)
    right = sum(1 for score in scores if score.table.weights_matched)
    exact = sum(1 for score in scores if score.verdict == "exact")
    print(f"\ntable right {right}/{total}   exact {exact}/{total}")

    sent = sum(score.input_tokens for score in scores)
    received = sum(score.output_tokens for score in scores)
    print(f"{sent} input tokens, {received} output tokens over {total} calls")

    # prices move, so they are given on the command line rather than baked in
    if price_in is not None and price_out is not None:
        cost = (sent * price_in + received * price_out) / 1_000_000
        print(
            f"${cost:.4f} for this run, ${cost / total * 1_000:.2f} per 1,000 imports"
        )


async def main() -> None:
    parser = argparse.ArgumentParser(prog="evals.run")
    parser.add_argument(
        "--provider", required=True, choices=[p.value for p in SyllabusProvider]
    )
    parser.add_argument("--model", required=True)
    parser.add_argument("--api-key-env", default="SYLLABUS_API_KEY")
    parser.add_argument("--base-url", default=None)
    parser.add_argument(
        "--case", default=None, help="only cases whose name contains this"
    )
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument(
        "--price-in", type=float, default=None, help="USD per million in"
    )
    parser.add_argument(
        "--price-out", type=float, default=None, help="USD per million out"
    )
    arguments = parser.parse_args()

    key = os.environ.get(arguments.api_key_env)
    if not key:
        raise SystemExit(f"{arguments.api_key_env} is not set")

    cases, missing = load_cases(arguments.case)
    for note in missing:
        print(f"skipped {note}")
    if not cases:
        raise SystemExit("no cases to run")

    settings = Settings(
        APP_ENV="development",
        SYLLABUS_PROVIDER=arguments.provider,
        SYLLABUS_MODEL=arguments.model,
        SYLLABUS_API_KEY=key,
        SYLLABUS_BASE_URL=arguments.base_url,
    )
    client = create_model_client(settings)
    reader = SyllabusDocumentReader(
        maximum_pages=settings.syllabus_document_max_pages,
        maximum_characters=settings.syllabus_document_max_characters,
    )
    plan = f"{len(cases)} cases x {arguments.repeat}"
    print(f"{arguments.provider}/{arguments.model}, {plan}")
    scores: list[CaseScore] = []
    try:
        for attempt in range(arguments.repeat):
            if arguments.repeat > 1:
                print(f"\n== run {attempt + 1}")
            for case in cases:
                score = await run_case(
                    case,
                    reader=reader,
                    client=client,
                    maximum_output_tokens=settings.syllabus_output_tokens,
                )
                if score is not None:
                    scores.append(score)
    finally:
        await client.aclose()

    report(scores, price_in=arguments.price_in, price_out=arguments.price_out)


if __name__ == "__main__":
    asyncio.run(main())
