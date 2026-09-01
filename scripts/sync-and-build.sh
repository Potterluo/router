#!/usr/bin/env bash
# Sync fork with upstream and build the vllm-router image locally via docker buildx.
#
# Usage:
#   scripts/sync-and-build.sh [-t tag] [-i image] [-p platforms] [--push] [--skip-sync]
#
# Requirements: git, docker with buildx.
# Multi-arch (arm64) builds on an x86 host need QEMU emulation:
#   docker run --privileged --rm tonistiigi/binfmt --install all
set -euo pipefail

TAG="latest"
IMAGE="ghcr.io/potterluo/router"
PLATFORMS="linux/amd64,linux/arm64"
PUSH=""
SKIP_SYNC=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t) TAG="$2"; shift 2 ;;
        -i) IMAGE="$2"; shift 2 ;;
        -p) PLATFORMS="$2"; shift 2 ;;
        --push) PUSH="--push"; shift ;;
        --skip-sync) SKIP_SYNC=1; shift ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$SKIP_SYNC" -ne 1 ]]; then
    git -C "$ROOT" fetch upstream main || {
        echo "git fetch upstream failed. Add it first:" >&2
        echo "  git remote add upstream https://github.com/vllm-project/router.git" >&2
        exit 1
    }
    git -C "$ROOT" merge --no-edit upstream/main || {
        echo "Merge conflict with upstream/main - resolve manually, then rerun." >&2
        exit 1
    }
    echo "[sync] merged upstream/main into $ROOT"
fi

docker buildx version >/dev/null 2>&1 || {
    echo "docker buildx is not available." >&2
    exit 1
}

docker buildx build \
    --platform "$PLATFORMS" \
    -f Dockerfile.router \
    -t "${IMAGE}:${TAG}" \
    ${PUSH:---load} \
    "$ROOT"

echo "[build] done: ${IMAGE}:${TAG} (${PLATFORMS})"