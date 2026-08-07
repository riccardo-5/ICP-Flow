#!/bin/bash

#SBATCH --job-name=icp_setup_apptainer
#SBATCH --output=logs/setup_%j.out
#SBATCH --error=logs/setup_%j.err
#SBATCH --partition=allgroups
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --mail-user=tosinricca@dei.unipd.it
#SBATCH --mail-type=END,FAIL

echo "=== Starting Apptainer Setup Job ==="
echo "Node: $(hostname)"

# 1. Move to project directory
cd /home/tosinricca/ICP-Flow || exit 1
mkdir -p logs

# 2. Set temp directories to compute node scratch to avoid home quota issues
JOB_TMPDIR=${SLURM_TMPDIR:-/tmp/${USER}_${SLURM_JOB_ID}}
mkdir -p "${JOB_TMPDIR}/apptainer_cache" "${JOB_TMPDIR}/apptainer_tmp"
export APPTAINER_CACHEDIR="${JOB_TMPDIR}/apptainer_cache"
export APPTAINER_TMPDIR="${JOB_TMPDIR}/apptainer_tmp"

# 3. Pull Docker Image from GHCR and convert to .sif
IMAGE_NAME="icpflow.sif"
REGISTRY_URL="docker://ghcr.io/riccardo-5/icp-flow:latest"

echo "=== Pulling Docker image from GHCR and building ${IMAGE_NAME} ==="
apptainer build --force "${IMAGE_NAME}" "${REGISTRY_URL}"

if [ ! -f "${IMAGE_NAME}" ]; then
    echo "ERROR: Failed to build ${IMAGE_NAME}"
    exit 1
fi
echo "Apptainer image created successfully: ${IMAGE_NAME}"

# 4. Patch and Compile Patchwork++ inside the container
echo "=== Compiling Patchwork++ inside Apptainer container ==="
cd /home/tosinricca/ICP-Flow/patchwork-plusplus || exit 1

# Reset CMakeLists.txt to clean state if modified
git checkout -- CMakeLists.txt 2>/dev/null || true

# Apply patches for pybind11 and demo executables
sed -i 's/include(pybind11)/find_package(pybind11 REQUIRED)/g' CMakeLists.txt
sed -i '/add_executable(demo_/d' CMakeLists.txt
sed -i '/target_link_libraries(demo_/d' CMakeLists.txt
sed -i '/target_include_directories(demo_/d' CMakeLists.txt
sed -i '/set_target_properties(demo_/d' CMakeLists.txt

# Run cmake & make inside container using apptainer exec
srun apptainer exec -B /home/tosinricca/ICP-Flow:/workspace /home/tosinricca/ICP-Flow/icpflow.sif bash -c "
    cd /workspace/patchwork-plusplus && \
    PYBIND_DIR=\$(python3 -c 'import pybind11; print(pybind11.get_cmake_dir())') && \
    rm -rf build && mkdir -p build && cd build && \
    cmake .. -DEIGEN3_INCLUDE_DIR=/usr/include/eigen3 -DPYTHON_EXECUTABLE=/usr/bin/python3 -Dpybind11_DIR=\$PYBIND_DIR && \
    make -j4
"

# Verify build output
if [ -d "/home/tosinricca/ICP-Flow/patchwork-plusplus/build/python_wrapper" ]; then
    echo "=== Patchwork++ built successfully! ==="
else
    echo "ERROR: Patchwork++ compilation failed!"
    exit 1
fi

# 5. Cleanup temp files on compute node
rm -rf "${JOB_TMPDIR}"
echo "=== Apptainer Setup Job Completed Successfully ==="
