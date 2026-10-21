#=========================================================================#
# Python Application Proxy Template for HestiaCP - HTTP                   #
#   /usr/local/hestia/data/templates/web/nginx/python-app.tpl             #
#=========================================================================#

server {
    listen %ip%:%proxy_port%;
    server_name %domain_idn% %alias_idn%;
    error_log /var/log/%web_system%/domains/%domain%.error.log error;

    # Hestia: redireccion HTTPS gestionada por el panel. Se elimina y se
    # restaura automaticamente durante la validacion ACME; no hardcodear 301.
    include %home%/%user%/conf/web/%domain%/nginx.forcessl.conf*;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /error/ {
        alias %home%/%user%/web/%domain%/document_errors/;
    }

    location ~ /\.ht {
        return 404;
    }
    location ~ /\.svn/ {
        return 404;
    }
    location ~ /\.git/ {
        return 404;
    }
    location ~ /\.hg/ {
        return 404;
    }
    location ~ /\.bzr/ {
        return 404;
    }

    # Hestia: snippets del dominio. Aqui vive nginx.conf_letsencrypt, que es
    # donde Hestia escribe el reto ACME durante la emision/renovacion.
    include %home%/%user%/conf/web/%domain%/nginx.conf_*;
}
