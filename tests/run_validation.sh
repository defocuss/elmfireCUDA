#!/bin/bash
# run_validation.sh — ELMFIRE optimization validation pipeline.
#
# Modes:
#   ./run_validation.sh          After-only (default): build optimized, run tutorials,
#                                compare against saved *-outputs_before/ results.
#                                Skips stash + original build — saves ~5 minutes.
#   ./run_validation.sh --full   Full cycle: stash → build original → run before →
#                                pop → build optimized → run after → compare.
#                                Use this to regenerate the saved baseline.
#
# This script is self-contained: it always uses its own repo for paths,
# ignoring any inherited ELMFIRE_INSTALL_DIR or ELMFIRE_BASE_DIR env vars.
# This is due to an issue where it used the wrong binary when run from a different repo (e.g., elmfireCUDA).

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# 0. Configuration & mode selection
# ─────────────────────────────────────────────────────────────────────────────

FULL_MODE=false
if [ "${1:-}" = "--full" ]; then
    FULL_MODE=true
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ALWAYS use this repo's paths — ignore any inherited env vars
export ELMFIRE_BASE_DIR="$REPO_ROOT"
export ELMFIRE_INSTALL_DIR="$REPO_ROOT/build/linux/bin"
ELMFIRE_VER="${ELMFIRE_VER:-2025.1002}"

# Prepend install dir to PATH so tutorial scripts find elmfire_$ELMFIRE_VER
export PATH="${ELMFIRE_INSTALL_DIR}:${PATH}"

OPT_FILES=(
  "build/source/elmfire_level_set.f90"
  "build/source/elmfire_subs.f90"
  "build/source/elmfire_spread_rate.f90"
)

TUT_NUMS=(01 02 03)
TUT_NAMES=("constant-wind" "transient-wind" "real-fuels")

# ─────────────────────────────────────────────────────────────────────────────
# Helper: cleanup trap for git stash (only needed in full mode)
# ─────────────────────────────────────────────────────────────────────────────

INITIAL_STASH_COUNT=$(git stash list 2>/dev/null | wc -l || echo 0)

cleanup() {
    local current_count
    current_count=$(git stash list 2>/dev/null | wc -l || echo 0)
    if [ "$current_count" -gt "$INITIAL_STASH_COUNT" ]; then
        echo ""
        echo "=========================================="
        echo "Restoring stashed changes (cleanup trap)"
        echo "=========================================="
        git stash pop || true
    fi
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────────
# 1. Pre-flight checks
# ─────────────────────────────────────────────────────────────────────────────

preflight() {
    echo "=========================================="
    echo "Pre-flight checks"
    echo "=========================================="

    # 1a. Verify repo root looks right
    if [ ! -d "${REPO_ROOT}/build/source" ]; then
        echo "ERROR: build/source/ not found. Is this the elmfireCUDA repo root?"
        exit 1
    fi

    # 1b. Verify pytz (needed for tutorial 03 fuel download)
    if ! python3 -c "import pytz" 2>/dev/null; then
        echo "ERROR: pytz is not installed. Run: pip install pytz"
        exit 1
    fi

    # 1c. Verify the 3 source files have modifications (optimization changes)
    local has_changes=false
    for f in "${OPT_FILES[@]}"; do
        if ! git -C "$REPO_ROOT" diff --quiet -- "$f" 2>/dev/null; then
            has_changes=true
        fi
    done
    if [ "$has_changes" = false ]; then
        echo "WARNING: None of the 3 optimized source files have modifications."
        echo "The script will test identical code before/after. Continue? [y/N]"
        read -r answer
        if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
            exit 1
        fi
    fi

    # 1d. Clean after output dirs; handle before dirs depending on mode
    for i in "${!TUT_NUMS[@]}"; do
        local num=${TUT_NUMS[$i]}
        rm -rf "${SCRIPT_DIR}/${num}-outputs_after"
        if [ "$FULL_MODE" = true ]; then
            rm -rf "${SCRIPT_DIR}/${num}-outputs_before"
        fi
    done

    # 1e. Check before results exist (default mode only)
    if [ "$FULL_MODE" = false ]; then
        local missing_before=false
        for num in "${TUT_NUMS[@]}"; do
            if [ ! -d "${SCRIPT_DIR}/${num}-outputs_before" ]; then
                missing_before=true
                echo "  Missing: ${SCRIPT_DIR}/${num}-outputs_before/"
            fi
        done
        if [ "$missing_before" = true ]; then
            echo ""
            echo "ERROR: Saved 'before' results are missing."
            echo "Run the full cycle first to generate baseline results:"
            echo "  ./run_validation.sh --full"
            exit 1
        fi
    fi

    # 1f. Print config
    echo "REPO_ROOT:           $REPO_ROOT"
    echo "ELMFIRE_BASE_DIR:    $ELMFIRE_BASE_DIR"
    echo "ELMFIRE_INSTALL_DIR: $ELMFIRE_INSTALL_DIR"
    echo "MODE:                $([ "$FULL_MODE" = true ] && echo 'full (before + after)' || echo 'after-only')"
    echo ""
    echo "Pre-flight checks passed."
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Build helper
# ─────────────────────────────────────────────────────────────────────────────

build_binary() {
    local label=$1
    echo ""
    echo "=========================================="
    echo "Building ${label} binary"
    echo "=========================================="

    cd "${REPO_ROOT}/build/linux"
    ./make_gnu.sh

    local built_bin
    built_bin="${ELMFIRE_INSTALL_DIR}/elmfire_${ELMFIRE_VER}"
    if [ ! -f "${built_bin}" ]; then
        echo "ERROR: Expected binary ${built_bin} not found after build."
        exit 1
    fi

    echo "Build complete: ${built_bin}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Tutorial runner
# ─────────────────────────────────────────────────────────────────────────────

run_tutorial() {
    local num=$1
    local name=$2
    local phase=$3   # "before" or "after"
    local tut_dir="${REPO_ROOT}/tutorials/${num}-${name}"

    echo ""
    echo "------------------------------------------"
    echo "Tutorial ${num} (${phase}): ${name}"
    echo "------------------------------------------"

    cd "$tut_dir"

    # Clean previous outputs
    rm -rf ./outputs ./scratch ./inputs
    rm -f "run_${phase}.log"

    # Build the command
    local cmd=""
    if [ "$num" = "03" ]; then
        # Tutorial 03 needs ELMFIRE_BASE_DIR for fuel_wx_ign.py
        cmd="ELMFIRE_BASE_DIR=${ELMFIRE_BASE_DIR} ./01-run.sh"
    else
        cmd="./01-run.sh"
    fi

    # Run and log
    eval "$cmd" > "run_${phase}.log" 2>&1

    # Check for success
    if ! grep -q "Fire area" "run_${phase}.log"; then
        echo "ERROR: Tutorial ${num} (${phase}) failed — no 'Fire area' found in log."
        echo "Check: ${tut_dir}/run_${phase}.log"
        exit 1
    fi

    local fire_area
    fire_area=$(grep "Fire area" "run_${phase}.log" | tail -1 | sed 's/.*Fire area:/Fire area:/')

    # Save outputs
    mkdir -p "${SCRIPT_DIR}/${num}-outputs_${phase}"
    cp ./outputs/*.tif "${SCRIPT_DIR}/${num}-outputs_${phase}/"

    echo "  ✓ ${fire_area}"
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. Main pipeline
# ─────────────────────────────────────────────────────────────────────────────

preflight

# ── BEFORE phase (only in --full mode) ──
if [ "$FULL_MODE" = true ]; then
    echo ""
    echo "=========================================="
    echo "PHASE: BEFORE (original / unoptimized)"
    echo "=========================================="

    echo "Stashing optimized source files..."
    git -C "$REPO_ROOT" stash push -- "${OPT_FILES[@]}"

    build_binary "original"

    for i in "${!TUT_NUMS[@]}"; do
        run_tutorial "${TUT_NUMS[$i]}" "${TUT_NAMES[$i]}" "before"
    done

    # ── AFTER phase (full mode: after stash pop + rebuild) ──
    echo ""
    echo "=========================================="
    echo "PHASE: AFTER (optimized)"
    echo "=========================================="

    echo "Restoring optimized source files..."
    git -C "$REPO_ROOT" stash pop

    build_binary "optimized"
else
    # ── AFTER phase (default mode: just build optimized) ──
    echo ""
    echo "=========================================="
    echo "PHASE: AFTER (optimized)"
    echo "=========================================="

    build_binary "optimized"
fi

# Run tutorials (after) — both modes
for i in "${!TUT_NUMS[@]}"; do
    run_tutorial "${TUT_NUMS[$i]}" "${TUT_NAMES[$i]}" "after"
done

# ── COMPARE ──
echo ""
echo "=========================================="
echo "PHASE: COMPARISON"
echo "=========================================="

cd "$SCRIPT_DIR"
python3 "$SCRIPT_DIR/compare_outputs.py"

echo ""
echo "=========================================="
echo "Validation pipeline complete"
echo "=========================================="

exit 0
