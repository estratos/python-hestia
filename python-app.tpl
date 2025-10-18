#!/bin/bash

# Hestia CP Python Application Template
# Template: python-app

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
mkdir -p $home_dir/web/$domain/logs/python
mkdir -p $home_dir/web/$domain/.python-venv

# Crear virtual environment
python3 -m venv $home_dir/web/$domain/.python-venv

# Crear archivo de configuración básico para la app Python
cat > $home_dir/web/$domain/private/python_app/app.py << EOF
from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>Python App - $domain</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 800px; margin: 0 auto; }
            .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
            .info { background: #e7f3ff; padding: 15px; border-left: 4px solid #2196F3; margin: 20px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🚀 Python Application Ready!</h1>
                <p>Your Python application is successfully deployed on <strong>$domain</strong></p>
            </div>
            
            <div class="info">
                <h3>Application Information:</h3>
                <ul>
                    <li><strong>Domain:</strong> $domain</li>
                    <li><strong>User:</strong> $user</li>
                    <li><strong>App Directory:</strong> $home_dir/web/$domain/private/python_app</li>
                    <li><strong>Virtual Environment:</strong> $home_dir/web/$domain/.python-venv</li>
                </ul>
            </div>
            
            <h3>Next Steps:</h3>
            <ol>
                <li>Upload your Python application files to <code>private/python_app/</code></li>
                <li>Install dependencies in the virtual environment</li>
                <li>Configure your WSGI application in <code>private/python_app/app.py</code></li>
                <li>Restart the web service when you make changes</li>
            </ol>
            
            <p><em>This is a default template. Replace this content with your actual Python application.</em></p>
        </div>
    </body>
    </html>
    '''

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=$WEB_PORT)
EOF

# Crear requirements.txt
cat > $home_dir/web/$domain/private/python_app/requirements.txt << EOF
Flask==2.3.3
gunicorn==21.2.0
EOF

# Crear archivo WSGI para Gunicorn
cat > $home_dir/web/$domain/private/python_app/wsgi.py << EOF
import sys
import os

# Add the app directory to Python path
app_dir = os.path.join(os.path.dirname(__file__))
if app_dir not in sys.path:
    sys.path.insert(0, app_dir)

from app import app as application

if __name__ == "__main__":
    application.run()
EOF

# Crear script de inicio para la aplicación
cat > $home_dir/web/$domain/private/python_app/start_app.sh << EOF
#!/bin/bash
cd $home_dir/web/$domain/private/python_app
source $home_dir/web/$domain/.python-venv/bin/activate
pip install -r requirements.txt
gunicorn --bind 127.0.0.1:$WEB_PORT --workers 3 wsgi:application
EOF

chmod +x $home_dir/web/$domain/private/python_app/start_app.sh

# Crear systemd service file
cat > /tmp/${domain}_python.service << EOF
[Unit]
Description=Python App for $domain
After=network.target

[Service]
Type=simple
User=$user
Group=$user
WorkingDirectory=$home_dir/web/$domain/private/python_app
Environment=PATH=$home_dir/web/$domain/.python-venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$home_dir/web/$domain/.python-venv/bin/gunicorn --bind 127.0.0.1:$WEB_PORT --workers 3 wsgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Instalar dependencias en el virtual environment
$home_dir/web/$domain/.python-venv/bin/pip install -r $home_dir/web/$domain/private/python_app/requirements.txt

# Configurar permisos
chown -R $user:$user $home_dir/web/$domain/private/python_app
chown -R $user:$user $home_dir/web/$domain/.python-venv
chmod 755 $home_dir/web/$domain/private/python_app

# Crear archivo de configuración nginx para Python
cat > $home_dir/conf/web/$domain/nginx.conf << EOF
# Python Application Configuration for $domain
location / {
    proxy_pass http://127.0.0.1:$WEB_PORT;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
}

location /static/ {
    alias $home_dir/web/$domain/private/python_app/static/;
    expires 30d;
}
EOF

echo "Python application template successfully configured for $domain"
echo "App directory: $home_dir/web/$domain/private/python_app"
echo "Virtual environment: $home_dir/web/$domain/.python-venv"
echo "Application will run on port: $WEB_PORT"
