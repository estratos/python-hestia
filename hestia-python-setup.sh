#!/bin/bash

# Hestia CP Python Application Setup Script
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
Hestia CP Python Application Setup Script

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

# Crear template temporal
TEMPLATE_FILE="/tmp/python-app-${DOMAIN}.tpl"
cat > $TEMPLATE_FILE << EOF
#!/bin/bash

# Template temporal para $DOMAIN
WEB_TEMPLATE='python-app'
WEB_BACKEND='python'
WEB_PYTHON_VERSION='$PYTHON_VERSION'
WEB_PORT='$PORT'

user='$USER'
domain='$DOMAIN'
ip='$IP'
home_dir='$HOME_DIR'
public_html='$HOME_DIR/web/$DOMAIN/public_html'
EOF

# Agregar el contenido del template principal
cat python-app.tpl >> $TEMPLATE_FILE

# Aplicar el template
info "Aplicando template Python..."
chmod +x $TEMPLATE_FILE

# Backup de configuración actual si existe
if [[ -f "$HOME_DIR/conf/web/$DOMAIN/nginx.conf" ]]; then
    cp "$HOME_DIR/conf/web/$DOMAIN/nginx.conf" "$HOME_DIR/conf/web/$DOMAIN/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Ejecutar template
if $TEMPLATE_FILE; then
    success "Template aplicado correctamente"
else
    error "Error al aplicar el template"
    exit 1
fi

# Configurar proxy en Hestia
info "Configurando proxy en Hestia..."
v-change-web-domain-proxy-tpl $USER $DOMAIN 'default' 'no' >/dev/null 2>&1
sleep 2

# Crear configuración de proxy manual
cat > "$HOME_DIR/conf/web/$DOMAIN/nginx.conf" << EOF
# Python Application Configuration for $DOMAIN
location / {
    proxy_pass http://127.0.0.1:$PORT;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}

location /static/ {
    alias $HOME_DIR/web/$DOMAIN/private/python_app/static/;
    expires 30d;
    access_log off;
}

location /media/ {
    alias $HOME_DIR/web/$DOMAIN/private/python_app/media/;
    expires 30d;
    access_log off;
}
EOF

# Reiniciar servicios
info "Reiniciando servicios web..."
v-restart-web

# Instalar systemd service
info "Configurando servicio systemd..."
cp /tmp/${DOMAIN}_python.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable ${DOMAIN}_python.service
systemctl start ${DOMAIN}_python.service

# Verificar que el servicio está corriendo
if systemctl is-active --quiet ${DOMAIN}_python.service; then
    success "Servicio Python iniciado correctamente"
else
    error "El servicio Python no se pudo iniciar"
    systemctl status ${DOMAIN}_python.service
fi

# Mostrar información final
success "Aplicación Python configurada exitosamente!"
echo
info "Resumen de la configuración:"
echo "  - Dominio: https://$DOMAIN"
echo "  - Directorio de la app: $HOME_DIR/web/$DOMAIN/private/python_app"
echo "  - Entorno virtual: $HOME_DIR/web/$DOMAIN/.python-venv"
echo "  - Puerto de la app: $PORT"
echo "  - Servicio systemd: ${DOMAIN}_python.service"
echo
info "Comandos útiles:"
echo "  - Reiniciar app: systemctl restart ${DOMAIN}_python.service"
echo "  - Ver logs: journalctl -u ${DOMAIN}_python.service -f"
echo "  - Instalar dependencias: $HOME_DIR/web/$DOMAIN/.python-venv/bin/pip install [package]"
echo
info "¡Recuerda subir tu aplicación Python al directorio private/python_app/!"

# Limpiar archivo temporal
rm -f $TEMPLATE_FILE
