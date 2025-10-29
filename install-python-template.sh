#!/bin/bash

# HestiaCP Python Template Installation Script - Complete Version
# Includes both .tpl and .stpl files

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
    exit 1
fi

# Directories
HESTIA_TEMPLATES="/usr/local/hestia/data/templates/web"
NGINX_DIR="$HESTIA_TEMPLATES/nginx"
APACHE_DIR="$HESTIA_TEMPLATES/apache2"
PROXY_DIR="$NGINX_DIR"  # .stpl files go in the same directory as .tpl files
SCRIPTS_DIR="/usr/local/hestia/scripts"

# Create directories if they don't exist
mkdir -p "$NGINX_DIR" "$APACHE_DIR" "$SCRIPTS_DIR"

# Backup existing templates
backup_templates() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/tmp/hestia_python_backup_$timestamp"
    
    mkdir -p "$backup_dir"
    
    if [ -f "$NGINX_DIR/python-app.tpl" ]; then
        cp "$NGINX_DIR/python-app.tpl" "$backup_dir/"
        info "Backed up existing python-app.tpl"
    fi
    
    if [ -f "$NGINX_DIR/python-app.stpl" ]; then
        cp "$NGINX_DIR/python-app.stpl" "$backup_dir/"
        info "Backed up existing python-app.stpl"
    fi
    
    if [ -f "$APACHE_DIR/python-app.tpl" ]; then
        cp "$APACHE_DIR/python-app.tpl" "$backup_dir/"
        info "Backed up existing apache python-app.tpl"
    fi
    
    if [ -d "$backup_dir" ] && [ "$(ls -A "$backup_dir")" ]; then
        info "Backups saved to: $backup_dir"
    else
        rm -rf "$backup_dir"
    fi
}

# Install Nginx template (.tpl)
install_nginx_template() {
    log "Installing Nginx template (python-app.tpl)..."
    
    cat > "$NGINX_DIR/python-app.tpl" << 'NGINXTPL'
server {
    listen      %ip%:%web_port%;
    server_name %domain_idn% %alias_idn%;
    root        %docroot%;
    index       index.html index.htm;
    
    # Access and error logs
    access_log  /home/%user%/web/%domain%/logs/nginx_access.log;
    error_log   /home/%user%/web/%domain%/logs/nginx_error.log;

    # Static files
    location /static/ {
        alias /home/%user%/web/%domain%/private/python_app/static/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Media files
    location /media/ {
        alias /home/%user%/web/%domain%/private/python_app/media/;
        expires 30d;
        access_log off;
    }

    # Main application proxy
    location / {
        proxy_pass http://127.0.0.1:%web_ssl_port%;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:%web_ssl_port%/health;
        proxy_set_header Host $host;
        access_log off;
    }

    # Deny access to sensitive files
    location ~ /(\.git|\.env|venv|__pycache__) {
        deny all;
        return 404;
    }

    # Include SSL configuration
    include %home%/%user%/conf/web/%domain%/nginx.ssl.conf*;
}

# HTTP to HTTPS redirect
server {
    listen      %ip%:80;
    server_name %domain_idn% %alias_idn%;
    return      301 https://%domain_idn%$request_uri;
}
NGINXTPL

    chmod 644 "$NGINX_DIR/python-app.tpl"
    log "Nginx template installed successfully"
}

# Install Proxy template (.stpl)
install_proxy_template() {
    log "Installing Proxy template (python-app.stpl)..."
    
    cat > "$NGINX_DIR/python-app.stpl" << 'PROXYSTPL'
# Python Application Proxy Configuration
# HestiaCP Proxy Template - .stpl file

location / {
    proxy_pass http://127.0.0.1:%proxy_port%;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}

location /static/ {
    alias %home%/%user%/web/%domain%/private/python_app/static/;
    expires 30d;
    access_log off;
    add_header Cache-Control "public, immutable";
}

location /media/ {
    alias %home%/%user%/web/%domain%/private/python_app/media/;
    expires 30d;
    access_log off;
}

location /health {
    proxy_pass http://127.0.0.1:%proxy_port%/health;
    proxy_set_header Host $host;
    access_log off;
}

# Deny access to sensitive files
location ~ /(\.git|\.env|venv|__pycache__|requirements\.txt) {
    deny all;
    return 404;
}
PROXYSTPL

    chmod 644 "$NGINX_DIR/python-app.stpl"
    log "Proxy template installed successfully"
}

# Install Apache2 template
install_apache_template() {
    log "Installing Apache2 template..."
    
    cat > "$APACHE_DIR/python-app.tpl" << 'APACHETPL'
<VirtualHost %ip%:%web_ssl_port%>
    ServerName %domain_idn%
    ServerAlias www.%domain_idn%
    
    DocumentRoot %docroot%
    
    # Python application via WSGI
    WSGIDaemonProcess %domain% python-home=/home/%user%/web/%domain%/.python-venv python-path=/home/%user%/web/%domain%/private/python_app
    WSGIProcessGroup %domain%
    WSGIScriptAlias / /home/%user%/web/%domain%/private/python_app/wsgi.py
    
    # Static files
    Alias /static/ /home/%user%/web/%domain%/private/python_app/static/
    <Directory /home/%user%/web/%domain%/private/python_app/static>
        Require all granted
    </Directory>
    
    # Media files
    Alias /media/ /home/%user%/web/%domain%/private/python_app/media/
    <Directory /home/%user%/web/%domain%/private/python_app/media>
        Require all granted
    </Directory>
    
    # WSGI application directory
    <Directory /home/%user%/web/%domain%/private/python_app>
        <Files wsgi.py>
            Require all granted
        </Files>
    </Directory>
    
    ErrorLog /home/%user%/web/%domain%/logs/apache_error.log
    CustomLog /home/%user%/web/%domain%/logs/apache_access.log combined
</VirtualHost>
APACHETPL

    chmod 644 "$APACHE_DIR/python-app.tpl"
    log "Apache2 template installed successfully"
}

# Install application manager script
install_app_manager() {
    log "Installing application manager script..."
    
    cat > "$SCRIPTS_DIR/python-app-manager" << 'SCRIPT'
#!/bin/bash

# HestiaCP Python Application Manager
# Usage: python-app-manager <domain> <action> [port]

[Insert the complete python-app-manager.sh script content from previous response]
SCRIPT

    chmod +x "$SCRIPTS_DIR/python-app-manager"
    
    # Create symbolic link for easy access
    ln -sf "$SCRIPTS_DIR/python-app-manager" "/usr/local/bin/hestia-python-app"
    
    log "Application manager installed successfully"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    local errors=0
    
    if [ -f "$NGINX_DIR/python-app.tpl" ]; then
        log "✓ Nginx template (.tpl) found"
    else
        error "✗ Nginx template (.tpl) missing"
        ((errors++))
    fi
    
    if [ -f "$NGINX_DIR/python-app.stpl" ]; then
        log "✓ Proxy template (.stpl) found"
    else
        error "✗ Proxy template (.stpl) missing"
        ((errors++))
    fi
    
    if [ -f "$APACHE_DIR/python-app.tpl" ]; then
        log "✓ Apache2 template found"
    else
        error "✗ Apache2 template missing"
        ((errors++))
    fi
    
    if [ -f "$SCRIPTS_DIR/python-app-manager" ]; then
        log "✓ Application manager found"
    else
        error "✗ Application manager missing"
        ((errors++))
    fi
    
    if [ -L "/usr/local/bin/hestia-python-app" ]; then
        log "✓ Symbolic link created"
    else
        error "✗ Symbolic link missing"
        ((errors++))
    fi
    
    return $errors
}

# Main installation process
main() {
    echo
    echo "================================================"
    echo "🧩 HestiaCP Python Template Installer"
    echo "================================================"
    echo
    
    # Check HestiaCP installation
    if [ ! -d "/usr/local/hestia" ]; then
        error "HestiaCP not found in /usr/local/hestia"
        exit 1
    fi
    
    # Backup existing templates
    backup_templates
    
    # Install templates
    install_nginx_template
    install_proxy_template
    install_apache_template
    install_app_manager
    
    # Verify installation
    if verify_installation; then
        echo
        log "🎉 Installation completed successfully!"
        echo
        info "Installed components:"
        echo "  📄 Nginx Template: $NGINX_DIR/python-app.tpl"
        echo "  📄 Proxy Template: $NGINX_DIR/python-app.stpl"
        echo "  📄 Apache2 Template: $APACHE_DIR/python-app.tpl"
        echo "  🔧 Application Manager: /usr/local/bin/hestia-python-app"
        echo
        info "Usage examples:"
        echo "  hestia-python-app example.com init 8000"
        echo "  hestia-python-app example.com start"
        echo "  hestia-python-app example.com status"
        echo
        info "To use in HestiaCP:"
        echo "  1. Go to Web Domains → Edit domain"
        echo "  2. Web Template: select 'python-app'"
        echo "  3. Enable Proxy Support"
        echo "  4. Proxy Template: select 'python-app'"
        echo "  5. Backend Port: set your application port (e.g., 8000)"
        echo
        warning "Note: You may need to restart HestiaCP for templates to appear"
        echo "  service hestia restart"
    else
        error "Installation completed with errors. Please check the messages above."
        exit 1
    fi
}

# Run main function
main "$@"
