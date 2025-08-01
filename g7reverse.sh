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
    read -p "Press Enter to return to menu..."
}

# ----------- NGINX Reverse Proxy -----------
function install_nginx() {
    clear
    banner
    echo -e "${GREEN}[+] Installing Nginx reverse proxy and configuring firewall...${RESET}"

    read -p "Enter local IP (default 127.0.0.1): " LOCAL_IP
    LOCAL_IP=${LOCAL_IP:-127.0.0.1}

    read -p "Enter local port (default 8000): " LOCAL_PORT
    LOCAL_PORT=${LOCAL_PORT:-8000}

    read -p "Enter domain name for proxy (optional, press Enter to skip): " DOMAIN_NAME

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

    if [[ -z "$DOMAIN_NAME" ]]; then
        cat > /etc/nginx/sites-available/g7reverse << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://$LOCAL_IP:$LOCAL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
    else
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
    fi

    ln -sf /etc/nginx/sites-available/g7reverse /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx

    echo -e "${GREEN}[✓] Installation complete. G7Reverse panel running behind${DOMAIN_NAME:-'default domain'}.${RESET}"
    pause
}

function uninstall_nginx() {
    clear
    banner
    echo -e "${RED}[!] Uninstalling nginx reverse proxy configuration...${RESET}"
    rm -f /etc/nginx/sites-enabled/g7reverse
    rm -f /etc/nginx/sites-available/g7reverse
    iptables -D INPUT -p tcp --dport 8000 ! -s 127.0.0.1 -j DROP 2>/dev/null
    systemctl restart nginx
    echo -e "${GREEN}[✓] Uninstallation complete.${RESET}"
    pause
}

function update_nginx() {
    clear
    banner
    echo -e "${YELLOW}[~] Updating nginx reverse proxy configuration...${RESET}"
    uninstall_nginx
    install_nginx
}

# ----------- BBRv3 Management -----------
function install_bbr() {
    clear
    banner
    echo -e "${GREEN}[+] Installing BBRv3 (TCP BBR alternative)...${RESET}"

    # نصب از repo رسمی BBRv3
    apt update && apt install -y --no-install-recommends linux-headers-$(uname -r)
    apt install -y --no-install-recommends bbrtools
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install bbrtools.${RESET}"
        pause
        return
    fi

    # فعال سازی BBRv3
    modprobe tcp_bbr
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf
    echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
    sysctl -p

    echo -e "${GREEN}[✓] BBRv3 installed and activated successfully.${RESET}"
    pause
}

function remove_bbr() {
    clear
    banner
    echo -e "${RED}[!] Removing BBRv3...${RESET}"

    # حذف تنظیمات BBRv3
    sed -i '/tcp_bbr/d' /etc/modules-load.d/bbr.conf 2>/dev/null
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf 2>/dev/null
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null
    sysctl -p

    echo -e "${GREEN}[✓] BBRv3 removed.${RESET}"
    pause
}

function check_bbr_status() {
    clear
    banner
    echo -e "${CYAN}Checking BBR status:${RESET}"
    sysctl net.ipv4.tcp_congestion_control
    lsmod | grep bbr
    pause
}

# ----------- Fail2Ban Management -----------
function install_fail2ban() {
    clear
    banner
    echo -e "${GREEN}[+] Installing Fail2Ban...${RESET}"
    apt update && apt install -y fail2ban
    systemctl enable --now fail2ban
    echo -e "${GREEN}[✓] Fail2Ban installed and running.${RESET}"
    pause
}

function remove_fail2ban() {
    clear
    banner
    echo -e "${RED}[!] Removing Fail2Ban...${RESET}"
    systemctl stop fail2ban
    systemctl disable fail2ban
    apt remove -y fail2ban
    echo -e "${GREEN}[✓] Fail2Ban removed.${RESET}"
    pause
}

# ----------- Warp Management -----------
function install_warp() {
    clear
    banner
    echo -e "${GREEN}[+] Installing Cloudflare Warp...${RESET}"

    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download Cloudflare GPG key.${RESET}"
        pause
        return
    fi

    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list

    apt update
    apt install -y cloudflare-warp
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install cloudflare-warp.${RESET}"
        pause
        return
    fi

    systemctl enable --now warp-svc
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to enable warp-svc service.${RESET}"
        pause
        return
    fi

    warp-cli register
    warp-cli connect

    echo -e "${GREEN}[✓] Cloudflare Warp installed and connected successfully.${RESET}"
    pause
}

function remove_warp() {
    clear
    banner
    echo -e "${RED}[!] Removing Cloudflare Warp...${RESET}"

    warp-cli disconnect 2>/dev/null
    systemctl disable --now warp-svc
    apt remove -y cloudflare-warp
    rm -f /etc/apt/sources.list.d/cloudflare-client.list
    rm -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

    echo -e "${GREEN}[✓] Cloudflare Warp removed.${RESET}"
    pause
}

function warp_status() {
    clear
    banner
    echo -e "${CYAN}Checking Cloudflare Warp status:${RESET}"
    warp-cli status
    pause
}

# ----------- Main Menu -----------
function main_menu() {
    while true; do
        banner
        echo -e "${YELLOW}1.${RESET} Nginx Reverse Proxy Management"
        echo -e "2. BBRv3 (TCP BBR alternative) Management"
        echo -e "3. Fail2Ban Management"
        echo -e "4. Cloudflare Warp Management"
        echo -e "0. Exit"
        echo -e "=============================="
        read -p "Select an option [0-4]: " main_option

        case $main_option in
            1) nginx_menu ;;
            2) bbr_menu ;;
            3) fail2ban_menu ;;
            4) warp_menu ;;
            0) echo -e "${CYAN}Bye!${RESET}" ; exit 0 ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function nginx_menu() {
    while true; do
        clear
        banner
        echo -e "${YELLOW}Nginx Reverse Proxy Management:${RESET}"
        echo "1) Install Nginx Reverse Proxy"
        echo "2) Uninstall Nginx Reverse Proxy"
        echo "3) Update Nginx Reverse Proxy"
        echo "0) Back to Main Menu"
        echo "=============================="
        read -p "Select an option [0-3]: " option
        case $option in
            1) install_nginx ;;
            2) uninstall_nginx ;;
            3) update_nginx ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function bbr_menu() {
    while true; do
        clear
        banner
        echo -e "${YELLOW}BBRv3 Management:${RESET}"
        echo "1) Install BBRv3"
        echo "2) Remove BBRv3"
        echo "3) Check BBR Status"
        echo "0) Back to Main Menu"
        echo "=============================="
        read -p "Select an option [0-3]: " option
        case $option in
            1) install_bbr ;;
            2) remove_bbr ;;
            3) check_bbr_status ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function fail2ban_menu() {
    while true; do
        clear
        banner
        echo -e "${YELLOW}Fail2Ban Management:${RESET}"
        echo "1) Install Fail2Ban"
        echo "2) Remove Fail2Ban"
        echo "0) Back to Main Menu"
        echo "=============================="
        read -p "Select an option [0-2]: " option
        case $option in
            1) install_fail2ban ;;
            2) remove_fail2ban ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

function warp_menu() {
    while true; do
        clear
        banner
        echo -e "${YELLOW}Cloudflare Warp Management:${RESET}"
        echo "1) Install Warp"
        echo "2) Remove Warp"
        echo "3) Check Warp Status"
        echo "0) Back to Main Menu"
        echo "=============================="
        read -p "Select an option [0-3]: " option
        case $option in
            1) install_warp ;;
            2) remove_warp ;;
            3) warp_status ;;
            0) break ;;
            *) echo -e "${RED}Invalid option!${RESET}" ; sleep 1 ;;
        esac
    done
}

# اجرای منو اصلی
main_menu
