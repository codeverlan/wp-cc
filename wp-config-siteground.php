<?php
/**
 * WordPress Configuration - Works for both Local by Flywheel and SiteGround
 * 
 * This file automatically detects the environment and configures WordPress accordingly.
 */

// Environment detection
$is_local = false;
$is_siteground = false;

// Check for Local by Flywheel environment
if (isset($_SERVER['HTTP_HOST'])) {
    if (strpos($_SERVER['HTTP_HOST'], '.local') !== false) {
        $is_local = true;
    } elseif (file_exists('/home/customer/www') || file_exists('/home/' . get_current_user() . '/www')) {
        $is_siteground = true;
    }
}

// Alternative Local detection
if (!$is_local && (
    $_SERVER['HTTP_HOST'] === 'localhost' || 
    $_SERVER['HTTP_HOST'] === '127.0.0.1' ||
    strpos($_SERVER['SERVER_SOFTWARE'], 'Local') !== false
)) {
    $is_local = true;
}

// Database settings - dynamically set based on environment
if ($is_local) {
    // Local by Flywheel environment
    define('DB_NAME', 'local');
    define('DB_USER', 'root');
    define('DB_PASSWORD', 'root');
    define('DB_HOST', 'localhost');
} elseif ($is_siteground) {
    // SiteGround production - these should be updated with actual values
    define('DB_NAME', getenv('DB_NAME') ?: 'your_db_name');
    define('DB_USER', getenv('DB_USER') ?: 'your_db_user');
    define('DB_PASSWORD', getenv('DB_PASSWORD') ?: 'your_db_password');
    define('DB_HOST', getenv('DB_HOST') ?: 'localhost');
} else {
    // Fallback/Docker environment (if still needed)
    define('DB_NAME', getenv('WORDPRESS_DB_NAME') ?: 'wordpress');
    define('DB_USER', getenv('WORDPRESS_DB_USER') ?: 'wordpress');
    define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') ?: 'wordpress_password');
    define('DB_HOST', getenv('WORDPRESS_DB_HOST') ?: 'mysql:3306');
}

define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// Authentication keys and salts
// These should be regenerated for production: https://api.wordpress.org/secret-key/1.1/salt/
define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');

// WordPress Database Table prefix
$table_prefix = 'wp_';

// Development/Debug settings
if ($is_local) {
    define('WP_DEBUG', true);
    define('WP_DEBUG_LOG', true);
    define('WP_DEBUG_DISPLAY', true);
    define('SCRIPT_DEBUG', true);
    define('SAVEQUERIES', true);
} else {
    define('WP_DEBUG', false);
    define('WP_DEBUG_DISPLAY', false);
    define('WP_DEBUG_LOG', false);
}

// URL settings for Local development
if ($is_local && isset($_SERVER['HTTP_HOST'])) {
    $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    define('WP_HOME', $protocol . '://' . $_SERVER['HTTP_HOST']);
    define('WP_SITEURL', $protocol . '://' . $_SERVER['HTTP_HOST']);
}

// SiteGround specific optimizations
if ($is_siteground) {
    // Enable SiteGround's Dynamic Cache
    define('WP_CACHE', true);
    
    // SiteGround's Memcached settings (if available)
    if (file_exists('/home/' . get_current_user() . '/.memcached')) {
        define('WP_CACHE_KEY_SALT', $_SERVER['HTTP_HOST']);
    }
}

// File permissions
define('FS_METHOD', 'direct');
define('FS_CHMOD_DIR', (0755 & ~ umask()));
define('FS_CHMOD_FILE', (0644 & ~ umask()));

// Increase memory limits
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');

// Disable automatic updates in Local development
if ($is_local) {
    define('AUTOMATIC_UPDATER_DISABLED', true);
    define('WP_AUTO_UPDATE_CORE', false);
    define('DISALLOW_FILE_MODS', false);
}

// SSL settings for production
if (!$is_local) {
    if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
        $_SERVER['HTTPS'] = 'on';
    }
    
    // Force SSL for admin and logins on production
    define('FORCE_SSL_ADMIN', true);
}

// SiteGround specific: Handle their proxy setup
if ($is_siteground && isset($_SERVER['HTTP_X_FORWARDED_HOST'])) {
    $_SERVER['HTTP_HOST'] = $_SERVER['HTTP_X_FORWARDED_HOST'];
}

// Optimize for performance
if (!$is_local) {
    define('COMPRESS_CSS', true);
    define('COMPRESS_SCRIPTS', true);
    define('CONCATENATE_SCRIPTS', true);
    define('ENFORCE_GZIP', true);
}

// Limit post revisions
define('WP_POST_REVISIONS', $is_local ? true : 5);

// Auto-save interval
define('AUTOSAVE_INTERVAL', 120); // seconds

// Empty trash automatically
define('EMPTY_TRASH_DAYS', 30);

// Absolute path to the WordPress directory
if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

// Sets up WordPress vars and included files
require_once(ABSPATH . 'wp-settings.php');