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

############# Functions for Main Script ################

function install_script() {
    banner
    echo -e "${GREEN}[+] Installing Nginx reverse proxy and configuring firewall...${RESET}"

    read -p "Enter local IP (default 127.0.0.1): " LOCAL_IP
    LOCAL_IP=${LOCAL_IP:-127.0.0.1}

    read -p "Enter local port (default 8000): " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-8000}

    read -p "Enter your domain (or leave empty to skip): " DOMAIN

    apt update && apt install nginx ufw -y

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

    # تنظیم کانفیگ Nginx با یا بدون دامنه
    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="panel.example.ir"
    fi

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

    echo -e "${GREEN}[✓] Installation complete. G7Reverse panel running behind domain: $DOMAIN${RESET}"
    read -p "Press Enter to return to menu..."
}

function uninstall_script() {
    banner
    echo -e "${RED}[!] Uninstalling G7Reverse configuration...${RESET}"
    rm -f /etc/nginx/sites-enabled/g7reverse
    rm -f /etc/nginx/sites-available/g7reverse
    iptables -D INPUT -p tcp --dport 8000 ! -s 127.0.0.1 -j DROP 2>/dev/null
    systemctl restart nginx
    echo -e "${GREEN}[✓] Uninstallation complete.${RESET}"
    read -p "Press Enter to return to menu..."
}

function update_script() {
    banner
    echo -e "${YELLOW}[~] Updating script (re-applying configs)...${RESET}"
    uninstall_script
    install_script
}

############# Functions for BBRv3 ################

function install_bbr() {
    clear
    echo -e "${GREEN}Installing BBR v3...${RESET}"
    # نصب BBRv3 ساده (این نسخه ساده است)
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}[✓] BBR v3 installed and enabled.${RESET}"
    read -p "Press Enter to return to menu..."
}

function remove_bbr() {
    clear
    echo -e "${RED}Removing BBR v3 settings...${RESET}"
    sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}[✓] BBR v3 removed.${RESET}"
    read -p "Press Enter to return to menu..."
}

function check_bbr_status() {
    clear
    echo -e "${CYAN}BBR Status:${RESET}"
    sysctl net.ipv4.tcp_congestion_control
    sysctl net.core.default_qdisc
    echo ""
    lsmod | grep bbr
    echo ""
    read -p "Press Enter to return to menu..."
}

############# Functions for Fail2Ban ################

function install_fail2ban() {
    clear
    echo -e "${GREEN}Installing Fail2Ban...${RESET}"
    apt update && apt install fail2ban -y
    systemctl enable --now fail2ban
    echo -e "${GREEN}[✓] Fail2Ban installed and running.${RESET}"
    read -p "Press Enter to return to menu..."
}

function remove_fail2ban() {
    clear
    echo -e "${RED}Removing Fail2Ban...${RESET}"
    systemctl stop fail2ban
    systemctl disable fail2ban
    apt remove fail2ban -y
    echo -e "${GREEN}[✓] Fail2Ban removed.${RESET}"
    read -p "Press Enter to return to menu..."
}

function check_fail2ban_status() {
    clear
    echo -e "${CYAN}Fail2Ban Status:${RESET}"
    systemctl status fail2ban --no-pager
    echo ""
    read -p "Press Enter to return to menu..."
}

############# Functions for Warp ################

function install_warp() {
    clear
    echo -e "${CYAN}=============================================="
    echo -e "      ${GREEN}Installing Warp client...${RESET}"
    echo -e "==============================================${RESET}"
    curl https://pkg.cloudflareclient.com/install.sh | bash
    systemctl enable --now warp-svc
    warp-cli register
    warp-cli connect
    echo -e "${GREEN}[✓] Warp installed and connected.${RESET}"
    read -p "Press Enter to return to menu..."
}

function warp_status() {
    clear
    echo -e "${CYAN}=============================================="
    echo -e "      ${GREEN}Warp Client Status${RESET}"
    echo -e "==============================================${RESET}"
    warp-cli status
    echo -e "\n"
    read -p "Press Enter to return to menu..."
}

function warp_connect() {
    warp-cli connect
    echo -e "${GREEN}[✓] Warp connected.${RESET}"
    sleep 2
}

function warp_disconnect() {
    warp-cli disconnect
    echo -e "${YELLOW}[!] Warp disconnected.${RESET}"
    sleep 2
}

function uninstall_warp() {
    clear
    echo -e "${RED}Uninstalling Warp client...${RESET}"
    warp-cli disconnect
    systemctl disable --now warp-svc
    apt remove cloudflare-warp -y
    echo -e "${GREEN}[✓] Warp client uninstalled.${RESET}"
    read -p "Press Enter to return to menu..."
}

############# Menu Sections ################

function menu_script_management() {
    while true; do
        banner
        echo -e "📄 Script Management"
        echo -e "1. Install G7Reverse"
        echo -e "2. Uninstall G7Reverse"
        echo -e "3. Update G7Reverse"
        echo -e "0. Back to Main Menu"
        echo -e "=============================="
        read -p "Select an option [0-3]: " opt
        case $opt in
            1) install_script ;;
            2) uninstall_script ;;
            3) update_script ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function menu_bbr_management() {
    while true; do
        banner
        echo -e "⚙️  BBRv3 Management"
        echo -e "1. Install BBR v3"
        echo -e "2. Remove BBR v3"
        echo -e "3. Check BBR Status"
        echo -e "0. Back to Main Menu"
        echo -e "=============================="
        read -p "Select an option [0-3]: " opt
        case $opt in
            1) install_bbr ;;
            2) remove_bbr ;;
            3) check_bbr_status ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function menu_fail2ban_management() {
    while true; do
        banner
        echo -e "🛡️ Fail2Ban Management"
        echo -e "1. Install Fail2Ban"
        echo -e "2. Remove Fail2Ban"
        echo -e "3. Check Fail2Ban Status"
        echo -e "0. Back to Main Menu"
        echo -e "=============================="
        read -p "Select an option [0-3]: " opt
        case $opt in
            1) install_fail2ban ;;
            2) remove_fail2ban ;;
            3) check_fail2ban_status ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function menu_warp_management() {
    while true; do
        banner
        echo -e "🌐 Warp Management"
        echo -e "1. Install Warp"
        echo -e "2. Check Warp Status"
        echo -e "3. Connect Warp"
        echo -e "4. Disconnect Warp"
        echo -e "5. Uninstall Warp"
        echo -e "0. Back to Main Menu"
        echo -e "=============================="
        read -p "Select an option [0-5]: " opt
        case $opt in
            1) install_warp ;;
            2) warp_status ;;
            3) warp_connect ;;
            4) warp_disconnect ;;
            5) uninstall_warp ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

############# Main Menu ################

while true; do
    banner
    echo -e "🗂️ Main Menu"
    echo -e "1. 📄 Script Management"
    echo -e "2. ⚙️ BBRv3 Management"
    echo -e "3. 🛡️ Fail2Ban Management"
    echo -e "4. 🌐 Warp Management"
    echo -e "0. Exit"
    echo -e "=============================="
    read -p "Select an option [0-4]: " mainopt

    case $mainopt in
        1) menu_script_management ;;
        2) menu_bbr_management ;;
        3) menu_fail2ban_management ;;
        4) menu_warp_management ;;
        0) echo -e "${CYAN}Bye!${RESET}" ; exit 0 ;;
        *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
    esac
done
