#!/bin/bash

# Install sshpass for automated SSH passphrase handling
# Required for SiteGround deployments with password-protected keys

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Installing sshpass for macOS${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if sshpass is already installed
if command -v sshpass >/dev/null 2>&1; then
    echo -e "${GREEN}✓ sshpass is already installed${NC}"
    sshpass -V
    exit 0
fi

# Check for Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}Homebrew is not installed${NC}"
    echo "Installing Homebrew first..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo -e "${YELLOW}Installing sshpass...${NC}"
echo ""

# sshpass is not in the main Homebrew repo, need to use a custom formula
echo "sshpass is not available in the main Homebrew repository due to security concerns."
echo "However, for SiteGround deployments with passphrase-protected keys, we have options:"
echo ""
echo -e "${BLUE}Option 1: Use expect (Recommended)${NC}"
echo "Install expect and use it for automation:"
echo "  brew install expect"
echo ""
echo -e "${BLUE}Option 2: Install sshpass from source${NC}"
echo "Download and compile sshpass manually"
echo ""
echo -e "${BLUE}Option 3: Use SSH Agent (Most Secure)${NC}"
echo "Add your key to ssh-agent with passphrase:"
echo "  ssh-add ~/.ssh/siteground_rsa"
echo ""

read -p "Choose option (1-3): " option

case $option in
    1)
        echo "Installing expect..."
        brew install expect
        
        # Create expect wrapper script
        cat > deploy-with-expect.sh << 'EOF'
#!/usr/bin/expect -f

# Get passphrase from environment
set passphrase $env(SITEGROUND_SSH_KEY_PASSPHRASE)
set timeout -1

# Run the actual deployment
spawn ./deploy-to-siteground.sh
expect {
    "Enter passphrase" {
        send "$passphrase\r"
        exp_continue
    }
    "password:" {
        send "$passphrase\r"
        exp_continue
    }
    eof
}
EOF
        chmod +x deploy-with-expect.sh
        echo -e "${GREEN}✓ Expect installed and wrapper created${NC}"
        echo "Use: ./deploy-with-expect.sh to deploy with automatic passphrase"
        ;;
    
    2)
        echo "Installing sshpass from source..."
        cd /tmp
        curl -O -L https://sourceforge.net/projects/sshpass/files/sshpass/1.09/sshpass-1.09.tar.gz
        tar xvf sshpass-1.09.tar.gz
        cd sshpass-1.09
        ./configure
        make
        sudo make install
        echo -e "${GREEN}✓ sshpass installed from source${NC}"
        ;;
    
    3)
        echo -e "${YELLOW}Using SSH Agent${NC}"
        echo ""
        echo "To add your key to ssh-agent:"
        echo "  1. Start ssh-agent: eval \$(ssh-agent -s)"
        echo "  2. Add your key: ssh-add ~/.ssh/siteground_rsa"
        echo "  3. Enter passphrase when prompted"
        echo "  4. Deploy without passphrase prompts"
        echo ""
        echo "The key will remain unlocked until you log out."
        
        read -p "Add key to ssh-agent now? (y/n): " add_now
        if [[ $add_now =~ ^[Yy]$ ]]; then
            eval $(ssh-agent -s)
            ssh-add ~/.ssh/siteground_rsa
            echo -e "${GREEN}✓ Key added to ssh-agent${NC}"
        fi
        ;;
    
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"