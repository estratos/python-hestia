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
wget https://raw.githubusercontent.com/estratos/python-hestia/refs/heads/main/install-python-templates.sh
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

# Python Application Service Creator for HestiaCP

A standalone script to create systemd services for Python applications running with HestiaCP's python-app Nginx template.

## Overview

This script creates a systemd service that manages your Python application as a background service. It automatically configures the service to work with the python-app Nginx template, handling port configuration, virtual environments, logging, and security hardening.

## Features

- Domain Integration: Automatically detects and lists HestiaCP domains
- Custom Path Support: Works with any absolute path, not just Hestia domains
- Automatic Detection: Identifies common Python application files (app.py, run.py, main.py, etc.)
- Virtual Environment Support: Detects and configures existing virtual environments or creates new ones
- Port Configuration: Interactive port selection with validation
- User Management: Choose which system user runs the service
- Logging Setup: Automatic log directory creation with proper permissions
- Security Hardening: Implements systemd security features (PrivateTmp, ProtectSystem, etc.)
- Service Management: Provides commands for starting, stopping, and monitoring the service

## Requirements

- HestiaCP installed (optional, for domain integration)
- Python 3.6+ installed
- Root or sudo access
- systemd (standard on Ubuntu 22.04/24.04 and Debian 11/12)

## Installation

Download and make the script executable:

```bash
wget https://raw.githubusercontent.com/estratos/python-hestia/refs/heads/main/create-python-service.sh
chmod +x create-python-service.sh
```

## Usage

Run the script as root:

```bash
sudo ./create-python-service.sh
```

## Interactive Prompts

The script guides you through the configuration process:

### Select Domain or Custom Path

- Choose from a list of HestiaCP domains
- Or enter `c` to specify a custom path

### Startup Script Detection

- Automatically detects files like:
  - `app.py`
  - `run.py`
  - `main.py`
- Or manually define your command

### Port Configuration

- Define the port your app will run on
- Must match Nginx template configuration

### Virtual Environment

- Detects existing environments (`venv`, `.venv`, `env`)
- Option to create a new one

### Working Directory

- Defaults to app path
- Can be customized

### Service User

- Choose user (`admin`, `www-data`, `root`, custom)
- Script validates existence

### Logging

- Default: `application_path/logs`
- Creates access and error logs

### Confirmation

- Review settings before creation
- Option to start service immediately
- Option to enable auto-start

## Service Management

### Start

```bash
sudo systemctl start domain_python
```

### Stop

```bash
sudo systemctl stop domain_python
```

### Restart

```bash
sudo systemctl restart domain_python
```

### Status

```bash
sudo systemctl status domain_python
```

### Logs

```bash
sudo journalctl -u domain_python -f
```

### Enable Auto-Start

```bash
sudo systemctl enable domain_python
```

### Disable Auto-Start

```bash
sudo systemctl disable domain_python
```

## Service File Structure

The generated service includes:

- WorkingDirectory
- User / Group
- Environment variables
- ExecStart command
- Restart policy
- Security hardening:
  - NoNewPrivileges
  - PrivateTmp
  - ProtectSystem
  - ProtectHome
- ReadWritePaths restrictions

## Example Service Configuration

```ini
[Unit]
Description=Python Application for example.com
After=network.target

[Service]
Type=simple
User=admin
Group=admin
WorkingDirectory=/home/admin/web/example.com/private/python_app
Environment="PATH=/home/admin/web/example.com/.python-venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="PYTHONUNBUFFERED=1"

ExecStart=/home/admin/web/example.com/.python-venv/bin/gunicorn --bind 127.0.0.1:8000 wsgi:application

Restart=always
RestartSec=5

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/home/admin/web/example.com/private/python_app /home/admin/web/example.com/logs/python

[Install]
WantedBy=multi-user.target
```

## Integration with HestiaCP

- Ensure service is running
- Select `python-app` template in HestiaCP
- Nginx will proxy to your app

## Troubleshooting

### Service Not Starting

```bash
sudo systemctl status domain_python
sudo journalctl -u domain_python -n 50
```

### Port Already in Use

- Change port in:
  - Service config
  - Nginx template

### Permission Issues

```bash
sudo chown -R user:group /path/to/app
sudo chmod -R 755 /path/to/app
```

### Virtual Environment Issues

```bash
source /path/to/venv/bin/activate
python app.py
```

## Uninstallation

```bash
sudo systemctl stop domain_python
sudo systemctl disable domain_python
sudo rm /etc/systemd/system/domain_python.service
sudo systemctl daemon-reload
```

## Script Options

- Fully interactive
- No CLI arguments required

## Important Notes

- Ensure service user has proper permissions
- Default port is 8000
- Use Gunicorn or uWSGI in production
- Adjust `ReadWritePaths` if needed
