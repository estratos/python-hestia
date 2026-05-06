#!/bin/bash
# Script para crear servicio systemd para Python app en HestiaCP
# 

set -e

# Colores para output
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

print_prompt() {
    echo -e "${MAGENTA}[PROMPT]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Este script debe ejecutarse como root (usa sudo)"
        exit 1
    fi
}

get_app_config() {
    # Configuración específica para tu aplicación
    APP_USER="machovaquero"
    APP_DOMAIN="pandoraapi.machovaquero.com"
    APP_PATH="/home/machovaquero/web/pandoraapi.machovaquero.com/private/pandora"
    APP_SCRIPT="run.py"
    PORT=8000
    
    print_status "Usando configuración para: $APP_DOMAIN"
    print_status "Ruta de la aplicación: $APP_PATH"
    print_status "Script principal: $APP_SCRIPT"
    
    # Verificar que run.py existe
    if [[ ! -f "$APP_PATH/$APP_SCRIPT" ]]; then
        print_error "No se encuentra $APP_SCRIPT en $APP_PATH"
        exit 1
    fi
    
    print_success "Configuración verificada correctamente"
}

detect_python_command() {
    # Detectar comando Python correcto
    if [[ -f "$APP_PATH/venv/bin/python" ]]; then
        PYTHON_CMD="$APP_PATH/venv/bin/python"
        VENV_PATH="$APP_PATH/venv"
        print_success "Virtualenv detectado en: $VENV_PATH"
    elif [[ -f "$APP_PATH/.venv/bin/python" ]]; then
        PYTHON_CMD="$APP_PATH/.venv/bin/python"
        VENV_PATH="$APP_PATH/.venv"
        print_success "Virtualenv detectado en: $VENV_PATH"
    elif [[ -f "$APP_PATH/env/bin/python" ]]; then
        PYTHON_CMD="$APP_PATH/env/bin/python"
        VENV_PATH="$APP_PATH/env"
        print_success "Virtualenv detectado en: $VENV_PATH"
    else
        PYTHON_CMD="/usr/bin/python3"
        VENV_PATH=""
        print_status "Usando Python del sistema: $PYTHON_CMD"
    fi
    
    # Verificar que el comando Python funciona
    if ! $PYTHON_CMD --version > /dev/null 2>&1; then
        print_error "El comando Python no funciona: $PYTHON_CMD"
        exit 1
    fi
}

create_service_file() {
    SERVICE_NAME="pandora"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    
    # Hacer backup si existe
    if [[ -f "$SERVICE_FILE" ]]; then
        BACKUP="${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "Servicio existente encontrado. Creando backup: $BACKUP"
        cp "$SERVICE_FILE" "$BACKUP"
    fi
    
    print_status "Creando archivo de servicio systemd..."
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Python Application for ${APP_DOMAIN} - Pandora Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_PATH}
Environment="PYTHONUNBUFFERED=1"
Environment="PORT=${PORT}"
EOF

    # Añadir virtualenv si existe
    if [[ -n "$VENV_PATH" ]]; then
        cat >> "$SERVICE_FILE" << EOF
Environment="PATH=${VENV_PATH}/bin:/usr/local/bin:/usr/bin:/bin"
EOF
    fi
    
    # Comando de inicio
    cat >> "$SERVICE_FILE" << EOF
ExecStart=${PYTHON_CMD} ${APP_PATH}/${APP_SCRIPT}
Restart=always
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5

# Seguridad
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=${APP_PATH} ${APP_PATH}/logs

# Limites de recursos
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Archivo de servicio creado: $SERVICE_FILE"
    
    # Configurar permisos
    chmod 644 "$SERVICE_FILE"
}

create_app_sh() {
    # Crear script alternativo app.sh (opcional)
    cat > "$APP_PATH/app.sh" << 'EOF'
#!/bin/bash
# Script wrapper para la aplicación Pandora
cd "$(dirname "$0")"

# Activar virtualenv si existe
if [[ -f "venv/bin/activate" ]]; then
    source venv/bin/activate
fi

# Ejecutar la aplicación
exec python3 run.py
EOF
    
    chmod +x "$APP_PATH/app.sh"
    chown "$APP_USER:$APP_USER" "$APP_PATH/app.sh"
    print_success "Script app.sh creado (alternativa)"
}

setup_logging() {
    LOG_DIR="$APP_PATH/logs"
    mkdir -p "$LOG_DIR"
    chown -R "$APP_USER:$APP_USER" "$LOG_DIR"
    print_success "Directorio de logs configurado: $LOG_DIR"
}

setup_environment() {
    print_status "Verificando requisitos..."
    
    # Verificar Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 no está instalado"
        exit 1
    fi
    
    # Verificar pip
    if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
        print_warning "pip no encontrado. Puede necesitar instalar dependencias manualmente"
    fi
    
    # Verificar requirements.txt
    if [[ -f "$APP_PATH/requirements.txt" ]]; then
        print_status "Instalando dependencias desde requirements.txt..."
        if [[ -n "$VENV_PATH" ]]; then
            $VENV_PATH/bin/pip install -r "$APP_PATH/requirements.txt"
        else
            pip3 install -r "$APP_PATH/requirements.txt" || \
            print_warning "No se pudieron instalar todas las dependencias"
        fi
    fi
}

manage_service() {
    print_status "Recargando systemd..."
    systemctl daemon-reload
    
    echo
    print_prompt "¿Qué acción deseas realizar?"
    echo "1) Iniciar el servicio"
    echo "2) Detener el servicio"
    echo "3) Reiniciar el servicio"
    echo "4) Ver estado del servicio"
    echo "5) Ver logs en tiempo real"
    echo "6) Habilitar inicio automático"
    echo "7) Deshabilitar inicio automático"
    echo "8) Salir"
    echo
    
    read -p "Selecciona una opción (1-8): " ACTION
    
    case $ACTION in
        1)
            systemctl start pandora
            print_success "Servicio iniciado"
            sleep 2
            systemctl status pandora --no-pager
            ;;
        2)
            systemctl stop pandora
            print_success "Servicio detenido"
            ;;
        3)
            systemctl restart pandora
            print_success "Servicio reiniciado"
            sleep 2
            systemctl status pandora --no-pager
            ;;
        4)
            systemctl status pandora --no-pager
            ;;
        5)
            print_status "Mostrando logs (Ctrl+C para salir)"
            journalctl -u pandora -f
            ;;
        6)
            systemctl enable pandora
            print_success "Servicio habilitado para inicio automático"
            ;;
        7)
            systemctl disable pandora
            print_warning "Servicio deshabilitado para inicio automático"
            ;;
        8)
            print_status "Saliendo"
            exit 0
            ;;
        *)
            print_error "Opción inválida"
            ;;
    esac
}

show_info() {
    echo
    echo "================================================================================"
    print_success "CONFIGURACIÓN COMPLETADA"
    echo "================================================================================"
    echo
    echo "📁 Ruta de la aplicación: $APP_PATH"
    echo "🐍 Script principal: $APP_SCRIPT"
    [[ -n "$VENV_PATH" ]] && echo "🔧 Virtualenv: $VENV_PATH"
    echo "👤 Usuario: $APP_USER"
    echo "🌐 Puerto: $PORT"
    echo "📝 Logs: $APP_PATH/logs"
    echo
    echo "📋 Comandos útiles:"
    echo "  sudo systemctl start pandora     # Iniciar"
    echo "  sudo systemctl stop pandora      # Detener"
    echo "  sudo systemctl restart pandora   # Reiniciar"
    echo "  sudo systemctl status pandora    # Estado"
    echo "  sudo journalctl -u pandora -f    # Ver logs"
    echo
    echo "🔍 Verificar si el puerto $PORT está en uso:"
    echo "  sudo lsof -i :$PORT"
    echo "  sudo netstat -tulpn | grep :$PORT"
    echo
    echo "================================================================================"
}

main() {
    echo "================================================================================"
    echo "  📦 Creador de Servicio Systemd para Pandora API"
    echo "  Aplicación: pandoraapi.machovaquero.com"
    echo "================================================================================"
    echo
    
    check_root
    get_app_config
    detect_python_command
    setup_logging
    setup_environment
    create_service_file
    create_app_sh  # Opcional, para compatibilidad
    
    show_info
    
    read -p "¿Deseas gestionar el servicio ahora? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        manage_service
    else
        print_success "Servicio creado. Usa 'sudo systemctl start pandora' cuando estés listo"
    fi
}

# Ejecutar script
main
