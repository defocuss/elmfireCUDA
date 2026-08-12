#!/usr/bin/env python3
"""Compare ELMFIRE tutorial outputs against immutable baselines in /home/david/Tests/."""

import glob
import os
import re
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


def compare_tutorial(baseline_dir, after_dir, baseline_log, after_log, label):
    """Compare tutorial after-outputs against saved baselines."""
    print("=" * 70)
    print(f"ELMFIRE OUTPUT VALIDATION: {label}")
    print("=" * 70)

    # Compare fire area from stdout logs
    baseline_acres = extract_fire_area(baseline_log)
    after_acres = extract_fire_area(after_log)
    print(f"\n1. Fire area (stdout)")
    if baseline_acres is None:
        print(f"   Baseline:  MISSING ({baseline_log})")
    else:
        print(f"   Baseline:  {baseline_acres} acres")
    if after_acres is None:
        print(f"   After:     MISSING ({after_log})")
    else:
        print(f"   After:     {after_acres} acres")
    print(f"   Match:     {baseline_acres == after_acres}")

    # Compare .tif raster files by prefix
    print(f"\n2. Raster pixel comparison")
    all_match = True

    for rtype in RASTER_TYPES:
        bpath = find_raster_by_prefix(baseline_dir, rtype)
        apath = find_raster_by_prefix(after_dir, rtype)

        if bpath is None and apath is None:
            continue  # Both missing, skip
        if bpath is None:
            print(f"   {rtype}: MISSING in baseline directory")
            all_match = False
            continue
        if apath is None:
            print(f"   {rtype}: MISSING in after directory")
            all_match = False
            continue

        bname = os.path.basename(bpath)
        aname = os.path.basename(apath)

        with rasterio.open(bpath) as src_b, rasterio.open(apath) as src_a:
            arr_b = src_b.read(1)
            arr_a = src_a.read(1)

            # Check dimensions match
            if arr_b.shape != arr_a.shape:
                print(f"   {rtype}: DIMENSION MISMATCH {bname} vs {aname} ({arr_b.shape} vs {arr_a.shape})")
                all_match = False
                continue

            identical = np.array_equal(arr_b, arr_a)
            if identical:
                print(f"   {rtype}: IDENTICAL (max_diff=0.0, n_diff_pixels=0)")
            else:
                diff = np.abs(arr_b.astype(np.float64) - arr_a.astype(np.float64))
                max_diff = np.max(diff)
                n_diff = np.count_nonzero(diff > 0)
                all_match = False
                print(f"   {rtype}: DIFFERENT {bname} vs {aname} (max_diff={max_diff:.6e}, n_diff_pixels={n_diff})")

    print(f"\n3. Overall result")
    print(f"   All rasters identical: {all_match}")
    print(f"   Fire area identical:   {baseline_acres == after_acres}")
    if all_match and baseline_acres == after_acres:
        print("\n   => VALIDATION PASSED: After code produced bit-identical results.")
    else:
        print("\n   => VALIDATION FAILED: Results differ!")
    print("=" * 70)
    return all_match and baseline_acres == after_acres


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
