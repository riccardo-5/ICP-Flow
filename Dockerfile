FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

# Configure environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV TORCH_CUDA_ARCH_LIST="7.5 8.0 8.6 8.9"
ENV CUDA_HOME=/usr/local/cuda

# Install system dependencies & Python 3.9 via deadsnakes PPA
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.9 \
    python3.9-dev \
    python3.9-distutils \
    curl \
    git \
    build-essential \
    cmake \
    ninja-build \
    eigen3-dev \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.9 as default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.9 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

# Install pip for python3.9
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.9

# Install PyTorch with CUDA 11.8 support
RUN pip install --no-cache-dir \
    torch==2.4.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Install additional Python dependencies required by ICP-Flow
RUN pip install --no-cache-dir \
    numpy \
    scipy \
    pandas \
    scikit-learn \
    matplotlib \
    pyyaml \
    tqdm \
    requests \
    torchist \
    open3d-cpu \
    pybind11

# Set the working directory
WORKDIR /workspace
