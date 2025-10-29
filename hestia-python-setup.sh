#!/bin/bash

# Hestia CP Python Application Setup Script - WITH USER SUPPORT
# Usage: ./hestia-python-setup.sh [domain] [--user USER] [--port PORT] [--python-version VERSION]

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar mensajes de error
error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Función para mostrar mensajes de éxito
success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Función para mostrar información
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Función para mostrar advertencias
warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Función para mostrar ayuda
show_help() {
    cat << EOF
Hestia CP Python Application Setup Script

Usage: $0 DOMAIN [OPTIONS]

Options:
    -u, --user USER          Hestia user account (default: current user)
    -p, --port PORT          Set application port (default: 8000)
    -v, --python-version VERSION Set Python version (default: 3.9)
    -f, --force              Force recreation of application
    -h, --help               Show this help message

Examples:
    $0 example.com
    $0 example.com --user admin --port 8000
    $0 example.com --user myuser --python-version 3.11 --port 3000
    $0 example.com --force
EOF
}

# Variables por defecto
DOMAIN=""
USER=""  # No default user - will be determined
PORT="8000"
PYTHON_VERSION="3.9"
FORCE=false

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -v|--python-version)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            error "Opción desconocida: $1"
            show_help
            exit 1
            ;;
        *)
            DOMAIN="$1"
            shift
            ;;
    esac
done

# Validar dominio
if [[ -z "$DOMAIN" ]]; then
    error "Debe especificar un dominio"
    show_help
    exit 1
fi

# Determinar usuario si no se especificó
if [[ -z "$USER" ]]; then
    # Intentar detectar el usuario actual
    if [[ -n "$SUDO_USER" ]]; then
        USER="$SUDO_USER"
    else
        USER=$(whoami)
    fi
    info "Usando usuario: $USER (detectado automáticamente)"
fi

# Validar que el usuario existe en el sistema
if ! id "$USER" &>/dev/null; then
    error "El usuario $USER no existe en el sistema"
    exit 1
fi

# Validar que el usuario tiene permisos en Hestia
if ! sudo -u "$USER" -H hestia -v &>/dev/null; then
    error "El usuario $USER no tiene acceso a Hestia CP o no está configurado correctamente"
    exit 1
fi

# Validar que el dominio existe en Hestia para este usuario
if ! sudo -u "$USER" -H v-list-web-domain "$USER" "$DOMAIN" >/dev/null 2>&1; then
    error "El dominio $DOMAIN no existe para el usuario $USER"
    echo "Crear el dominio primero con: v-add-web-domain $USER $DOMAIN"
    exit 1
fi

# Obtener información del dominio
DOMAIN_INFO=$(sudo -u "$USER" -H v-list-web-domain "$USER" "$DOMAIN" json)
HOME_DIR=$(echo "$DOMAIN_INFO" | grep -o '"HOME":"[^"]*' | cut -d'"' -f4)
IP=$(echo "$DOMAIN_INFO" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)

if [[ -z "$HOME_DIR" ]] || [[ -z "$IP" ]]; then
    error "No se pudo obtener la información del dominio $DOMAIN"
    exit 1
fi

info "Configurando aplicación Python para: $DOMAIN"
info "Usuario Hestia: $USER"
info "Directorio home: $HOME_DIR"
info "IP: $IP"
info "Puerto: $PORT"
info "Versión Python: $PYTHON_VERSION"

# Verificar si ya existe una aplicación Python
APP_DIR="$HOME_DIR/web/$DOMAIN/private/python_app"
if [[ -d "$APP_DIR" ]] && [[ "$FORCE" != "true" ]]; then
    warning "Ya existe una aplicación Python para este dominio."
    read -p "¿Desea recrearla? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Operación cancelada."
        exit 0
    fi
    FORCE=true
fi

# Crear estructura de directorios
create_app_structure() {
    info "Creando estructura de directorios..."
    
    sudo -u "$USER" -H mkdir -p "$APP_DIR/static"
    sudo -u "$USER" -H mkdir -p "$APP_DIR/templates"
    sudo -u "$USER" -H mkdir -p "$APP_DIR/media"
    sudo -u "$USER" -H mkdir -p "$HOME_DIR/web/$DOMAIN/.python-venv"
    sudo -u "$USER" -H mkdir -p "$HOME_DIR/web/$DOMAIN/logs/python"
    
    success "Estructura de directorios creada"
}

# Crear entorno virtual
setup_virtualenv() {
    info "Configurando entorno virtual Python..."
    
    VENV_DIR="$HOME_DIR/web/$DOMAIN/.python-venv"
    
    if [[ -d "$VENV_DIR/bin" ]] && [[ "$FORCE" != "true" ]]; then
        warning "El entorno virtual ya existe. Usando el existente."
    else
        # Limpiar si force está activado
        if [[ "$FORCE" == "true" ]] && [[ -d "$VENV_DIR" ]]; then
            sudo -u "$USER" -H rm -rf "$VENV_DIR"
        fi
        
        if command -v python3 >/dev/null 2>&1; then
            sudo -u "$USER" -H python3 -m venv "$VENV_DIR"
            success "Entorno virtual creado"
        else
            error "Python3 no está instalado"
            exit 1
        fi
    fi
}

# Crear archivos de aplicación por defecto
create_default_app() {
    info "Creando aplicación Python por defecto..."
    
    # Limpiar directorio si force está activado
    if [[ "$FORCE" == "true" ]]; then
        sudo -u "$USER" -H rm -rf "$APP_DIR"/* 2>/dev/null || true
    fi
    
    # requirements.txt
    sudo -u "$USER" -H bash -c "cat > '$APP_DIR/requirements.txt'" << 'REQ'
Flask==2.3.3
gunicorn==21.2.0
Werkzeug==2.3.7
REQ

    # app.py
    sudo -u "$USER" -H bash -c "cat > '$APP_DIR/app.py'" << 'APP'
from flask import Flask, jsonify, render_template
import os
import datetime

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html', 
                         domain=os.environ.get('DOMAIN', 'localhost'),
                         time=datetime.datetime.now())

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
APP

    # templates/index.html
    sudo -u "$USER" -H mkdir -p "$APP_DIR/templates"
    sudo -u "$USER" -H bash -c "cat > '$APP_DIR/templates/index.html'" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Python App - {{ domain }}</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container { 
            background: white; 
            padding: 3rem; 
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 600px;
        }
        .logo { 
            font-size: 4rem; 
            margin-bottom: 1rem; 
        }
        h1 { 
            color: #333; 
            margin-bottom: 1rem;
        }
        .status {
            background: #4CAF50;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            display: inline-block;
            margin: 1rem 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🐍</div>
        <h1>Python Application Ready!</h1>
        <p>Your Python application is successfully deployed on <strong>{{ domain }}</strong></p>
        <div class="status">🚀 Application Running</div>
        <p><em>Server Time: {{ time }}</em></p>
    </div>
</body>
</html>
HTML

    # wsgi.py
    sudo -u "$USER" -H bash -c "cat > '$APP_DIR/wsgi.py'" << 'WSGI'
import sys
import os

app_dir = os.path.dirname(os.path.abspath(__file__))
if app_dir not in sys.path:
    sys.path.insert(0, app_dir)

from app import app as application

if __name__ == "__main__":
    application.run()
WSGI

    success "Aplicación por defecto creada"
}

# Instalar dependencias
install_dependencies() {
    info "Instalando dependencias Python..."
    
    VENV_DIR="$HOME_DIR/web/$DOMAIN/.python-venv"
    
    if sudo -u "$USER" -H bash -c "source '$VENV_DIR/bin/activate' && pip install -r '$APP_DIR/requirements.txt'"; then
        success "Dependencias instaladas correctamente"
    else
        error "Error al instalar dependencias"
        exit 1
    fi
}

# Configurar permisos
set_permissions() {
    info "Configurando permisos..."
    
    # Los archivos ya deberían tener los permisos correctos por el uso de sudo -u $USER
    # Solo aseguramos permisos de ejecución si es necesario
    sudo -u "$USER" -H chmod -R 755 "$APP_DIR"
    sudo -u "$USER" -H chmod -R 755 "$HOME_DIR/web/$DOMAIN/.python-venv"
    
    success "Permisos configurados"
}

# Crear servicio systemd
create_systemd_service() {
    info "Creando servicio systemd..."
    
    SERVICE_NAME="${DOMAIN//./_}_python"
    VENV_DIR="$HOME_DIR/web/$DOMAIN/.python-venv"
    
    # Crear el archivo de servicio temporal como root
    cat > "/tmp/$SERVICE_NAME.service" << EOF
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
          --access-logfile $HOME_DIR/web/$DOMAIN/logs/python/access.log \\
          --error-logfile $HOME_DIR/web/$DOMAIN/logs/python/error.log \\
          --capture-output \\
          --log-level info \\
          wsgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    success "Servicio systemd creado en /tmp/$SERVICE_NAME.service"
}

# Configurar template en HestiaCP
configure_hestia_templates() {
    info "Configurando templates en HestiaCP..."
    
    # Aplicar template web Python
    if sudo -u "$USER" -H v-change-web-domain-tpl "$USER" "$DOMAIN" 'python-app' 'yes'; then
        success "Template web Python aplicado"
    else
        error "Error al aplicar template web Python"
        error "Asegúrate de que el template 'python-app' está instalado"
        exit 1
    fi
    
    # Configurar proxy
    sleep 2
    if sudo -u "$USER" -H v-change-web-domain-proxy-tpl "$USER" "$DOMAIN" 'python-app' 'yes'; then
        success "Template proxy Python aplicado"
    else
        error "Error al aplicar template proxy Python"
        exit 1
    fi
    
    # Actualizar puerto del backend
    sleep 2
    if sudo -u "$USER" -H v-change-web-domain-backend "$USER" "$DOMAIN" 'python' "$PORT" 'no'; then
        success "Puerto backend configurado a $PORT"
    else
        warning "No se pudo configurar el puerto backend automáticamente"
        info "Configura manualmente en HestiaCP: Backend Port -> $PORT"
    fi
}

# Reiniciar servicios
restart_services() {
    info "Reiniciando servicios web..."
    
    sudo -u "$USER" -H v-restart-web
    sleep 2
    
    success "Servicios reiniciados"
}

# Iniciar servicio de aplicación
start_application_service() {
    info "Iniciando servicio de aplicación..."
    
    SERVICE_NAME="${DOMAIN//./_}_python"
    
    # Copiar servicio a systemd (requiere root)
    if sudo cp "/tmp/$SERVICE_NAME.service" "/etc/systemd/system/"; then
        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME.service"
        
        # Intentar iniciar el servicio
        if sudo systemctl start "$SERVICE_NAME.service"; then
            sleep 2
            if sudo systemctl is-active --quiet "$SERVICE_NAME.service"; then
                success "Servicio de aplicación iniciado correctamente"
            else
                error "El servicio se inició pero no está activo"
                sudo systemctl status "$SERVICE_NAME.service"
            fi
        else
            error "Error al iniciar el servicio"
            sudo systemctl status "$SERVICE_NAME.service"
        fi
    else
        error "Error al copiar el servicio systemd (se requieren permisos root)"
        info "Puedes copiar manualmente:"
        echo "  sudo cp /tmp/$SERVICE_NAME.service /etc/systemd/system/"
        echo "  sudo systemctl daemon-reload"
        echo "  sudo systemctl enable $SERVICE_NAME.service"
        echo "  sudo systemctl start $SERVICE_NAME.service"
    fi
}

# Limpiar archivos temporales
cleanup() {
    SERVICE_NAME="${DOMAIN//./_}_python"
    rm -f "/tmp/$SERVICE_NAME.service"
    info "Archivos temporales limpiados"
}

# Función principal
main() {
    info "Iniciando configuración de aplicación Python..."
    
    create_app_structure
    setup_virtualenv
    create_default_app
    install_dependencies
    set_permissions
    create_systemd_service
    configure_hestia_templates
    restart_services
    start_application_service
    cleanup
    
    # Mostrar resumen
    success "Aplicación Python configurada exitosamente!"
    echo
    info "=== RESUMEN DE CONFIGURACIÓN ==="
    echo "  Dominio: https://$DOMAIN"
    echo "  Usuario: $USER"
    echo "  Directorio de la app: $APP_DIR"
    echo "  Entorno virtual: $HOME_DIR/web/$DOMAIN/.python-venv"
    echo "  Puerto de la app: $PORT"
    echo "  Servicio systemd: ${DOMAIN//./_}_python.service"
    echo
    info "=== COMANDOS ÚTILES ==="
    echo "  Reiniciar app: sudo systemctl restart ${DOMAIN//./_}_python.service"
    echo "  Ver logs: sudo journalctl -u ${DOMAIN//./_}_python.service -f"
    echo "  Ver estado: sudo systemctl status ${DOMAIN//./_}_python.service"
    echo "  Instalar dependencias: $HOME_DIR/web/$DOMAIN/.python-venv/bin/pip install [package]"
    echo
    info "=== PRÓXIMOS PASOS ==="
    echo "  1. Sube tu aplicación Python a: $APP_DIR"
    echo "  2. Actualiza requirements.txt si es necesario"
    echo "  3. Reinicia la aplicación: sudo systemctl restart ${DOMAIN//./_}_python.service"
    echo "  4. Configura SSL/Let's Encrypt en el panel de HestiaCP"
    echo
    warning "Si tienes problemas con Let's Encrypt, asegúrate de usar los templates corregidos"
}

# Ejecutar función principal
main "$@"
