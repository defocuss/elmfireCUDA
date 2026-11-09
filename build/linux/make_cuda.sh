#!/bin/bash

# ELMFIRE version:
ELMFIRE_VER=2025.1002

# Use NVIDIA HPC SDK compilers
export ELMFIRE_FCOMPL_SERIAL_GNU=/opt/nvidia/hpc_sdk/Linux_x86_64/26.5/compilers/bin/nvfortran
export ELMFIRE_FCOMPL_MPI_GNU=/opt/nvidia/hpc_sdk/Linux_x86_64/26.5/comm_libs/mpi/bin/mpif90
export ELMFIRE_INSTALL_DIR=${ELMFIRE_INSTALL_DIR:-$(pwd)/bin}

# Preprocessor flags: same as gfortran build + _CUDA
export ELMFIRE_PRECOMPILER_FLAGS="-D_SMOKE -D_WUI -D_UMDSPOTTING -D_SUPPRESSION -D_CUDA"

# Object files: same as standard build + elmfire_gpu.o
export ELMFIRE_OBJECTS="elmfire_vars.o sort.o elmfire_subs.o elmfire_init.o elmfire_namelists.o elmfire_spread_rate.o elmfire_ignition.o elmfire_io.o elmfire_spotting.o elmfire_suppression.o elmfire_spotting_superseded.o elmfire_calibration.o elmfire_gpu.o elmfire_level_set.o elmfire.o"

# Build
echo "Making elmfire_cuda_linux"
mkdir elmfire 2> /dev/null
cd elmfire
rm -f *.o *.mod elmfire_cuda
make -f ../Makefile_elmfire cuda_linux
cp -f elmfire_cuda $ELMFIRE_INSTALL_DIR/elmfire_cuda_$ELMFIRE_VER
rm -f *.o *.mod elmfire_cuda

echo "Cleaning up"
cd ..
rm -f -r elmfire

exit 0