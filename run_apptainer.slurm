#!/bin/bash

#SBATCH --job-name=icp_flow_apptainer
#SBATCH --output=logs/run_%j.out
#SBATCH --error=logs/run_%j.err
#SBATCH --partition=allgroups
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --gres=gpu:rtx:1
#SBATCH --mail-user=tosinricca@dei.unipd.it
#SBATCH --mail-type=END,FAIL

# 1. Move into project directory
cd /home/tosinricca/ICP-Flow || exit 1
mkdir -p logs

# 2. Setup compute-node temporary scratch directory
JOB_TMPDIR=${SLURM_TMPDIR:-/tmp/${USER}_${SLURM_JOB_ID}}
mkdir -p "${JOB_TMPDIR}/torch_extensions"
export TMPDIR="${JOB_TMPDIR}"
export TORCH_EXTENSIONS_DIR="${JOB_TMPDIR}/torch_extensions"

IMAGE_PATH="/home/tosinricca/ICP-Flow/icpflow.sif"

if [ ! -f "${IMAGE_PATH}" ]; then
    echo "ERROR: Container image ${IMAGE_PATH} does not exist. Run setup_apptainer.slurm first!"
    exit 1
fi

echo "=== Environment Info ==="
echo "Node: $(hostname)"
echo "GPU: $CUDA_VISIBLE_DEVICES"

# 3. Environment sanity check inside Apptainer
srun apptainer exec --nv -B /home/tosinricca/ICP-Flow:/workspace "${IMAGE_PATH}" python3 -c "
import torch, pytorch3d
print('PyTorch Version:', torch.__version__)
print('PyTorch3D Version:', pytorch3d.__version__)
print('CUDA Available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('Device Name:', torch.cuda.get_device_name(0))
"

# 4. Run ICP-Flow demo inside container
echo "=== Starting ICP-Flow Execution ==="

srun apptainer exec --nv \
    -B /home/tosinricca/ICP-Flow:/workspace \
    -B "${JOB_TMPDIR}":/tmp \
    --env PYTHONPATH=/workspace/patchwork-plusplus/build/python_wrapper:$PYTHONPATH \
    --env TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6 8.9" \
    "${IMAGE_PATH}" \
    bash -c "cd /workspace && python3 demo.py --root './' --dataset='argo' --split='val' --if_gpu --gpu_idx=0 --num_frames=2 --range_x=10000.0 --range_y=10000.0 --range_z=-10000.0 --ground_slack=0.0 --if_hdbscan --num_clusters=200 --min_cluster_size=20 --epsilon=0.25 --speed=1.0 --thres_dist=0.1 --max_points=10000 --thres_box=0.1 --thres_rot=0.1 --thres_error=0.2 --thres_iou=0.2 --batch_size=1 --num_workers=0"

echo "=== Job Completed Successfully ==="

# 5. Cleanup temporary scratch directory
rm -rf "${JOB_TMPDIR}"
