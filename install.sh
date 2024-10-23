#!/bin/bash
#
# Copyright 2024 Doijode Technologies
#
# Install script for MacOS

set -e 
# 
# # Set download directory
DOWNLOAD_DIR=$1
PROJ_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PATH=${PROJ_DIR}/local/bin:$PATH
export LD_LIBRARY_PATH=${PROJ_DIR}/local/lib:${LD_LIBRARY_PATH}
export ALPHAFOLD_BRANCH=alphafold_mac

# Get number of processors
NPROC=$(sysctl -n hw.ncpu)

# Step 1a: Download reduced data set
if [ -n "$DOWNLOAD_DIR" ]; then
  chmod +x scripts/download_all_data.sh

  alias grep=/opt/homebrew/Cellar/grep/3.11/bin/ggrep

  # Download reduced data set
  ./scripts/download_all_data.sh "${DOWNLOAD_DIR}" reduced_dbs > download.log 2> download_all.log &
else
  echo "DOWNLOAD_DIR is not specified. Skipping data download."
fi

# Step 1b: Initialize and update git submodules
git submodule update --init --recursive

#Step 1c: Install openmpi
install_openmpi() {
  cd ${PROJ_DIR}/deps/openmpi-5.0.5 || exit
  ./configure CFLAGS="-arch arm64" CXXFLAGS="-arch arm64" --prefix=${PROJ_DIR}/local --enable-mpi-profile 
  make -j "$NPROC"
  make install
  cd ${PROJ_DIR}
}
#install_openmpi

# Step 2: Create conda environment
conda create --prefix ./env python=3.11.5 pip -y

# Step 3a: Activate conda environment
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate ./env

# Step 3b: Install dependencies
pip install -r requirements.txt

# Step 3c: Install OpenMM with python wrappers as well
install_openmm() {
  cd ${PROJ_DIR}/deps/openmm || exit
  git checkout dev/alphafold_arm64
  # git switch -c ${ALPHAFOLD_BRANCH}
  rm -rf build
  mkdir -p build
  cd build
  cmake .. -DCMAKE_INSTALL_PREFIX=${PROJ_DIR}/local \
           -DOPENMM_PYTHON_INSTALL=ON \
           -DPYTHON_EXECUTABLE=${PROJ_DIR}/env/bin/python \
           -DOPENMM_PYTHON_INSTALL_DIR=${PROJ_DIR}/env/lib/python3.11/site-packages
  make -j "$NPROC" 
  make install 
  make PythonInstall || { echo "OpenMM installation failed"; exit 1; }
  make install

  cd ${PROJ_DIR}
}
install_openmm

# Step 4: Install HH-suite which is a submodule now in deps/hh-suite
# Install directory is ./local/
install_hh_suite() {
  cd ${PROJ_DIR}/deps/hh-suite || exit
  rm -rf build
  mkdir build
  cd build
  export OMPLIBPATH="/opt/homebrew/Cellar/libomp/19.1.2/lib/libomp.dylib"
  export CPPFLAGS="-I/opt/homebrew/Cellar/libomp/19.1.2/include"
  cmake -DCMAKE_INSTALL_PREFIX=${PROJ_DIR}/local \
        -DOpenMP_C_FLAGS=$CPPFLAGS \
        -DOpenMP_C_LIB_NAMES="omp" \
        -DOpenMP_CXX_FLAGS=$CPPFLAGS \
        -DOpenMP_CXX_LIB_NAMES="omp" \
        -DOpenMP_omp_LIBRARY=$OMPLIBPATH \
        -DCMAKE_BUILD_TYPE=Release ..
  make -j "$NPROC"
  make install
  cd ${PROJ_DIR}
}
install_hh_suite

# Step 5: Install pdbfixer
install_pdbfixer() {
  cd ${PROJ_DIR}/deps/pdbfixer || exit
  conda run --prefix ${PROJ_DIR}/env pip install .
  cd ${PROJ_DIR}
}
install_pdbfixer


# Step 6: Install Kalign
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

# Step 7: Install hmmer
install_hmmer() {
  cd ${PROJ_DIR}/deps/hmmer-3.4 || exit
  ./configure --prefix=${PROJ_DIR}/local \
              --enable-threads
  make -j "$NPROC"
  make install
  cd ${PROJ_DIR}
}
install_hmmer




