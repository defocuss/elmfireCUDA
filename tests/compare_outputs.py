#!/usr/bin/env python3
"""Compare ELMFIRE tutorials output rasters before and after optimization."""

import glob
import os
import re
import sys

import numpy as np
import rasterio
import warnings

# Suppress deprecation warnings
warnings.filterwarnings("ignore", message="Setting the shape", category=DeprecationWarning)

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def extract_fire_area(log_path):
    """Extract 'Fire area: X acres' from logs."""
    with open(log_path, "r") as f:
        text = f.read()
    m = re.search(r"Fire area:\s+([0-9.]+)\s+acres", text)
    return float(m.group(1)) if m else None

def compare_tutorial(before_dir, after_dir, before_log, after_log, label):
    """Compare before/after outputs for a single tutorial."""
    print("=" * 70)
    print(f"ELMFIRE OUTPUT VALIDATION: {label}")
    print("=" * 70)

    # Compare fire area from stdout logs
    before_acres = extract_fire_area(before_log)
    after_acres = extract_fire_area(after_log)
    print(f"\n1. Fire area (stdout)")
    print(f"   Before:  {before_acres} acres")
    print(f"   After:   {after_acres} acres")
    print(f"   Match:   {before_acres == after_acres}")

    # Compare .tif raster files
    print(f"\n2. Raster pixel comparison")
    before_files = sorted(glob.glob(os.path.join(before_dir, "*.tif")))
    after_files = sorted(glob.glob(os.path.join(after_dir, "*.tif")))

    before_names = {os.path.basename(p) for p in before_files}
    after_names = {os.path.basename(p) for p in after_files}

    if before_names != after_names:
        print("   WARNING: file sets differ!")
        print(f"   Only in before: {before_names - after_names}")
        print(f"   Only in after:  {after_names - before_names}")

    all_match = True
    for bpath in before_files: # Iterate over before files
        fname = os.path.basename(bpath)
        apath = os.path.join(after_dir, fname)
        if not os.path.exists(apath): # Cheks if the path exists in the after directory
            print(f"   {fname}: MISSING in after directory")
            all_match = False
            continue

        with rasterio.open(bpath) as src_b, rasterio.open(apath) as src_a:
            arr_b = src_b.read(1) # Read the first band of the raster file
            arr_a = src_a.read(1) # Read the first band of the raster file

            identical = np.array_equal(arr_b, arr_a) # Compare the begofore and after arrays
            if identical:
                print(f"   {fname}: IDENTICAL (max_diff=0.0, n_diff_pixels=0)")
            else:
                diff = np.abs(arr_b.astype(np.float64) - arr_a.astype(np.float64)) # Calculate the absolute difference between the two arrays
                max_diff = np.max(diff)
                n_diff = np.count_nonzero(diff > 0)
                all_match = False
                print(f"   {fname}: DIFFERENT (max_diff={max_diff:.6e}, n_diff_pixels={n_diff})")

    print(f"\n3. Overall result")
    print(f"   All rasters identical: {all_match}")
    print(f"   Fire area identical:   {before_acres == after_acres}")
    if all_match and before_acres == after_acres:
        print("\n   => VALIDATION PASSED: Optimization produced bit-identical results.")
    else:
        print("\n   => VALIDATION FAILED: Results differ!")
    print("=" * 70)
    return all_match and before_acres == after_acres

# Run the tutorial01 tests
def tutorial_one_test():
    before_dir = os.path.join(BASE, "tests", "01-outputs_before")
    after_dir = os.path.join(BASE, "tests", "01-outputs_after")
    before_log = os.path.join(BASE, "tutorials/01-constant-wind/run_before.log")
    after_log = os.path.join(BASE, "tutorials/01-constant-wind/run_after.log")
    return compare_tutorial(before_dir, after_dir, before_log, after_log, "Tutorial 01")

# Run the tutorial02 tests
def tutorial_two_test():
    before_dir = os.path.join(BASE, "tests", "02-outputs_before")
    after_dir = os.path.join(BASE, "tests", "02-outputs_after")
    before_log = os.path.join(BASE, "tutorials/02-transient-wind/run_before.log")
    after_log = os.path.join(BASE, "tutorials/02-transient-wind/run_after.log")
    return compare_tutorial(before_dir, after_dir, before_log, after_log, "Tutorial 02")

# Run the tutorial03 tests
def tutorial_three_test():
    before_dir = os.path.join(BASE, "tests", "03-outputs_before")
    after_dir = os.path.join(BASE, "tests", "03-outputs_after")
    before_log = os.path.join(BASE, "tutorials/03-real-fuels/run_before.log")
    after_log = os.path.join(BASE, "tutorials/03-real-fuels/run_after.log")
    return compare_tutorial(before_dir, after_dir, before_log, after_log, "Tutorial 03")

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
