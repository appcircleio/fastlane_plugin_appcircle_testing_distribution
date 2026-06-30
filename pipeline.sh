#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

MODE="${1:-}"
IMAGE="ac-fastlane-testdist-ci"

git fetch --tags --force || true
LATEST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
echo "Latest git tag: ${LATEST_TAG:-<none>}"

echo "=== Build CI image ==="
docker image build -f Dockerfile.ci -t "$IMAGE" .

run_in_docker() {
    docker run --rm \
        -e GEM_HOST_API_KEY \
        -e LATEST_TAG="$LATEST_TAG" \
        "$IMAGE" sh -c "$1"
}

status=0
case "$MODE" in
    prerelease)
        run_in_docker "ruby ci/release.rb prerelease" || status=1
        ;;
    production)
        run_in_docker "ruby ci/release.rb production" || status=1
        ;;
    *)
        echo "Unknown mode '$MODE' (expected: prerelease|production)" >&2
        status=1
        ;;
esac

docker image rm "$IMAGE" >/dev/null 2>&1 || true
exit "$status"
