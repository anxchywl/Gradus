from __future__ import annotations

import re
from pathlib import Path

WORKFLOWS = Path(__file__).parents[3] / ".github" / "workflows"
ACTION_REFERENCE = re.compile(r"uses:\s+([^\s]+)@([^\s#]+)")
COMMIT_SHA = re.compile(r"^[0-9a-f]{40}$")

CREDENTIAL_DEFINE = re.compile(r"--dart-define=\w*(TOKEN|SECRET|PASSWORD)\w*=")


def _workflows() -> list[Path]:
    return sorted(WORKFLOWS.glob("*.yml"))


def test_workflows_exist() -> None:
    assert _workflows()


def test_every_action_is_pinned_to_a_commit() -> None:
    for workflow in _workflows():
        references = ACTION_REFERENCE.findall(workflow.read_text())
        assert references, f"{workflow.name} references no action"
        for name, reference in references:
            assert COMMIT_SHA.fullmatch(reference), (
                f"{workflow.name} pins {name} to {reference}; use a commit SHA "
                "so a retagged upstream action cannot change what runs"
            )


def test_workflows_declare_least_privilege_permissions() -> None:
    for workflow in _workflows():
        assert "permissions:" in workflow.read_text(), (
            f"{workflow.name} inherits the default token scope"
        )


def test_scanner_downloads_are_checksum_verified() -> None:
    ci = (WORKFLOWS / "ci.yml").read_text()
    assert ci.count("sha256sum --check") >= 2


def test_secret_and_dependency_scanning_run() -> None:
    ci = (WORKFLOWS / "ci.yml").read_text()
    assert "gitleaks detect" in ci
    assert "fetch-depth: 0" in ci
    assert "osv-scanner" in ci


def test_no_workflow_bakes_a_credential_into_a_build() -> None:
    # a --dart-define is compiled into the binary and is recoverable from it.
    # a predecessor project shipped an operator token in a public release APK;
    # this test is why that cannot happen here
    for workflow in _workflows():
        found = CREDENTIAL_DEFINE.findall(workflow.read_text())
        assert not found, (
            f"{workflow.name} passes a credential as a build define: {found}"
        )


def test_no_workflow_enables_standalone_release_access() -> None:
    for workflow in _workflows():
        text = workflow.read_text()
        assert "ALLOW_STANDALONE_DEV_ACCESS=true" not in text, workflow.name
        assert "ENABLE_DEV_ACCESS=true" not in text, workflow.name


def test_deployment_uses_the_tested_revision() -> None:
    ci = (WORKFLOWS / "ci.yml").read_text()
    if "deploy" not in ci:
        return
    assert "github.sha" in ci, "deploy must pin the revision CI actually tested"
