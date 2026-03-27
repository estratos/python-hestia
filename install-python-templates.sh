#!/bin/bash
# HestiaCP Python Template Installer (stable version)

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

# URLs
TPL_URL="https://raw.githubusercontent.com/estratos/python-hestia/refs/heads/main/web/nginx/python-app.tpl"
STPL_URL="https://raw.githubusercontent.com/estratos/python-hestia/refs/heads/main/web/nginx/python-app.stpl"

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Run this script as root"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME="${NAME:-Unknown}"
        OS_VERSION="${VERSION_ID:-Unknown}"
        OS_ID="${ID:-unknown}"
        print_status "Detected: $OS_NAME $OS_VERSION"
    else
        print_warning "Cannot detect OS"
        OS_ID="unknown"
    fi
}

validate_os() {
    case "$OS_ID" in
        ubuntu)
            [[ "$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04" ]] || {
                print_error "Unsupported Ubuntu version"
                exit 1
            }
            ;;
        debian)
            [[ "$OS_VERSION" == "11" || "$OS_VERSION" == "12" ]] || {
                print_error "Unsupported Debian version"
                exit 1
            }
            ;;
        *)
            print_warning "Unknown OS, continuing anyway..."
            ;;
    esac
}

check_hestia() {
    if [[ -d "/usr/local/hestia" ]]; then
        print_success "HestiaCP detected"
    else
        print_warning "HestiaCP not found"
        read -p "Continue anyway? (yes/no): " ans
        [[ "$ans" == "yes" ]] || exit 1
    fi
}

show_plan() {
    echo
    echo "=========== INSTALLATION PLAN ==========="
    echo "Download:"
    echo "  - python-app.stpl"
    echo "  - python-app.tpl"
    echo
    echo "Local path:"
    echo "  $TEMPLATE_DIR/"
    echo
    echo "Install to:"
    echo "  $TARGET_DIR/"
    echo
    echo "Backup if exists:"
    echo "  $TARGET_DIR/backup_TIMESTAMP/"
    echo "========================================"
    echo
}

confirm() {
    read -p "Proceed? (yes/no): " ans
    if [[ "$ans" != "yes" ]]; then
        print_warning "Cancelled"
        exit 0
    fi
}

download_templates() {
    print_status "Downloading templates..."
    mkdir -p "$TEMPLATE_DIR"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$STPL_URL" -o "$TEMPLATE_DIR/python-app.stpl"
        curl -fL "$TPL_URL" -o "$TEMPLATE_DIR/python-app.tpl"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$TEMPLATE_DIR/python-app.stpl" "$STPL_URL"
        wget -O "$TEMPLATE_DIR/python-app.tpl" "$TPL_URL"
    else
        print_error "Install curl or wget"
        exit 1
    fi

    [[ -s "$TEMPLATE_DIR/python-app.stpl" ]] || { print_error "Download failed (stpl)"; exit 1; }
    [[ -s "$TEMPLATE_DIR/python-app.tpl" ]] || { print_error "Download failed (tpl)"; exit 1; }

    print_success "Downloaded successfully"
}

backup_templates() {
    if [[ -f "$TARGET_DIR/python-app.tpl" || -f "$TARGET_DIR/python-app.stpl" ]]; then
        BACKUP="$TARGET_DIR/backup_$(date +%Y%m%d_%H%M%S)"
        print_status "Creating backup..."
        mkdir -p "$BACKUP"

        [[ -f "$TARGET_DIR/python-app.tpl" ]] && cp "$TARGET_DIR/python-app.tpl" "$BACKUP/"
        [[ -f "$TARGET_DIR/python-app.stpl" ]] && cp "$TARGET_DIR/python-app.stpl" "$BACKUP/"

        print_success "Backup: $BACKUP"
    fi
}

install_templates() {
    print_status "Installing templates..."
    mkdir -p "$TARGET_DIR"

    cp "$TEMPLATE_DIR/python-app.stpl" "$TARGET_DIR/"
    cp "$TEMPLATE_DIR/python-app.tpl" "$TARGET_DIR/"

    chmod 644 "$TARGET_DIR"/python-app.*
    chown root:root "$TARGET_DIR"/python-app.*

    print_success "Installed"
}

verify() {
    if [[ -f "$TARGET_DIR/python-app.tpl" && -f "$TARGET_DIR/python-app.stpl" ]]; then
        print_success "Verification OK"
    else
        print_error "Verification failed"
        exit 1
    fi
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
    echo "Run:"
    echo "  systemctl restart hestia"
    echo "  systemctl restart nginx"
}

main "$@"
