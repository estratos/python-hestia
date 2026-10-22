#!/bin/bash
# Remove a systemd service created by create-python-service.sh
#
# Usage:
#   sudo ./remove-python-service.sh                # interactive list
#   sudo ./remove-python-service.sh <service>      # remove one service
#   sudo ./remove-python-service.sh <service> -y   # non-interactive
#   sudo ./remove-python-service.sh --list         # only list
#
# This only removes the systemd unit (and its drop-ins). It does NOT delete
# the application directory or the logs.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

UNIT_DIR="/etc/systemd/system"
ASSUME_YES="no"
LIST_ONLY="no"
SERVICE=""
UNIT_FILE=""

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_file() { echo -e "${CYAN}[FILE]${NC} $1"; }

usage() {
    cat << EOF
Usage: sudo $0 [SERVICE] [OPTIONS]

SERVICE   systemd unit name, with or without .service. If omitted, the
          script lists the units created by create-python-service.sh and
          asks which one to remove.

Options:
  -y, --yes    Do not ask for confirmation (SERVICE is required).
  -l, --list   List matching services and exit.
  -h, --help   Show this help.

The application directory and logs are NOT removed.
EOF
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

find_services() {
    local unit desc
    for unit in "$UNIT_DIR"/*.service; do
        [[ -f "$unit" ]] || continue
        desc=$(sed -n 's/^Description=//p' "$unit" | head -n1)
        if [[ "$desc" == "Python Application for "* ]]; then
            basename "$unit" .service
        fi
    done
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes)
                ASSUME_YES="yes"
                shift
                ;;
            -l|--list)
                LIST_ONLY="yes"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                if [[ -n "$SERVICE" ]]; then
                    print_error "Only one service name is allowed"
                    exit 1
                fi
                SERVICE="$1"
                shift
                ;;
        esac
    done
}

show_services() {
    local -a services=()
    mapfile -t services < <(find_services)

    if [[ ${#services[@]} -eq 0 ]]; then
        print_warning "No services created by create-python-service.sh were found"
        return 0
    fi

    echo "Services created by create-python-service.sh:"
    local service
    for service in "${services[@]}"; do
        echo "  - $service"
    done
}

select_service() {
    local -a services=()
    mapfile -t services < <(find_services)

    if [[ ${#services[@]} -eq 0 ]]; then
        print_warning "No services created by create-python-service.sh were found in $UNIT_DIR"
        exit 0
    fi

    echo
    echo "Services created by create-python-service.sh:"
    echo "----------------------------------------"
    local i
    for i in "${!services[@]}"; do
        echo "$((i+1)). ${services[$i]}"
    done
    echo "----------------------------------------"
    echo

    local choice
    read -r -p "Enter number or service name: " choice
    if [[ -z "$choice" ]]; then
        print_error "No selection"
        exit 1
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if (( choice < 1 || choice > ${#services[@]} )); then
            print_error "Invalid number"
            exit 1
        fi
        SERVICE="${services[$((choice-1))]}"
    else
        SERVICE="$choice"
    fi
}

unit_value() {
    local key="$1"
    sed -n "s/^${key}=//p" "$UNIT_FILE" | head -n1
}

remove_service() {
    local description="$1"
    local working_dir="$2"
    local exec_start="$3"
    local service_user="$4"

    echo
    echo "================================================================================"
    print_status "Service to remove"
    echo "================================================================================"
    echo "  Name:        ${SERVICE}.service"
    print_file "  Unit:        $UNIT_FILE"
    echo "  Description: ${description:-<none>}"
    echo "  User:        ${service_user:-<none>}"
    echo "  WorkingDir:  ${working_dir:-<none>}"
    echo "  ExecStart:   ${exec_start:-<none>}"
    echo "================================================================================"
    echo

    if [[ "$ASSUME_YES" != "yes" ]]; then
        local answer
        read -r -p "Remove this service? The application files and logs are NOT removed. (y/N): " answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            print_status "Aborted"
            exit 0
        fi
    fi

    if systemctl is-active --quiet "${SERVICE}.service" 2>/dev/null; then
        print_status "Stopping ${SERVICE}.service..."
        systemctl stop "${SERVICE}.service"
        print_success "Stopped"
    else
        print_status "Service is not running"
    fi

    if systemctl is-enabled --quiet "${SERVICE}.service" 2>/dev/null; then
        print_status "Disabling ${SERVICE}.service..."
        systemctl disable "${SERVICE}.service" >/dev/null 2>&1 || true
        print_success "Disabled"
    fi

    rm -f "$UNIT_FILE"
    rm -f "$UNIT_DIR/multi-user.target.wants/${SERVICE}.service"
    rm -rf "$UNIT_DIR/${SERVICE}.service.d"

    systemctl daemon-reload
    systemctl reset-failed "${SERVICE}.service" 2>/dev/null || true

    print_success "Removed ${SERVICE}.service"
    echo
    echo "The application directory and logs were left untouched."
    if [[ -n "$working_dir" ]]; then
        echo "  $working_dir"
    fi
    echo
    echo "To verify:"
    echo "  systemctl status ${SERVICE}.service"
    echo "  systemctl cat ${SERVICE}.service"
}

main() {
    parse_args "$@"
    check_root

    if [[ "$LIST_ONLY" == "yes" ]]; then
        show_services
        exit 0
    fi

    if [[ -z "$SERVICE" ]]; then
        if [[ "$ASSUME_YES" == "yes" ]]; then
            print_error "SERVICE is required when using --yes"
            usage
            exit 1
        fi
        select_service
    fi

    SERVICE="${SERVICE%.service}"

    if [[ ! "$SERVICE" =~ ^[A-Za-z0-9_.@:-]+$ ]]; then
        print_error "Invalid service name: $SERVICE"
        exit 1
    fi

    UNIT_FILE="$UNIT_DIR/${SERVICE}.service"
    if [[ ! -f "$UNIT_FILE" ]]; then
        print_error "Unit not found: $UNIT_FILE"
        echo
        show_services
        exit 1
    fi

    local description working_dir exec_start service_user
    description=$(unit_value Description)
    working_dir=$(unit_value WorkingDirectory)
    exec_start=$(unit_value ExecStart)
    service_user=$(unit_value User)

    remove_service "$description" "$working_dir" "$exec_start" "$service_user"
}

main "$@"
