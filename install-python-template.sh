#!/bin/bash

# Hestia CP Python Template Installer 
# Script para instalar el template de Python en HESTIA CP incluyendo proxy template

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
HESTIA_TEMPLATES_DIR="/usr/local/hestia/data/templates/web/nginx"
HESTIA_PROXY_TEMPLATES_DIR="/usr/local/hestia/data/templates/web/nginx/proxy"
HESTIA_SCRIPTS_DIR="/usr/local/hestia/scripts"
TEMPLATE_NAME="python-app"
PROXY_TEMPLATE_NAME="python-app"
SCRIPT_NAME="hestia-python-setup"
BACKUP_DIR="/tmp/hestia-python-backup"

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

# Función para verificar si se está ejecutando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script debe ejecutarse como root"
        exit 1
    fi
}

# Función para verificar la instalación de Hestia
check_hestia() {
    if [[ ! -d "/usr/local/hestia" ]]; then
        error "Hestia CP no está instalado en /usr/local/hestia"
        exit 1
    fi
    
    if [[ ! -d "$HESTIA_TEMPLATES_DIR" ]]; then
        error "No se encuentra el directorio de templates de Hestia: $HESTIA_TEMPLATES_DIR"
        exit 1
    fi
}

# Función para crear backup de templates existentes
create_backup() {
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="${BACKUP_DIR}_${backup_timestamp}"
    
    info "Creando backup en: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup del template web si existe
    if [[ -f "$HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl" ]]; then
        cp "$HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl" "$BACKUP_DIR/"
        success "Backup del template web creado"
    fi
    
    # Backup del template proxy si existe
    if [[ -f "$HESTIA_PROXY_TEMPLATES_DIR/$PROXY_TEMPLATE_NAME.tpl" ]]; then
        cp "$HESTIA_PROXY_TEMPLATES_DIR/$PROXY_TEMPLATE_NAME.tpl" "$BACKUP_DIR/"
        success "Backup del template proxy creado"
    fi
    
    # Backup del script si existe
    if [[ -f "$HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh" ]]; then
        cp "$HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh" "$BACKUP_DIR/"
        success "Backup del script creado"
    fi
}

# Función para crear el template web de Python
create_python_web_template() {
    info "Creando template web de Python..."
    
    cat > "$HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl" << 'EOF'
#!/bin/bash

# Hestia CP Python Application Template
# Template: python-app
# Description: Template for Python web applications with Flask/Gunicorn

# Variables del template
WEB_TEMPLATE='python-app'
WEB_BACKEND='python'
WEB_PYTHON_VERSION='3.9'
WEB_PORT='5000'

# Configuración inicial
user='$USER'
domain='$DOMAIN'
ip='$IP'
home_dir='$HOMEDIR'
public_html='$PUBLIC_HTML'

# Crear estructura de directorios
mkdir -p $home_dir/web/$domain/private/python_app
mkdir -p $home_dir/web/$domain/private/python_app/static
mkdir -p $home_dir/web/$domain/private/python_app/templates
mkdir -p $home_dir/web/$domain/logs/python
mkdir -p $home_dir/web/$domain/.python-venv

# Crear virtual environment
echo "Creating Python virtual environment..."
python3 -m venv $home_dir/web/$domain/.python-venv

# Crear archivo de configuración básico para la app Python
cat > $home_dir/web/$domain/private/python_app/app.py << 'PYEOF'
from flask import Flask, render_template
import os
import datetime

app = Flask(__name__)

@app.route('/')
def hello():
    return render_template('index.html', 
                         domain=os.environ.get('DOMAIN', 'localhost'),
                         time=datetime.datetime.now())

@app.route('/health')
def health():
    return {'status': 'healthy', 'timestamp': datetime.datetime.now().isoformat()}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYEOF

# Crear template HTML básico
mkdir -p $home_dir/web/$domain/private/python_app/templates
cat > $home_dir/web/$domain/private/python_app/templates/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Python App - {{ domain }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
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
            width: 90%;
        }
        .logo { 
            font-size: 4rem; 
            margin-bottom: 1rem; 
        }
        h1 { 
            color: #333; 
            margin-bottom: 1rem;
            font-size: 2.2rem;
        }
        .subtitle {
            color: #666;
            font-size: 1.2rem;
            margin-bottom: 2rem;
        }
        .info-box {
            background: #f8f9fa;
            padding: 1.5rem;
            border-radius: 8px;
            border-left: 4px solid #667eea;
            text-align: left;
            margin: 2rem 0;
        }
        .info-box h3 {
            color: #333;
            margin-bottom: 1rem;
        }
        .info-box ul {
            list-style: none;
            padding: 0;
        }
        .info-box li {
            padding: 0.3rem 0;
            color: #555;
        }
        .info-box strong {
            color: #333;
        }
        .next-steps {
            text-align: left;
            background: #e7f3ff;
            padding: 1.5rem;
            border-radius: 8px;
            border-left: 4px solid #2196F3;
        }
        .next-steps h3 {
            color: #1565C0;
            margin-bottom: 1rem;
        }
        .next-steps ol {
            padding-left: 1.5rem;
        }
        .next-steps li {
            margin-bottom: 0.5rem;
            color: #555;
        }
        .status {
            display: inline-block;
            background: #4CAF50;
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            font-weight: bold;
            margin-top: 1rem;
        }
        code {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 0.2rem 0.4rem;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🐍</div>
        <h1>Python Application Ready!</h1>
        <p class="subtitle">Your Python application is successfully deployed on <strong>{{ domain }}</strong></p>
        
        <div class="status">🚀 Application Running</div>
        
        <div class="info-box">
            <h3>📋 Application Information</h3>
            <ul>
                <li><strong>Domain:</strong> {{ domain }}</li>
                <li><strong>User:</strong> $user</li>
                <li><strong>App Directory:</strong> <code>$home_dir/web/$domain/private/python_app</code></li>
                <li><strong>Virtual Environment:</strong> <code>$home_dir/web/$domain/.python-venv</code></li>
                <li><strong>Python Version:</strong> $WEB_PYTHON_VERSION</li>
                <li><strong>Application Port:</strong> $WEB_PORT</li>
                <li><strong>Server Time:</strong> {{ time.strftime('%Y-%m-%d %H:%M:%S') }}</li>
            </ul>
        </div>
        
        <div class="next-steps">
            <h3>🎯 Next Steps</h3>
            <ol>
                <li>Upload your Python application files to <code>private/python_app/</code></li>
                <li>Install dependencies: <code>source .python-venv/bin/activate && pip install -r requirements.txt</code></li>
                <li>Configure your WSGI application in <code>app.py</code></li>
                <li>Restart the service when you make changes: <code>systemctl restart ${domain}_python.service</code></li>
                <li>Check application logs: <code>journalctl -u ${domain}_python.service -f</code></li>
            </ol>
        </div>
        
        <p style="margin-top: 2rem; color: #666; font-size: 0.9rem;">
            <em>This is a default template. Replace this content with your actual Python application.</em>
        </p>
    </div>
</body>
</html>
HTMLEOF

# Crear requirements.txt
cat > $home_dir/web/$domain/private/python_app/requirements.txt << 'REQEOF'
Flask==2.3.3
gunicorn==21.2.0
REQEOF

# Crear archivo WSGI para Gunicorn
cat > $home_dir/web/$domain/private/python_app/wsgi.py << 'WSGIEOF'
import sys
import os

# Add the app directory to Python path
app_dir = os.path.join(os.path.dirname(__file__))
if app_dir not in sys.path:
    sys.path.insert(0, app_dir)

from app import app as application

if __name__ == "__main__":
    application.run()
WSGIEOF

# Crear script de inicio para la aplicación
cat > $home_dir/web/$domain/private/python_app/start_app.sh << 'SHEOF'
#!/bin/bash
cd $home_dir/web/$domain/private/python_app
source $home_dir/web/$domain/.python-venv/bin/activate
pip install -r requirements.txt
gunicorn --bind 127.0.0.1:$WEB_PORT --workers 3 wsgi:application
SHEOF

chmod +x $home_dir/web/$domain/private/python_app/start_app.sh

# Instalar dependencias en el virtual environment
echo "Installing Python dependencies..."
$home_dir/web/$domain/.python-venv/bin/pip install -r $home_dir/web/$domain/private/python_app/requirements.txt

# Configurar permisos
chown -R $user:$user $home_dir/web/$domain/private/python_app
chown -R $user:$user $home_dir/web/$domain/.python-venv
chmod 755 $home_dir/web/$domain/private/python_app

# Crear systemd service file
cat > /tmp/${domain}_python.service << 'SERVICEEOF'
[Unit]
Description=Python App for $domain
After=network.target
Wants=network.target

[Service]
Type=simple
User=$user
Group=$user
WorkingDirectory=$home_dir/web/$domain/private/python_app
Environment=PATH=$home_dir/web/$domain/.python-venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=DOMAIN=$domain
ExecStart=$home_dir/web/$domain/.python-venv/bin/gunicorn \
          --bind 127.0.0.1:$WEB_PORT \
          --workers 2 \
          --threads 4 \
          --access-logfile $home_dir/web/$domain/logs/python/access.log \
          --error-logfile $home_dir/web/$domain/logs/python/error.log \
          --capture-output \
          --log-level info \
          wsgi:application
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$home_dir/web/$domain/private/python_app
ReadWritePaths=$home_dir/web/$domain/logs/python

[Install]
WantedBy=multi-user.target
SERVICEEOF

echo "Python application template successfully configured for $domain"
echo "================================================================"
echo "🎉 Python Application Setup Complete!"
echo "================================================================"
echo "App directory: $home_dir/web/$domain/private/python_app"
echo "Virtual environment: $home_dir/web/$domain/.python-venv"
echo "Application URL: https://$domain"
echo "Application port: $WEB_PORT"
echo "Systemd service: ${domain}_python.service"
echo "================================================================"
EOF

    # Establecer permisos correctos en el template
    chmod 755 "$HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl"
    chown root:root "$HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl"
    
    success "Template web de Python creado en: $HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl"
}

# Función para crear el template de proxy de Python
create_python_proxy_template() {
    info "Creando template de proxy de Python..."
    
    # Crear directorio de templates proxy si no existe
    mkdir -p "$HESTIA_PROXY_TEMPLATES_DIR"
    
    cat > "$HESTIA_PROXY_TEMPLATES_DIR/$PROXY_TEMPLATE_NAME.tpl" << 'EOF'
# Python Application Proxy Configuration for $DOMAIN
# Generated by Python App Template

# Main application
location / {
    proxy_pass http://127.0.0.1:$WEB_PORT;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}

# Static files
location /static/ {
    alias $HOMEDIR/web/$DOMAIN/private/python_app/static/;
    expires 30d;
    access_log off;
    add_header Cache-Control "public, immutable";
}

# Media files
location /media/ {
    alias $HOMEDIR/web/$DOMAIN/private/python_app/media/;
    expires 30d;
    access_log off;
}

# Health check endpoint
location /health {
    proxy_pass http://127.0.0.1:$WEB_PORT/health;
    proxy_set_header Host $host;
    access_log off;
}

# Deny access to sensitive files
location ~ /(\.git|\.env|requirements\.txt|wsgi\.py) {
    deny all;
    return 404;
}
EOF

    # Establecer permisos correctos en el template proxy
    chmod 644 "$HESTIA_PROXY_TEMPLATES_DIR/$PROXY_TEMPLATE_NAME.tpl"
    chown root:root "$HESTIA_PROXY_TEMPLATES_DIR/$PROXY_TEMPLATE_NAME.tpl"
    
    success "Template de proxy de Python creado en: $HESTIA_PROXY_TEMPLATES_DIR/$PROXY_TEMPLATE_NAME.tpl"
}

# Función para crear el script de configuración
create_setup_script() {
    info "Creando script de configuración..."
    
    # Crear directorio de scripts si no existe
    mkdir -p "$HESTIA_SCRIPTS_DIR"
    
    cat > "$HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh" << 'SCRIPTEOF'
#!/bin/bash

# Hestia CP Python Application Setup Script - Fixed Version
# Usage: ./hestia-python-setup.sh [domain] [--port PORT] [--python-version VERSION]

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
Hestia CP Python Application Setup Script - Fixed Version

Usage: $0 DOMAIN [OPTIONS]

Options:
    -p, --port PORT          Set application port (default: 5000)
    -v, --python-version VERSION Set Python version (default: 3.9)
    -f, --force              Force recreation of application
    -h, --help               Show this help message

Examples:
    $0 example.com
    $0 example.com --port 8000
    $0 example.com --python-version 3.11 --port 3000
EOF
}

# Variables por defecto
DOMAIN=""
PORT="5000"
PYTHON_VERSION="3.9"
FORCE=false

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
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

# Validar que el dominio existe en Hestia
if ! v-list-web-domain $USER $DOMAIN >/dev/null 2>&1; then
    error "El dominio $DOMAIN no existe para el usuario $USER"
    exit 1
fi

# Obtener información del dominio
DOMAIN_INFO=$(v-list-web-domain $USER $DOMAIN json)
HOME_DIR=$(echo "$DOMAIN_INFO" | grep -o '"HOME":"[^"]*' | cut -d'"' -f4)
IP=$(echo "$DOMAIN_INFO" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)

if [[ -z "$HOME_DIR" ]] || [[ -z "$IP" ]]; then
    error "No se pudo obtener la información del dominio $DOMAIN"
    exit 1
fi

info "Configurando aplicación Python para: $DOMAIN"
info "Directorio home: $HOME_DIR"
info "IP: $IP"
info "Puerto: $PORT"
info "Versión Python: $PYTHON_VERSION"

# Verificar si ya existe una aplicación Python
if [[ -d "$HOME_DIR/web/$DOMAIN/private/python_app" ]] && [[ "$FORCE" != "true" ]]; then
    warning "Ya existe una aplicación Python para este dominio."
    read -p "¿Desea recrearla? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Operación cancelada."
        exit 0
    fi
    FORCE=true
fi

# Aplicar el template de Python
info "Aplicando template Python..."
v-change-web-domain-tpl "$USER" "$DOMAIN" "python-app" "yes"

# Configurar proxy template
info "Configurando proxy template..."
v-change-web-domain-proxy-tpl "$USER" "$DOMAIN" "python-app" "yes"

# Actualizar el puerto en la configuración del template
info "Actualizando configuración con puerto $PORT..."
# Crear configuración temporal con el puerto correcto
mkdir -p "$HOME_DIR/conf/web/$DOMAIN"

# Instalar systemd service
info "Configurando servicio systemd..."
if [[ -f "/tmp/${DOMAIN}_python.service" ]]; then
    cp "/tmp/${DOMAIN}_python.service" "/etc/systemd/system/"
    systemctl daemon-reload
    systemctl enable "${DOMAIN}_python.service"
    systemctl start "${DOMAIN}_python.service"
    
    # Verificar que el servicio está corriendo
    if systemctl is-active --quiet "${DOMAIN}_python.service"; then
        success "Servicio Python iniciado correctamente"
    else
        error "El servicio Python no se pudo iniciar"
        systemctl status "${DOMAIN}_python.service"
    fi
fi

# Reiniciar servicios
info "Reiniciando servicios web..."
v-restart-web

success "Aplicación Python configurada exitosamente!"
echo
info "Resumen de la configuración:"
echo "  - Dominio: https://$DOMAIN"
echo "  - Directorio de la app: $HOME_DIR/web/$DOMAIN/private/python_app"
echo "  - Entorno virtual: $HOME_DIR/web/$DOMAIN/.python-venv"
echo "  - Puerto de la app: $PORT"
echo "  - Servicio systemd: ${DOMAIN}_python.service"
echo "  - Template web: python-app"
echo "  - Template proxy: python-app"
echo
info "Comandos útiles:"
echo "  - Reiniciar app: systemctl restart ${DOMAIN}_python.service"
echo "  - Ver logs: journalctl -u ${DOMAIN}_python.service -f"
echo "  - Instalar dependencias: $HOME_DIR/web/$DOMAIN/.python-venv/bin/pip install [package]"
echo
info "¡Recuerda subir tu aplicación Python al directorio private/python_app/!"
SCRIPTEOF

    # Establecer permisos correctos en el script
    chmod 755 "$HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh"
    chown root:root "$HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh"
    
    # Crear enlace simbólico
    ln -sf "$HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh" "/usr/local/bin/$SCRIPT_NAME"
    
    success "Script de configuración creado en: $HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh"
    success "Enlace simbólico creado en: /usr/local/bin/$SCRIPT_NAME"
}

# Función para verificar la instalación
verify_installation() {
    info "Verificando la instalación..."
    
    local errors=0
    
    # Verificar template web
    if [[ -f "$HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl" ]]; then
        success "✓ Template web encontrado: $TEMPLATE_NAME.tpl"
    else
        error "✗ Template web no encontrado"
        ((errors++))
    fi
    
    # Verificar template proxy
    if [[ -f "$HESTIA_PROXY_TEMPLATES_DIR/$PROXY_TEMPLATE_NAME.tpl" ]]; then
        success "✓ Template proxy encontrado: $PROXY_TEMPLATE_NAME.tpl"
    else
        error "✗ Template proxy no encontrado"
        ((errors++))
    fi
    
    # Verificar script
    if [[ -f "$HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh" ]]; then
        success "✓ Script encontrado: $SCRIPT_NAME.sh"
    else
        error "✗ Script no encontrado"
        ((errors++))
    fi
    
    # Verificar enlace simbólico
    if [[ -L "/usr/local/bin/$SCRIPT_NAME" ]]; then
        success "✓ Enlace simbólico encontrado: /usr/local/bin/$SCRIPT_NAME"
    else
        error "✗ Enlace simbólico no encontrado"
        ((errors++))
    fi
    
    # Verificar permisos del template web
    if [[ -x "$HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl" ]]; then
        success "✓ Permisos correctos en el template web"
    else
        error "✗ Permisos incorrectos en el template web"
        ((errors++))
    fi
    
    # Verificar permisos del script
    if [[ -x "$HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh" ]]; then
        success "✓ Permisos correctos en el script"
    else
        error "✗ Permisos incorrectos en el script"
        ((errors++))
    fi
    
    return $errors
}

# Función para mostrar información post-instalación
show_post_install_info() {
    echo
    success "Instalación completada exitosamente!"
    echo
    info "Componentes instalados:"
    echo "  📁 Template web: $HESTIA_TEMPLATES_DIR/$TEMPLATE_NAME.tpl"
    echo "  📁 Template proxy: $HESTIA_PROXY_TEMPLATES_DIR/$PROXY_TEMPLATE_NAME.tpl"
    echo "  📁 Script: $HESTIA_SCRIPTS_DIR/$SCRIPT_NAME.sh"
    echo "  🔗 Comando: $SCRIPT_NAME"
    echo
    info "Uso:"
    echo "  $SCRIPT_NAME ejemplo.com"
    echo "  $SCRIPT_NAME ejemplo.com --port 8000"
    echo "  $SCRIPT_NAME ejemplo.com --python-version 3.11"
    echo
    info "Para usar el template en Hestia CP:"
    echo "  1. Ve al panel de control de Hestia"
    echo "  2. Edita el dominio"
    echo "  3. En 'Web Template' selecciona: python-app"
    echo "  4. En 'Proxy Template' selecciona: python-app"
    echo "  5. Guarda los cambios"
    echo
    info "Backup creado en: $BACKUP_DIR"
}

# Función principal
main() {
    echo
    echo "================================================================"
    echo "🧩 Hestia CP Python Template Installer - Fixed Version"
    echo "================================================================"
    echo
    
    # Verificaciones iniciales
    check_root
    check_hestia
    
    # Crear backup
    create_backup
    
    # Instalar componentes
    create_python_web_template
    create_python_proxy_template
    create_setup_script
    
    # Verificar instalación
    if verify_installation; then
        show_post_install_info
    else
        error "Hubo problemas con la instalación. Por favor, revisa los mensajes anteriores."
        exit 1
    fi
}

# Manejar señal de interrupción
trap 'error "Instalación interrumpida por el usuario"; exit 1' INT TERM

# Ejecutar función principal
main "$@"
