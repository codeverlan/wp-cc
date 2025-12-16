#!/bin/bash

# Deploy to SiteGround Script
# Replaces the Digital Ocean deployment with SiteGround SFTP deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  SiteGround WordPress Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Load environment variables
if [ -f .env.siteground ]; then
    export $(cat .env.siteground | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env.siteground file not found!${NC}"
    echo "Please copy .env.siteground.example to .env.siteground and configure it."
    exit 1
fi

# Validate required variables
if [ -z "$SITEGROUND_USERNAME" ] || [ -z "$SITEGROUND_REMOTE_PATH" ]; then
    echo -e "${RED}Error: Missing required SiteGround configuration!${NC}"
    exit 1
fi

# Expand tilde in SSH key path
SITEGROUND_SSH_KEY_PATH="${SITEGROUND_SSH_KEY_PATH/#\~/$HOME}"

# Check if SSH key exists
if [ ! -f "$SITEGROUND_SSH_KEY_PATH" ]; then
    echo -e "${RED}Error: SSH key not found at $SITEGROUND_SSH_KEY_PATH${NC}"
    exit 1
fi

# Function to deploy files
deploy_files() {
    echo -e "${YELLOW}Starting deployment to SiteGround...${NC}"
    
    # Build exclude options
    EXCLUDE_OPTS=""
    IFS=',' read -ra EXCLUDES <<< "$DEPLOY_EXCLUDE_PATTERNS"
    for pattern in "${EXCLUDES[@]}"; do
        EXCLUDE_OPTS="$EXCLUDE_OPTS --exclude=$pattern"
    done
    
    # Prepare source path
    if [ -z "$LOCAL_SITE_PATH" ]; then
        SOURCE_PATH="."
    else
        SOURCE_PATH="${LOCAL_SITE_PATH/#\~/$HOME}"
    fi
    
    # Set up SSH command with passphrase handling
    if [ -n "$SITEGROUND_SSH_KEY_PASSPHRASE" ]; then
        # Use sshpass if available, or SSH_ASKPASS method
        if command -v sshpass >/dev/null 2>&1; then
            SSH_CMD="sshpass -p '$SITEGROUND_SSH_KEY_PASSPHRASE' ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH}"
        else
            # Create temporary SSH_ASKPASS script
            ASKPASS_SCRIPT=$(mktemp)
            cat > "$ASKPASS_SCRIPT" << EOF
#!/bin/bash
echo "$SITEGROUND_SSH_KEY_PASSPHRASE"
EOF
            chmod +x "$ASKPASS_SCRIPT"
            export SSH_ASKPASS="$ASKPASS_SCRIPT"
            export DISPLAY=:0
            SSH_CMD="ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH}"
        fi
    else
        SSH_CMD="ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH}"
    fi
    
    # Run rsync
    echo "Syncing files from $SOURCE_PATH to SiteGround..."
    rsync -avz \
        --delete \
        $EXCLUDE_OPTS \
        --exclude='.env*' \
        --exclude='deploy-*.sh' \
        --exclude='*.sql' \
        --exclude='*.log' \
        --exclude='wp-config-local.php' \
        --exclude='wp-config-siteground.php' \
        --exclude='docker*' \
        --exclude='Dockerfile' \
        -e "$SSH_CMD" \
        "$SOURCE_PATH/" \
        "${SITEGROUND_USERNAME}@${SITEGROUND_HOST}:${SITEGROUND_REMOTE_PATH}/"
    
    # Clean up temporary askpass script if created
    [ -n "$ASKPASS_SCRIPT" ] && rm -f "$ASKPASS_SCRIPT"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Files deployed successfully!${NC}"
    else
        echo -e "${RED}Deployment failed!${NC}"
        exit 1
    fi
}

# Function to clear SiteGround cache
clear_cache() {
    if [ "$DEPLOY_CLEAR_CACHE" = "true" ]; then
        echo -e "${YELLOW}Clearing SiteGround cache...${NC}"
        ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH} \
            ${SITEGROUND_USERNAME}@${SITEGROUND_HOST} \
            "cd ${SITEGROUND_REMOTE_PATH} && wp sg purge 2>/dev/null || echo 'Cache clear command not available'"
    fi
}

# Function to push to GitHub
push_to_github() {
    if [ "$GITHUB_AUTO_PUSH" = "true" ] && [ -n "$GITHUB_REPO" ]; then
        echo -e "${YELLOW}Pushing to GitHub...${NC}"
        
        # Initialize git if needed
        if [ ! -d .git ]; then
            git init
            git remote add origin "$GITHUB_REPO"
        fi
        
        # Stage and commit changes
        git add -A
        git commit -m "Deployment to SiteGround - $(date '+%Y-%m-%d %H:%M:%S')" || true
        
        # Push to GitHub
        git push -u origin "${GITHUB_BRANCH:-main}" || echo "Push to GitHub failed, continuing..."
    fi
}

# Function to backup before deployment
backup_before_deploy() {
    if [ "$DEPLOY_BACKUP_BEFORE" = "true" ]; then
        echo -e "${YELLOW}Creating backup...${NC}"
        BACKUP_FILE="backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        
        ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH} \
            ${SITEGROUND_USERNAME}@${SITEGROUND_HOST} \
            "cd ${SITEGROUND_REMOTE_PATH} && tar -czf ../${BACKUP_FILE} . && echo 'Backup created: ${BACKUP_FILE}'"
    fi
}

# Main deployment process
echo ""
echo "Deployment Configuration:"
echo "  Host: ${SITEGROUND_HOST}:${SITEGROUND_PORT}"
echo "  User: ${SITEGROUND_USERNAME}"
echo "  Remote Path: ${SITEGROUND_REMOTE_PATH}"
echo "  Local Path: ${LOCAL_SITE_PATH:-current directory}"
echo ""

# Ask for confirmation
read -p "Do you want to proceed with deployment? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Execute deployment steps
backup_before_deploy
push_to_github
deploy_files
clear_cache

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your WordPress site has been deployed to SiteGround."
echo "If this is the first deployment, you may need to:"
echo "  1. Update database credentials in wp-config.php on the server"
echo "  2. Run WordPress installation or import your database"
echo "  3. Update URLs using wp-cli or a search-replace plugin"