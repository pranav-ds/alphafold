#!/bin/bash
#
# Copyright 2024 Doijode Technologies
#
# Install script for MacOS

# Set download directory
DOWNLOAD_DIR=$1
PROJ_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Get number of processors
NPROC=$(sysctl -n hw.ncpu)

# Step 1: Download reduced data set
if [ -n "$DOWNLOAD_DIR" ]; then
  chmod +x scripts/download_all_data.sh

  alias grep=/opt/homebrew/Cellar/grep/3.11/bin/ggrep

  # Download reduced data set
  ./scripts/download_all_data.sh "${DOWNLOAD_DIR}" reduced_dbs > download.log 2> download_all.log &
else
  echo "DOWNLOAD_DIR is not specified. Skipping data download."
fi

# Step 2: Create conda environment
conda create --prefix ./env python=3.11.5 pip -y

# Step 3: Activate conda environment
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate ./env

# Step 4: Install dependencies
pip install -r requirements.txt

# Step 5: Initialize and update git submodules
git submodule update --init --recursive

# Step 6: Install HH-suite which is a submodule now in deps/hh-suite
# Install directory is ./local/
install_hh_suite() {
  cd ${PROJ_DIR}/deps/hh-suite || exit
  rm -rf build
  mkdir build
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=${PROJ_DIR}/local -DCMAKE_BUILD_TYPE=Debug ..
  make -j "$NPROC"
  make install
  cd ${PROJ_DIR}
}
install_hh_suite

# Step 7: Install pdbfixer
install_pdbfixer() {
  cd ${PROJ_DIR}/deps/pdbfixer || exit
  conda run --prefix ${PROJ_DIR}/env pip install .
  cd ${PROJ_DIR}
}
install_pdbfixer


# Step 8: Install Kalign
install_kalign() {
  cd ${PROJ_DIR}/deps/kalign || exit
  rm -rf build
  mkdir build
  cd build
  cmake -DCMAKE_INSTALL_PREFIX=${PROJ_DIR}/local ..
  make -j "$NPROC"
  make install
  cd ${PROJ_DIR}
}
install_kalign

# Step 9: Install hmmer
install_hmmer() {
  cd ${PROJ_DIR}/deps/hmmer-3.4 || exit
  ./configure --prefix=${PROJ_DIR}/local \
              --enable-threads --enable-mpi \
              --enable-debug 
  make -j "$NPROC"
  make install
  cd ${PROJ_DIR}
}
install_hmmer




