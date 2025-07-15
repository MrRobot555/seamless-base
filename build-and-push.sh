#!/usr/bin/env bash
# Build and push SeamlessExpressive base image with progress indication

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="ghcr.io"
DEFAULT_USERNAME="mrrobot555"
DEFAULT_IMAGE_NAME="seamless-base"
DEFAULT_TAG="cuda12.4-v1"

# Progress bar function
progress_bar() {
    local duration=$1
    local steps=$2
    local step_duration=$((duration / steps))
    
    for ((i=1; i<=steps; i++)); do
        printf "\r["
        printf "%0.s=" $(seq 1 $i)
        printf "%0.s " $(seq $i $((steps-1)))
        printf "] %d%%" $((i * 100 / steps))
        sleep $step_duration
    done
    printf "\r[%0.s=%.0s] 100%%\n" $(seq 1 $steps)
}

# Spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    echo -n " "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Header
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     SeamlessExpressive Base Image Builder & Publisher    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Get user input
echo -e "${YELLOW}Configuration:${NC}"
read -p "GitHub username (default: $DEFAULT_USERNAME): " USERNAME
USERNAME=${USERNAME:-$DEFAULT_USERNAME}

read -p "Image name (default: $DEFAULT_IMAGE_NAME): " IMAGE_NAME
IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

read -p "Tag (default: $DEFAULT_TAG): " TAG
TAG=${TAG:-$DEFAULT_TAG}

FULL_IMAGE_NAME="$REGISTRY/$USERNAME/$IMAGE_NAME:$TAG"

echo
echo -e "${GREEN}Building and pushing:${NC} $FULL_IMAGE_NAME"
echo

# Check Docker daemon
echo -e "${YELLOW}[1/5] Checking Docker daemon...${NC}"
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker daemon is not running!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"
echo

# Check GitHub registry login
echo -e "${YELLOW}[2/5] Checking GitHub Container Registry login...${NC}"
if ! docker pull $REGISTRY/$USERNAME/test:latest >/dev/null 2>&1; then
    echo -e "${YELLOW}Not logged in to GitHub Container Registry${NC}"
    echo "Please provide your GitHub Personal Access Token (PAT) with 'write:packages' scope"
    echo "You can create one at: https://github.com/settings/tokens/new"
    echo
    read -s -p "GitHub PAT: " GITHUB_TOKEN
    echo
    echo "$GITHUB_TOKEN" | docker login $REGISTRY -u $USERNAME --password-stdin
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to login to GitHub Container Registry${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Logged in to GitHub Container Registry${NC}"
echo

# Build image
echo -e "${YELLOW}[3/5] Building Docker image...${NC}"
echo -e "${BLUE}This will take 15-30 minutes depending on your internet speed${NC}"
echo -e "${BLUE}Building seamless_communication from source...${NC}"
echo

# Create a temporary file for build output
BUILD_LOG=$(mktemp)

# Start build in background
docker build -t $FULL_IMAGE_NAME . > $BUILD_LOG 2>&1 &
BUILD_PID=$!

# Monitor build progress
echo -n "Building"
while kill -0 $BUILD_PID 2>/dev/null; do
    # Check last line of build output
    if [ -f $BUILD_LOG ]; then
        LAST_LINE=$(tail -n 1 $BUILD_LOG 2>/dev/null | tr -d '\n')
        if [[ $LAST_LINE == *"Step"* ]]; then
            # Extract step number
            STEP=$(echo $LAST_LINE | sed -n 's/.*Step \([0-9]*\).*/\1/p')
            if [ ! -z "$STEP" ]; then
                printf "\rBuilding... Step %s" "$STEP"
            fi
        fi
    fi
    sleep 1
done

# Check if build succeeded
wait $BUILD_PID
BUILD_EXIT_CODE=$?

if [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo
    echo -e "${RED}✗ Build failed!${NC}"
    echo -e "${RED}Error output:${NC}"
    tail -n 20 $BUILD_LOG
    rm -f $BUILD_LOG
    exit 1
fi

echo
echo -e "${GREEN}✓ Docker image built successfully${NC}"
rm -f $BUILD_LOG
echo

# Tag for latest if on main tag
if [ "$TAG" == "$DEFAULT_TAG" ]; then
    echo -e "${YELLOW}[4/5] Tagging image as latest...${NC}"
    docker tag $FULL_IMAGE_NAME $REGISTRY/$USERNAME/$IMAGE_NAME:latest
    echo -e "${GREEN}✓ Tagged as latest${NC}"
else
    echo -e "${YELLOW}[4/5] Skipping latest tag (not default version)${NC}"
fi
echo

# Push image
echo -e "${YELLOW}[5/5] Pushing image to GitHub Container Registry...${NC}"
echo -e "${BLUE}This may take 10-20 minutes depending on your upload speed${NC}"

# Push with progress
docker push $FULL_IMAGE_NAME &
PUSH_PID=$!

# Show spinner while pushing
echo -n "Pushing image"
spinner $PUSH_PID
wait $PUSH_PID
PUSH_EXIT_CODE=$?

if [ $PUSH_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}✗ Push failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Image pushed successfully${NC}"

# Push latest tag if created
if [ "$TAG" == "$DEFAULT_TAG" ]; then
    echo -n "Pushing latest tag"
    docker push $REGISTRY/$USERNAME/$IMAGE_NAME:latest &
    PUSH_LATEST_PID=$!
    spinner $PUSH_LATEST_PID
    wait $PUSH_LATEST_PID
    echo -e "${GREEN}✓ Latest tag pushed${NC}"
fi

echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 Success! 🎉                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}Your image is now available at:${NC}"
echo -e "${GREEN}  $FULL_IMAGE_NAME${NC}"
if [ "$TAG" == "$DEFAULT_TAG" ]; then
    echo -e "${GREEN}  $REGISTRY/$USERNAME/$IMAGE_NAME:latest${NC}"
fi
echo
echo -e "${BLUE}To use in your Dockerfile:${NC}"
echo -e "${YELLOW}  FROM $FULL_IMAGE_NAME${NC}"
echo
echo -e "${BLUE}To pull the image:${NC}"
echo -e "${YELLOW}  docker pull $FULL_IMAGE_NAME${NC}"
echo
echo -e "${BLUE}Update your main Dockerfile to use this base image:${NC}"
echo -e "${YELLOW}  cd ../
  # Edit Dockerfile to use: FROM $FULL_IMAGE_NAME${NC}"
echo

# Cleanup
echo -e "${BLUE}Image size:${NC}"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep $IMAGE_NAME

echo
echo -e "${GREEN}Build complete!${NC}"