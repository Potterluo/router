#!/usr/bin/env bash
# Merge upstream (vllm-project/router) changes into the current branch and optionally push.
#
# Usage:
#   scripts/sync-upstream-local.sh [--push]
set -euo pipefail

PUSH=0
[[ "${1:-}" == "--push" ]] && PUSH=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git -C "$ROOT" fetch upstream main || {
    echo "git fetch upstream failed. Add it first:" >&2
    echo "  git remote add upstream https://github.com/vllm-project/router.git" >&2
    exit 1
}

BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
git -C "$ROOT" merge --no-edit upstream/main || {
    echo "Merge conflict with upstream/main - resolve it manually." >&2
    exit 1
}
echo "[sync] merged upstream/main into $BRANCH"

if [[ "$PUSH" -eq 1 ]]; then
    git -C "$ROOT" push origin "$BRANCH"
    echo "[sync] pushed $BRANCH to origin"
fi