FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

# Configure environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6 8.9"
ENV FORCE_CUDA=1
ENV CUDA_HOME=/usr/local/cuda

# Install system dependencies & Python 3.10 (native on Ubuntu 22.04, no PPA needed)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    curl \
    ca-certificates \
    git \
    build-essential \
    cmake \
    ninja-build \
    libeigen3-dev \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Make python3 the default python command
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Upgrade pip to latest
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch with CUDA 11.8 support
RUN pip install --no-cache-dir \
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu118

# Install additional Python dependencies required by ICP-Flow
RUN pip install --no-cache-dir \
    "numpy<2" \
    "pydantic<2" \
    "dash==2.9.3" \
    scipy \
    pandas \
    scikit-learn \
    matplotlib \
    seaborn \
    plotly \
    parmap \
    hdbscan \
    kiss-icp==0.2.9 \
    iopath \
    fvcore \
    pyyaml \
    tqdm \
    requests \
    torchist \
    open3d \
    pybind11

RUN pip install --no-build-isolation --no-cache-dir "git+https://github.com/facebookresearch/pytorch3d.git"

# Set the working directory
WORKDIR /workspace
