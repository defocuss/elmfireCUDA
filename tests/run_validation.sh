#!/bin/bash
# run_validation.sh — ELMFIRE optimization validation pipeline.
#
# Compares current (optimized) tutorial outputs against immutable baselines
# stored in $BASELINE_DIR (default: /home/david/Tests).
#
# Usage:
#   ./run_validation.sh                 Run validation against baselines
#   ./run_validation.sh --save-baselines  Rebuild baselines from current code
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

# Build mode: gnu (default) or cuda
BUILD_MODE="${BUILD_MODE:-gnu}"

# Base directory for immutable baselines
BASELINE_DIR="${BASELINE_DIR:-/home/david/Tests}"

# Prepend install dir to PATH so tutorial scripts find elmfire_$ELMFIRE_VER
export PATH="${ELMFIRE_INSTALL_DIR}:${PATH}"

OPT_FILES=(
  "build/source/elmfire_level_set.f90"
  "build/source/elmfire_subs.f90"
  "build/source/elmfire_spread_rate.f90"
  "build/source/elmfire_gpu.cuf"
)

TUT_NUMS=(01 02 03)
TUT_NAMES=("constant-wind" "transient-wind" "real-fuels")

# Path to T01 run script (we patch it temporarily)
T01_RUN_SH="${REPO_ROOT}/tutorials/01-constant-wind/01-run.sh"
T01_BACKUP="${T01_RUN_SH}.bak"

# Path to a tutorial's run script, given its index into TUT_NUMS/TUT_NAMES
tut_run_sh() {
    echo "${REPO_ROOT}/tutorials/$(printf '%02d' "${TUT_NUMS[$1]}")-${TUT_NAMES[$1]}/01-run.sh"
}

# Rebuild-baselines mode: save current outputs over the immutable baselines
SAVE_BASELINES=false
for arg in "$@"; do
    case "$arg" in
        --save-baselines)
            SAVE_BASELINES=true
            ;;
        *)
            echo "ERROR: Unknown argument: $arg"
            echo "Usage: ./run_validation.sh [--save-baselines]"
            exit 1
            ;;
    esac
done

# ─────────────────────────────────────────────────────────────────────────────
# Trap: always restore any patched tutorial script on exit
# ─────────────────────────────────────────────────────────────────────────────

cleanup() {
    for i in "${!TUT_NUMS[@]}"; do
        local run_sh
        run_sh="$(tut_run_sh "$i")"
        if [ -f "${run_sh}.bak" ]; then
            mv "${run_sh}.bak" "$run_sh"
            echo "(Restored ${run_sh})"
        fi
    done
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

    # 1e. Verify baselines exist (skipped in --save-baselines mode, which
    #     regenerates them)
    if [ "$SAVE_BASELINES" = true ]; then
        echo "WARNING: --save-baselines will OVERWRITE existing baselines in ${BASELINE_DIR}"
        echo "         (T01-constant-wind, T02-transient-wind, T03-real-fuels)"
    else
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
    echo "Building ${label} binary (mode: ${BUILD_MODE})"
    echo "=========================================="

    cd "${REPO_ROOT}/build/linux"

    local built_bin
    if [ "$BUILD_MODE" = "cuda" ]; then
        ./make_cuda.sh
        built_bin="${ELMFIRE_INSTALL_DIR}/elmfire_cuda_${ELMFIRE_VER}"
        # Tutorial scripts look for elmfire_$ELMFIRE_VER, so prepend cuda_
        export ELMFIRE_VER="cuda_${ELMFIRE_VER}"
    else
        ./make_gnu.sh
        built_bin="${ELMFIRE_INSTALL_DIR}/elmfire_${ELMFIRE_VER}"
    fi

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
        # Preserve fire_size_stats.csv (the T01 script otherwise deletes all .csv)
        sed -i 's|\./outputs/\*\.csv ||' "$T01_RUN_SH"
        echo "  (Patched T01 to DOMAINSIZE=120000, SIMULATION_TSTOP=86400, preserve stats CSV)"
    fi

    # Build the command
    local cmd=""
    if [ "$num" = "03" ]; then
        cmd="ELMFIRE_BASE_DIR=${ELMFIRE_BASE_DIR} ./01-run.sh"
    else
        cmd="./01-run.sh"
    fi

    # Run and log (with wall-clock timing)
    local start_time end_time wall_time
    start_time=$(date +%s.%N)
    eval "$cmd" > "run_${phase}.log" 2>&1
    end_time=$(date +%s.%N)
    wall_time=$(awk "BEGIN {print $end_time - $start_time}")
    echo "  (Wall clock time: ${wall_time}s)"

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

    # Save outputs (rasters + isochrones + stats)
    mkdir -p "${SCRIPT_DIR}/${num}-outputs_${phase}"
    cp ./outputs/*.tif "${SCRIPT_DIR}/${num}-outputs_${phase}/"
    cp ./outputs/*.shp ./outputs/*.shx ./outputs/*.dbf ./outputs/*.prj "${SCRIPT_DIR}/${num}-outputs_${phase}/" 2>/dev/null || true
    cp ./outputs/fire_size_stats.csv "${SCRIPT_DIR}/${num}-outputs_${phase}/" 2>/dev/null || true

    echo "  ✓ ${fire_area}"

    if [ "$SAVE_BASELINES" = true ]; then
        save_baseline "$num" "$name"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 3b. Baseline saver (used with --save-baselines)
# ─────────────────────────────────────────────────────────────────────────────

save_baseline() {
    local num=$1
    local name=$2
    local tut_dir="${REPO_ROOT}/tutorials/${num}-${name}"
    local dst="${BASELINE_DIR}/T${num}-${name}"
    local dst_outputs="${dst}/outputs"

    echo ""
    echo "------------------------------------------"
    echo "Saving baseline T${num}: ${name}"
    echo "------------------------------------------"

    mkdir -p "$dst"
    rm -rf "$dst_outputs"
    mkdir -p "$dst_outputs"

    cp "${tut_dir}"/outputs/*.tif "$dst_outputs/"
    cp "${tut_dir}"/outputs/*.shp "${tut_dir}"/outputs/*.shx \
       "${tut_dir}"/outputs/*.dbf "${tut_dir}"/outputs/*.prj \
       "$dst_outputs/" 2>/dev/null || true
    cp "${tut_dir}"/outputs/*.bil "${tut_dir}"/outputs/*.hdr \
       "${tut_dir}"/outputs/*.aux.xml "$dst_outputs/" 2>/dev/null || true
    cp "${tut_dir}/outputs/fire_size_stats.csv" "$dst_outputs/" 2>/dev/null || true
    cp "${tut_dir}/run_after.log" "${dst}/run_baseline.log"

    local fire_area
    fire_area=$(grep "Fire area" "${dst}/run_baseline.log" | tail -1 | sed 's/.*Fire area:/Fire area:/')
    echo "  ✓ Saved ${dst_outputs} and ${dst}/run_baseline.log"
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

# ── NSYS (optional, CUDA only) ──
# When RUN_NSYS=yes, re-run all tutorials under nsys and export GPU kernel /
# memcpy / API stats to tests/XX-outputs_after/gpu_stats.txt. Each tutorial's
# 01-run.sh is sed-patched at runtime to inject $ELMFIRE_WRAP before the
# elmfire invocation and immediately restored — no permanent edits to
# tutorial scripts. The default pipeline skips this to avoid profiling
# overhead on every run.
if [ "$BUILD_MODE" = "cuda" ] && [ "${RUN_NSYS:-no}" = "yes" ] && command -v nsys >/dev/null 2>&1; then
    echo ""
    echo "=========================================="
    echo "PHASE: NSYS PROFILING (all tutorials, CUDA only)"
    echo "=========================================="

    for i in "${!TUT_NUMS[@]}"; do
        num="${TUT_NUMS[$i]}"
        name="${TUT_NAMES[$i]}"
        tut_dir="${REPO_ROOT}/tutorials/${num}-${name}"
        run_sh="${tut_dir}/01-run.sh"
        bak="${run_sh}.bak"

        echo ""
        echo "--- Tutorial ${num}: ${name} (nsys) ---"
        cd "$tut_dir"
        rm -rf ./outputs ./scratch ./inputs

        # Backup the tutorial script
        cp "$run_sh" "$bak"

        # T01 override: patch to 120 km / 24 h to match baseline
        if [ "$num" = "01" ]; then
            sed -i 's/DOMAINSIZE=12000.0/DOMAINSIZE=120000.0/' "$run_sh"
            sed -i 's/SIMULATION_TSTOP=19800.0/SIMULATION_TSTOP=86400.0/' "$run_sh"
            sed -i 's|\./outputs/\*\.csv ||' "$run_sh"
        fi

        # Inject ELMFIRE_WRAP before the elmfire invocation
        sed -i 's/^elmfire_\$ELMFIRE_VER/$ELMFIRE_WRAP elmfire_$ELMFIRE_VER/' "$run_sh"

        # Run the tutorial with nsys wrapping only the elmfire binary.
        # --trace=cuda excludes OS-runtime tracing: on the 120km T01 domain the
        # full trace overflows nsys's protobuf serialization (ProtobufSerializeException).
        export ELMFIRE_WRAP="nsys profile --trace=cuda -o ./outputs/profile"
        if [ "$num" = "03" ]; then
            ELMFIRE_BASE_DIR=${ELMFIRE_BASE_DIR} ./01-run.sh > run_nsys.log 2>&1
        else
            ./01-run.sh > run_nsys.log 2>&1
        fi
        unset ELMFIRE_WRAP

        # Restore the tutorial script
        mv "$bak" "$run_sh"

        # Export nsys stats to the after-outputs dir
        rep=$(ls ./outputs/profile.nsys-rep* 2>/dev/null | head -1)
        if [ -n "$rep" ]; then
            nsys stats --report cuda_gpu_kern_sum,cuda_api_sum,cuda_gpu_mem_time_sum "$rep" \
                > "${SCRIPT_DIR}/${num}-outputs_after/gpu_stats.txt" 2>&1
            echo "  GPU stats exported to tests/${num}-outputs_after/gpu_stats.txt"
        else
            echo "  WARNING: no nsys profile found for T${num} (did the run finish?)"
        fi
    done
fi

# ── COMPARE ──
if [ "$SAVE_BASELINES" = true ]; then
    echo ""
    echo "=========================================="
    echo "Baselines saved to ${BASELINE_DIR}"
    echo "(comparison skipped in --save-baselines mode)"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "PHASE: COMPARISON"
    echo "=========================================="

    cd "$SCRIPT_DIR"
    python3 "$SCRIPT_DIR/compare_outputs.py"
fi

echo ""
echo "=========================================="
echo "Validation pipeline complete"
echo "=========================================="

exit 0
