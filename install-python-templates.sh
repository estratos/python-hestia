#!/bin/bash
# Interactive script to install HestiaCP nginx templates
# Supports: Ubuntu 22.04, Ubuntu 24.04, and Debian (11, 12)

set -euo pipefail

trap 'echo -e "\033[0;31m[ERROR]\033[0m Script failed at line $LINENO"; exit 1' ERR

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/web/nginx"

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Run as root (sudo)"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="$ID"
        print_status "Detected OS: $OS_NAME $OS_VERSION"
    else
        print_error "/etc/os-release not found"
        exit 1
    fi
}

validate_os() {
    print_status "Checking OS compatibility..."

    case "$OS_ID" in
        ubuntu)
            [[ "$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04" ]] \
                && print_success "Ubuntu $OS_VERSION supported" \
                || { print_error "Unsupported Ubuntu version"; exit 1; }
            ;;
        debian)
            [[ "$OS_VERSION" == "11" || "$OS_VERSION" == "12" ]] \
                && print_success "Debian $OS_VERSION supported" \
                || { print_error "Unsupported Debian version"; exit 1; }
            ;;
        *)
            print_error "Only Ubuntu/Debian supported"
            exit 1
            ;;
    esac
}

check_hestia() {
    print_status "Checking HestiaCP..."

    if [[ -d "/usr/local/hestia" ]]; then
        print_success "HestiaCP detected"

        if systemctl is-enabled hestia &>/dev/null; then
            print_success "Hestia service detected"
        else
            print_warning "Service not found"
        fi
    else
        print_warning "Hestia not installed"

        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    fi
}

check_templates() {
    print_status "Checking template files..."

    for f in python-app.stpl python-app.tpl; do
        if [[ ! -f "$TEMPLATE_DIR/$f" ]]; then
            print_error "Missing: $TEMPLATE_DIR/$f"
            exit 1
        fi
    done

    print_success "Templates found"
}

create_target_dir() {
    TARGET="/usr/local/hestia/data/templates/web/nginx"
    print_status "Target: $TARGET"
    mkdir -p "$TARGET"
}

backup_templates() {
    TARGET="/usr/local/hestia/data/templates/web/nginx"
    BACKUP="$TARGET/backup_$(date +%Y%m%d_%H%M%S)"

    if [[ -f "$TARGET/python-app.tpl" || -f "$TARGET/python-app.stpl" ]]; then
        print_status "Creating backup..."
        mkdir -p "$BACKUP"
        cp -f "$TARGET"/python-app.* "$BACKUP/" 2>/dev/null || true
        print_success "Backup saved to $BACKUP"
    fi
}

install_templates() {
    TARGET="/usr/local/hestia/data/templates/web/nginx"

    print_status "Installing templates..."

    cp "$TEMPLATE_DIR/python-app.stpl" "$TARGET/"
    cp "$TEMPLATE_DIR/python-app.tpl" "$TARGET/"

    chmod 644 "$TARGET"/python-app.*
    chown root:root "$TARGET"/python-app.*

    print_success "Templates installed"
}

verify() {
    TARGET="/usr/local/hestia/data/templates/web/nginx"

    print_status "Verifying..."

    [[ -f "$TARGET/python-app.tpl" && -f "$TARGET/python-app.stpl" ]] \
        && print_success "Verification OK" \
        || { print_error "Verification failed"; exit 1; }
}

post_info() {
    echo
    print_success "INSTALL COMPLETE"
    echo

    echo "Restart services:"
    echo "  systemctl restart hestia"
    echo "  systemctl restart nginx"
    echo

    echo "Templates installed at:"
    echo "  /usr/local/hestia/data/templates/web/nginx/"
}

confirm() {
    echo
    echo "Install templates to HestiaCP?"
    read -p "(y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 0
}

main() {
    echo "=== Hestia Python Template Installer ==="

    check_root
    detect_os
    validate_os
    check_hestia
    check_templates
    confirm
    create_target_dir
    backup_templates
    install_templates
    verify
    post_info
}

main "$@"
