# SeamlessExpressive Base Image

Pre-built Docker image with NVIDIA CUDA 12.4, PyTorch 2.6.0, fairseq2 0.2.*, and seamless_communication for fast deployments.

## What's Included

- **Base**: `nvidia/cuda:12.4.1-runtime-ubuntu22.04`
- **Python**: 3 (system Python from Ubuntu 22.04)
- **PyTorch**: 2.6.0 with CUDA 12.4 support
- **fairseq2**: 0.2.* (pinned for compatibility)
- **seamless_communication**: Latest from [facebookresearch/seamless_communication](https://github.com/facebookresearch/seamless_communication)
- **Common Dependencies**: FastAPI, Redis, aioboto3, soundfile, and more
- **TBB Allocator**: Intel Threading Building Blocks for optimized memory allocation

## Key Features

- **Two-stage build**: Separates build dependencies from runtime for smaller image
- **Pre-built wheel**: seamless_communication is compiled during build, not at runtime
- **Optimized for GPU**: CUDA 12.4 with all necessary libraries
- **Ready for production**: Includes health check and common service dependencies

## Usage

### Pull the image

```bash
docker pull ghcr.io/mrrobot555/seamless-base:cuda12.4-v1
```

### Use in your Dockerfile

```dockerfile
FROM ghcr.io/mrrobot555/seamless-base:cuda12.4-v1

# Add your application code
WORKDIR /app
COPY requirements.txt /app/
RUN python3 -m pip install --no-cache-dir -r requirements.txt

COPY . /app
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000
CMD ["python3", "api_server.py"]
```

### Build locally

```bash
# Run the interactive build script
./build-and-push.sh

# Or build manually
docker build -t seamless-base:latest .
```

## Directory Structure

- `/data/models/` - Model storage directory (SEAMLESS_MODEL_DIR)
- `/data/output/` - Output directory for generated audio
- `/data/temp/` - Temporary files
- `/app/` - Your application directory

## Environment Variables

- `TORCH_HOME` - `/data/models`
- `SEAMLESS_MODEL_DIR` - `/data/models`
- `SEAMLESS_MODEL` - `seamlessM4T_v2_large`
- `SEAMLESS_VOCODER` - `vocoder_v2`
- `OUTPUT_DIR` - `/data/output`
- `TEMP_DIR` - `/data/temp`
- `CUDA_VISIBLE_DEVICES` - `0`
- `PYTHONUNBUFFERED` - `1`
- `NVIDIA_VISIBLE_DEVICES` - `all`
- `NVIDIA_DRIVER_CAPABILITIES` - `compute,utility`
- `CUDA_MODULE_LOADING` - `LAZY`

## Volume

The `/data` directory is declared as a volume for persistent storage of models and outputs.

## Pre-installed Python Packages

### Core ML/Audio
- PyTorch 2.6.0+cu124
- fairseq2 0.2.*
- seamless_communication (latest)
- torchaudio
- numpy, scipy, soundfile

### Web Framework
- FastAPI
- uvicorn[standard]
- python-multipart

### Infrastructure
- redis, aioredis
- aioboto3, boto3
- structlog
- pydantic, pydantic-settings

## Health Check

The image includes a health check that verifies PyTorch and seamless_communication can be imported:

```bash
python3 -c "import torch; import seamless_communication; print('OK')"
```

## Building the Image

The build process:
1. **Build stage**: Compiles seamless_communication wheel using nvidia/cuda:12.4.1-devel
2. **Runtime stage**: Copies wheel and installs in nvidia/cuda:12.4.1-runtime

This two-stage process reduces the final image size by ~50%.

## GitHub Container Registry

To push to GitHub Container Registry:

1. Create a Personal Access Token with `write:packages` scope
2. Login: `echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin`
3. Use the build script: `./build-and-push.sh`

## License

This image includes:
- NVIDIA CUDA (see NVIDIA license)
- Meta's seamless_communication (MIT License)
- Various Python packages (see individual licenses)

## Troubleshooting

### Out of Memory
- The base image is optimized for L40S GPUs (48GB VRAM)
- Model loading requires ~10GB VRAM at 24kHz sample rate

### fairseq2 Version Issues
- This image pins fairseq2 to 0.2.* for compatibility
- Do NOT upgrade to fairseq2 0.4.x without code changes

### CUDA Errors
- Ensure your host has NVIDIA drivers compatible with CUDA 12.4
- Check GPU availability with `nvidia-smi`