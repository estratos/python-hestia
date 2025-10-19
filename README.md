# python-hestia
# Hestia CP Python Application Template
A complete solution to run Python web applications on Hestia Control Panel. This package provides a custom template and CLI tool to easily deploy Python/Flask applications with proper virtual environments, systemd services, and Nginx configuration.

🚀 Features
Easy Deployment: One-command setup for Python applications

Virtual Environments: Automatic Python virtual environment creation

Production Ready: Gunicorn WSGI server with proper configuration

Systemd Integration: Automatic service creation and management

Nginx Proxy: Proper reverse proxy configuration

Multiple Python Versions: Support for different Python versions (3.8, 3.9, 3.10, 3.11)

Security: Secure configuration with proper permissions and isolation

Logging: Comprehensive logging and log rotation

Backup System: Automatic backups before making changes

📋 Requirements
Hestia Control Panel installed

Root access or sudo privileges

Python 3.8+ installed on the system

# 🛠 Installation
# Method 1: Automated Installation
Download the installer script:

```console
wget https://raw.githubusercontent.com/estratos/python-hestia/main/install-python-template.sh
```
Make it executable:

```bash
chmod +x install-python-template.sh
```
Run the installer as root:


```bash
sudo ./install-python-template.sh
```

# Method 2: Manual Installation
If you prefer manual installation, you can copy the files directly:

bash
### Copy template to Hestia templates directory
```
sudo cp python-app.tpl /usr/local/hestia/data/templates/web/nginx/
```

### Copy setup script
```
sudo cp hestia-python-setup.sh /usr/local/hestia/scripts/
```
```
sudo chmod +x /usr/local/hestia/scripts/hestia-python-setup.sh
```

### Create symbolic link
```
sudo ln -s /usr/local/hestia/scripts/hestia-python-setup.sh /usr/local/bin/hestia-python-setup
```
📖 Usage
Basic Usage
First, create a domain in Hestia CP (if you haven't already):

```bash
v-add-web-domain admin example.com
```
Set up Python application for the domain:

```bash
hestia-python-setup example.com
```
Advanced Options
bash
### Custom port
```
hestia-python-setup example.com --port 8000
```

### Specific Python version
```
hestia-python-setup example.com --python-version 3.11
```

### Force recreation (if app already exists)
```
hestia-python-setup example.com --force
```

### Combine options
```
hestia-python-setup example.com --port 3000 --python-version 3.10
```
Command Reference
bash
Usage: hestia-python-setup DOMAIN [OPTIONS]

Options:
    -p, --port PORT          Set application port (default: 5000)
    -v, --python-version VERSION Set Python version (default: 3.9)
    -f, --force              Force recreation of application
    -h, --help               Show this help message

Examples:
    hestia-python-setup example.com
    hestia-python-setup example.com --port 8000
    hestia-python-setup example.com --python-version 3.11 --port 3000
🎯 What Gets Installed
When you run the setup script, it creates:

Directory Structure
text
/home/admin/web/example.com/
├── private/python_app/
│   ├── app.py              # Main Flask application
│   ├── wsgi.py             # WSGI entry point
│   ├── requirements.txt    # Python dependencies
│   ├── start_app.sh        # Startup script
│   ├── static/            # Static files directory
│   └── templates/         # HTML templates directory
├── .python-venv/          # Python virtual environment
└── logs/python/           # Application logs
System Components
Systemd Service: example.com_python.service

Nginx Configuration: Proper proxy setup

Log Rotation: Automatic log management

Virtual Environment: Isolated Python environment

🔧 Managing Your Application
Application Commands
bash
### Restart application
```
sudo systemctl restart example.com_python.service
```

### Check status
```
sudo systemctl status example.com_python.service
```

### View logs
```
sudo journalctl -u example.com_python.service -f
```

### Stop application
```
sudo systemctl stop example.com_python.service
```

### Enable auto-start on boot
```
sudo systemctl enable example.com_python.service
```
Python Environment Management
bash
### Activate virtual environment
```
source /home/admin/web/example.com/.python-venv/bin/activate
```

### Install packages
```
/home/admin/web/example.com/.python-venv/bin/pip install package-name
```

### Install from requirements.txt
```
/home/admin/web/example.com/.python-venv/bin/pip install -r /home/admin/web/example.com/private/python_app/requirements.txt
```
## Update pip
```
/home/admin/web/example.com/.python-venv/bin/pip install --upgrade pip
```
File Locations
Component	Location
Application Code	/home/admin/web/example.com/private/python_app/
Virtual Environment	/home/admin/web/example.com/.python-venv/
Log Files	/home/admin/web/example.com/logs/python/
Systemd Service	/etc/systemd/system/example.com_python.service
Nginx Config	/home/admin/conf/web/example.com/nginx.conf
🐍 Deploying Your Python Application
1. Upload Your Application
Replace the default application with your own:

bash
### Upload your files to:
```
/home/admin/web/example.com/private/python_app/
```

### Your main application should be named:

app.py  # or modify wsgi.py to import your app
2. Update Dependencies
Edit the requirements.txt file:

bash
```
nano /home/admin/web/example.com/private/python_app/requirements.txt
```
Example:

txt
Flask==2.3.3
gunicorn==21.2.0
requests==2.31.0
python-dotenv==1.0.0
3. Install Dependencies
bash
### Manual installation
```
/home/admin/web/example.com/.python-venv/bin/pip install -r /home/admin/web/example.com/private/python_app/requirements.txt
```

### Or let the system handle it on restart
```
sudo systemctl restart example.com_python.service
```
4. Restart Application
bash
```
sudo systemctl restart example.com_python.service
```
🔄 Example Application Structure
Here's a complete example of a Flask application:

app.py
python
from flask import Flask, render_template, request, jsonify
import os
import datetime

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html', 
                         domain=request.host,
                         time=datetime.datetime.now())

@app.route('/api/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now().isoformat(),
        'version': '1.0.0'
    })

@app.route('/api/info')
def api_info():
    return jsonify({
        'app_name': 'My Python App',
        'python_version': os.sys.version,
        'environment': os.environ.get('FLASK_ENV', 'production')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
requirements.txt
txt
Flask==2.3.3
gunicorn==21.2.0
wsgi.py
python
import sys
import os

# Add the app directory to Python path
app_dir = os.path.join(os.path.dirname(__file__))
if app_dir not in sys.path:
    sys.path.insert(0, app_dir)

from app import app as application

if __name__ == "__main__":
    application.run()
🐛 Troubleshooting
Common Issues
<details> <summary><b>Application not starting</b></summary>
bash
# Check service status
sudo systemctl status example.com_python.service

# Check logs
sudo journalctl -u example.com_python.service -f
</details><details> <summary><b>Port already in use</b></summary>
bash
# Change to a different port
hestia-python-setup example.com --port 5001
</details><details> <summary><b>Python version not available</b></summary>
bash
# Check available Python versions
ls /usr/bin/python*

# Use available version
hestia-python-setup example.com --python-version 3.8
</details><details> <summary><b>Permission errors</b></summary>
bash
# Fix permissions
sudo chown -R admin:admin /home/admin/web/example.com/private/python_app
sudo chmod 755 /home/admin/web/example.com/private/python_app
</details>
Log Files
Check these locations for debugging:

bash
# Application logs
tail -f /home/admin/web/example.com/logs/python/error.log

# Systemd logs
journalctl -u example.com_python.service -f

# Nginx logs
tail -f /var/log/nginx/example.com.error.log
🔄 Updating
To update the template and script:

Re-run the installer:

bash
sudo ./install-python-template.sh
The installer will automatically:

Create backups of existing files

Install updated versions

Preserve your existing applications

🗑 Uninstallation
To remove the Python template:

bash
# Remove template
sudo rm /usr/local/hestia/data/templates/web/nginx/python-app.tpl

# Remove script
sudo rm /usr/local/hestia/scripts/hestia-python-setup.sh

# Remove symbolic link
sudo rm /usr/local/bin/hestia-python-setup
Note: This only removes the template and script, not your existing Python applications.

🤝 Contributing
We welcome contributions! Please feel free to submit pull requests or open issues for bugs and feature requests.

Development Setup
Fork the repository

Create a feature branch

Make your changes

Test thoroughly

Submit a pull request

📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

🆘 Support
If you encounter any issues:

Check the troubleshooting section

Search existing issues

Create a new issue with detailed information

🙏 Acknowledgments
Hestia CP team for the excellent control panel

Flask and Gunicorn communities

Contributors and testers

Important: Always test in a development environment before deploying to production.
