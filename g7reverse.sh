#!/bin/bash

# رنگ‌ها
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
RESET='\e[0m'

function pause() {
  echo -e "\n${CYAN}Press Enter to return to the menu...${RESET}"
  read
}

function banner() {
    clear
    echo -e "${CYAN}=============================================="
    echo -e "      ${GREEN}G7Reverse - Nginx Reverse Proxy Manager"
    echo -e "${CYAN}=============================================="
    echo -e "║  Developer: ${YELLOW}@arshiapm47${CYAN}                      ║"
    echo -e "==============================================${RESET}\n"
}

function install_script() {
    banner
    echo -e "${GREEN}[+] Installing Nginx reverse proxy and configuring firewall...${RESET}"

    read -p "Enter local IP (default 127.0.0.1): " LOCAL_IP
    LOCAL_IP=${LOCAL_IP:-127.0.0.1}

    read -p "Enter local port (default 8000): " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-8000}

    apt update && apt install nginx ufw -y

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 2922,80,443,8443,4433,9999/tcp
    ufw --force enable

    iptables -D INPUT -p tcp --dport "$LOCAL_PORT" ! -s "$LOCAL_IP" -j DROP 2>/dev/null
    iptables -A INPUT -p tcp --dport "$LOCAL_PORT" ! -s "$LOCAL_IP" -j DROP

    read -p "Enter your domain (or press Enter to use panel.example.ir): " DOMAIN
    DOMAIN=${DOMAIN:-panel.example.ir}

    cat > /etc/nginx/sites-available/g7reverse << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://$LOCAL_IP:$LOCAL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/g7reverse /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx

    echo -e "${GREEN}[✓] Installation complete. Panel is accessible behind domain: $DOMAIN${RESET}"
    pause
}

function uninstall_script() {
    banner
    echo -e "${RED}[!] Removing reverse proxy configuration...${RESET}"
    rm -f /etc/nginx/sites-{enabled,available}/g7reverse
    iptables -D INPUT -p tcp --dport 8000 ! -s 127.0.0.1 -j DROP 2>/dev/null
    systemctl restart nginx
    echo -e "${GREEN}[✓] Uninstallation complete.${RESET}"
    pause
}

function update_script() {
    banner
    echo -e "${YELLOW}[~] Updating script (re-applying configs)...${RESET}"
    uninstall_script
    install_script
}

function install_bbrv3() {
    banner
    echo -e "${GREEN}[+] Installing BBRv3 Kernel (v6.1.x)...${RESET}"
    bash <(curl -sL https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    pause
}

function remove_bbr() {
    banner
    echo -e "${RED}[-] Removing BBR configuration...${RESET}"
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}[✓] BBR configuration removed.${RESET}"
    pause
}

function check_bbr_status() {
    banner
    echo -e "${CYAN}[?] Checking BBR status...${RESET}"
    sysctl net.ipv4.tcp_congestion_control
    sysctl net.core.default_qdisc
    lsmod | grep bbr
    pause
}

function install_fail2ban() {
    banner
    echo -e "${GREEN}[+] Installing Fail2Ban...${RESET}"
    apt install fail2ban -y
    systemctl enable fail2ban --now
    echo -e "${GREEN}[✓] Fail2Ban installed and active.${RESET}"
    pause
}

function remove_fail2ban() {
    banner
    echo -e "${RED}[-] Removing Fail2Ban...${RESET}"
    systemctl stop fail2ban 2>/dev/null
    systemctl disable fail2ban 2>/dev/null
    apt purge --auto-remove fail2ban -y
    rm -rf /etc/fail2ban
    echo -e "${GREEN}[✓] Fail2Ban completely removed.${RESET}"
    pause
}

# منو اصلی
while true; do
    banner
    echo -e "${YELLOW}1.${RESET} Install Reverse Proxy"
    echo -e "${YELLOW}2.${RESET} Uninstall Reverse Proxy"
    echo -e "${YELLOW}3.${RESET} Update Configuration"
    echo -e "${YELLOW}4.${RESET} Install BBRv3"
    echo -e "${YELLOW}5.${RESET} Remove BBR"
    echo -e "${YELLOW}6.${RESET} Check BBR Status"
    echo -e "${YELLOW}7.${RESET} Install Fail2Ban"
    echo -e "${YELLOW}8.${RESET} Remove Fail2Ban"
    echo -e "${YELLOW}0.${RESET} Exit"
    echo -e "=============================================="
    read -p "Select an option [0-8]: " option

    case $option in
        1) install_script ;;
        2) uninstall_script ;;
        3) update_script ;;
        4) install_bbrv3 ;;
        5) remove_bbr ;;
        6) check_bbr_status ;;
        7) install_fail2ban ;;
        8) remove_fail2ban ;;
        0) echo -e "${CYAN}Goodbye!${RESET}"; exit 0 ;;
        *) echo -e "${RED}Invalid option!${RESET}"; sleep 1 ;;
    esac
done
