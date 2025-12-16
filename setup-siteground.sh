#!/bin/bash

# Setup Script for SiteGround WordPress Deployment
# Initializes local environment and prepares for SiteGround deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SiteGround WordPress Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to create .env file
setup_env_file() {
    if [ -f .env.siteground ]; then
        echo -e "${YELLOW}Warning: .env.siteground already exists${NC}"
        read -p "Do you want to overwrite it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    cp .env.siteground.example .env.siteground
    echo -e "${GREEN}Created .env.siteground file${NC}"
    echo "Please edit .env.siteground with your SiteGround credentials"
}

# Function to setup SSH key
setup_ssh_key() {
    echo ""
    echo -e "${YELLOW}SSH Key Setup${NC}"
    echo -e "${BLUE}Important: SiteGround requires a passphrase for SSH keys${NC}"
    echo ""
    echo "1. Log into SiteGround Client Area"
    echo "2. Go to Profile → Multisite SFTP Access"
    echo "3. Generate SSH key WITH a passphrase (required by SiteGround)"
    echo "4. Download the private key"
    echo ""
    
    read -p "Enter the path to your SiteGround SSH private key (or press Enter to skip): " ssh_key_path
    
    if [ -n "$ssh_key_path" ]; then
        # Expand tilde
        ssh_key_path="${ssh_key_path/#\~/$HOME}"
        
        if [ -f "$ssh_key_path" ]; then
            # Set correct permissions
            chmod 600 "$ssh_key_path"
            echo -e "${GREEN}SSH key permissions set correctly${NC}"
            
            # Update .env file
            sed -i.bak "s|SITEGROUND_SSH_KEY_PATH=.*|SITEGROUND_SSH_KEY_PATH=$ssh_key_path|" .env.siteground
            echo -e "${GREEN}Updated SSH key path in .env.siteground${NC}"
            
            # Ask for passphrase
            echo ""
            echo -e "${YELLOW}SSH Key Passphrase${NC}"
            echo "Enter the passphrase you set when creating the SSH key on SiteGround"
            echo "(This will be saved in .env.siteground for automated deployments)"
            read -s -p "Passphrase: " ssh_passphrase
            echo ""
            
            if [ -n "$ssh_passphrase" ]; then
                # Update passphrase in .env file
                sed -i.bak "s|SITEGROUND_SSH_KEY_PASSPHRASE=.*|SITEGROUND_SSH_KEY_PASSPHRASE=$ssh_passphrase|" .env.siteground
                echo -e "${GREEN}Passphrase saved in .env.siteground${NC}"
            else
                echo -e "${YELLOW}Warning: No passphrase saved. You'll be prompted each time.${NC}"
            fi
        else
            echo -e "${RED}SSH key file not found: $ssh_key_path${NC}"
        fi
    fi
}

# Function to test SSH connection
test_connection() {
    echo ""
    echo -e "${YELLOW}Testing SiteGround connection...${NC}"
    
    # Load environment variables
    if [ -f .env.siteground ]; then
        export $(cat .env.siteground | grep -v '^#' | xargs)
    else
        echo -e "${RED}Error: .env.siteground not found${NC}"
        return 1
    fi
    
    # Expand tilde in SSH key path
    SITEGROUND_SSH_KEY_PATH="${SITEGROUND_SSH_KEY_PATH/#\~/$HOME}"
    
    # Test connection
    ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH} \
        -o ConnectTimeout=10 \
        ${SITEGROUND_USERNAME}@${SITEGROUND_HOST} \
        "echo 'Connection successful!'" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Connection to SiteGround successful!${NC}"
        return 0
    else
        echo -e "${RED}✗ Connection failed. Please check your credentials.${NC}"
        return 1
    fi
}

# Function to setup Local integration
setup_local_integration() {
    echo ""
    echo -e "${YELLOW}Local by Flywheel Integration${NC}"
    
    # Check if running from Local site directory
    if [[ "$PWD" == *"/app/public"* ]]; then
        echo -e "${GREEN}✓ Detected Local site directory${NC}"
        LOCAL_PATH="$PWD"
    else
        echo "Enter the path to your Local WordPress site"
        echo "Example: ~/Local Sites/site-name/app/public"
        read -p "Path: " local_path
        
        if [ -d "$local_path" ]; then
            LOCAL_PATH="$local_path"
            # Update .env file
            sed -i.bak "s|LOCAL_SITE_PATH=.*|LOCAL_SITE_PATH=$local_path|" .env.siteground
            echo -e "${GREEN}✓ Local site path configured${NC}"
        else
            echo -e "${YELLOW}Local site path not found, skipping...${NC}"
        fi
    fi
}

# Function to copy wp-config for SiteGround
setup_wp_config() {
    echo ""
    echo -e "${YELLOW}Setting up WordPress configuration...${NC}"
    
    if [ -f wp-config-siteground.php ]; then
        echo "Found wp-config-siteground.php"
        
        if [ -n "$LOCAL_PATH" ] && [ -d "$LOCAL_PATH" ]; then
            cp wp-config-siteground.php "$LOCAL_PATH/wp-config-siteground.php"
            echo -e "${GREEN}✓ Copied wp-config-siteground.php to Local site${NC}"
        fi
        
        echo ""
        echo "Note: You'll need to:"
        echo "1. Update database credentials in wp-config-siteground.php for production"
        echo "2. Rename to wp-config.php on SiteGround server after first deployment"
    fi
}

# Function to initialize Git repository
setup_git() {
    echo ""
    echo -e "${YELLOW}Git Repository Setup${NC}"
    
    if [ -d .git ]; then
        echo -e "${GREEN}✓ Git repository already initialized${NC}"
    else
        read -p "Initialize Git repository? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git init
            
            # Create .gitignore if it doesn't exist
            if [ ! -f .gitignore ]; then
                cat > .gitignore << 'EOF'
# WordPress Core
/wp-admin/
/wp-includes/
/wp-*.php
/index.php
/license.txt
/readme.html

# Configuration
wp-config.php
wp-config-local.php
.htaccess

# Content
/wp-content/uploads/
/wp-content/upgrade/
/wp-content/cache/
/wp-content/backup*/

# Environment
.env
.env.*
!.env.*.example

# Logs and databases
*.log
*.sql
*.sqlite
error_log

# OS files
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.sublime-*

# Docker (if still present)
docker-compose.yml
Dockerfile
EOF
                echo -e "${GREEN}✓ Created .gitignore${NC}"
            fi
            
            git add -A
            git commit -m "Initial commit - SiteGround WordPress setup" || true
            echo -e "${GREEN}✓ Git repository initialized${NC}"
        fi
    fi
}

# Function to make scripts executable
setup_permissions() {
    echo ""
    echo -e "${YELLOW}Setting script permissions...${NC}"
    chmod +x deploy-to-siteground.sh 2>/dev/null || true
    chmod +x setup-siteground.sh 2>/dev/null || true
    chmod +x migrate-to-siteground.sh 2>/dev/null || true
    echo -e "${GREEN}✓ Scripts are now executable${NC}"
}

# Main setup flow
echo "This script will help you set up WordPress deployment to SiteGround."
echo ""

# Step 1: Environment file
echo -e "${BLUE}Step 1: Environment Configuration${NC}"
setup_env_file

# Step 2: SSH Key
echo ""
echo -e "${BLUE}Step 2: SSH Key Configuration${NC}"
setup_ssh_key

# Step 3: Test connection
echo ""
echo -e "${BLUE}Step 3: Connection Test${NC}"
test_connection

# Step 4: Local integration
echo ""
echo -e "${BLUE}Step 4: Local Integration${NC}"
setup_local_integration

# Step 5: WordPress config
echo ""
echo -e "${BLUE}Step 5: WordPress Configuration${NC}"
setup_wp_config

# Step 6: Git setup
echo ""
echo -e "${BLUE}Step 6: Version Control${NC}"
setup_git

# Step 7: Permissions
echo ""
echo -e "${BLUE}Step 7: Final Setup${NC}"
setup_permissions

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Edit .env.siteground with your SiteGround credentials"
echo "2. Test deployment with: ./deploy-to-siteground.sh"
echo "3. For database migration, use: ./migrate-to-siteground.sh"
echo ""
echo "For Local addon integration:"
echo "- Restart Local to see the SiteGround Deploy addon"
echo "- Configure deployment settings in the addon UI"
echo ""
echo -e "${GREEN}Happy deploying!${NC}"