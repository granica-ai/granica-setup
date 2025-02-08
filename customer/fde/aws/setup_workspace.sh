#!/bin/bash
set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define directories
CURRENT_DIR=$(pwd)
FDE_WORKSPACE_DIR="/home/terraform-workspaces/fde"

echo -e "${YELLOW}Setting up FDE workspace...${NC}"

# Create workspace directory if it doesn't exist
if [ ! -d "$FDE_WORKSPACE_DIR" ]; then
    sudo mkdir -p "$FDE_WORKSPACE_DIR"
    echo -e "${GREEN}Created workspace directory at $FDE_WORKSPACE_DIR${NC}"
fi

# Clean up any existing .terraform directories in current directory
if [ -d ".terraform" ]; then
    rm -rf .terraform
    echo -e "${GREEN}Cleaned up existing .terraform directory in source${NC}"
fi

# Copy all files except the script itself
for file in *; do
    if [ "$file" != "setup_workspace.sh" ]; then
        sudo cp -r "$file" "$FDE_WORKSPACE_DIR/"
    fi
done
echo -e "${GREEN}Copied FDE configuration files to workspace${NC}"

# Create symlink for easy access (recreate if exists)
if [ -L ~/fde-workspace ]; then
    rm ~/fde-workspace
fi
ln -sf $FDE_WORKSPACE_DIR ~/fde-workspace
echo -e "${GREEN}Created symlink at ~/fde-workspace${NC}"

# Clean up any existing .terraform directories in workspace
if [ -d "$FDE_WORKSPACE_DIR/.terraform" ]; then
    sudo rm -rf "$FDE_WORKSPACE_DIR/.terraform"
    echo -e "${GREEN}Cleaned up existing .terraform directory in workspace${NC}"
fi

# Set permissions for the workspace directory
sudo chown -R $USER:$USER "$FDE_WORKSPACE_DIR"
sudo chmod -R 755 "$FDE_WORKSPACE_DIR"

echo -e "${YELLOW}Setup complete!${NC}"
echo -e "${YELLOW}To work with FDE deployment:${NC}"
echo -e "1. ${GREEN}cd ~/fde-workspace${NC}"
echo -e "2. ${GREEN}terraform init -backend-config=backend.conf${NC}"
echo -e "3. ${GREEN}terraform plan${NC}"
echo -e "4. ${GREEN}terraform apply${NC}" 
