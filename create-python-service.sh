#!/bin/bash
# Interactive script to create systemd service for Python applications in HestiaCP
# Supports: Ubuntu 22.04, Ubuntu 24.04, and Debian (11, 12)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

print_file() {
    echo -e "${CYAN}[FILE]${NC} $1"
}

print_prompt() {
    echo -e "${MAGENTA}[PROMPT]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

list_hestia_users() {
    print_status "Fetching HestiaCP users..."
    
    USERS=()
    if [[ -d "/home" ]]; then
        for user_dir in /home/*; do
            if [[ -d "$user_dir" ]]; then
                username=$(basename "$user_dir")
                if [[ -d "/home/$username/web" ]]; then
                    USERS+=("$username")
                fi
            fi
        done
    fi
    
    if [[ ${#USERS[@]} -eq 0 ]]; then
        print_warning "No HestiaCP users found in /home/*/web"
        return 1
    fi
    
    echo
    echo "Available HestiaCP users:"
    echo "----------------------------------------"
    for i in "${!USERS[@]}"; do
        echo "$((i+1)). ${USERS[$i]}"
    done
    echo "----------------------------------------"
    
    return 0
}

select_user() {
    echo
    print_prompt "Select the HestiaCP user that owns the domain"
    
    if list_hestia_users; then
        read -p "Enter number (1-${#USERS[@]}) or enter custom username: " USER_CHOICE
        
        if [[ "$USER_CHOICE" =~ ^[0-9]+$ ]]; then
            if [[ $USER_CHOICE -ge 1 ]] && [[ $USER_CHOICE -le ${#USERS[@]} ]]; then
                SELECTED_USER="${USERS[$((USER_CHOICE-1))]}"
                print_success "Selected user: $SELECTED_USER"
                return 0
            else
                print_error "Invalid selection number"
                return 1
            fi
        else
            if [[ -n "$USER_CHOICE" ]]; then
                SELECTED_USER="$USER_CHOICE"
                if id "$SELECTED_USER" &>/dev/null; then
                    print_success "Using user: $SELECTED_USER"
                else
                    print_warning "User $SELECTED_USER does not exist"
                    read -p "Create user $SELECTED_USER? (y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        useradd -m -s /bin/bash "$SELECTED_USER"
                        print_success "Created user: $SELECTED_USER"
                    else
                        print_error "User does not exist. Please create it first."
                        return 1
                    fi
                fi
                return 0
            else
                print_error "No user specified"
                return 1
            fi
        fi
    else
        read -p "Enter the username that owns the domain: " SELECTED_USER
        if [[ -z "$SELECTED_USER" ]]; then
            print_error "No user specified"
            return 1
        fi
        
        if id "$SELECTED_USER" &>/dev/null; then
            print_success "Using user: $SELECTED_USER"
        else
            print_warning "User $SELECTED_USER does not exist"
            read -p "Create user $SELECTED_USER? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                useradd -m -s /bin/bash "$SELECTED_USER"
                print_success "Created user: $SELECTED_USER"
            else
                print_error "User does not exist. Please create it first."
                return 1
            fi
        fi
        return 0
    fi
}

list_domains_for_user() {
    local user="$1"
    local user_home="/home/$user"
    
    print_status "Fetching domains for user: $user"
    
    DOMAINS=()
    if [[ -d "$user_home/web" ]]; then
        for domain in "$user_home/web"/*; do
            if [[ -d "$domain" ]]; then
                domain_name=$(basename "$domain")
                if [[ "$domain_name" != "stats" ]] && [[ "$domain_name" != "default" ]]; then
                    DOMAINS+=("$domain_name")
                fi
            fi
        done
    fi
    
    if [[ ${#DOMAINS[@]} -eq 0 ]]; then
        print_warning "No domains found for user $user in $user_home/web/"
        return 1
    fi
    
    echo
    echo "Available domains for user $user:"
    echo "----------------------------------------"
    for i in "${!DOMAINS[@]}"; do
        echo "$((i+1)). ${DOMAINS[$i]}"
    done
    echo "----------------------------------------"
    
    return 0
}

select_domain_or_path() {
    local user="$1"
    
    echo
    print_prompt "Select a domain or specify custom path"
    echo "Options:"
    echo "  - Enter number (1-${#DOMAINS[@]}) to select a domain"
    echo "  - Enter 'c' to specify a custom absolute path"
    echo "  - Enter 'q' to quit"
    echo
    
    read -p "Your choice: " DOMAIN_CHOICE
    
    case $DOMAIN_CHOICE in
        [0-9]*)
            if [[ $DOMAIN_CHOICE -ge 1 ]] && [[ $DOMAIN_CHOICE -le ${#DOMAINS[@]} ]]; then
                SELECTED_DOMAIN="${DOMAINS[$((DOMAIN_CHOICE-1))]}"
                DEFAULT_PATH="/home/$user/web/$SELECTED_DOMAIN/private/python_app"
                print_success "Selected domain: $SELECTED_DOMAIN"
                confirm_or_change_path "$DEFAULT_PATH"
                return $?
            else
                print_error "Invalid selection number"
                return 1
            fi
            ;;
        c|C)
            select_custom_path
            return $?
            ;;
        q|Q)
            print_status "Exiting script"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

confirm_or_change_path() {
    local suggested_path="$1"
    
    echo
    print_prompt "Application path: $suggested_path"
    echo "Options:"
    echo "  - Enter 'y' to accept this path"
    echo "  - Enter 'c' to change to a custom path"
    echo "  - Enter 's' to scan for existing Python applications"
    echo
    
    read -p "Your choice (y/c/s): " PATH_CHOICE
    
    case $PATH_CHOICE in
        y|Y)
            APP_PATH="$suggested_path"
            print_success "Using application path: $APP_PATH"
            SERVICE_NAME="${SELECTED_DOMAIN}_python"
            return 0
            ;;
        c|C)
            select_custom_path
            return $?
            ;;
        s|S)
            scan_for_applications
            return $?
            ;;
        *)
            print_error "Invalid choice, using default path"
            APP_PATH="$suggested_path"
            SERVICE_NAME="${SELECTED_DOMAIN}_python"
            return 0
            ;;
    esac
}

scan_for_applications() {
    print_status "Scanning for Python applications..."
    
    local found_apps=()
    local base_path="/home/$SELECTED_USER/web/$SELECTED_DOMAIN/private"
    
    if [[ -d "$base_path" ]]; then
        for app_dir in "$base_path"/*; do
            if [[ -d "$app_dir" ]]; then
                # Check for Python files
                if ls "$app_dir"/*.py &>/dev/null 2>&1; then
                    found_apps+=("$(basename "$app_dir")")
                fi
            fi
        done
    fi
    
    if [[ ${#found_apps[@]} -eq 0 ]]; then
        print_warning "No Python applications found in $base_path"
        select_custom_path
        return $?
    fi
    
    echo
    echo "Found Python applications:"
    echo "----------------------------------------"
    for i in "${!found_apps[@]}"; do
        echo "$((i+1)). ${found_apps[$i]}"
    done
    echo "----------------------------------------"
    echo
    
    read -p "Select application number or enter 'c' for custom path: " APP_CHOICE
    
    if [[ "$APP_CHOICE" =~ ^[0-9]+$ ]] && [[ $APP_CHOICE -ge 1 ]] && [[ $APP_CHOICE -le ${#found_apps[@]} ]]; then
        local selected_app="${found_apps[$((APP_CHOICE-1))]}"
        APP_PATH="$base_path/$selected_app"
        SERVICE_NAME="${SELECTED_DOMAIN}_${selected_app}"
        print_success "Selected application: $APP_PATH"
        return 0
    elif [[ "$APP_CHOICE" =~ ^[cC]$ ]]; then
        select_custom_path
        return $?
    else
        print_error "Invalid selection"
        select_custom_path
        return $?
    fi
}

select_custom_path() {
    echo
    print_prompt "Enter the absolute path to your Python application directory"
    echo "Examples: /home/admin/web/example.com/private/myapp"
    echo "          /opt/myapp"
    echo "          /var/www/myapp"
    echo
    
    read -p "Absolute path: " CUSTOM_PATH
    
    if [[ -z "$CUSTOM_PATH" ]]; then
        print_error "Path cannot be empty"
        return 1
    fi
    
    if [[ ! -d "$CUSTOM_PATH" ]]; then
        print_warning "Directory does not exist: $CUSTOM_PATH"
        read -p "Create directory? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$CUSTOM_PATH"
            if [[ -n "$SELECTED_USER" ]]; then
                chown "$SELECTED_USER:$SELECTED_USER" "$CUSTOM_PATH"
            fi
            print_success "Created directory: $CUSTOM_PATH"
        else
            print_error "Directory does not exist. Please create it first."
            return 1
        fi
    fi
    
    APP_PATH="$CUSTOM_PATH"
    SERVICE_NAME=$(basename "$CUSTOM_PATH" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
    print_success "Using custom path: $APP_PATH"
    print_file "Service name will be: ${SERVICE_NAME}_python"
    
    return 0
}

detect_start_script() {
    print_status "Detecting Python application files..."
    
    START_SCRIPT=""
    
    COMMON_SCRIPTS=("app.py" "run.py" "main.py" "application.py" "wsgi.py" "manage.py" "start.py" "server.py")
    
    echo "Files found in $APP_PATH:"
    echo "----------------------------------------"
    ls -la "$APP_PATH" 2>/dev/null | grep -E "\.(py|sh)$" || echo "No Python or shell scripts found"
    echo "----------------------------------------"
    echo
    
    for script in "${COMMON_SCRIPTS[@]}"; do
        if [[ -f "$APP_PATH/$script" ]]; then
            START_SCRIPT="$APP_PATH/$script"
            print_success "Detected: $START_SCRIPT"
            break
        fi
    done
    
    if [[ -z "$START_SCRIPT" ]]; then
        print_warning "Could not automatically detect a Python application file"
        echo
        print_prompt "Please specify the startup script or command"
        echo "Examples:"
        echo "  - Python script: /path/to/app.py"
        echo "  - Shell script: /path/to/start.sh"
        echo "  - Command: gunicorn --bind 127.0.0.1:8000 wsgi:application"
        echo
        
        read -p "Startup script/command: " USER_SCRIPT
        
        if [[ -z "$USER_SCRIPT" ]]; then
            print_error "No startup script specified"
            return 1
        fi
        
        START_SCRIPT="$USER_SCRIPT"
    fi
    
    if [[ -f "$START_SCRIPT" ]]; then
        if [[ "$START_SCRIPT" == *.sh ]]; then
            SCRIPT_TYPE="shell"
            print_success "Shell script detected: $START_SCRIPT"
        elif [[ "$START_SCRIPT" == *.py ]]; then
            SCRIPT_TYPE="python"
            print_success "Python script detected: $START_SCRIPT"
        else
            SCRIPT_TYPE="custom"
            print_success "Custom script: $START_SCRIPT"
        fi
    else
        SCRIPT_TYPE="command"
        print_success "Command: $START_SCRIPT"
    fi
    
    return 0
}

configure_port() {
    echo
    print_prompt "Configure the port your Python application will run on"
    read -p "Port number [default: 8000]: " USER_PORT
    
    if [[ -z "$USER_PORT" ]]; then
        PORT="8000"
    elif [[ "$USER_PORT" =~ ^[0-9]+$ ]] && [[ "$USER_PORT" -ge 1024 ]] && [[ "$USER_PORT" -le 65535 ]]; then
        PORT="$USER_PORT"
    else
        print_error "Invalid port number. Using default: 8000"
        PORT="8000"
    fi
    
    print_success "Will use port: $PORT"
}

configure_virtualenv() {
    echo
    print_prompt "Does your application use a virtual environment?"
    read -p "Use virtual environment? (y/n) [default: n]: " USE_VENV
    
    if [[ $USE_VENV =~ ^[Yy]$ ]]; then
        VENV_PATH=""
        
        if [[ -d "$APP_PATH/venv" ]]; then
            VENV_PATH="$APP_PATH/venv"
        elif [[ -d "$APP_PATH/.venv" ]]; then
            VENV_PATH="$APP_PATH/.venv"
        elif [[ -d "$APP_PATH/env" ]]; then
            VENV_PATH="$APP_PATH/env"
        elif [[ -d "$APP_PATH/../.python-venv" ]]; then
            VENV_PATH="$APP_PATH/../.python-venv"
        fi
        
        if [[ -n "$VENV_PATH" ]]; then
            print_success "Detected virtual environment: $VENV_PATH"
            read -p "Use this virtual environment? (y/n) [default: y]: " USE_DETECTED
            if [[ ! $USE_DETECTED =~ ^[Nn]$ ]]; then
                print_success "Using detected virtual environment"
            else
                VENV_PATH=""
            fi
        fi
        
        if [[ -z "$VENV_PATH" ]]; then
            read -p "Enter virtual environment path (absolute path): " VENV_PATH
            if [[ -z "$VENV_PATH" ]]; then
                print_warning "No virtual environment specified, using system Python"
                USE_VENV="n"
            fi
        fi
        
        if [[ "$USE_VENV" =~ ^[Yy]$ ]] && [[ -n "$VENV_PATH" ]]; then
            if [[ ! -d "$VENV_PATH" ]]; then
                print_warning "Virtual environment directory does not exist: $VENV_PATH"
                read -p "Create it? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    python3 -m venv "$VENV_PATH"
                    if [[ -n "$SELECTED_USER" ]]; then
                        chown -R "$SELECTED_USER:$SELECTED_USER" "$VENV_PATH"
                    fi
                    print_success "Created virtual environment: $VENV_PATH"
                else
                    print_warning "Continuing without virtual environment"
                    USE_VENV="n"
                fi
            fi
        fi
    fi
    
    if [[ "$USE_VENV" =~ ^[Yy]$ ]]; then
        print_success "Will use virtual environment: $VENV_PATH"
    else
        print_success "Will use system Python"
        VENV_PATH=""
    fi
}

configure_working_directory() {
    print_status "Working directory configuration"
    
    read -p "Use custom working directory? (y/n) [default: n]: " USE_CUSTOM_WD
    
    if [[ $USE_CUSTOM_WD =~ ^[Yy]$ ]]; then
        read -p "Working directory path: " WORKING_DIR
        if [[ -z "$WORKING_DIR" ]]; then
            WORKING_DIR="$APP_PATH"
        fi
    else
        WORKING_DIR="$APP_PATH"
    fi
    
    if [[ ! -d "$WORKING_DIR" ]]; then
        print_warning "Working directory does not exist: $WORKING_DIR"
        read -p "Create it? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$WORKING_DIR"
            if [[ -n "$SELECTED_USER" ]]; then
                chown "$SELECTED_USER:$SELECTED_USER" "$WORKING_DIR"
            fi
            print_success "Created working directory"
        fi
    fi
    
    print_success "Working directory: $WORKING_DIR"
}

configure_service_user() {
    echo
    print_prompt "Select user to run the service"
    echo "Common options: admin, www-data, root"
    echo "Default will use the HestiaCP user: $SELECTED_USER"
    read -p "Service user [default: $SELECTED_USER]: " SERVICE_USER
    
    if [[ -z "$SERVICE_USER" ]]; then
        SERVICE_USER="$SELECTED_USER"
    fi
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        print_warning "User $SERVICE_USER does not exist"
        read -p "Create user? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            useradd -m -s /bin/bash "$SERVICE_USER"
            print_success "Created user: $SERVICE_USER"
        else
            print_error "User does not exist. Using root instead."
            SERVICE_USER="root"
        fi
    fi
    
    SERVICE_GROUP="$SERVICE_USER"
    print_success "Service will run as: $SERVICE_USER:$SERVICE_GROUP"
}

configure_logging() {
    echo
    print_prompt "Configure logging"
    
    LOG_DIR="$WORKING_DIR/logs"
    read -p "Log directory [default: $LOG_DIR]: " USER_LOG_DIR
    
    if [[ -n "$USER_LOG_DIR" ]]; then
        LOG_DIR="$USER_LOG_DIR"
    fi
    
    mkdir -p "$LOG_DIR"
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$LOG_DIR" 2>/dev/null || true
    
    ACCESS_LOG="$LOG_DIR/access.log"
    ERROR_LOG="$LOG_DIR/error.log"
    
    print_success "Access log: $ACCESS_LOG"
    print_success "Error log: $ERROR_LOG"
}

create_service_file() {
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    print_status "Creating systemd service file..."
    print_file "$SERVICE_FILE"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Python Application for ${SERVICE_NAME}
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${WORKING_DIR}
EOF

    if [[ -n "$VENV_PATH" ]]; then
        cat >> "$SERVICE_FILE" << EOF
Environment="PATH=${VENV_PATH}/bin:/usr/local/bin:/usr/bin:/bin"
EOF
    fi
    
    cat >> "$SERVICE_FILE" << EOF
Environment="PYTHONUNBUFFERED=1"

ExecStart=${START_SCRIPT}
Restart=always
RestartSec=5

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${WORKING_DIR} ${LOG_DIR}

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Created service file: $SERVICE_FILE"
    print_success "Service name: ${SERVICE_NAME}"
}

show_service_details() {
    echo
    echo "================================================================================"
    print_success "SERVICE CREATED SUCCESSFULLY!"
    echo "================================================================================"
    echo
    echo "Service Details:"
    echo "  Name: ${SERVICE_NAME}.service"
    echo "  Working Directory: $WORKING_DIR"
    echo "  Startup Command: $START_SCRIPT"
    echo "  Port: $PORT"
    [[ -n "$VENV_PATH" ]] && echo "  Virtual Environment: $VENV_PATH"
    echo "  User: $SERVICE_USER"
    echo "  Log Directory: $LOG_DIR"
    echo
    echo "Service Management Commands:"
    echo "  Start:   systemctl start ${SERVICE_NAME}"
    echo "  Stop:    systemctl stop ${SERVICE_NAME}"
    echo "  Restart: systemctl restart ${SERVICE_NAME}"
    echo "  Status:  systemctl status ${SERVICE_NAME}"
    echo "  Logs:    journalctl -u ${SERVICE_NAME} -f"
    echo
    echo "To enable auto-start on boot:"
    echo "  systemctl enable ${SERVICE_NAME}"
    echo
    echo "To disable auto-start on boot:"
    echo "  systemctl disable ${SERVICE_NAME}"
    echo
    echo "Nginx Template:"
    echo "  Make sure to select 'python-app' template in HestiaCP for your domain"
    echo "  The template proxies to port $PORT"
    echo
    echo "================================================================================"
}

confirm_and_create() {
    echo
    echo "================================================================================"
    print_status "Service Configuration Summary"
    echo "================================================================================"
    echo
    echo "HestiaCP User: $SELECTED_USER"
    echo "Service Name: ${SERVICE_NAME}"
    echo "Application Path: $APP_PATH"
    echo "Working Directory: $WORKING_DIR"
    echo "Startup Command: $START_SCRIPT"
    echo "Port: $PORT"
    [[ -n "$VENV_PATH" ]] && echo "Virtual Environment: $VENV_PATH"
    echo "Service User: $SERVICE_USER"
    echo "Log Directory: $LOG_DIR"
    echo
    echo "Systemd Service File: /etc/systemd/system/${SERVICE_NAME}.service"
    echo
    echo "================================================================================"
    echo
    
    read -p "Create this service? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Service creation aborted"
        exit 0
    fi
    
    create_service_file
    systemctl daemon-reload
    
    echo
    read -p "Start service now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl start "${SERVICE_NAME}"
        print_success "Service started"
        
        sleep 2
        systemctl status "${SERVICE_NAME}" --no-pager
    else
        print_status "Service created but not started"
    fi
    
    read -p "Enable service on boot? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl enable "${SERVICE_NAME}"
        print_success "Service enabled on boot"
    fi
    
    show_service_details
}

main() {
    echo "================================================================================"
    echo "  HestiaCP Python Application Service Creator"
    echo "  Creates systemd service for Python applications"
    echo "  Supports: Ubuntu 22.04/24.04 | Debian 11/12"
    echo "================================================================================"
    echo
    
    check_root
    
    while ! select_user; do
        print_status "Please try again"
    done
    
    if list_domains_for_user "$SELECTED_USER"; then
        while ! select_domain_or_path "$SELECTED_USER"; do
            print_status "Please try again"
        done
    else
        select_custom_path
    fi
    
    detect_start_script
    configure_port
    configure_virtualenv
    configure_working_directory
    configure_service_user
    configure_logging
    confirm_and_create
}

main