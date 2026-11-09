#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# make_baselines_from_main.sh — Regenerate the validation baselines from the
# upstream reference code (default: origin/main), not from the current branch.
#
# Usage:
#   ./make_baselines_from_main.sh                 # baselines from origin/main
#   BASELINE_REF=<commit|branch> ./make_baselines_from_main.sh
#
# How it works:
#   1. Creates a temporary git worktree of $BASELINE_REF (your working tree is
#      not touched; binaries are built inside the worktree).
#   2. Copies this branch's test harness (run_validation.sh, compare_outputs.py)
#      into it, because tests/ does not exist on main.
#   3. Runs `run_validation.sh --save-baselines` with the gfortran build and
#      BASELINE_DIR pointing to this repo's tests/baselines/.
#   4. Records the source commit in $BASELINE_DIR/BASELINE_SOURCE.txt and
#      removes the worktree.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BASELINE_REF="${BASELINE_REF:-origin/main}"
export BASELINE_DIR="${BASELINE_DIR:-$SCRIPT_DIR/baselines}"

# Refresh the remote ref so "origin/main" really is the latest upstream sync
if [[ "$BASELINE_REF" == origin/* ]]; then
    git -C "$REPO_ROOT" fetch origin "${BASELINE_REF#origin/}"
fi
REF_SHA="$(git -C "$REPO_ROOT" rev-parse --verify "${BASELINE_REF}^{commit}")"

# Hash of the files inside a tar, independent of the tar's own timestamps/headers.
# The fuel server rebuilds the tarball on every request (new mtimes), so a plain
# sha256sum of the .tar changes even when the rasters are identical.
tar_content_sha256() {
    local tarfile=$1 member
    tar -tf "$tarfile" | grep -v '/$' | LC_ALL=C sort | while read -r member; do
        printf '%s  %s\n' "$(tar -xOf "$tarfile" "$member" | sha256sum | cut -d' ' -f1)" "$member"
    done | sha256sum | cut -d' ' -f1
}

WORKTREE="$(mktemp -d -t elmfire-baselines-XXXXXX)"
cleanup() {
    git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" 2>/dev/null || rm -rf "$WORKTREE"
}
trap cleanup EXIT

echo "Reference: ${BASELINE_REF} (${REF_SHA})"
echo "Worktree:  ${WORKTREE}"
echo "Output:    ${BASELINE_DIR}"

git -C "$REPO_ROOT" worktree add --detach "$WORKTREE" "$REF_SHA"

mkdir -p "$WORKTREE/tests"
cp "$SCRIPT_DIR/run_validation.sh" "$SCRIPT_DIR/compare_outputs.py" "$WORKTREE/tests/"

# T03 fuel data: cloudfire/fuel_wx_ign.py needs grpc + network access to the
# fuel server. When that fails the tutorial silently falls back to a previously
# downloaded ./fuel/tutorial03.tar (git-ignored), so reuse this clone's copy.
T03_FUEL="$REPO_ROOT/tutorials/03-real-fuels/fuel/tutorial03.tar"
if [ -f "$T03_FUEL" ]; then
    mkdir -p "$WORKTREE/tutorials/03-real-fuels/fuel"
    cp "$T03_FUEL" "$WORKTREE/tutorials/03-real-fuels/fuel/"
    echo "T03 fuel:  reusing cached $T03_FUEL"
elif ! python3 -c "import grpc" 2>/dev/null; then
    echo "ERROR: no cached $T03_FUEL and python 'grpc' is not installed,"
    echo "       so tutorial 03 cannot get its fuel data. Install grpcio or"
    echo "       provide the tar file."
    exit 1
fi

# The reference tree has no "optimized" changes, so answer the preflight prompt.
# ELMFIRE_VER is unset so the version comes from the reference tree's VERSION.
echo y | env -u ELMFIRE_VER BUILD_MODE=gnu "$WORKTREE/tests/run_validation.sh" --save-baselines

# Fuel tar actually used by T03 (re-downloaded in the worktree when grpc and the
# server are available, otherwise the cached copy).
T03_FUEL_USED="$WORKTREE/tutorials/03-real-fuels/fuel/tutorial03.tar"

cat > "$BASELINE_DIR/BASELINE_SOURCE.txt" <<EOF
ref:      ${BASELINE_REF}
commit:   ${REF_SHA}
version:  $(tr -d '[:space:]' < "$WORKTREE/VERSION")
build:    gnu (make_gnu.sh)
compiler: $(gfortran --version | head -1)
t03_fuel_content_sha256: $(tar_content_sha256 "$T03_FUEL_USED")
date:     $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo ""
echo "Baselines written to ${BASELINE_DIR} from ${REF_SHA}"
