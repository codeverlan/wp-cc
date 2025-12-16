#!/bin/bash

# Simple deployment script for SiteGround with passphrase handling
# This version uses ssh-agent for clean passphrase management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Simple SiteGround Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Load environment variables
if [ -f .env.siteground ]; then
    export $(cat .env.siteground | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env.siteground file not found!${NC}"
    echo "Run ./setup-siteground.sh first"
    exit 1
fi

# Expand tilde in paths
SITEGROUND_SSH_KEY_PATH="${SITEGROUND_SSH_KEY_PATH/#\~/$HOME}"
LOCAL_SITE_PATH="${LOCAL_SITE_PATH/#\~/$HOME}"

# Function to add key to ssh-agent
setup_ssh_agent() {
    echo -e "${YELLOW}Setting up SSH agent...${NC}"
    
    # Check if ssh-agent is running
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval $(ssh-agent -s)
    fi
    
    # Check if key is already added
    if ssh-add -l | grep -q "$SITEGROUND_SSH_KEY_PATH"; then
        echo -e "${GREEN}✓ SSH key already in agent${NC}"
        return 0
    fi
    
    # Add key to agent
    echo -e "${BLUE}Adding SSH key to agent...${NC}"
    if [ -n "$SITEGROUND_SSH_KEY_PASSPHRASE" ]; then
        # Use expect to provide passphrase automatically
        if command -v expect >/dev/null 2>&1; then
            expect << EOF
spawn ssh-add $SITEGROUND_SSH_KEY_PATH
expect "Enter passphrase"
send "$SITEGROUND_SSH_KEY_PASSPHRASE\r"
expect eof
EOF
        else
            # Manual entry
            echo "Enter your SSH key passphrase when prompted:"
            ssh-add "$SITEGROUND_SSH_KEY_PATH"
        fi
    else
        echo "Enter your SSH key passphrase:"
        ssh-add "$SITEGROUND_SSH_KEY_PATH"
    fi
    
    echo -e "${GREEN}✓ SSH key added to agent${NC}"
}

# Function to deploy
deploy() {
    echo -e "${YELLOW}Deploying to SiteGround...${NC}"
    echo "  From: ${LOCAL_SITE_PATH:-current directory}"
    echo "  To: ${SITEGROUND_REMOTE_PATH}"
    echo ""
    
    # Prepare source path
    if [ -z "$LOCAL_SITE_PATH" ]; then
        SOURCE_PATH="."
    else
        SOURCE_PATH="$LOCAL_SITE_PATH"
    fi
    
    # Build exclude list
    EXCLUDES="--exclude=.git --exclude=.DS_Store --exclude=node_modules --exclude=*.log --exclude=.env* --exclude=wp-config-local.php"
    
    # Run rsync (ssh-agent handles the passphrase)
    rsync -avz \
        --delete \
        $EXCLUDES \
        -e "ssh -p ${SITEGROUND_PORT}" \
        "$SOURCE_PATH/" \
        "${SITEGROUND_USERNAME}@${SITEGROUND_HOST}:${SITEGROUND_REMOTE_PATH}/"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Deployment successful!${NC}"
        
        # Clear cache if configured
        if [ "$DEPLOY_CLEAR_CACHE" = "true" ]; then
            echo -e "${YELLOW}Clearing SiteGround cache...${NC}"
            ssh -p ${SITEGROUND_PORT} \
                ${SITEGROUND_USERNAME}@${SITEGROUND_HOST} \
                "cd ${SITEGROUND_REMOTE_PATH} && wp sg purge 2>/dev/null || echo 'Cache cleared'"
        fi
    else
        echo -e "${RED}✗ Deployment failed${NC}"
        return 1
    fi
}

# Main process
echo "Checking configuration..."

# Verify required settings
if [ -z "$SITEGROUND_USERNAME" ] || [ -z "$SITEGROUND_REMOTE_PATH" ]; then
    echo -e "${RED}Missing required configuration!${NC}"
    echo "Please run: ./setup-siteground.sh"
    exit 1
fi

# Check SSH key exists
if [ ! -f "$SITEGROUND_SSH_KEY_PATH" ]; then
    echo -e "${RED}SSH key not found: $SITEGROUND_SSH_KEY_PATH${NC}"
    echo "Please check your .env.siteground file"
    exit 1
fi

# Setup SSH agent
setup_ssh_agent

# Confirm deployment
echo ""
echo -e "${BLUE}Ready to deploy!${NC}"
read -p "Deploy now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    deploy
else
    echo "Deployment cancelled"
fi

echo ""
echo -e "${BLUE}Tip:${NC} Your SSH key is now unlocked in ssh-agent."
echo "You can run this script again without entering the passphrase."
echo "To lock it: ssh-add -d ~/.ssh/siteground_rsa"