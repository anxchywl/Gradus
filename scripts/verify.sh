#!/usr/bin/env bash
# formatting, analysis, tests and coverage floors - the same checks ci runs
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> backend"
(
  cd backend
  uv sync --frozen --extra dev >/dev/null
  uv run --frozen ruff format --check app tests
  uv run --frozen ruff check app tests
  uv run --frozen mypy app
  uv run --frozen bandit -q -r app
  uv run --frozen pytest --cov=app --cov-report=term-missing --cov-fail-under=90 -q
)

echo "==> localizations"
(cd gpa_feature && flutter pub get >/dev/null && flutter gen-l10n)

for package in app_ui gpa_feature gpa_app; do
  echo "==> $package"
  (
    cd "$package"
    flutter pub get >/dev/null
    dart format --output=none --set-exit-if-changed lib test
    flutter analyze --no-pub --fatal-infos
    if [ "$package" = "gpa_feature" ]; then
      flutter test --no-pub --coverage --reporter=failures-only
    else
      flutter test --no-pub --reporter=failures-only
    fi
  )
done

echo "==> coverage"
./scripts/coverage_floor.sh gpa_feature/coverage/lcov.info 70

echo "==> all checks passed"
