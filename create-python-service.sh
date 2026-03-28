#!/bin/bash
# Interactive script to create systemd service for Python applications in HestiaCP
# Supports: Ubuntu 22.04, Ubuntu 24.04, and Debian (11, 12)
# Creates app.sh template if it doesn't exist

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

select_domain() {
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
                
                # Look for application subdirectory
                local base_path="/home/$user/web/$SELECTED_DOMAIN/private"
                local app_subdir=""
                
                # Check common subdirectory names
                if [[ -d "$base_path/python_app" ]]; then
                    app_subdir="python_app"
                elif [[ -d "$base_path/pandora" ]]; then
                    app_subdir="pandora"
                elif [[ -d "$base_path/app" ]]; then
                    app_subdir="app"
                elif [[ -d "$base_path/application" ]]; then
                    app_subdir="application"
                else
                    # Ask user for subdirectory
                    echo
                    print_prompt "Available directories in $base_path:"
                    ls -la "$base_path" 2>/dev/null | grep '^d' | awk '{print $9}' | grep -v '^\.\.\?$' || echo "  (none found)"
                    echo
                    read -p "Enter the application subdirectory name (e.g., pandora, python_app) or press Enter for base path: " app_subdir
                fi
                
                if [[ -n "$app_subdir" ]]; then
                    APP_PATH="$base_path/$app_subdir"
                else
                    APP_PATH="$base_path"
                fi
                
                SERVICE_NAME="${SELECTED_DOMAIN}"
                print_success "Selected domain: $SELECTED_DOMAIN"
                print_file "Application path: $APP_PATH"
                return 0
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

select_custom_path() {
    echo
    print_prompt "Enter the absolute path to your Python application directory"
    echo "Examples: /home/admin/web/example.com/private/pandora"
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
    SERVICE_NAME=$(basename "$(dirname "$APP_PATH")" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')
    print_success "Using custom path: $APP_PATH"
    
    return 0
}

detect_or_create_app_sh() {
    print_status "Checking for app.sh in $APP_PATH..."
    
    APP_SH_PATH="$APP_PATH/app.sh"
    
    if [[ -f "$APP_SH_PATH" ]]; then
        print_success "Found existing app.sh: $APP_SH_PATH"
        read -p "Use existing app.sh? (y/n) [default: y]: " USE_EXISTING
        if [[ ! $USE_EXISTING =~ ^[Nn]$ ]]; then
            START_SCRIPT="$APP_SH_PATH"
            SCRIPT_TYPE="shell"
            print_success "Will use existing app.sh"
            return 0
        fi
    fi
    
    # Create app.sh template
    print_status "Creating app.sh template..."
    
    # Detect Python entry point
    PYTHON_ENTRY=""
    if [[ -f "$APP_PATH/run.py" ]]; then
        PYTHON_ENTRY="run.py"
    elif [[ -f "$APP_PATH/app.py" ]]; then
        PYTHON_ENTRY="app.py"
    elif [[ -f "$APP_PATH/main.py" ]]; then
        PYTHON_ENTRY="main.py"
    elif [[ -f "$APP_PATH/wsgi.py" ]]; then
        PYTHON_ENTRY="wsgi.py"
    fi
    
    cat > "$APP_SH_PATH" << 'EOF'
#!/bin/bash
# app.sh - Startup script for Python application
# Created by HestiaCP Python Service Creator

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to the script directory
cd "$SCRIPT_DIR"

# Set Python path to include current directory
export PYTHONPATH="${SCRIPT_DIR}:${PYTHONPATH}"

# Activate virtual environment if it exists
if [[ -d "venv" ]]; then
    source venv/bin/activate
    echo "Virtual environment activated: venv"
elif [[ -d ".venv" ]]; then
    source .venv/bin/activate
    echo "Virtual environment activated: .venv"
elif [[ -d "../.python-venv" ]]; then
    source ../.python-venv/bin/activate
    echo "Virtual environment activated: ../.python-venv"
fi

# Determine which Python file to run
PYTHON_SCRIPT=""
if [[ -f "run.py" ]]; then
    PYTHON_SCRIPT="run.py"
elif [[ -f "app.py" ]]; then
    PYTHON_SCRIPT="app.py"
elif [[ -f "main.py" ]]; then
    PYTHON_SCRIPT="main.py"
elif [[ -f "wsgi.py" ]]; then
    PYTHON_SCRIPT="wsgi.py"
else
    echo "ERROR: No Python application file found (run.py, app.py, main.py, wsgi.py)"
    exit 1
fi

echo "Starting Python application: $PYTHON_SCRIPT"

# Execute Python script with all passed arguments
exec python3 "$PYTHON_SCRIPT" "$@"
EOF
    
    # If we detected a specific Python entry point, customize the script
    if [[ -n "$PYTHON_ENTRY" ]]; then
        sed -i "s|PYTHON_SCRIPT=\"\"|PYTHON_SCRIPT=\"$PYTHON_ENTRY\"|" "$APP_SH_PATH"
        sed -i "s|if \[\[ -f \"run\.py\" \]\]; then|if [[ -f \"$PYTHON_ENTRY\" ]]; then|" "$APP_SH_PATH"
    fi
    
    chmod +x "$APP_SH_PATH"
    chown "$SELECTED_USER:$SELECTED_USER" "$APP_SH_PATH"
    
    print_success "Created app.sh at $APP_SH_PATH"
    print_success "Made app.sh executable"
    
    START_SCRIPT="$APP_SH_PATH"
    SCRIPT_TYPE="shell"
    
    return 0
}

configure_port() {
    echo
    print_prompt "Configure the port your Python application will run on"
    echo "This should match the port in your Nginx template (python-app)"
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
        
        # Try to detect common virtual environment locations
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

configure_logging() {
    echo
    print_prompt "Configure logging"
    
    LOG_DIR="$APP_PATH/logs"
    read -p "Log directory [default: $LOG_DIR]: " USER_LOG_DIR
    
    if [[ -n "$USER_LOG_DIR" ]]; then
        LOG_DIR="$USER_LOG_DIR"
    fi
    
    mkdir -p "$LOG_DIR"
    chown -R "$SELECTED_USER:$SELECTED_USER" "$LOG_DIR" 2>/dev/null || true
    
    print_success "Log directory: $LOG_DIR"
}

create_service_file() {
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    print_status "Creating systemd service file..."
    print_file "$SERVICE_FILE"
    
    # Create the exact service structure you specified
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Python Application for ${SERVICE_NAME}
After=network.target

[Service]
Type=simple
User=${SELECTED_USER}
Group=${SELECTED_USER}
WorkingDirectory=${APP_PATH}
Environment="PYTHONUNBUFFERED=1"

ExecStart=${APP_PATH}/app.sh
Restart=always
RestartSec=5

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
# ProtectHome=yes  # REMOVED - was blocking access to /home
ReadWritePaths=${APP_PATH} ${LOG_DIR}

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Created service file: $SERVICE_FILE"
    print_success "Service name: $SERVICE_NAME"
}

show_service_details() {
    echo
    echo "================================================================================"
    print_success "SERVICE CREATED SUCCESSFULLY!"
    echo "================================================================================"
    echo
    echo "Service Details:"
    echo "  Name: $SERVICE_NAME"
    echo "  Working Directory: $APP_PATH"
    echo "  Startup Script: $APP_PATH/app.sh"
    echo "  Port: $PORT"
    [[ -n "$VENV_PATH" ]] && echo "  Virtual Environment: $VENV_PATH"
    echo "  User: $SELECTED_USER"
    echo "  Log Directory: $LOG_DIR"
    echo
    echo "Service Management Commands:"
    echo "  Start:   systemctl start $SERVICE_NAME"
    echo "  Stop:    systemctl stop $SERVICE_NAME"
    echo "  Restart: systemctl restart $SERVICE_NAME"
    echo "  Status:  systemctl status $SERVICE_NAME"
    echo "  Logs:    journalctl -u $SERVICE_NAME -f"
    echo
    echo "To enable auto-start on boot:"
    echo "  systemctl enable $SERVICE_NAME"
    echo
    echo "To disable auto-start on boot:"
    echo "  systemctl disable $SERVICE_NAME"
    echo
    echo "Nginx Template:"
    echo "  Make sure to select 'python-app' template in HestiaCP for your domain"
    echo "  The template proxies to port $PORT"
    echo
    echo "IMPORTANT: ProtectHome=yes is NOT enabled to allow access to /home directory"
    echo
    echo "================================================================================"
}

confirm_and_create() {
    echo
    echo "================================================================================"
    print_status "Service Configuration Summary"
    echo "================================================================================"
    echo
    echo "Service Name: $SERVICE_NAME"
    echo "Application Path: $APP_PATH"
    echo "Startup Script: $APP_PATH/app.sh"
    echo "Port: $PORT"
    [[ -n "$VENV_PATH" ]] && echo "Virtual Environment: $VENV_PATH"
    echo "User: $SELECTED_USER"
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
        systemctl start "$SERVICE_NAME"
        print_success "Service started"
        
        sleep 2
        echo
        print_status "Service status:"
        systemctl status "$SERVICE_NAME" --no-pager || true
    else
        print_status "Service created but not started"
    fi
    
    read -p "Enable service on boot? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl enable "$SERVICE_NAME"
        print_success "Service enabled on boot"
    fi
    
    show_service_details
}

main() {
    echo "================================================================================"
    echo "  HestiaCP Python Application Service Creator"
    echo "  Creates systemd service for Python applications"
    echo "  Supports: Ubuntu 22.04/24.04 | Debian 11/12"
    echo "  Creates app.sh template if it doesn't exist"
    echo "================================================================================"
    echo
    
    check_root
    
    # Select HestiaCP user
    while ! select_user; do
        print_status "Please try again"
    done
    
    # List domains for selected user
    if list_domains_for_user "$SELECTED_USER"; then
        while ! select_domain "$SELECTED_USER"; do
            print_status "Please try again"
        done
    else
        select_custom_path
    fi
    
    # Ensure directory exists
    if [[ ! -d "$APP_PATH" ]]; then
        print_warning "Directory does not exist: $APP_PATH"
        read -p "Create directory? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$APP_PATH"
            if [[ -n "$SELECTED_USER" ]]; then
                chown "$SELECTED_USER:$SELECTED_USER" "$APP_PATH"
            fi
            print_success "Created directory: $APP_PATH"
        else
            print_error "Directory does not exist. Please create it first."
            exit 1
        fi
    fi
    
    # Detect or create app.sh
    detect_or_create_app_sh
    
    configure_port
    configure_virtualenv
    configure_logging
    confirm_and_create
}

main