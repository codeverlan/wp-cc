#!/bin/bash

# Migrate WordPress to SiteGround
# Handles database export/import and URL replacement

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  WordPress Migration to SiteGround${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Load environment variables
if [ -f .env.siteground ]; then
    export $(cat .env.siteground | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env.siteground file not found!${NC}"
    exit 1
fi

# Expand paths
SITEGROUND_SSH_KEY_PATH="${SITEGROUND_SSH_KEY_PATH/#\~/$HOME}"
LOCAL_SITE_PATH="${LOCAL_SITE_PATH/#\~/$HOME}"

# Function to export local database
export_database() {
    echo -e "${YELLOW}Exporting local database...${NC}"
    
    # Try to detect Local's database settings
    if [ -f "$LOCAL_SITE_PATH/wp-config.php" ]; then
        DB_NAME=$(grep "define.*DB_NAME" "$LOCAL_SITE_PATH/wp-config.php" | cut -d "'" -f 4)
        DB_USER=$(grep "define.*DB_USER" "$LOCAL_SITE_PATH/wp-config.php" | cut -d "'" -f 4)
        DB_PASS=$(grep "define.*DB_PASSWORD" "$LOCAL_SITE_PATH/wp-config.php" | cut -d "'" -f 4)
        DB_HOST=$(grep "define.*DB_HOST" "$LOCAL_SITE_PATH/wp-config.php" | cut -d "'" -f 4)
    else
        # Default Local settings
        DB_NAME="local"
        DB_USER="root"
        DB_PASS="root"
        DB_HOST="localhost"
    fi
    
    # Export database
    EXPORT_FILE="wordpress-export-$(date +%Y%m%d-%H%M%S).sql"
    
    echo "Exporting database: $DB_NAME"
    mysqldump -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" "$DB_NAME" > "$EXPORT_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database exported to $EXPORT_FILE${NC}"
        echo "$EXPORT_FILE"
    else
        echo -e "${RED}Failed to export database. Using wp-cli instead...${NC}"
        
        # Try with wp-cli
        cd "$LOCAL_SITE_PATH"
        wp db export "$EXPORT_FILE" --add-drop-table
        cd - > /dev/null
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Database exported with wp-cli${NC}"
            echo "$EXPORT_FILE"
        else
            echo -e "${RED}Database export failed${NC}"
            return 1
        fi
    fi
}

# Function to upload database to SiteGround
upload_database() {
    local db_file=$1
    echo -e "${YELLOW}Uploading database to SiteGround...${NC}"
    
    scp -P ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH} \
        "$db_file" \
        "${SITEGROUND_USERNAME}@${SITEGROUND_HOST}:${SITEGROUND_REMOTE_PATH}/"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database uploaded${NC}"
    else
        echo -e "${RED}Failed to upload database${NC}"
        return 1
    fi
}

# Function to import database on SiteGround
import_database() {
    local db_file=$1
    echo -e "${YELLOW}Importing database on SiteGround...${NC}"
    
    # Get database credentials from SiteGround
    echo "You'll need your SiteGround database credentials."
    echo "Find them in Site Tools → Site → MySQL → Databases"
    echo ""
    read -p "Database name: " sg_db_name
    read -p "Database user: " sg_db_user
    read -s -p "Database password: " sg_db_pass
    echo ""
    
    # Import database
    ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH} \
        ${SITEGROUND_USERNAME}@${SITEGROUND_HOST} << EOF
cd ${SITEGROUND_REMOTE_PATH}

# Import database
mysql -u ${sg_db_user} -p${sg_db_pass} ${sg_db_name} < $(basename $db_file)

# Check if wp-cli is available
if command -v wp &> /dev/null; then
    echo "Running search-replace for URLs..."
    wp search-replace 'http://localhost' 'https://yourdomain.com' --all-tables
    wp search-replace 'https://localhost' 'https://yourdomain.com' --all-tables
    wp search-replace '.local' '.com' --all-tables
    
    # Clear cache
    wp cache flush
    wp sg purge
else
    echo "wp-cli not available. You'll need to update URLs manually."
fi

# Clean up
rm $(basename $db_file)

echo "Database import complete!"
EOF
    
    echo -e "${GREEN}✓ Database imported and URLs updated${NC}"
}

# Function to update wp-config on SiteGround
update_wp_config() {
    echo -e "${YELLOW}Updating wp-config.php on SiteGround...${NC}"
    
    echo "Enter your SiteGround database credentials:"
    read -p "Database name: " sg_db_name
    read -p "Database user: " sg_db_user
    read -s -p "Database password: " sg_db_pass
    echo ""
    read -p "Database host (usually localhost): " sg_db_host
    sg_db_host=${sg_db_host:-localhost}
    
    # Create temporary wp-config with SiteGround credentials
    cat > wp-config-temp.php << EOF
<?php
// SiteGround Database Configuration
define('DB_NAME', '${sg_db_name}');
define('DB_USER', '${sg_db_user}');
define('DB_PASSWORD', '${sg_db_pass}');
define('DB_HOST', '${sg_db_host}');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// Include the rest of the configuration
if (file_exists(dirname(__FILE__) . '/wp-config-siteground.php')) {
    require_once(dirname(__FILE__) . '/wp-config-siteground.php');
}
EOF
    
    # Upload the config
    scp -P ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH} \
        wp-config-temp.php \
        "${SITEGROUND_USERNAME}@${SITEGROUND_HOST}:${SITEGROUND_REMOTE_PATH}/wp-config.php"
    
    # Clean up
    rm wp-config-temp.php
    
    echo -e "${GREEN}✓ wp-config.php updated on SiteGround${NC}"
}

# Function to sync uploads folder
sync_uploads() {
    echo -e "${YELLOW}Syncing uploads folder...${NC}"
    
    if [ -d "$LOCAL_SITE_PATH/wp-content/uploads" ]; then
        rsync -avz \
            -e "ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH}" \
            "$LOCAL_SITE_PATH/wp-content/uploads/" \
            "${SITEGROUND_USERNAME}@${SITEGROUND_HOST}:${SITEGROUND_REMOTE_PATH}/wp-content/uploads/"
        
        echo -e "${GREEN}✓ Uploads folder synced${NC}"
    else
        echo -e "${YELLOW}No uploads folder found${NC}"
    fi
}

# Function to set proper permissions
set_permissions() {
    echo -e "${YELLOW}Setting proper file permissions...${NC}"
    
    ssh -p ${SITEGROUND_PORT} -i ${SITEGROUND_SSH_KEY_PATH} \
        ${SITEGROUND_USERNAME}@${SITEGROUND_HOST} << EOF
cd ${SITEGROUND_REMOTE_PATH}

# Set directory permissions
find . -type d -exec chmod 755 {} \;

# Set file permissions
find . -type f -exec chmod 644 {} \;

# Make wp-config.php more secure
chmod 600 wp-config.php

# Set proper ownership for uploads
chmod -R 755 wp-content/uploads

echo "Permissions set!"
EOF
    
    echo -e "${GREEN}✓ File permissions configured${NC}"
}

# Main migration menu
echo "WordPress Migration Options:"
echo "1. Full migration (database + files + uploads)"
echo "2. Database only"
echo "3. Files only"
echo "4. Uploads only"
echo "5. Update wp-config.php only"
echo ""
read -p "Select option (1-5): " option

case $option in
    1)
        # Full migration
        echo -e "${BLUE}Starting full migration...${NC}"
        
        # Export and upload database
        DB_FILE=$(export_database)
        if [ -n "$DB_FILE" ]; then
            upload_database "$DB_FILE"
            import_database "$DB_FILE"
        fi
        
        # Deploy files
        ./deploy-to-siteground.sh
        
        # Sync uploads
        sync_uploads
        
        # Update config
        update_wp_config
        
        # Set permissions
        set_permissions
        ;;
    
    2)
        # Database only
        DB_FILE=$(export_database)
        if [ -n "$DB_FILE" ]; then
            upload_database "$DB_FILE"
            import_database "$DB_FILE"
        fi
        ;;
    
    3)
        # Files only
        ./deploy-to-siteground.sh
        ;;
    
    4)
        # Uploads only
        sync_uploads
        ;;
    
    5)
        # wp-config only
        update_wp_config
        ;;
    
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Migration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Post-migration checklist:"
echo "□ Test your site at the SiteGround URL"
echo "□ Update DNS records to point to SiteGround"
echo "□ Set up SSL certificate in Site Tools"
echo "□ Configure SiteGround's caching and optimization"
echo "□ Test all functionality"
echo "□ Set up regular backups"