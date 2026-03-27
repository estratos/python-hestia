#!/bin/bash
# Interactive script to install HestiaCP nginx templates
# Supports: Ubuntu 22.04, Ubuntu 24.04, and Debian (11, 12)
# Validates OS version before installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
                print_error "Installation aborted."
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
                print_error "Installation aborted."
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
        print_success "HestiaCP installation detected"
        
        if systemctl list-units --full -all | grep -q "hestia.service"; then
            print_success "HestiaCP service detected"
        else
            print_warning "HestiaCP directory exists but service not found"
        fi
    else
        print_warning "HestiaCP does not appear to be installed at /usr/local/hestia"
        print_warning "Continuing installation, but templates may not be usable until HestiaCP is installed"
        
        read -p "Do you want to continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Installation aborted by user"
            exit 1
        fi
    fi
}

check_template_files() {
    print_status "Checking for template files..."
    
    local missing_files=()
    
    if [[ ! -f "web/nginx/python-app.stpl" ]]; then
        missing_files+=("web/nginx/python-app.stpl")
    fi
    
    if [[ ! -f "web/nginx/python-app.tpl" ]]; then
        missing_files+=("web/nginx/python-app.tpl")
    fi
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "The following template files are missing from the current directory:"
        for file in "${missing_files[@]}"; do
            print_error "  - $file"
        done
        print_error "Please ensure these files exist in the 'web/nginx/' directory relative to this script."
        exit 1
    fi
    
    print_success "All template files found"
}

create_target_directory() {
    local target_dir="/usr/local/hestia/data/templates/web/nginx"
    
    print_status "Target directory: $target_dir"
    
    if [[ ! -d "$target_dir" ]]; then
        print_warning "Target directory does not exist. Creating it..."
        mkdir -p "$target_dir"
        if [[ $? -eq 0 ]]; then
            print_success "Target directory created successfully"
        else
            print_error "Failed to create target directory"
            exit 1
        fi
    else
        print_success "Target directory exists"
    fi
}

backup_existing_templates() {
    local target_dir="/usr/local/hestia/data/templates/web/nginx"
    local backup_dir="/usr/local/hestia/data/templates/web/nginx/backup_$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$target_dir/python-app.stpl" ]] || [[ -f "$target_dir/python-app.tpl" ]]; then
        print_status "Existing templates found. Creating backup..."
        mkdir -p "$backup_dir"
        
        if [[ -f "$target_dir/python-app.stpl" ]]; then
            cp "$target_dir/python-app.stpl" "$backup_dir/"
            print_success "Backed up python-app.stpl to $backup_dir/"
        fi
        
        if [[ -f "$target_dir/python-app.tpl" ]]; then
            cp "$target_dir/python-app.tpl" "$backup_dir/"
            print_success "Backed up python-app.tpl to $backup_dir/"
        fi
        
        print_success "Backup completed"
    else
        print_status "No existing templates to backup"
    fi
}

install_templates() {
    local target_dir="/usr/local/hestia/data/templates/web/nginx"
    
    print_status "Installing templates..."
    
    cp -v "web/nginx/python-app.stpl" "$target_dir/"
    if [[ $? -eq 0 ]]; then
        print_success "Installed python-app.stpl"
    else
        print_error "Failed to install python-app.stpl"
        exit 1
    fi
    
    cp -v "web/nginx/python-app.tpl" "$target_dir/"
    if [[ $? -eq 0 ]]; then
        print_success "Installed python-app.tpl"
    else
        print_error "Failed to install python-app.tpl"
        exit 1
    fi
    
    chmod 644 "$target_dir/python-app.stpl"
    chmod 644 "$target_dir/python-app.tpl"
    chown root:root "$target_dir/python-app.stpl"
    chown root:root "$target_dir/python-app.tpl"
    
    print_success "Templates installed successfully"
}

verify_installation() {
    local target_dir="/usr/local/hestia/data/templates/web/nginx"
    
    print_status "Verifying installation..."
    
    if [[ -f "$target_dir/python-app.stpl" ]] && [[ -f "$target_dir/python-app.tpl" ]]; then
        print_success "Verification passed: Both template files are present"
        
        echo
        print_status "Installed files:"
        ls -lh "$target_dir/python-app.stpl" "$target_dir/python-app.tpl"
        
        if [[ -s "$target_dir/python-app.stpl" ]] && [[ -s "$target_dir/python-app.tpl" ]]; then
            print_success "File content verification passed (non-empty files)"
        else
            print_warning "One or both template files are empty"
        fi
    else
        print_error "Verification failed: One or both template files are missing"
        exit 1
    fi
}

suggest_restart_commands() {
    echo
    print_status "Recommended restart commands for your OS ($OS_ID $OS_VERSION):"
    
    if [[ "$OS_ID" == "ubuntu" ]] || [[ "$OS_ID" == "debian" ]]; then
        echo "  # Restart HestiaCP control panel"
        echo "  sudo systemctl restart hestia"
        echo
        echo "  # Restart Nginx web server"
        echo "  sudo systemctl restart nginx"
        echo
        echo "  # Alternatively, you can reload services without full restart:"
        echo "  sudo systemctl reload hestia"
        echo "  sudo systemctl reload nginx"
    fi
}

show_post_install_instructions() {
    echo
    echo "================================================================================"
    print_success "INSTALLATION COMPLETE!"
    echo "================================================================================"
    echo
    echo "System: $OS_NAME $OS_VERSION"
    echo "Templates installed successfully"
    echo
    echo "Next steps:"
    echo
    suggest_restart_commands
    echo
    echo "Template locations:"
    echo "  - /usr/local/hestia/data/templates/web/nginx/python-app.stpl"
    echo "  - /usr/local/hestia/data/templates/web/nginx/python-app.tpl"
    echo
    echo "How to use these templates:"
    echo "  1. In HestiaCP, go to Web Domains"
    echo "  2. Create a new domain or edit an existing one"
    echo "  3. Navigate to Advanced Options"
    echo "  4. Select 'python-app' from the Nginx Template dropdown"
    echo "  5. Save and apply changes"
    echo
    echo "Backup location:"
    echo "  /usr/local/hestia/data/templates/web/nginx/backup_*"
    echo
    echo "Troubleshooting:"
    echo "  - If templates don't appear, try clearing browser cache"
    echo "  - Check HestiaCP logs: sudo tail -f /var/log/hestia/hestia.log"
    echo "  - Verify template syntax: nginx -t"
    echo
    echo "================================================================================"
}

confirm_installation() {
    echo
    print_status "Installation Summary:"
    echo "  Operating System: $OS_NAME $OS_VERSION"
    echo "  Template Source: web/nginx/python-app.{stpl,tpl}"
    echo "  Installation Path: /usr/local/hestia/data/templates/web/nginx/"
    echo "  Backup: Will be created if existing templates found"
    echo
    read -p "Proceed with installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Installation aborted by user"
        exit 0
    fi
}

main() {
    echo "================================================================================"
    echo "  HestiaCP Nginx Python Templates Installer"
    echo "  Supports: Ubuntu 22.04/24.04 | Debian 11/12"
    echo "================================================================================"
    echo
    
    check_root
    detect_os
    validate_os_compatibility
    check_hestia_installation
    check_template_files
    confirm_installation
    create_target_directory
    backup_existing_templates
    install_templates
    verify_installation
    show_post_install_instructions
}

main
