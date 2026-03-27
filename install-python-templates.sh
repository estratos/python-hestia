#!/bin/bash
# HestiaCP Python Template Installer (with preview + confirmation)

set -euo pipefail

trap 'echo -e "\033[0;31m[ERROR]\033[0m Failed at line $LINENO"; exit 1' ERR

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/web/nginx"
TARGET_DIR="/usr/local/hestia/data/templates/web/nginx"

# Remote URLs
TPL_URL="https://raw.githubusercontent.com/estratos/python-hestia/refs/heads/main/web/nginx/python-app.tpl"
STPL_URL="https://raw.githubusercontent.com/estratos/python-hestia/refs/heads/main/web/nginx/python-app.stpl"

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    [[ $EUID -ne 0 ]] && { print_error "Run as root"; exit 1; }
}

detect_os() {
    source /etc/os-release
    OS_NAME="$NAME"
    OS_VERSION="$VERSION_ID"
    OS_ID="$ID"
    print_status "Detected: $OS_NAME $OS_VERSION"
}

validate_os() {
    case "$OS_ID" in
        ubuntu)
            [[ "$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04" ]] || { print_error "Unsupported Ubuntu"; exit 1; }
            ;;
        debian)
            [[ "$OS_VERSION" == "11" || "$OS_VERSION" == "12" ]] || { print_error "Unsupported Debian"; exit 1; }
            ;;
        *)
            print_error "Unsupported OS"
            exit 1
            ;;
    esac
    print_success "OS supported"
}

check_hestia() {
    if [[ -d "/usr/local/hestia" ]]; then
        print_success "HestiaCP detected"
    else
        print_warning "HestiaCP not found"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    fi
}

show_plan() {
    echo
    echo "================ INSTALLATION PLAN ================"
    echo
    echo "Files to DOWNLOAD:"
    echo "  - $STPL_URL"
    echo "  - $TPL_URL"
    echo
    echo "Temporary storage (local):"
    echo "  - $TEMPLATE_DIR/python-app.stpl"
    echo "  - $TEMPLATE_DIR/python-app.tpl"
    echo
    echo "Files to INSTALL:"
    echo "  - $TARGET_DIR/python-app.stpl"
    echo "  - $TARGET_DIR/python-app.tpl"
    echo
    echo "If existing files are found:"
    echo "  - Backup will be created in:"
    echo "    $TARGET_DIR/backup_YYYYMMDD_HHMMSS/"
    echo
    echo "Permissions to be set:"
    echo "  - chmod 644"
    echo "  - owner root:root"
    echo
    echo "=================================================="
    echo
}

confirm() {
    read -p "Proceed with installation? (yes/no): " -r
    case "$REPLY" in
        yes|YES|y|Y)
            print_status "Proceeding..."
            ;;
        *)
            print_error "Installation cancelled"
            exit 0
            ;;
    esac
}

download_templates() {
    print_status "Downloading templates..."

    mkdir -p "$TEMPLATE_DIR"

    if command -v curl &>/dev/null; then
        curl -fsSL "$STPL_URL" -o "$TEMPLATE_DIR/python-app.stpl"
        curl -fsSL "$TPL_URL" -o "$TEMPLATE_DIR/python-app.tpl"
    elif command -v wget &>/dev/null; then
        wget -qO "$TEMPLATE_DIR/python-app.stpl" "$STPL_URL"
        wget -qO "$TEMPLATE_DIR/python-app.tpl" "$TPL_URL"
    else
        print_error "curl or wget required"
        exit 1
    fi

    [[ -s "$TEMPLATE_DIR/python-app.stpl" ]] || { print_error "Download failed (.stpl)"; exit 1; }
    [[ -s "$TEMPLATE_DIR/python-app.tpl" ]] || { print_error "Download failed (.tpl)"; exit 1; }

    print_success "Download complete"
}

backup_templates() {
    if [[ -f "$TARGET_DIR/python-app.tpl" || -f "$TARGET_DIR/python-app.stpl" ]]; then
        local BACKUP="$TARGET_DIR/backup_$(date +%Y%m%d_%H%M%S)"
        print_status "Creating backup..."
        mkdir -p "$BACKUP"
        cp -f "$TARGET_DIR"/python-app.* "$BACKUP/" 2>/dev/null || true
        print_success "Backup saved: $BACKUP"
    fi
}

install_templates() {
    print_status "Installing templates..."

    mkdir -p "$TARGET_DIR"

    cp "$TEMPLATE_DIR/python-app.stpl" "$TARGET_DIR/"
    cp "$TEMPLATE_DIR/python-app.tpl" "$TARGET_DIR/"

    chmod 644 "$TARGET_DIR"/python-app.*
    chown root:root "$TARGET_DIR"/python-app.*

    print_success "Installation complete"
}

verify() {
    [[ -f "$TARGET_DIR/python-app.tpl" && -f "$TARGET_DIR/python-app.stpl" ]] \
        && print_success "Verification OK" \
        || { print_error "Verification failed"; exit 1; }
}

main() {
    echo "=== Hestia Python Template Installer ==="

    check_root
    detect_os
    validate_os
    check_hestia
    show_plan
    confirm
    download_templates
    backup_templates
    install_templates
    verify

    echo
    print_success "DONE"
    echo "Restart services:"
    echo "  systemctl restart hestia"
    echo "  systemctl restart nginx"
}

main "$@"
