#!/bin/bash
# run_validation.sh — ELMFIRE optimization validation pipeline.
#
# Compares current (optimized) tutorial outputs against immutable baselines
# stored in $BASELINE_DIR (default: /home/david/Tests).
#
# Usage:
#   ./run_validation.sh
#
# T01 is run with a patched 120 km / 24 h domain so it matches the baseline
# (the tutorial script itself is left untouched).

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# 0. Configuration
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

export ELMFIRE_BASE_DIR="$REPO_ROOT"
export ELMFIRE_INSTALL_DIR="$REPO_ROOT/build/linux/bin"
ELMFIRE_VER="${ELMFIRE_VER:-2025.1002}"

# Base directory for immutable baselines
BASELINE_DIR="${BASELINE_DIR:-/home/david/Tests}"

# Prepend install dir to PATH so tutorial scripts find elmfire_$ELMFIRE_VER
export PATH="${ELMFIRE_INSTALL_DIR}:${PATH}"

OPT_FILES=(
  "build/source/elmfire_level_set.f90"
  "build/source/elmfire_subs.f90"
  "build/source/elmfire_spread_rate.f90"
)

TUT_NUMS=(01 02 03)
TUT_NAMES=("constant-wind" "transient-wind" "real-fuels")

# Path to T01 run script (we patch it temporarily)
T01_RUN_SH="${REPO_ROOT}/tutorials/01-constant-wind/01-run.sh"
T01_BACKUP="${T01_RUN_SH}.bak"

# ─────────────────────────────────────────────────────────────────────────────
# Trap: always restore the T01 script on exit
# ─────────────────────────────────────────────────────────────────────────────

cleanup() {
    if [ -f "$T01_BACKUP" ]; then
        mv "$T01_BACKUP" "$T01_RUN_SH"
        echo "(Restored ${T01_RUN_SH})"
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

    # 1d. Clean after output dirs
    for num in "${TUT_NUMS[@]}"; do
        rm -rf "${SCRIPT_DIR}/${num}-outputs_after"
    done

    # 1e. Verify baselines exist
    local missing_baseline=false
    for t in T01-constant-wind T02-transient-wind T03-real-fuels; do
        if [ ! -d "${BASELINE_DIR}/${t}/outputs" ]; then
            missing_baseline=true
            echo "  Missing baseline dir: ${BASELINE_DIR}/${t}/outputs"
        fi
        if [ ! -f "${BASELINE_DIR}/${t}/run_baseline.log" ]; then
            missing_baseline=true
            echo "  Missing baseline log: ${BASELINE_DIR}/${t}/run_baseline.log"
        fi
    done
    if [ "$missing_baseline" = true ]; then
        echo ""
        echo "ERROR: Baseline results are missing in ${BASELINE_DIR}."
        echo "Generate them first, e.g.:"
        echo "  cd tutorials/01-constant-wind && bash 01-run.sh"
        echo "  cp outputs/*.tif /home/david/Tests/T01-constant-wind/outputs/"
        echo "  cp run_after.log /home/david/Tests/T01-constant-wind/run_baseline.log"
        exit 1
    fi

    # 1f. Print config
    echo "REPO_ROOT:           $REPO_ROOT"
    echo "ELMFIRE_BASE_DIR:    $ELMFIRE_BASE_DIR"
    echo "ELMFIRE_INSTALL_DIR: $ELMFIRE_INSTALL_DIR"
    echo "BASELINE_DIR:        $BASELINE_DIR"
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
    local phase="after"
    local tut_dir="${REPO_ROOT}/tutorials/${num}-${name}"

    echo ""
    echo "------------------------------------------"
    echo "Tutorial ${num} (${phase}): ${name}"
    echo "------------------------------------------"

    cd "$tut_dir"

    # Clean previous outputs
    rm -rf ./outputs ./scratch ./inputs
    rm -f "run_${phase}.log"

    # T01 override: patch to 120 km / 24 h to match baseline
    if [ "$num" = "01" ]; then
        cp "$T01_RUN_SH" "$T01_BACKUP"
        sed -i 's/DOMAINSIZE=12000.0/DOMAINSIZE=120000.0/' "$T01_RUN_SH"
        sed -i 's/SIMULATION_TSTOP=19800.0/SIMULATION_TSTOP=86400.0/' "$T01_RUN_SH"
        echo "  (Patched T01 to DOMAINSIZE=120000, SIMULATION_TSTOP=86400)"
    fi

    # Build the command
    local cmd=""
    if [ "$num" = "03" ]; then
        cmd="ELMFIRE_BASE_DIR=${ELMFIRE_BASE_DIR} ./01-run.sh"
    else
        cmd="./01-run.sh"
    fi

    # Run and log
    eval "$cmd" > "run_${phase}.log" 2>&1

    # Restore T01 script immediately after run
    if [ "$num" = "01" ] && [ -f "$T01_BACKUP" ]; then
        mv "$T01_BACKUP" "$T01_RUN_SH"
        echo "  (Restored T01 script)"
    fi

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

# Build optimized binary
echo ""
echo "=========================================="
echo "PHASE: BUILD (optimized)"
echo "=========================================="

build_binary "optimized"

# Run tutorials (after)
for i in "${!TUT_NUMS[@]}"; do
    run_tutorial "${TUT_NUMS[$i]}" "${TUT_NAMES[$i]}"
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
