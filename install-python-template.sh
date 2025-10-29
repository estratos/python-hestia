#!/bin/bash

# HestiaCP Python Template Installer - Final Version
# Installs both .tpl and .stpl templates

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

# Check root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
    exit 1
fi

# Hestia directories
HESTIA_DIR="/usr/local/hestia"
NGINX_DIR="$HESTIA_DIR/data/templates/web/nginx"
TEMPLATE_NAME="python-app"

check_hestia() {
    if [ ! -d "$HESTIA_DIR" ]; then
        error "HestiaCP not found at $HESTIA_DIR"
        exit 1
    fi
    
    if [ ! -d "$NGINX_DIR" ]; then
        error "Nginx templates directory not found: $NGINX_DIR"
        exit 1
    fi
    
    log "✓ HestiaCP installation verified"
}

backup_existing() {
    local backup_dir="/tmp/hestia_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    if [ -f "$NGINX_DIR/$TEMPLATE_NAME.tpl" ]; then
        cp "$NGINX_DIR/$TEMPLATE_NAME.tpl" "$backup_dir/"
        info "Backed up existing $TEMPLATE_NAME.tpl"
    fi
    
    if [ -f "$NGINX_DIR/$TEMPLATE_NAME.stpl" ]; then
        cp "$NGINX_DIR/$TEMPLATE_NAME.stpl" "$backup_dir/"
        info "Backed up existing $TEMPLATE_NAME.stpl"
    fi
    
    if [ "$(ls -A "$backup_dir")" ]; then
        info "Backups saved to: $backup_dir"
    else
        rmdir "$backup_dir"
    fi
}

install_python_tpl() {
    log "Installing Python web template ($TEMPLATE_NAME.tpl)..."
    
    cat > "$NGINX_DIR/$TEMPLATE_NAME.tpl" << 'PYTHON_TPL'
#=========================================================================#
# Python Application Web Template for HestiaCP
#=========================================================================#

server {
    listen      %ip%:%web_ssl_port% ssl;
    server_name %domain_idn% %alias_idn%;
    root        %sdocroot%;
    index       index.html index.htm;

    access_log  /var/log/%web_system%/domains/%domain%.log combined;
    access_log  /var/log/%web_system%/domains/%domain%.bytes bytes;
    error_log   /var/log/%web_system%/domains/%domain%.error.log error;

    ssl_certificate     %ssl_pem%;
    ssl_certificate_key %ssl_key%;
    ssl_stapling        on;
    ssl_stapling_verify on;

    # TLS 1.3 0-RTT anti-replay
    if ($anti_replay = 307) { return 307 https://$host$request_uri; }
    if ($anti_replay = 425) { return 425; }

    include %home%/%user%/conf/web/%domain%/nginx.hsts.conf*;

    location ~ /\.(?!well-known\/|file) {
        deny all;
        return 404;
    }

    location / {
        # This will be handled by the proxy template
        # For non-proxy mode, we serve static files
        try_files $uri $uri/ =404;
    }

    # Static files for direct access (non-proxy mode)
    location /static/ {
        alias %home%/%user%/web/%domain%/private/python_app/static/;
        expires 30d;
        access_log off;
    }

    location /error/ {
        alias %home%/%user%/web/%domain%/document_errors/;
    }

    proxy_hide_header Upgrade;

    include %home%/%user%/conf/web/%domain%/nginx.ssl.conf_*;
}

# HTTP to HTTPS redirect
server {
    listen      %ip%:80;
    server_name %domain_idn% %alias_idn%;
    return      301 https://%domain_idn%$request_uri;
}
PYTHON_TPL

    chmod 644 "$NGINX_DIR/$TEMPLATE_NAME.tpl"
    log "✓ Python web template installed"
}

install_python_stpl() {
    log "Installing Python proxy template ($TEMPLATE_NAME.stpl)..."
    
    cat > "$NGINX_DIR/$TEMPLATE_NAME.stpl" << 'PYTHON_STPL'
#=========================================================================#
# Python Application Proxy Template for HestiaCP
# Based on default.stpl structure with SSL
#=========================================================================#

server {
    listen      %ip%:%proxy_ssl_port% ssl;
    server_name %domain_idn% %alias_idn%;
    error_log   /var/log/%web_system%/domains/%domain%.error.log error;

    ssl_certificate     %ssl_pem%;
    ssl_certificate_key %ssl_key%;
    ssl_stapling        on;
    ssl_stapling_verify on;

    # TLS 1.3 0-RTT anti-replay
    if ($anti_replay = 307) { return 307 https://$host$request_uri; }
    if ($anti_replay = 425) { return 425; }

    include %home%/%user%/conf/web/%domain%/nginx.hsts.conf*;

    location ~ /\.(?!well-known\/|file) {
        deny all;
        return 404;
    }

    location / {
        proxy_pass http://127.0.0.1:%web_port%;
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

    # Static files
    location /static/ {
        alias %home%/%user%/web/%domain%/private/python_app/static/;
        expires 30d;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    # Media files
    location /media/ {
        alias %home%/%user%/web/%domain%/private/python_app/media/;
        expires 30d;
        access_log off;
    }

    # Health check
    location /health {
        proxy_pass http://127.0.0.1:%web_port%/health;
        proxy_set_header Host $host;
        access_log off;
    }

    location /error/ {
        alias %home%/%user%/web/%domain%/document_errors/;
    }

    proxy_hide_header Upgrade;

    include %home%/%user%/conf/web/%domain%/nginx.ssl.conf_*;
}
PYTHON_STPL

    chmod 644 "$NGINX_DIR/$TEMPLATE_NAME.stpl"
    log "✓ Python proxy template installed"
}

create_domain_setup_script() {
    log "Creating domain setup script..."
    
    cat > "/usr/local/bin/hestia-python-domain" << 'DOMAIN_SCRIPT'
#!/bin/bash

# HestiaCP Python Domain Setup
# Usage: hestia-python-domain <domain> [port]

set -e

DOMAIN="$1"
PORT="${2:-8000}"
USER=$(whoami)

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [port]"
    echo "Example: $0 example.com 8000"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo() {
    builtin echo -e "$@"
}

log() {
    echo "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo "${RED}[ERROR]${NC} $1" >&2
}

# Check if domain exists
if ! v-list-web-domain "$USER" "$DOMAIN" >/dev/null 2>&1; then
    error "Domain $DOMAIN does not exist for user $USER"
    echo "Create it first with: v-add-web-domain $USER $DOMAIN"
    exit 1
fi

APP_DIR="$HOME/web/$DOMAIN/private/python_app"
VENV_DIR="$HOME/web/$DOMAIN/.python-venv"
SERVICE_NAME="${DOMAIN//./_}_python"

log "Setting up Python application for $DOMAIN..."

# Create directory structure
log "Creating directory structure..."
mkdir -p "$APP_DIR/static"
mkdir -p "$APP_DIR/templates"
mkdir -p "$VENV_DIR"
mkdir -p "$HOME/web/$DOMAIN/logs/python"

# Create virtual environment
log "Creating Python virtual environment..."
if ! python3 -m venv "$VENV_DIR"; then
    error "Failed to create virtual environment"
    exit 1
fi

# Create application files
log "Creating application files..."

# Create requirements.txt
cat > "$APP_DIR/requirements.txt" << 'REQ'
Flask==2.3.3
gunicorn==21.2.0
Werkzeug==2.3.7
REQ

# Create app.py
cat > "$APP_DIR/app.py" << 'APP_PY'
from flask import Flask, jsonify, render_template
import os
import datetime

app = Flask(__name__)

@app.route('/')
def index():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Python App - ''' + os.environ.get('DOMAIN', 'localhost') + '''</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 800px; margin: 0 auto; }
            .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
            .info { background: #e7f3ff; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
            .status { color: green; font-weight: bold; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 Python Application Ready!</h1>
                <p>Your Python application is successfully deployed on <strong>''' + os.environ.get('DOMAIN', 'localhost') + '''</strong></p>
            </div>
            <div class="info">
                <h3>Application Information:</h3>
                <ul>
                    <li><strong>Domain:</strong> ''' + os.environ.get('DOMAIN', 'localhost') + '''</li>
                    <li><strong>Time:</strong> ''' + str(datetime.datetime.now()) + '''</li>
                    <li><strong>Status:</strong> <span class="status">● Running</span></li>
                    <li><strong>Port:</strong> ''' + str(''' + str($PORT) + ''') + '''</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
    '''

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now().isoformat(),
        'service': 'Python Flask App'
    })

@app.route('/api/info')
def api_info():
    return jsonify({
        'python_version': os.sys.version,
        'environment': os.environ.get('FLASK_ENV', 'production')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
APP_PY

# Create WSGI file
cat > "$APP_DIR/wsgi.py" << 'WSGI_PY'
import sys
import os

app_dir = os.path.dirname(os.path.abspath(__file__))
if app_dir not in sys.path:
    sys.path.insert(0, app_dir)

from app import app as application

if __name__ == "__main__":
    application.run()
WSGI_PY

# Install dependencies
log "Installing Python dependencies..."
if ! "$VENV_DIR/bin/pip" install -r "$APP_DIR/requirements.txt"; then
    error "Failed to install dependencies"
    exit 1
fi

# Set permissions
log "Setting permissions..."
chown -R "$USER:$USER" "$APP_DIR"
chown -R "$USER:$USER" "$VENV_DIR"
chmod 755 "$APP_DIR"

# Create systemd service file
log "Creating systemd service..."
cat > "/tmp/$SERVICE_NAME.service" << SYSTEMD_SERVICE
[Unit]
Description=Python Application for $DOMAIN
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$VENV_DIR/bin:/usr/local/bin:/usr/bin:/bin
Environment=DOMAIN=$DOMAIN
Environment=FLASK_ENV=production
ExecStart=$VENV_DIR/bin/gunicorn \\
          --bind 127.0.0.1:$PORT \\
          --workers 2 \\
          --threads 2 \\
          --access-logfile $HOME/web/$DOMAIN/logs/python/access.log \\
          --error-logfile $HOME/web/$DOMAIN/logs/python/error.log \\
          --capture-output \\
          --log-level info \\
          wsgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SYSTEMD_SERVICE

log "✓ Python application setup complete!"
echo
echo "=== NEXT STEPS ==="
echo
echo "1. Configure domain in HestiaCP Panel:"
echo "   - Web Template: python-app"
echo "   - Enable Proxy Support"
echo "   - Proxy Template: python-app"
echo "   - Backend Port: $PORT"
echo
echo "2. Start the application service:"
echo "   sudo cp /tmp/$SERVICE_NAME.service /etc/systemd/system/"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable $SERVICE_NAME.service"
echo "   sudo systemctl start $SERVICE_NAME.service"
echo
echo "3. Check application status:"
echo "   sudo systemctl status $SERVICE_NAME.service"
echo
echo "4. View application logs:"
echo "   sudo journalctl -u $SERVICE_NAME.service -f"
echo
echo "Application URL: https://$DOMAIN"
echo "Application directory: $APP_DIR"
DOMAIN_SCRIPT

    chmod +x "/usr/local/bin/hestia-python-domain"
    log "✓ Domain setup script installed"
}

verify_installation() {
    log "Verifying installation..."
    
    local errors=0
    
    if [ -f "$NGINX_DIR/$TEMPLATE_NAME.tpl" ]; then
        log "✓ Web template: $TEMPLATE_NAME.tpl"
    else
        error "✗ Web template missing"
        ((errors++))
    fi
    
    if [ -f "$NGINX_DIR/$TEMPLATE_NAME.stpl" ]; then
        log "✓ Proxy template: $TEMPLATE_NAME.stpl"
    else
        error "✗ Proxy template missing"
        ((errors++))
    fi
    
    if [ -f "/usr/local/bin/hestia-python-domain" ]; then
        log "✓ Domain setup script installed"
    else
        error "✗ Domain setup script missing"
        ((errors++))
    fi
    
    return $errors
}

show_usage() {
    echo
    info "=== USAGE INSTRUCTIONS ==="
    echo
    echo "1. Install templates (this script):"
    echo "   sudo ./install-python-hestia-final.sh"
    echo
    echo "2. Create a domain in HestiaCP:"
    echo "   v-add-web-domain admin example.com"
    echo
    echo "3. Setup Python application:"
    echo "   hestia-python-domain example.com 8000"
    echo
    echo "4. Configure in HestiaCP Panel:"
    echo "   - Web Template: python-app"
    echo "   - Proxy Support: Enable"
    echo "   - Proxy Template: python-app"
    echo "   - Backend Port: 8000"
    echo
    echo "5. Start the service:"
    echo "   sudo cp /tmp/example_com_python.service /etc/systemd/system/"
    echo "   sudo systemctl daemon-reload"
    echo "   sudo systemctl enable example_com_python.service"
    echo "   sudo systemctl start example_com_python.service"
    echo
    echo "6. Check status:"
    echo "   sudo systemctl status example_com_python.service"
}

main() {
    echo
    echo "========================================"
    echo "🧩 HestiaCP Python Template Installer"
    echo "========================================"
    echo
    
    check_hestia
    backup_existing
    install_python_tpl
    install_python_stpl
    create_domain_setup_script
    
    if verify_installation; then
        echo
        log "🎉 Installation completed successfully!"
        echo
        show_usage
        
        # Check if we need to restart Hestia
        echo
        warning "Note: If templates don't appear in HestiaCP, restart the service:"
        echo "  service hestia restart"
        echo
        info "Templates installed at: $NGINX_DIR/"
        ls -la "$NGINX_DIR/$TEMPLATE_NAME".*
    else
        error "Installation completed with errors"
        exit 1
    fi
}

main "$@"
