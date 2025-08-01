#!/bin/bash

# رنگ‌ها
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
RESET='\e[0m'

function banner() {
    clear
    echo -e "${CYAN}=============================================="
    echo -e "      ${GREEN}G7Reverse - Nginx Reverse Proxy Manager"
    echo -e "==============================================${RESET}"
    echo -e "║  Developer: ${YELLOW}@arshiapm47${CYAN}                      ║"
    echo -e "==============================================${RESET}\n"
}

function pause() {
    read -rp "Press any key to return to menu..." -n1
}

function install_script() {
    banner
    echo -e "${GREEN}[+] Installing Nginx reverse proxy and configuring firewall...${RESET}"

    read -p "Enter local IP (default 127.0.0.1): " LOCAL_IP
    LOCAL_IP=${LOCAL_IP:-127.0.0.1}

    read -p "Enter local port (default 8000): " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-8000}

    read -p "Enter domain name (optional, press Enter to skip): " DOMAIN_NAME
    if [[ -z "$DOMAIN_NAME" ]]; then
        DOMAIN_NAME="panel.example.ir"
    fi

    apt update && apt install -y nginx ufw

    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 2922/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 8443/tcp
    ufw allow 4433/tcp
    ufw allow 9999/tcp
    ufw --force enable

    iptables -D INPUT -p tcp --dport "$LOCAL_PORT" ! -s "$LOCAL_IP" -j DROP 2>/dev/null
    iptables -A INPUT -p tcp --dport "$LOCAL_PORT" ! -s "$LOCAL_IP" -j DROP

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

    echo -e "${GREEN}[✓] Installation complete. G7Reverse panel running behind domain: $DOMAIN_NAME${RESET}"
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
    banner
    echo -e "${GREEN}[+] Installing Fail2Ban...${RESET}"
    apt update && apt install -y fail2ban
    systemctl enable fail2ban --now
    echo -e "${GREEN}[✓] Fail2Ban installed and started.${RESET}"
    pause
}

function uninstall_fail2ban() {
    banner
    echo -e "${RED}[!] Removing Fail2Ban...${RESET}"
    systemctl stop fail2ban
    systemctl disable fail2ban
    apt purge -y fail2ban
    echo -e "${GREEN}[✓] Fail2Ban removed.${RESET}"
    pause
}

function install_bbr() {
    banner
    echo -e "${GREEN}[+] Installing BBR v3...${RESET}"
    apt update && apt install -y linux-headers-$(uname -r) gcc make
    wget -N --no-check-certificate https://github.com/teddysun/across/raw/master/bbr3.sh
    bash bbr3.sh
    echo -e "${GREEN}[✓] BBR v3 installed.${RESET}"
    pause
}

function uninstall_bbr() {
    banner
    echo -e "${RED}[!] Removing BBR...${RESET}"
    sysctl -w net.ipv4.tcp_congestion_control=reno
    sysctl -w net.core.default_qdisc=fq
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}[✓] BBR removed and system reverted to default TCP settings.${RESET}"
    pause
}

function install_warp() {
    banner
    echo -e "${GREEN}[+] Installing Cloudflare Warp...${RESET}"
    curl -s https://pkg.cloudflareclient.com/install.sh | bash
    echo y | warp-cli register
    warp-cli connect
    echo -e "${GREEN}[✓] Warp installed and connected.${RESET}"
    pause
}

function uninstall_warp() {
    banner
    echo -e "${RED}[!] Uninstalling Cloudflare Warp...${RESET}"
    warp-cli disconnect
    warp-cli uninstall
    systemctl disable warp-svc --now
    echo -e "${GREEN}[✓] Warp uninstalled.${RESET}"
    pause
}

function check_warp_status() {
    banner
    echo -e "${CYAN}Checking Cloudflare Warp status...${RESET}"
    STATUS=$(warp-cli status 2>/dev/null | grep 'Status update' | awk -F': ' '{print $2}')
    if [[ "$STATUS" == "Connected" ]]; then
        echo -e "${GREEN}Warp is connected and running.${RESET}"
    elif [[ "$STATUS" == "Registration Missing" || "$STATUS" == "Unable" ]]; then
        echo -e "${YELLOW}Warp is not registered. Registering now...${RESET}"
        echo y | warp-cli register
        warp-cli connect
        echo -e "${GREEN}Warp registered and connected.${RESET}"
    else
        echo -e "${RED}Warp status unknown or failed.${RESET}"
    fi
    pause
}

function warp_menu() {
    while true; do
        banner
        echo -e "${CYAN}--- Warp Menu ---${RESET}"
        echo -e "1. Install Warp"
        echo -e "2. Uninstall Warp"
        echo -e "3. Check Warp Status"
        echo -e "0. Back to Main Menu"
        echo -e "=============================="
        read -p "Select an option [0-3]: " warp_option

        case $warp_option in
            1) install_warp ;;
            2) uninstall_warp ;;
            3) check_warp_status ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function bbr_menu() {
    while true; do
        banner
        echo -e "${CYAN}--- BBR Menu ---${RESET}"
        echo -e "1. Install BBR v3"
        echo -e "2. Uninstall BBR"
        echo -e "0. Back to Main Menu"
        echo -e "=============================="
        read -p "Select an option [0-2]: " bbr_option

        case $bbr_option in
            1) install_bbr ;;
            2) uninstall_bbr ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function fail2ban_menu() {
    while true; do
        banner
        echo -e "${CYAN}--- Fail2Ban Menu ---${RESET}"
        echo -e "1. Install Fail2Ban"
        echo -e "2. Uninstall Fail2Ban"
        echo -e "0. Back to Main Menu"
        echo -e "=============================="
        read -p "Select an option [0-2]: " f2b_option

        case $f2b_option in
            1) install_fail2ban ;;
            2) uninstall_fail2ban ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

# منو اصلی
while true; do
    banner
    echo -e "1. Install Script"
    echo -e "2. Uninstall Script"
    echo -e "3. Update Script"
    echo -e "4. Fail2Ban Options"
    echo -e "5. BBR Options"
    echo -e "6. Warp Options"
    echo -e "0. Exit"
    echo -e "=============================="
    read -p "Select an option [0-6]: " option

    case $option in
        1) install_script ;;
        2) uninstall_script ;;
        3) update_script ;;
        4) fail2ban_menu ;;
        5) bbr_menu ;;
        6) warp_menu ;;
        0) echo -e "${CYAN}Bye!${RESET}" ; exit 0 ;;
        *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
    esac
done
