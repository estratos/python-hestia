# Python Hestia
# Hestia CP Python Application Template

A complete solution to run Python web applications on Hestia Control Panel. This package provides a custom template and CLI tool to easily deploy Python/Flask applications with proper virtual environments, systemd services, and Nginx configuration.

## Features

- Easy Deployment: One-command setup for Python applications
- Virtual Environments: Automatic Python virtual environment creation
- Production Ready: Gunicorn WSGI server with proper configuration
- Systemd Integration: Automatic service creation and management
- Nginx Proxy: Proper reverse proxy configuration
- Multiple Python Versions: Support for Python 3.8–3.12
- Security: Secure configuration with proper permissions and isolation
- Logging: Comprehensive logging and log rotation
- Backup System: Automatic backups before making changes

## Requirements

- Hestia Control Panel installed
- Root access or sudo privileges
- Python 3.8+ installed on the system

### Supported Operating Systems

| Operating System | Versions        | Status           |
|-----------------|----------------|------------------|
| Ubuntu          | 22.04 (Jammy)  | Fully Supported  |
| Ubuntu          | 24.04 (Noble)  | Fully Supported  |
| Debian          | 11 (Bullseye)  | Fully Supported  |
| Debian          | 12 (Bookworm)  | Fully Supported  |

## Installation

### Method 1: Automated Installation

```bash
wget https://github.com/estratos/python-hestia/blob/main/install-python-templates.sh
chmod +x install-python-templates.sh
sudo ./install-python-templates.sh
```

The installer will automatically:

- Detect your operating system
- Validate OS compatibility
- Check for existing HestiaCP installation
- Create backups of existing templates
- Install the Python application templates
- Provide post-installation instructions

### Method 2: Manual Installation

```bash
# Create the target directory if it doesn't exist
sudo mkdir -p /usr/local/hestia/data/templates/web/nginx

# Copy templates
sudo cp python-app.tpl /usr/local/hestia/data/templates/web/nginx/
sudo cp python-app.stpl /usr/local/hestia/data/templates/web/nginx/

# Set permissions
sudo chmod 644 /usr/local/hestia/data/templates/web/nginx/python-app.*
sudo chown root:root /usr/local/hestia/data/templates/web/nginx/python-app.*

# Copy setup script
sudo cp hestia-python-setup.sh /usr/local/hestia/scripts/
sudo chmod +x /usr/local/hestia/scripts/hestia-python-setup.sh

# Create symbolic link
sudo ln -s /usr/local/hestia/scripts/hestia-python-setup.sh /usr/local/bin/hestia-python-setup
```

## Usage

### Basic Usage

```bash
v-add-web-domain admin example.com
hestia-python-setup example.com
```

### Advanced Options

```bash
# Custom port
hestia-python-setup example.com --port 8000

# Python version
hestia-python-setup example.com --python-version 3.11

# Force recreation
hestia-python-setup example.com --force

# Combined options
hestia-python-setup example.com --port 3000 --python-version 3.10
```

### Command Reference

```bash
Usage: hestia-python-setup DOMAIN [OPTIONS]

Options:
  -p, --port PORT
  -v, --python-version VERSION
  -f, --force
  -h, --help
```

## What Gets Installed

### Directory Structure

```text
/home/admin/web/example.com/
├── private/python_app/
│   ├── app.py
│   ├── wsgi.py
│   ├── requirements.txt
│   ├── start_app.sh
│   ├── static/
│   └── templates/
├── .python-venv/
└── logs/python/
```

### System Components

- Systemd service
- Nginx proxy configuration
- Log rotation
- Python virtual environment

## Managing Your Application

### Application Commands

```bash
sudo systemctl restart example.com_python.service
sudo systemctl status example.com_python.service
sudo journalctl -u example.com_python.service -f
sudo systemctl stop example.com_python.service
sudo systemctl enable example.com_python.service
```

### Python Environment Management

```bash
source /home/admin/web/example.com/.python-venv/bin/activate
pip install package-name
pip install -r requirements.txt
pip install --upgrade pip
```

### File Locations

| Component        | Location |
|-----------------|----------|
| Application Code| /home/admin/web/example.com/private/python_app/ |
| Virtual Env     | /home/admin/web/example.com/.python-venv/ |
| Logs            | /home/admin/web/example.com/logs/python/ |
| Systemd Service | /etc/systemd/system/example.com_python.service |
| Nginx Config    | /home/admin/conf/web/example.com/nginx.conf |

## Deploying Your Application

### Upload Your Application

```bash
/home/admin/web/example.com/private/python_app/
```

### Update Dependencies

```txt
Flask==2.3.3
gunicorn==21.2.0
requests==2.31.0
python-dotenv==1.0.0
```

### Install Dependencies

```bash
pip install -r requirements.txt
sudo systemctl restart example.com_python.service
```

## Example Application

### app.py

```python
from flask import Flask, render_template, request, jsonify
import os, datetime

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html',
        domain=request.host,
        time=datetime.datetime.now())

@app.route('/api/health')
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

### wsgi.py

```python
import sys, os

app_dir = os.path.dirname(__file__)
if app_dir not in sys.path:
    sys.path.insert(0, app_dir)

from app import app as application
```

## Troubleshooting

### App Not Starting

```bash
sudo systemctl status example.com_python.service
sudo journalctl -u example.com_python.service -f
```

### Port Conflict

```bash
hestia-python-setup example.com --port 5001
```

### Permission Errors

```bash
sudo chown -R admin:admin /home/admin/web/example.com/private/python_app
sudo chmod 755 /home/admin/web/example.com/private/python_app
```

### Logs

```bash
tail -f /home/admin/web/example.com/logs/python/error.log
journalctl -u example.com_python.service -f
tail -f /var/log/nginx/example.com.error.log
```

## Updating

```bash
wget https://raw.githubusercontent.com/estratos/python-hestia/main/install-python-template.sh
chmod +x install-python-template.sh
sudo ./install-python-template.sh
```

## Uninstallation

```bash
sudo rm /usr/local/hestia/data/templates/web/nginx/python-app.*
sudo rm /usr/local/hestia/scripts/hestia-python-setup.sh
sudo rm /usr/local/bin/hestia-python-setup
```

## Contributing

- Fork the repository
- Create a feature branch
- Test on supported OS versions
- Submit a pull request

## License

MIT License

## Support

Include:

- OS version
- HestiaCP version
- Python version
- Logs

## Acknowledgments

- Hestia CP team
- Flask & Gunicorn communities
- Contributors

**Important:** Always test in a development environment before deploying to production.
