#!/bin/bash

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[36m"
RESET="\e[0m"
BOLD="\e[1m"

function banner() {
    echo -e "${BLUE}${BOLD}"
    echo "╔═══════════════════════════════════════════════╗"
    echo "║             Welcome to G7Reverse              ║"
    echo "╠═══════════════════════════════════════════════╣"
    echo -e "║  Secure Marzban Reverse Proxy Setup Script    ║"
    echo -e "║  Developer: ${YELLOW}@arshiapm47${BLUE}                            ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

function install_script() {
    echo -e "${GREEN}[+] Installing Nginx and configuring firewall...${RESET}"
    apt update && apt install nginx -y

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 2922/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8443/tcp
    ufw allow 4433/tcp
    ufw allow 9999/tcp
    ufw --force enable

    iptables -A INPUT -p tcp --dport 8000 ! -s 127.0.0.1 -j DROP

    cat > /etc/nginx/sites-available/marzban << EOF
server {
    listen 80;
    server_name panel.example.ir;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/marzban /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx

    # Enable BBR
    echo -e "${GREEN}[+] Enabling BBR...${RESET}"
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p

    echo -e "${GREEN}[✓] Installation complete. Marzban panel is hidden.${RESET}"
}

function uninstall_script() {
    echo -e "${RED}[!] Uninstalling configuration...${RESET}"
    rm -f /etc/nginx/sites-enabled/marzban
    rm -f /etc/nginx/sites-available/marzban
    iptables -D INPUT -p tcp --dport 8000 ! -s 127.0.0.1 -j DROP
    systemctl restart nginx
    echo -e "${GREEN}[✓] Uninstallation complete.${RESET}"
}

function update_script() {
    echo -e "${YELLOW}[~] Reapplying configuration...${RESET}"
    uninstall_script
    install_script
}

clear
banner
echo -e "${BOLD}${BLUE}Menu:${RESET}"
echo -e "${YELLOW}1)${RESET} Install G7Reverse"
echo -e "${YELLOW}2)${RESET} Uninstall G7Reverse"
echo -e "${YELLOW}3)${RESET} Update/Reinstall"
echo -e "${YELLOW}0)${RESET} Exit"
echo -e "${BLUE}---------------------------------------------${RESET}"
echo -e "${BOLD}Developer Contact:${RESET} ${YELLOW}@arshiapm47${RESET}"
echo -e "${BLUE}---------------------------------------------${RESET}"
read -p "Select an option [0-3]: " option

case $option in
    1) install_script ;;
    2) uninstall_script ;;
    3) update_script ;;
    0) echo -e "${RED}Bye!${RESET}" ;;
    *) echo -e "${RED}Invalid option!${RESET}" ;;
esac
