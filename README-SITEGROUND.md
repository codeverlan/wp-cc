# WordPress Local + SiteGround Deployment System 🚀

Complete WordPress development and deployment pipeline using Local by Flywheel for development and SiteGround for hosting. Replaces Docker + Digital Ocean workflow with a more user-friendly approach.

## Features

- **Local Development**: Use Local by Flywheel instead of Docker
- **SiteGround Hosting**: Deploy to SiteGround with multisite SFTP
- **GitHub Integration**: Version control and backup
- **One-Click Deployment**: Automated deployment scripts
- **Environment-Aware Config**: Auto-detects Local vs SiteGround
- **Custom Theme & Plugin**: Ready-to-use WordPress components
- **Local Addon**: Visual deployment interface in Local

## System Components

### 1. Local Development Environment
- Local by Flywheel for WordPress development
- No Docker required
- Visual interface for site management
- One-click WordPress installation

### 2. SiteGround Deployment Tools
- `deploy-to-siteground.sh` - Deploy files to SiteGround
- `migrate-to-siteground.sh` - Migrate database and content
- `setup-siteground.sh` - Initial configuration wizard

### 3. Local Addon (local-siteground-deploy)
- Visual deployment interface within Local
- Configure once, deploy many times
- Deployment history tracking
- GitHub integration

## Quick Start Guide

### Prerequisites
- [Local by Flywheel](https://localwp.com/) installed
- SiteGround hosting account with multisite SFTP access
- Git installed locally
- SSH key for SiteGround

### Step 1: Initial Setup

```bash
# Clone this repository
git clone https://github.com/yourusername/wp-cc.git
cd wp-cc

# Run the setup wizard
chmod +x setup-siteground.sh
./setup-siteground.sh
```

The setup wizard will:
- Create your `.env.siteground` configuration file
- Configure SSH key permissions
- Test SiteGround connection
- Initialize Git repository
- Set up WordPress configuration

### Step 2: Configure SiteGround Access

1. **Get Multisite SFTP Credentials**:
   - Log into SiteGround Client Area
   - Go to Profile → Multisite SFTP Access
   - Click "Create" to generate SSH key
   - Download private key to `~/.ssh/siteground_rsa`

2. **Edit `.env.siteground`**:
```bash
SITEGROUND_HOST=sftp.siteground.net
SITEGROUND_PORT=18765
SITEGROUND_USERNAME=your_username
SITEGROUND_SSH_KEY_PATH=~/.ssh/siteground_rsa
SITEGROUND_REMOTE_PATH=/home/user/www/yourdomain.com/public_html
```

### Step 3: Create Site in Local

1. Open Local by Flywheel
2. Click "Create a new site"
3. Choose **Custom** environment:
   - PHP: 8.2.x
   - Web Server: **Apache** (not nginx)
   - Database: **MySQL 5.7.x**
4. Name your site (e.g., "parenting")

### Step 4: Copy Theme and Plugin

```bash
# Copy custom theme to Local site
cp -r wp-content/themes/my-custom-theme ~/Local\ Sites/your-site/app/public/wp-content/themes/

# Copy custom post types plugin
cp -r wp-content/plugins/custom-post-types ~/Local\ Sites/your-site/app/public/wp-content/plugins/

# Copy SiteGround-aware wp-config
cp wp-config-siteground.php ~/Local\ Sites/your-site/app/public/
```

### Step 5: Deploy to SiteGround

```bash
# Deploy files only
./deploy-to-siteground.sh

# Or full migration with database
./migrate-to-siteground.sh
```

## Using the Local Addon

### Installation
The Local addon provides a visual interface for deployment:

```bash
# Navigate to addon directory
cd ~/projects/local-siteground-deploy

# Install and build
npm install
npm run build

# Link to Local
ln -sf $(pwd) ~/Library/Application\ Support/Local/addons/local-siteground-deploy
```

### Usage
1. Restart Local
2. Open your WordPress site
3. Click "SiteGround Deploy" in the left menu
4. Configure your credentials in the Configuration tab
5. Click "Deploy to SiteGround" in the Deploy tab

## Deployment Workflow

### Development Workflow
```
1. Develop locally in Local by Flywheel
   ↓
2. Test changes on local site
   ↓
3. Commit to Git (optional)
   ↓
4. Deploy to SiteGround
   ↓
5. Clear SiteGround cache
```

### File Structure
```
wp-cc/
├── .env.siteground           # Your credentials (git-ignored)
├── .env.siteground.example   # Template for credentials
├── deploy-to-siteground.sh   # Deployment script
├── migrate-to-siteground.sh  # Migration script
├── setup-siteground.sh       # Setup wizard
├── wp-config-siteground.php  # Environment-aware config
├── wp-content/
│   ├── themes/
│   │   └── my-custom-theme/  # Custom theme
│   └── plugins/
│       └── custom-post-types/ # CPT plugin
└── README-SITEGROUND.md      # This file
```

## Configuration Files

### .env.siteground
Contains all deployment configuration:
- SiteGround SFTP credentials
- GitHub repository settings
- Deployment options
- Local site paths

### wp-config-siteground.php
Smart configuration that:
- Auto-detects Local vs SiteGround environment
- Sets appropriate database credentials
- Configures debug settings for development
- Optimizes for SiteGround hosting

## Migration Options

The migration script offers several options:

1. **Full Migration**: Database + files + uploads
2. **Database Only**: Export/import WordPress database
3. **Files Only**: Deploy theme/plugin files
4. **Uploads Only**: Sync media uploads
5. **Config Only**: Update wp-config.php

## Troubleshooting

### SSH Connection Issues
```bash
# Test connection
ssh -p 18765 -i ~/.ssh/siteground_rsa username@sftp.siteground.net

# Fix key permissions
chmod 600 ~/.ssh/siteground_rsa
```

### Local Site Not Found
- Ensure Local site is running
- Check path in `.env.siteground`
- Use full path: `~/Local Sites/site-name/app/public`

### Deployment Fails
- Check SSH key is correct
- Verify remote path exists
- Ensure proper file permissions
- Check SiteGround disk quota

### Database Import Issues
- Get correct database credentials from Site Tools
- Ensure database exists on SiteGround
- Check for table prefix conflicts
- Use search-replace for URL updates

## Security Best Practices

1. **Never commit sensitive files**:
   - `.env.siteground` (contains credentials)
   - `wp-config.php` (contains passwords)
   - SSH private keys

2. **Use strong credentials**:
   - Generate strong database passwords
   - Use SSH keys instead of passwords
   - Rotate credentials regularly

3. **SiteGround Security**:
   - Enable SG Security plugin
   - Use SiteGround's SSL certificates
   - Configure firewall rules
   - Enable two-factor authentication

## Advanced Features

### Custom Deployment Hooks
Add pre/post deployment commands in `.env.siteground`:
```bash
# Run before deployment
PRE_DEPLOY_HOOK="npm run build"

# Run after deployment
POST_DEPLOY_HOOK="wp cache flush"
```

### Exclude Patterns
Customize what gets deployed:
```bash
DEPLOY_EXCLUDE_PATTERNS="node_modules/,.git/,*.log,*.sql"
```

### Multiple Sites
Create different `.env` files for each site:
```bash
# Deploy to staging
cp .env.staging .env.siteground
./deploy-to-siteground.sh

# Deploy to production
cp .env.production .env.siteground
./deploy-to-siteground.sh
```

## Comparison: Docker vs Local

| Feature | Docker + DO | Local + SiteGround |
|---------|------------|-------------------|
| Setup Complexity | High | Low |
| Visual Interface | No | Yes |
| Resource Usage | High | Low |
| Windows Support | Limited | Full |
| Deployment Speed | Slow | Fast |
| Cost | $6+/month | Included |
| SSL Setup | Manual | Automatic |

## Support & Resources

- **Local by Flywheel**: [localwp.com/help-docs](https://localwp.com/help-docs)
- **SiteGround**: [siteground.com/kb](https://www.siteground.com/kb)
- **This Project**: [GitHub Issues](https://github.com/yourusername/wp-cc/issues)

## Changelog

### Version 2.0.0 - SiteGround Edition
- Replaced Docker with Local by Flywheel
- Added SiteGround deployment scripts
- Created environment-aware wp-config
- Built Local addon for visual deployment
- Added migration tools
- Improved documentation

### Version 1.0.0 - Original
- Docker-based development
- Digital Ocean deployment
- Basic theme and plugin

## License

MIT License - Use freely for your WordPress projects!

---

**Created for WordPress developers who want a simpler, more reliable deployment workflow.**