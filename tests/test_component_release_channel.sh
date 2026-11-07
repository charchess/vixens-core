#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PYTHON'
from pathlib import Path

root = Path.cwd()
dev = (root / ".github/workflows/tag-dev-candidate.yaml").read_text(encoding="utf-8")
promote = (root / ".github/workflows/promote-prod-candidate.yaml").read_text(encoding="utf-8")
validate = (root / ".github/workflows/validate.yaml").read_text(encoding="utf-8")
workflow = (root / "WORKFLOW.md").read_text(encoding="utf-8")


def require(text: str, value: str, source: str) -> None:
    if value not in text:
        raise SystemExit(f"{source} is missing required release-channel contract: {value!r}")

# Dev candidates are produced only from a successful main validation workflow.
for value in (
    "workflow_run:",
    "workflows: [Validate & Security]",
    "branches: [main]",
    "types: [completed]",
    "github.event.workflow_run.conclusion == 'success'",
    "github.event.workflow_run.head_branch == 'main'",
    "contents: write",
    "dev-v$(date -u +%Y.%m).${suffix}",
    "git ls-remote --exit-code --refs origin \"refs/tags/$candidate_tag\"",
    "test \"$existing_sha\" = \"$CANDIDATE_SHA\"",
    "git push --force origin refs/tags/dev-latest",
    "test \"$remote_candidate\" = \"$CANDIDATE_SHA\"",
    "test \"$remote_latest\" = \"$CANDIDATE_SHA\"",
):
    require(dev, value, "tag-dev-candidate workflow")

# Production promotion takes one exact candidate, proves its provenance and validation,
# creates the immutable prod tag first, then moves and reads back prod-stable.
for value in (
    "workflow_dispatch:",
    "candidate:",
    "required: true",
    "re.fullmatch(r\"dev-v\\d{4}\\.(?:0[1-9]|1[0-2])\\.(?:[1-9]\\d*|[0-9a-f]{7,40})\"",
    "git show-ref --verify --quiet \"refs/tags/$CANDIDATE\"",
    "git merge-base --is-ancestor \"$candidate_sha\" origin/main",
    '"branch": "main"',
    '"event": "push"',
    '"head_sha": os.environ["CANDIDATE_SHA"]',
    'run["name"] == "Validate & Security"',
    'run["conclusion"] == "success"',
    "prod_tag=\"prod-v${CANDIDATE#dev-v}\"",
    "git ls-remote --exit-code --refs origin \"refs/tags/$prod_tag\"",
    "test \"$existing_sha\" = \"$candidate_sha\"",
    "git push --force origin refs/tags/prod-stable",
    "test \"$remote_prod\" = \"$candidate_sha\"",
    "test \"$remote_stable\" = \"$candidate_sha\"",
):
    require(promote, value, "promote-prod-candidate workflow")

require(validate, "release-channel-contract:", "validate workflow")
require(validate, "bash tests/test_component_release_channel.sh", "validate workflow")
require(validate, "      - release-channel-contract", "validate workflow")

for value in (
    "Repository-local component release contract",
    "immutable `dev-vYYYY.MM.<PR-or-short-sha>`",
    "explicit human action",
    "does not activate, bypass, or replace any separate Argo CD handoff",
    "physical validation",
):
    require(workflow, value, "WORKFLOW.md")

print("component release-channel contract: PASS")
PYTHON
