# syntax=docker/dockerfile:1

##############################
# 1) BUILD STAGE — build seamless_communication wheel
##############################
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS build

ENV DEBIAN_FRONTEND=noninteractive \
    TORCH_VERSION=2.6.0+cu124 \
    FAIRSEQ2_PYTORCH_VERSION=2.6.0 \
    SEAMLESS_BRANCH=main

# 1.1) System deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git wget build-essential cmake ninja-build \
      python3 python3-pip python3-dev \
      libsndfile1 libsndfile1-dev \
      ffmpeg sox libsox-dev \
      libtbb-dev libtbb2 libtbbmalloc2 && \
    rm -rf /var/lib/apt/lists/*

# 1.2) Python tooling + matching torch & fairseq2 (pinned to 0.2.*)
RUN python3 -m pip install --upgrade pip setuptools wheel numpy \
      --retries 5 && \
    python3 -m pip install \
      --extra-index-url https://download.pytorch.org/whl/cu124 \
      torch==${TORCH_VERSION} \
      --retries 5 && \
    python3 -m pip install \
      --index-url https://fair.pkg.atmeta.com/fairseq2/whl/pt${FAIRSEQ2_PYTORCH_VERSION}/cu124 \
      --extra-index-url https://pypi.org/simple \
      'fairseq2==0.2.*' \
      --retries 5

# 1.3) Clone & wheel seamless_communication
WORKDIR /tmp
RUN git clone --depth 1 -b ${SEAMLESS_BRANCH} \
       https://github.com/facebookresearch/seamless_communication.git seamless_comm
WORKDIR /tmp/seamless_comm
RUN python3 -m pip wheel .[gpu] --no-deps -w /tmp/wheels \
      --retries 5 && \
    ls -la /tmp/wheels/

##############################
# 2) RUNTIME STAGE
##############################
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TORCH_VERSION=2.6.0+cu124 \
    FAIRSEQ2_PYTORCH_VERSION=2.6.0 \
    TORCH_HOME=/data/models \
    SEAMLESS_MODEL_DIR=/data/models

# 2.1) Minimal runtime deps
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git python3 python3-pip \
      libsndfile1 sox ffmpeg libsox-dev \
      libtbb2 libtbbmalloc2 && \
    rm -rf /var/lib/apt/lists/*

# 2.2) Symlink TBB allocator
RUN ln -sf /usr/lib/x86_64-linux-gnu/libtbbmalloc.so.2 \
           /usr/lib/x86_64-linux-gnu/libtbbmalloc.so

# 2.3) Install torch, fairseq2 (0.2.*), then seamless_communication wheel
COPY --from=build /tmp/wheels /tmp/wheels

# 2.3.1) Upgrade pip
RUN python3 -m pip install --upgrade pip setuptools wheel --retries 5

# 2.3.2) Install PyTorch
RUN python3 -m pip install \
      --extra-index-url https://download.pytorch.org/whl/cu124 \
      torch==${TORCH_VERSION} \
      --retries 5

# 2.3.3) Install fairseq2
RUN python3 -m pip install \
      --index-url https://fair.pkg.atmeta.com/fairseq2/whl/pt${FAIRSEQ2_PYTORCH_VERSION}/cu124 \
      --extra-index-url https://pypi.org/simple \
      'fairseq2==0.2.*' \
      --retries 5

# 2.3.4) Install seamless_communication wheel
RUN ls -la /tmp/wheels/ && \
    python3 -m pip install /tmp/wheels/*.whl --retries 5

# Stop here for base image - the main Dockerfile will handle the rest
WORKDIR /app