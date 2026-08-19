# ELMFIRE Validation Tests

This directory contains the validation pipeline for ELMFIRE. It compares the outputs of the current (optimized) code against immutable baselines stored externally.

## Baselines

The reference outputs live outside the repo in `/home/david/Tests/`:

| Tutorial | Baseline fire area | Domain |
|---|---|---|
| T01 — constant wind | 72,886.2 acres | 120 km, 24 h |
| T02 — transient wind | 6,450.3 acres | 12 km, ~6.2 h |
| T03 — real fuels | 22,641.1 acres | LANDfire 300 m |

Each tutorial folder contains:
- `outputs/*.tif` — reference GeoTIFF rasters (flin, time_of_arrival, vs)
- `outputs/hourly_isochrones.*` — contour shapefile produced by `gdal_contour -i 3600` from the time-of-arrival raster
- `run_baseline.log` — stdout from the baseline run (used to extract "Fire area")

## How to run

```bash
cd tests
./run_validation.sh
```

### CUDA build

To validate the CUDA-accelerated binary instead of the standard gfortran build:

```bash
BUILD_MODE=cuda ./run_validation.sh
```

To also re-run all tutorials under `nsys` and populate the GPU stats section (section 5):

```bash
BUILD_MODE=cuda RUN_NSYS=yes ./run_validation.sh
```

### What it does

1. **Build** the optimized binary (`elmfire_2025.1002`) from the current working tree.
2. **Run T01** with a temporarily patched 120 km / 24 h domain (the tutorial script itself is left untouched).
3. **Run T02** and **T03** with their original parameters.
4. **Compare** the generated outputs against the baselines in `/home/david/Tests/` using `compare_outputs.py`.
5. **Optional nsys phase** (`RUN_NSYS=yes`, CUDA mode only): re-runs all three tutorials with `nsys profile --trace=cuda` wrapping just the elmfire binary (sed-patched into each `01-run.sh` at runtime, then restored) and exports `cuda_gpu_kern_sum` / `cuda_api_sum` / `cuda_gpu_mem_time_sum` stats to `XX-outputs_after/gpu_stats.txt`.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `BASELINE_DIR` | `/home/david/Tests` | Path to immutable baselines |
| `ELMFIRE_VER` | `2025.1002` | Version string used in binary name |
| `ELMFIRE_INSTALL_DIR` | `$(pwd)/../build/linux/bin` | Where to find / build the binary |
| `BUILD_MODE` | `gnu` | Build target: `gnu` (gfortran) or `cuda` (nvfortran GPU) |
| `RUN_NSYS` | `no` | `yes` to re-run all tutorials under `nsys` (CUDA mode) and export kernel stats |

### Expected output

```
======================================================================
ELMFIRE OUTPUT VALIDATION: Tutorial 01
======================================================================

1. Fire area (stdout)
   Baseline:  72886.2 acres
   After:     73007.2 acres
   Diff:      0.17% (threshold: 1.00%)
   Status:    PASS

2. Raster pixel comparison
   flin: PASS (2.05% pixels differ, max_diff=1.12e+04, threshold=20.0%)
   time_of_arrival: PASS (2.01% pixels differ, max_diff=9.64e+04, threshold=20.0%)
   vs: PASS (2.05% pixels differ, max_diff=1.01e+04, threshold=20.0%)

3. Isochrone comparison (hourly_isochrones.shp)
   Feature count:  baseline=187, after=189, diff=1.07% (threshold: 5.0%)  PASS
   Total length:   baseline=139136.1m, after=139002.5m, diff=0.10% (threshold: 1.00%)  PASS
   Status: PASS

4. Performance comparison
   Baseline (gfortran): 13.03s
   After:               32.96s
   Diff: +19.93s (+152.91%) => CUDA is 152.9% SLOWER

5. GPU performance stats (RUN_NSYS=yes)
   (from nsys profile; run with RUN_NSYS=yes to refresh)
   CUDA kernels:
      elmfire_gpu_calc_normal_vectors_kernel_: 0.0059s over 2,674 launches (100.0%)
   GPU memcpy by direction:
      [CUDA memcpy Host-to-Device]: 0.1544s over 13,870 ops (95.2%)
      [CUDA memcpy Device-to-Host]: 0.0078s over 6,685 ops (4.8%)
   CUDA API calls:
      cudaMemcpy: 0.3239s over 14,709 calls (56.7%)
      cudaDeviceSynchronize: 0.1719s over 2,676 calls (30.1%)
      cudaLaunchKernel: 0.0284s over 2,676 calls (5.0%)

   (Without RUN_NSYS=yes, section 5 prints: "No nsys profile found (run with RUN_NSYS=yes for GPU stats)")

6. Overall result
   All rasters within threshold: True
   Fire area within threshold:   True
   Isochrones within threshold:  True

   => VALIDATION PASSED: All metrics within thresholds.
======================================================================
```

### Runtime

- T01 (120 km, 24 h): ~5–10 minutes
- T02 (12 km): ~1 minute
- T03 (real fuels): ~1–2 minutes
- Total pipeline: ~10–15 minutes
- With `RUN_NSYS=yes`, each tutorial is re-run under `nsys`, roughly doubling the total wall-clock time (~20–25 minutes).

## How it works

### `compare_outputs.py`

- Reads baselines from `BASELINE_DIR` (default `/home/david/Tests/`).
- Matches raster files by **prefix** (`flin_*.tif`, `time_of_arrival_*.tif`, `vs_*.tif`) rather than exact filename, so different timestamps in the output names don't break the comparison.
- Extracts "Fire area: X acres" from stdout logs and compares numerically.
- **Fire area**: passes if within **1% relative difference** of baseline.
- **Raster pixels**: passes if **≤20% of pixels differ** (counted as `diff > 0`). Fire rasters are mostly zeros with a thin perimeter; compiler-level FP divergence typically affects only 2–20% of pixels at the fire edge. A 20% threshold catches real bugs while tolerating expected nvfortran-vs-gfortran differences.
- **Isochrones** (contours from `time_of_arrival` via `gdal_contour -i 3600`):
  - **Feature count**: passes if within **5%** difference. Extra fragments ("dots") caused by FP edge noise are expected; a real bug would produce dramatically more or fewer fragments.
  - **Total contour length**: passes if within **1%** relative difference. This is the strongest geometric check — it directly measures whether the fire perimeter shape is conserved regardless of fragment count.
- **Performance** (informational — does NOT affect PASS/FAIL):
  - Reads **wall clock time** from `fire_size_stats.csv` in both baseline and after dirs (produced by ELMFIRE's `DUMP_FIRE_SIZE_STATS`). Reports absolute and % difference (SLOWER/FASTER).
  - **GPU stats** come exclusively from an **nsys profile**. With `RUN_NSYS=yes`, **all three tutorials** are re-run under nsys and `cuda_gpu_kern_sum` (kernel time + launch count), `cuda_api_sum` (API call timing) and `cuda_gpu_mem_time_sum` (H2D/D2H memcpy breakdown) are exported to `XX-outputs_after/gpu_stats.txt` and displayed. No source-code timing instrumentation is needed — nsys auto-discovers any kernel added to the codebase.
  - Each tutorial's `01-run.sh` is sed-patched at runtime to inject `nsys profile --trace=cuda` before the elmfire invocation and immediately restored — **no permanent edits to tutorial scripts**. `--trace=cuda` (vs. the default full trace) is required: on the 120 km T01 domain the full trace overflows nsys's protobuf serialization (`ProtobufSerializeException`).
- All three pass/fail checks (fire area, rasters, isochrones) must pass for overall **PASS**.

### `run_validation.sh`

- No longer has a `--full` mode or git stash logic. The old "before" baselines are stored externally; this script only runs the "after" (current code) and compares.
- T01 override: the script temporarily patches `tutorials/01-constant-wind/01-run.sh` to `DOMAINSIZE=120000` and `SIMULATION_TSTOP=86400` via `sed`, runs it, and immediately restores the original file via a backup copy.
- nsys phase: when `BUILD_MODE=cuda` and `RUN_NSYS=yes`, each tutorial's `01-run.sh` is backed up, sed-patched to prefix the elmfire invocation with `nsys profile --trace=cuda`, run, and restored from the backup (a single EXIT trap covers any interrupted run). The `nsys stats` reports are exported to `XX-outputs_after/gpu_stats.txt` for `compare_outputs.py` to display. `--trace=cuda` is required — the default full trace overflows nsys's protobuf serialization on the large 120 km T01 trace.

## Interpreting failures

If a test **FAILS**, it means the current code produced different results from the baseline. Check:

1. **Fire area mismatch** — the simulation produced a different burned area. Could indicate a logic bug in spread rate, level-set, or ignition handling.
2. **Raster pixel mismatch** — the `.tif` pixels differ. `compare_outputs.py` prints `max_diff` and `n_diff_pixels` to help quantify the divergence.
3. **Isochrone mismatch** — either feature count exceeds 5% (contours severely fragmented or missing) or total contour length exceeds 1% (fire perimeter shape changed). Open both shapefiles in QGIS and overlay to inspect.
4. **Missing files** — if the after run didn't produce outputs, check `tutorials/XX-*/run_after.log` for crash messages.

## Regenerating baselines

If you intentionally changed physics or parameters, you will need new baselines:

```bash
cd tutorials/01-constant-wind
bash 01-run.sh
cp outputs/*.tif /home/david/Tests/T01-constant-wind/outputs/
cp run_after.log /home/david/Tests/T01-constant-wind/run_baseline.log
```

Do the same for T02 and T03. Then re-run `run_validation.sh` — it should report **PASS** against the new baselines.
