#!/bin/bash
# Interactive script to install HestiaCP nginx templates
# Downloads latest templates from GitHub and configures them for Python applications
# Supports: Ubuntu 22.04, Ubuntu 24.04, and Debian (11, 12)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Template URLs
STPL_URL="https://raw.githubusercontent.com/estratos/python-hestia/refs/heads/main/web/nginx/python-app.stpl"
TPL_URL="https://raw.githubusercontent.com/estratos/python-hestia/refs/heads/main/web/nginx/python-app.tpl"

# Default configuration
DEFAULT_PORT="8000"
INSTALL_DIR="/usr/local/hestia/data/templates/web/nginx"

# When the installer runs from a git checkout, use the local templates so the
# port rewrite and template fixes match the code being tested. When it runs
# standalone (downloaded with wget), fall back to the GitHub copies.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_TPL="$SCRIPT_DIR/web/nginx/python-app.tpl"
LOCAL_STPL="$SCRIPT_DIR/web/nginx/python-app.stpl"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_file() {
    echo -e "${CYAN}[FILE]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="$ID"
        
        print_status "Detected OS: $OS_NAME $OS_VERSION"
    else
        print_error "Cannot determine OS version. /etc/os-release not found."
        exit 1
    fi
}

validate_os_compatibility() {
    print_status "Checking OS compatibility..."
    
    if [[ "$OS_ID" == "ubuntu" ]]; then
        case "$OS_VERSION" in
            "22.04"|"24.04")
                print_success "Ubuntu $OS_VERSION is supported"
                ;;
            *)
                print_error "Ubuntu $OS_VERSION is not supported."
                print_error "Supported Ubuntu versions: 22.04 (Jammy), 24.04 (Noble)"
                exit 1
                ;;
        esac
    elif [[ "$OS_ID" == "debian" ]]; then
        case "$OS_VERSION" in
            "11"|"12")
                print_success "Debian $OS_VERSION is supported"
                ;;
            *)
                print_error "Debian $OS_VERSION is not supported."
                print_error "Supported Debian versions: 11 (Bullseye), 12 (Bookworm)"
                exit 1
                ;;
        esac
    else
        print_error "This script supports Ubuntu (22.04, 24.04) and Debian (11, 12) only."
        print_error "Detected: $OS_NAME $OS_VERSION"
        exit 1
    fi
}

check_hestia_installation() {
    print_status "Checking HestiaCP installation..."
    
    if [[ -d "/usr/local/hestia" ]]; then
        print_success "HestiaCP installation detected at: /usr/local/hestia"
        
        if systemctl list-units --full -all | grep -q "hestia.service"; then
            print_success "HestiaCP service detected"
        else
            print_warning "HestiaCP directory exists but service not found"
        fi
    else
        print_error "HestiaCP is not installed at /usr/local/hestia"
        print_error "Please install HestiaCP before running this script"
        exit 1
    fi
}

get_port_configuration() {
    echo
    print_status "Configure Python Application Port"
    echo "The templates will proxy requests to a Python application running locally."
    echo "You can specify the port your Python application will use."
    echo
    read -p "Enter port number for Python application [default: $DEFAULT_PORT]: " USER_PORT
    
    if [[ -z "$USER_PORT" ]]; then
        PORT="$DEFAULT_PORT"
    elif [[ "$USER_PORT" =~ ^[0-9]+$ ]] && [[ "$USER_PORT" -ge 1024 ]] && [[ "$USER_PORT" -le 65535 ]]; then
        PORT="$USER_PORT"
    else
        print_error "Invalid port number. Port must be between 1024 and 65535"
        print_status "Using default port $DEFAULT_PORT"
        PORT="$DEFAULT_PORT"
    fi
    
    print_success "Will configure templates to use port: $PORT"
}

show_file_operations() {
    echo
    echo "================================================================================"
    print_status "Files that will be created or modified:"
    echo "================================================================================"
    echo
    
    # Templates to be installed
    echo "HestiaCP Nginx Templates:"
    print_file "$INSTALL_DIR/python-app.stpl"
    print_file "$INSTALL_DIR/python-app.tpl"
    echo
    
    # Backup directory
    if [[ -f "$INSTALL_DIR/python-app.stpl" ]] || [[ -f "$INSTALL_DIR/python-app.tpl" ]]; then
        echo "Backup of existing templates will be created at:"
        print_file "$INSTALL_DIR/backup_$(date +%Y%m%d_%H%M%S)/"
        echo
    fi
    
    echo "================================================================================"
}

confirm_file_operations() {
    echo
    read -p "Do you want to proceed with these file operations? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Installation aborted by user"
        exit 0
    fi
}

download_templates() {
    # Create temporary directory for the working copies
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # Prefer the templates from this checkout when available (repo mode)
    if [[ -s "$LOCAL_STPL" ]] && [[ -s "$LOCAL_TPL" ]]; then
        print_status "Using local templates from $SCRIPT_DIR/web/nginx"
        cp "$LOCAL_STPL" python-app.stpl
        cp "$LOCAL_TPL" python-app.tpl
        print_success "Using local python-app.stpl / python-app.tpl"
        return 0
    fi

    print_status "Downloading latest templates from GitHub..."
    
    # Download the stpl template
    print_status "Downloading python-app.stpl..."
    print_file "$STPL_URL"
    if wget -q --show-progress -O python-app.stpl "$STPL_URL"; then
        print_success "Downloaded python-app.stpl"
    else
        print_error "Failed to download python-app.stpl from $STPL_URL"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Download the tpl template
    print_status "Downloading python-app.tpl..."
    print_file "$TPL_URL"
    if wget -q --show-progress -O python-app.tpl "$TPL_URL"; then
        print_success "Downloaded python-app.tpl"
    else
        print_error "Failed to download python-app.tpl from $TPL_URL"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Verify downloaded files
    if [[ -s "python-app.stpl" ]] && [[ -s "python-app.tpl" ]]; then
        print_success "Template files downloaded and verified"
    else
        print_error "Downloaded template files appear to be empty"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi
}

modify_templates() {
    print_status "Modifying templates to use port $PORT..."
    
    # Show original port
    echo "Original configuration:"
    grep -n "proxy_pass" python-app.stpl | head -2
    echo
    
    # Rewrite every backend reference (location /, /health, etc.), not only
    # the one ending in ";" -- otherwise /health keeps pointing at 8000.
    if [[ -f "python-app.stpl" ]]; then
        sed -i "s|127.0.0.1:8000|127.0.0.1:$PORT|g" python-app.stpl
        print_success "Modified python-app.stpl for port $PORT"
        
        # Show new configuration
        echo "New configuration:"
        grep -n "proxy_pass" python-app.stpl | head -5
        echo
    fi
    
    # Modify tpl template (HTTP version)
    if [[ -f "python-app.tpl" ]]; then
        sed -i "s|127.0.0.1:8000|127.0.0.1:$PORT|g" python-app.tpl
        print_success "Modified python-app.tpl for port $PORT"
    fi
}

create_backup() {
    BACKUP_DIR="$INSTALL_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$INSTALL_DIR/python-app.stpl" ]] || [[ -f "$INSTALL_DIR/python-app.tpl" ]]; then
        print_status "Creating backup of existing templates..."
        
        echo "Existing files found:"
        [[ -f "$INSTALL_DIR/python-app.stpl" ]] && print_file "$INSTALL_DIR/python-app.stpl"
        [[ -f "$INSTALL_DIR/python-app.tpl" ]] && print_file "$INSTALL_DIR/python-app.tpl"
        echo
        
        read -p "Create backup before overwriting? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$BACKUP_DIR"
            
            if [[ -f "$INSTALL_DIR/python-app.stpl" ]]; then
                cp "$INSTALL_DIR/python-app.stpl" "$BACKUP_DIR/"
                print_success "Backed up: $BACKUP_DIR/python-app.stpl"
            fi
            
            if [[ -f "$INSTALL_DIR/python-app.tpl" ]]; then
                cp "$INSTALL_DIR/python-app.tpl" "$BACKUP_DIR/"
                print_success "Backed up: $BACKUP_DIR/python-app.tpl"
            fi
            
            print_success "Backup created at: $BACKUP_DIR"
        else
            print_status "Skipping backup, existing files will be overwritten"
        fi
    else
        print_status "No existing templates to backup"
    fi
}

install_templates() {
    print_status "Installing templates to HestiaCP..."
    
    # Show what will be installed
    echo "Files to be installed:"
    print_file "$INSTALL_DIR/python-app.stpl"
    print_file "$INSTALL_DIR/python-app.tpl"
    echo
    
    read -p "Install templates? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Template installation skipped"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Copy modified templates to target directory
    cp -v python-app.stpl "$INSTALL_DIR/"
    if [[ $? -eq 0 ]]; then
        print_success "Installed: $INSTALL_DIR/python-app.stpl"
    else
        print_error "Failed to install python-app.stpl"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    cp -v python-app.tpl "$INSTALL_DIR/"
    if [[ $? -eq 0 ]]; then
        print_success "Installed: $INSTALL_DIR/python-app.tpl"
    else
        print_error "Failed to install python-app.tpl"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Set proper permissions
    chmod 644 "$INSTALL_DIR/python-app.stpl"
    chmod 644 "$INSTALL_DIR/python-app.tpl"
    chown root:root "$INSTALL_DIR/python-app.stpl"
    chown root:root "$INSTALL_DIR/python-app.tpl"
    
    print_success "Templates installed successfully with permissions 644"
}

verify_installation() {
    print_status "Verifying installation..."
    
    if [[ -f "$INSTALL_DIR/python-app.stpl" ]] && [[ -f "$INSTALL_DIR/python-app.tpl" ]]; then
        print_success "Verification passed: Both template files are present"
        
        echo
        print_status "Installed files details:"
        ls -lh "$INSTALL_DIR/python-app.stpl" "$INSTALL_DIR/python-app.tpl"
        
        # Verify port configuration
        if grep -q "127.0.0.1:$PORT" "$INSTALL_DIR/python-app.stpl" && \
           grep -q "127.0.0.1:$PORT" "$INSTALL_DIR/python-app.tpl"; then
            print_success "Port configuration verified: $PORT"
        else
            print_warning "Port configuration verification failed. Please check manually."
        fi

        # Catch leftovers such as /health when a custom port was chosen
        if [[ "$PORT" != "8000" ]] && \
           grep -q "127.0.0.1:8000" "$INSTALL_DIR/python-app.stpl" "$INSTALL_DIR/python-app.tpl"; then
            print_warning "Some 127.0.0.1:8000 references remain; check proxy_pass lines manually."
        fi
    else
        print_error "Verification failed: One or both template files are missing"
        exit 1
    fi
}

restart_services() {
    echo
    print_status "Services to restart:"
    echo "  - HestiaCP (to load new templates)"
    echo "  - Nginx (to apply template changes)"
    echo
    
    read -p "Restart services now? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Skipping service restart. You can restart manually later."
        return 0
    fi
    
    print_status "Restarting HestiaCP..."
    if systemctl restart hestia 2>/dev/null; then
        print_success "HestiaCP restarted successfully"
    else
        print_warning "Could not restart HestiaCP service. You may need to restart manually."
    fi
    
    print_status "Reloading Nginx..."
    if systemctl reload nginx 2>/dev/null; then
        print_success "Nginx reloaded successfully"
    else
        print_warning "Could not reload Nginx service. You may need to reload manually."
    fi
}

show_post_install_instructions() {
    echo
    echo "================================================================================"
    print_success "INSTALLATION COMPLETE!"
    echo "================================================================================"
    echo
    echo "System: $OS_NAME $OS_VERSION"
    echo "Python Application Port: $PORT"
    echo
    echo "Files installed:"
    print_file "$INSTALL_DIR/python-app.stpl"
    print_file "$INSTALL_DIR/python-app.tpl"
    echo
    echo "How to use these templates:"
    echo
    echo "1. Create a domain in HestiaCP:"
    echo "   v-add-web-domain admin example.com"
    echo
    echo "2. In HestiaCP web interface:"
    echo "   - Go to Web Domains"
    echo "   - Create a new domain or edit an existing one"
    echo "   - Navigate to Advanced Options"
    echo "   - Select 'python-app' from the Nginx Template dropdown"
    echo "   - Save and apply changes"
    echo
    echo "3. Configure your Python application:"
    echo "   - Run your Python application on port $PORT"
    echo "   - Bind to 127.0.0.1 (localhost) only"
    echo "   - Example with Gunicorn:"
    echo "     gunicorn --bind 127.0.0.1:$PORT myapp:app"
    echo
    echo "   - Or with Flask development server (for testing):"
    echo "     python app.py"
    echo "     # Make sure app.run(host='127.0.0.1', port=$PORT)"
    echo
    echo "4. Access your application:"
    echo "   http://example.com"
    echo
    echo "Backup location: $INSTALL_DIR/backup_*"
    echo
    echo "To uninstall:"
    echo "  sudo rm -f $INSTALL_DIR/python-app.stpl"
    echo "  sudo rm -f $INSTALL_DIR/python-app.tpl"
    echo
    echo "To restore from backup:"
    echo "  sudo cp $INSTALL_DIR/backup_*/* $INSTALL_DIR/"
    echo
    echo "================================================================================"
}

cleanup() {
    # Clean up temporary directory
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        cd - > /dev/null 2>&1
        rm -rf "$TEMP_DIR"
        print_status "Cleaned up temporary files"
    fi
}

main() {
    echo "================================================================================"
    echo "  HestiaCP Nginx Python Templates Installer"
    echo "  Downloads and configures templates for Python applications"
    echo "  Supports: Ubuntu 22.04/24.04 | Debian 11/12"
    echo "================================================================================"
    echo
    
    # Set trap to cleanup on exit
    trap cleanup EXIT
    
    check_root
    detect_os
    validate_os_compatibility
    check_hestia_installation
    get_port_configuration
    show_file_operations
    confirm_file_operations
    download_templates
    modify_templates
    create_backup
    install_templates
    verify_installation
    restart_services
    show_post_install_instructions
}

main
