#!/usr/bin/env bash
# Setup GitHub repository for SeamlessExpressive base image

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_REPO_NAME="seamless-base"
DEFAULT_DESCRIPTION="Pre-built Docker image with NVIDIA CUDA 12.4, PyTorch 2.6.0, fairseq2 0.2.*, and seamless_communication"

# Progress indicator
show_progress() {
    local message=$1
    echo -ne "${YELLOW}⏳ ${message}...${NC}"
}

show_success() {
    echo -e "\r${GREEN}✓ ${1}${NC}"
}

show_error() {
    echo -e "\r${RED}✗ ${1}${NC}"
}

# Header
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      SeamlessExpressive Base Repository Setup            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Check if gh CLI is installed
show_progress "Checking GitHub CLI"
if ! command -v gh &> /dev/null; then
    show_error "GitHub CLI (gh) is not installed"
    echo
    echo -e "${YELLOW}Please install GitHub CLI:${NC}"
    echo "  Ubuntu/Debian: sudo apt install gh"
    echo "  macOS: brew install gh"
    echo "  Or visit: https://cli.github.com/"
    exit 1
fi
show_success "GitHub CLI is installed"

# Check if authenticated
show_progress "Checking GitHub authentication"
if ! gh auth status &> /dev/null; then
    show_error "Not authenticated with GitHub"
    echo
    echo -e "${YELLOW}Please authenticate:${NC}"
    echo "  gh auth login"
    exit 1
fi
show_success "Authenticated with GitHub"

# Get repository details
echo
echo -e "${BLUE}Repository Configuration:${NC}"
read -p "Repository name (default: $DEFAULT_REPO_NAME): " REPO_NAME
REPO_NAME=${REPO_NAME:-$DEFAULT_REPO_NAME}

read -p "Description (default: $DEFAULT_DESCRIPTION): " DESCRIPTION
DESCRIPTION=${DESCRIPTION:-$DEFAULT_DESCRIPTION}

read -p "Make repository public? (y/n, default: y): " IS_PUBLIC
IS_PUBLIC=${IS_PUBLIC:-y}

if [[ "$IS_PUBLIC" == "y" ]]; then
    VISIBILITY="public"
else
    VISIBILITY="private"
fi

# Create repository
echo
show_progress "Creating GitHub repository"
if gh repo create "$REPO_NAME" --description "$DESCRIPTION" --$VISIBILITY --clone=false 2>/dev/null; then
    show_success "Repository created: $REPO_NAME"
else
    show_error "Failed to create repository (may already exist)"
    echo
    read -p "Use existing repository? (y/n): " USE_EXISTING
    if [[ "$USE_EXISTING" != "y" ]]; then
        exit 1
    fi
fi

# Get username
USERNAME=$(gh api user -q .login)

# Initialize git repository if needed
if [ ! -d .git ]; then
    echo
    show_progress "Initializing git repository"
    git init
    show_success "Git repository initialized"
fi

# Add .gitignore if it doesn't exist
if [ ! -f .gitignore ]; then
    echo
    show_progress "Creating .gitignore"
    cat > .gitignore << 'EOF'
# Docker
*.log
.docker/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Python
__pycache__/
*.py[cod]
*$py.class
EOF
    show_success "Created .gitignore"
fi

# Configure repository
echo
show_progress "Configuring repository"
git remote remove origin 2>/dev/null || true
git remote add origin "https://github.com/$USERNAME/$REPO_NAME.git"
show_success "Remote configured"

# Initial commit
echo
show_progress "Creating initial commit"
git add .
git commit -m "Initial commit: SeamlessExpressive base image

- CUDA 12.4.1 runtime
- PyTorch 2.6.0+cu124
- fairseq2 0.2.*
- Pre-built seamless_communication wheel
- GitHub Actions workflow for automated builds" || true
show_success "Initial commit created"

# Push to GitHub
echo
show_progress "Pushing to GitHub"
git branch -M main
git push -u origin main
show_success "Pushed to GitHub"

# Enable GitHub Container Registry
echo
show_progress "Configuring GitHub Container Registry"
gh api repos/$USERNAME/$REPO_NAME --method PATCH -f has_wiki=false -f has_projects=false > /dev/null
show_success "Repository settings updated"

# Summary
echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    🎉 Success! 🎉                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${BLUE}Repository created:${NC} https://github.com/$USERNAME/$REPO_NAME"
echo
echo -e "${BLUE}Next steps:${NC}"
echo "1. The GitHub Actions workflow will automatically build the image"
echo "2. Check the Actions tab: https://github.com/$USERNAME/$REPO_NAME/actions"
echo "3. Once built, the image will be available at:"
echo "   ${GREEN}ghcr.io/$USERNAME/$REPO_NAME:cuda12.4-v1${NC}"
echo
echo -e "${BLUE}To use in your main project:${NC}"
echo "   FROM ghcr.io/$USERNAME/$REPO_NAME:cuda12.4-v1"
echo