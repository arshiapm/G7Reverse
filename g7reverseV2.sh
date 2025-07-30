#!/bin/bash

function install_script() {
    echo -e "\e[32m[+] Installing Nginx reverse proxy and configuring firewall...\e[0m"

    DEFAULT_PORT=8000
    echo -e "\nDefault local IP port is \e[33m$DEFAULT_PORT\e[0m."
    read -p "Do you want to keep this port? (y/n): " choice

    if [[ "$choice" =~ ^[Yy]$ ]]; then
        PORT=$DEFAULT_PORT
    else
        read -p "Enter your custom port number: " PORT
    fi

    echo -e "\e[36mUsing port: $PORT\e[0m"

    apt update && apt install nginx -y

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 2922/tcp
    ufw allow 80/tcp
    ufw allow 2922/tcp
    ufw allow 443/tcp
    ufw allow 8443/tcp
    ufw allow 4433/tcp
    ufw allow 9999/tcp
    ufw --force enable

    iptables -A INPUT -p tcp --dport $PORT ! -s 127.0.0.1 -j DROP

    cat > /etc/nginx/sites-available/g7reverse << EOF
server {
    listen 80;
    server_name panel.example.ir;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/g7reverse /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx

    echo -e "\e[32m[✓] Installation complete. G7Reverse panel is ready behind fake domain.\e[0m"
}

function uninstall_script() {
    echo -e "\e[31m[!] Uninstalling configuration...\e[0m"
    rm -f /etc/nginx/sites-enabled/g7reverse
    rm -f /etc/nginx/sites-available/g7reverse
    iptables -D INPUT -p tcp --dport $PORT ! -s 127.0.0.1 -j DROP
    systemctl restart nginx
    echo -e "\e[32m[✓] Uninstallation complete.\e[0m"
}

function update_script() {
    echo -e "\e[34m[~] Updating script (re-applying configs)...\e[0m"
    uninstall_script
    install_script
}

echo -e "\e[35mG7Reverse Manager\e[0m"
echo -e "============================="
echo -e "1. Install Script"
echo -e "2. Uninstall Script"
echo -e "3. Update Script"
echo -e "0. Exit"
echo -e "============================="
echo -e "\e[33mDeveloper: @arshiapm47\e[0m"
read -p "Select an option [0-3]: " option

case $option in
    1) install_script ;;
    2) uninstall_script ;;
    3) update_script ;;
    0) echo "Bye!" ;;
    *) echo "Invalid option!" ;;
esac
