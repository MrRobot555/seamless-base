#!/usr/bin/env bash
# Helper script to login to GitHub Container Registry

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}GitHub Container Registry Login${NC}"
echo

# Get username
read -p "GitHub username: " USERNAME

# Get token
echo -e "${YELLOW}Enter your GitHub Personal Access Token (PAT) with 'write:packages' scope${NC}"
echo -e "${YELLOW}Create one at: https://github.com/settings/tokens/new${NC}"
read -s -p "GitHub PAT: " GITHUB_TOKEN
echo

# Login
echo "$GITHUB_TOKEN" | docker login ghcr.io -u $USERNAME --password-stdin

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully logged in to GitHub Container Registry${NC}"
    echo -e "${GREEN}You can now run ./build-and-push.sh${NC}"
else
    echo -e "${RED}✗ Login failed${NC}"
    exit 1
fi