#!/bin/bash

# رنگ‌ها
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
RESET='\e[0m'

function pause() {
    echo -e "\n${CYAN}Press Enter to return to menu...${RESET}"
    read -r
}

function banner() {
    clear
    echo -e "${CYAN}=============================================="
    echo -e "      ${GREEN}G7Reverse - Nginx Reverse Proxy Manager"
    echo -e "==============================================${RESET}"
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
    ufw allow 2922/tcp
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8443/tcp
    ufw allow 6026/tcp
    ufw allow 4433/tcp
    ufw allow 9999/tcp
    ufw --force enable

    iptables -D INPUT -p tcp --dport "$LOCAL_PORT" ! -s "$LOCAL_IP" -j DROP 2>/dev/null
    iptables -A INPUT -p tcp --dport "$LOCAL_PORT" ! -s "$LOCAL_IP" -j DROP

    read -p "Enter your domain name for reverse proxy (leave blank to skip): " DOMAIN_NAME
    if [[ -z "$DOMAIN_NAME" ]]; then
        DOMAIN_NAME="panel.example.ir"
    fi

    cat > /etc/nginx/sites-available/g7reverse << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://$LOCAL_IP:$LOCAL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/g7reverse /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx

    echo -e "${GREEN}[✓] Installation complete. G7Reverse panel running behind $DOMAIN_NAME.${RESET}"
    pause
}

function uninstall_script() {
    banner
    echo -e "${RED}[!] Uninstalling configuration...${RESET}"
    rm -f /etc/nginx/sites-enabled/g7reverse
    rm -f /etc/nginx/sites-available/g7reverse
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

function install_fail2ban() {
    clear
    banner
    echo -e "${GREEN}[+] Installing Fail2Ban...${RESET}"
    apt update && apt install fail2ban -y
    systemctl enable --now fail2ban
    echo -e "${GREEN}[✓] Fail2Ban installed and started.${RESET}"
    pause
}

function uninstall_fail2ban() {
    clear
    banner
    echo -e "${RED}[!] Removing Fail2Ban...${RESET}"
    systemctl stop fail2ban
    systemctl disable fail2ban
    apt remove --purge fail2ban -y
    echo -e "${GREEN}[✓] Fail2Ban removed.${RESET}"
    pause
}

function check_fail2ban_status() {
    clear
    banner
    echo -e "${CYAN}[~] Fail2Ban Status:${RESET}"
    systemctl status fail2ban --no-pager
    pause
}

function install_bbr() {
    clear
    banner
    echo -e "${GREEN}[+] Installing BBR v3...${RESET}"
    # نصب کرنل و فعال سازی bbr v3
    bash <(curl -sSL https://github.com/teddysun/across/raw/master/bbr.sh)
    echo -e "${GREEN}[✓] BBR v3 installation script executed.${RESET}"
    pause
}

function uninstall_bbr() {
    clear
    banner
    echo -e "${RED}[!] Removing BBR v3...${RESET}"
    # برای حذف BBR، کرنل و تنظیمات باید دستی پاک شوند یا به کرنل قبلی برگردید.
    echo -e "${YELLOW}Please reboot and switch to a kernel without BBR manually.${RESET}"
    pause
}

function check_bbr_status() {
    clear
    banner
    echo -e "${CYAN}[~] Checking BBR status...${RESET}"
    sysctl net.ipv4.tcp_congestion_control
    sysctl net.core.default_qdisc
    echo -e "\n${CYAN}Current TCP Congestion Control Algorithm and QDISC${RESET}"
    pause
}

# منو اصلی
while true; do
    banner
    echo -e "1. Install Script"
    echo -e "2. Uninstall Script"
    echo -e "3. Update Script"
    echo -e "4. Fail2Ban Menu"
    echo -e "5. BBR Menu"
    echo -e "0. Exit"
    echo -e "=============================="
    read -p "Select an option [0-5]: " option

    case $option in
        1) install_script ;;
        2) uninstall_script ;;
        3) update_script ;;
        4) 
            while true; do
                clear
                banner
                echo -e "Fail2Ban Menu:"
                echo -e "1. Install Fail2Ban"
                echo -e "2. Uninstall Fail2Ban"
                echo -e "3. Check Fail2Ban Status"
                echo -e "0. Back to Main Menu"
                echo -e "=============================="
                read -p "Select an option [0-3]: " f_option
                case $f_option in
                    1) install_fail2ban ;;
                    2) uninstall_fail2ban ;;
                    3) check_fail2ban_status ;;
                    0) break ;;
                    *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
                esac
            done
            ;;
        5)
            while true; do
                clear
                banner
                echo -e "BBR Menu:"
                echo -e "1. Install BBR v3"
                echo -e "2. Uninstall BBR"
                echo -e "3. Check BBR Status"
                echo -e "0. Back to Main Menu"
                echo -e "=============================="
                read -p "Select an option [0-3]: " b_option
                case $b_option in
                    1) install_bbr ;;
                    2) uninstall_bbr ;;
                    3) check_bbr_status ;;
                    0) break ;;
                    *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
                esac
            done
            ;;
        0) echo -e "${CYAN}Bye!${RESET}" ; exit 0 ;;
        *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
    esac
done
