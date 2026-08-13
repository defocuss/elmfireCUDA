#!/usr/bin/env python3
"""Compare ELMFIRE tutorial outputs against immutable baselines in /home/david/Tests/."""

import glob
import os
import re
import subprocess
import sys

import numpy as np
import rasterio
import warnings

# Suppress deprecation warnings
warnings.filterwarnings("ignore", message="Setting the shape", category=DeprecationWarning)

# Base directory for immutable baselines (env-overrideable)
BASELINE_DIR = os.environ.get("BASELINE_DIR", "/home/david/Tests")

# The three raster types we expect per tutorial
RASTER_TYPES = ["flin", "time_of_arrival", "vs"]

# Maximum allowed relative difference for fire area (1%)
# Between the CPU baseline and the after-run
FIRE_AREA_THRESHOLD = 0.01

# Maximum allowed fraction of differing pixels for raster comparison (15%)
# Between the CPU baseline and the after-run
PIXEL_PCT_THRESHOLD = 0.15

# Isochrone (hourly_isochrones.shp) comparison thresholds
ISOCHROME_FEATURE_THRESHOLD = 0.05  # 5% relative diff in feature count
ISOCHROME_LENGTH_THRESHOLD = 0.01   # 1% relative diff in total contour length


def extract_fire_area(log_path):
    """Extract 'Fire area: X acres' from stdout logs."""
    if not os.path.exists(log_path):
        return None
    with open(log_path, "r") as f:
        text = f.read()
    m = re.search(r"Fire area:\s+([0-9.]+)\s+acres", text)
    return float(m.group(1)) if m else None


def find_raster_by_prefix(directory, prefix):
    """Find exactly one .tif file in directory matching '<prefix>_*.tif'."""
    pattern = os.path.join(directory, f"{prefix}_*.tif")
    matches = glob.glob(pattern)
    if len(matches) == 0:
        return None
    if len(matches) > 1:
        # Take the first one and warn
        print(f"   WARNING: multiple files match {prefix}_*.tif in {directory}, using first")
    return matches[0]


def get_isochrone_stats(shp_path):
    """Get feature count and total contour length from a shapefile via ogrinfo."""
    if not os.path.exists(shp_path):
        return None, None
    # Feature count via summary
    try:
        r = subprocess.run(
            ["ogrinfo", "-so", shp_path, "hourly_isochrones"],
            capture_output=True, text=True, check=True,
        )
        m = re.search(r"Feature Count:\s+(\d+)", r.stdout)
        n_features = int(m.group(1)) if m else None
    except Exception:
        n_features = None
    # Total length via SQLite dialect
    try:
        r = subprocess.run(
            ["ogrinfo", "-dialect", "sqlite", "-sql",
             "SELECT SUM(ST_Length(geometry)) AS tl FROM hourly_isochrones",
             shp_path],
            capture_output=True, text=True, check=True,
        )
        m = re.search(r"tl \(Real\)\s*=\s*([\d.]+)", r.stdout)
        total_length = float(m.group(1)) if m else None
    except Exception:
        total_length = None
    return n_features, total_length


def compare_isochrones(baseline_dir, after_dir):
    """Compare hourly_isochrones.shp between baseline and after."""
    b_shp = os.path.join(baseline_dir, "hourly_isochrones.shp")
    a_shp = os.path.join(after_dir, "hourly_isochrones.shp")

    if not os.path.exists(b_shp) and not os.path.exists(a_shp):
        # Neither has isochrones — skip silently (e.g. early-stage baselines)
        return True
    if not os.path.exists(b_shp):
        print(f"   MISSING in baseline directory")
        return True  # Baseline doesn't have it; not a failure
    if not os.path.exists(a_shp):
        print(f"   MISSING in after directory")
        return False

    b_n, b_len = get_isochrone_stats(b_shp)
    a_n, a_len = get_isochrone_stats(a_shp)

    feature_pass = True
    length_pass = True

    # Feature count comparison
    if b_n is not None and a_n is not None:
        n_diff = abs(a_n - b_n)
        frac_diff = n_diff / b_n if b_n > 0 else 0.0
        feature_pass = frac_diff <= ISOCHROME_FEATURE_THRESHOLD
        status = "PASS" if feature_pass else "FAIL"
        print(f"   Feature count:  baseline={b_n}, after={a_n}, diff={frac_diff*100:.2f}% (threshold: {ISOCHROME_FEATURE_THRESHOLD*100:.1f}%)  {status}")
    else:
        print(f"   Feature count:  UNAVAILABLE")

    # Total contour length comparison
    if b_len is not None and a_len is not None:
        rel_diff = abs(a_len - b_len) / b_len if b_len > 0 else 0.0
        length_pass = rel_diff <= ISOCHROME_LENGTH_THRESHOLD
        status = "PASS" if length_pass else "FAIL"
        print(f"   Total length:   baseline={b_len:.1f}m, after={a_len:.1f}m, diff={rel_diff*100:.2f}% (threshold: {ISOCHROME_LENGTH_THRESHOLD*100:.2f}%)  {status}")
    else:
        print(f"   Total length:   UNAVAILABLE")

    return feature_pass and length_pass


def compare_tutorial(baseline_dir, after_dir, baseline_log, after_log, label):
    """Compare tutorial after-outputs against saved baselines."""
    print("=" * 70)
    print(f"ELMFIRE OUTPUT VALIDATION: {label}")
    print("=" * 70)

    # Compare fire area from stdout logs
    baseline_acres = extract_fire_area(baseline_log)
    after_acres = extract_fire_area(after_log)
    fire_area_pass = False
    print(f"\n1. Fire area (stdout)")
    if baseline_acres is None:
        print(f"   Baseline:  MISSING ({baseline_log})")
    else:
        print(f"   Baseline:  {baseline_acres} acres")
    if after_acres is None:
        print(f"   After:     MISSING ({after_log})")
    else:
        print(f"   After:     {after_acres} acres")
    if baseline_acres is not None and after_acres is not None:
        rel_diff = abs(after_acres - baseline_acres) / baseline_acres
        fire_area_pass = rel_diff <= FIRE_AREA_THRESHOLD
        status = "PASS" if fire_area_pass else "FAIL"
        print(f"   Diff:      {rel_diff*100:.2f}% (threshold: {FIRE_AREA_THRESHOLD*100:.2f}%)")
        print(f"   Status:    {status}")
    else:
        fire_area_pass = False

    # Compare .tif raster files by prefix
    print(f"\n2. Raster pixel comparison")
    all_rasters_pass = True

    for rtype in RASTER_TYPES:
        bpath = find_raster_by_prefix(baseline_dir, rtype)
        apath = find_raster_by_prefix(after_dir, rtype)

        if bpath is None and apath is None:
            continue  # Both missing, skip
        if bpath is None:
            print(f"   {rtype}: MISSING in baseline directory")
            all_rasters_pass = False
            continue
        if apath is None:
            print(f"   {rtype}: MISSING in after directory")
            all_rasters_pass = False
            continue

        bname = os.path.basename(bpath)
        aname = os.path.basename(apath)

        with rasterio.open(bpath) as src_b, rasterio.open(apath) as src_a:
            arr_b = src_b.read(1)
            arr_a = src_a.read(1)

            # Check dimensions match
            if arr_b.shape != arr_a.shape:
                print(f"   {rtype}: DIMENSION MISMATCH {bname} vs {aname} ({arr_b.shape} vs {arr_a.shape})")
                all_rasters_pass = False
                continue

            identical = np.array_equal(arr_b, arr_a)
            if identical:
                print(f"   {rtype}: IDENTICAL (0.00% pixels differ)")
            else:
                diff = np.abs(arr_b.astype(np.float64) - arr_a.astype(np.float64))
                max_diff = np.max(diff)
                n_diff = np.count_nonzero(diff > 0)
                total_pixels = arr_b.size
                frac_diff_pixels = n_diff / total_pixels
                raster_pass = frac_diff_pixels <= PIXEL_PCT_THRESHOLD
                if not raster_pass:
                    all_rasters_pass = False
                status = "PASS" if raster_pass else "FAIL"
                print(f"   {rtype}: {status} ({frac_diff_pixels*100:.2f}% pixels differ, max_diff={max_diff:.2e}, threshold={PIXEL_PCT_THRESHOLD*100:.1f}%)")

    # Compare isochrone shapefiles if present
    print(f"\n3. Isochrone comparison (hourly_isochrones.shp)")
    isochrone_pass = compare_isochrones(baseline_dir, after_dir)

    print(f"\n4. Overall result")
    overall_pass = all_rasters_pass and fire_area_pass and isochrone_pass
    print(f"   All rasters within threshold: {all_rasters_pass}")
    print(f"   Fire area within threshold:   {fire_area_pass}")
    print(f"   Isochrones within threshold:  {isochrone_pass}")
    if overall_pass:
        print(f"\n   => VALIDATION PASSED: All metrics within thresholds.")
    else:
        print(f"\n   => VALIDATION FAILED: One or more metrics exceed thresholds!")
    print("=" * 70)
    return overall_pass


def tutorial_one_test():
    baseline_dir = os.path.join(BASELINE_DIR, "T01-constant-wind", "outputs")
    after_dir = os.path.join(os.path.dirname(__file__), "01-outputs_after")
    baseline_log = os.path.join(BASELINE_DIR, "T01-constant-wind", "run_baseline.log")
    after_log = os.path.normpath(os.path.join(
        os.path.dirname(__file__), "..", "tutorials", "01-constant-wind", "run_after.log"
    ))
    return compare_tutorial(baseline_dir, after_dir, baseline_log, after_log, "Tutorial 01")


def tutorial_two_test():
    baseline_dir = os.path.join(BASELINE_DIR, "T02-transient-wind", "outputs")
    after_dir = os.path.join(os.path.dirname(__file__), "02-outputs_after")
    baseline_log = os.path.join(BASELINE_DIR, "T02-transient-wind", "run_baseline.log")
    after_log = os.path.normpath(os.path.join(
        os.path.dirname(__file__), "..", "tutorials", "02-transient-wind", "run_after.log"
    ))
    return compare_tutorial(baseline_dir, after_dir, baseline_log, after_log, "Tutorial 02")


def tutorial_three_test():
    baseline_dir = os.path.join(BASELINE_DIR, "T03-real-fuels", "outputs")
    after_dir = os.path.join(os.path.dirname(__file__), "03-outputs_after")
    baseline_log = os.path.join(BASELINE_DIR, "T03-real-fuels", "run_baseline.log")
    after_log = os.path.normpath(os.path.join(
        os.path.dirname(__file__), "..", "tutorials", "03-real-fuels", "run_after.log"
    ))
    return compare_tutorial(baseline_dir, after_dir, baseline_log, after_log, "Tutorial 03")


if __name__ == "__main__":
    results = []
    results.append(tutorial_one_test())
    results.append(tutorial_two_test())
    results.append(tutorial_three_test())
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"   Tutorial 01: {'PASS' if results[0] else 'FAIL'}")
    print(f"   Tutorial 02: {'PASS' if results[1] else 'FAIL'}")
    print(f"   Tutorial 03: {'PASS' if results[2] else 'FAIL'}")
    print(f"   Overall: {'ALL PASSED' if all(results) else 'SOME FAILED'}")
    print("=" * 70)
