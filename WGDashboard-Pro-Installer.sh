#!/bin/bash

# ==============================================================================
# WGDashboard Universal Installer - Pro Edition (Stable)
# Supported OS: Ubuntu 22.04, 24.04, 26.04+
# Architecture: Direct Python VENV & Systemd Forking Integration
# ==============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

APP_DIR="/opt/wgdashboard"
SRC_DIR="$APP_DIR/src"
SERVICE_FILE="/etc/systemd/system/wg-dashboard.service"
PYTHON_VERSION="python3.12"

# ---------------------------------------------------------
# Check Root
# ---------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[✕] This script must be run as root. Use sudo.${NC}"
    exit 1
fi

# ---------------------------------------------------------
# Menu Function
# ---------------------------------------------------------
display_menu() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}      WGDashboard Universal Installer (Custom)      ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${GREEN}1) Install / Re-install WGDashboard${NC}"
    echo -e "${CYAN}2) Start Service${NC}"
    echo -e "${YELLOW}3) Stop Service${NC}"
    echo -e "${CYAN}4) Restart Service${NC}"
    echo -e "${RED}5) Uninstall WGDashboard${NC}"
    echo -e "${NC}6) Exit${NC}"
    echo -e "${CYAN}====================================================${NC}"
    read -p "Select an option [1-6]: " choice
}

# ---------------------------------------------------------
# Core Install Function
# ---------------------------------------------------------
install_app() {
    echo -e "\n${CYAN}[*] Starting stable installation...${NC}"

    # 1. OS Detection and System Dependencies
    echo -e "${YELLOW}[*] Detecting Ubuntu Version...${NC}"
    source /etc/os-release
    OS_VER=$VERSION_ID
    
    echo -e "${GREEN}[+] Ubuntu version ${OS_VER} detected.${NC}"

    if dpkg --compare-versions "$OS_VER" "ge" "24.04"; then
        # For Ubuntu 24.04, 26.04 and above (Native Python 3.12+)
        echo -e "${YELLOW}[*] Using native Ubuntu repositories for Python 3.12...${NC}"
        apt-get update -y
        apt-get install git wireguard-tools net-tools $PYTHON_VERSION ${PYTHON_VERSION}-venv ${PYTHON_VERSION}-dev -y
    else
        # For Ubuntu 22.04 (Requires PPA)
        echo -e "${YELLOW}[*] Ubuntu 22.04 detected. Adding Deadsnakes PPA for Python 3.12...${NC}"
        apt-get update -y
        apt-get install software-properties-common -y
        add-apt-repository ppa:deadsnakes/ppa -y
        apt-get update -y
        apt-get install git wireguard-tools net-tools $PYTHON_VERSION ${PYTHON_VERSION}-venv ${PYTHON_VERSION}-dev -y
    fi

    # 2. Setup Directory structure
    echo -e "${YELLOW}[*] Cloning repository to $APP_DIR...${NC}"
    if [ -d "$APP_DIR" ]; then
        echo -e "${YELLOW}[!] Existing installation found. Removing...${NC}"
        systemctl stop wg-dashboard &>/dev/null
        rm -rf "$APP_DIR"
    fi
    
    git clone https://github.com/donaldzou/WGDashboard.git "$APP_DIR"
    cd "$SRC_DIR" || exit
    
    # Create required app folders
    mkdir -p log db download

    # 3. Setup Virtual Environment (VENV)
    echo -e "${YELLOW}[*] Creating Python Virtual Environment...${NC}"
    $PYTHON_VERSION -m venv venv

    # 4. Smart PIP Installation with Fallback Mirrors
    echo -e "${YELLOW}[*] Checking PIP connectivity...${NC}"
    PIP_CMD="./venv/bin/pip"
    
    # Test connection to official PyPI
    if curl -s --head https://pypi.org/simple | grep "200 OK" > /dev/null; then
        echo -e "${GREEN}[+] Official PyPI is reachable. Using default servers.${NC}"
        INDEX_URL=""
    else
        echo -e "${RED}[!] Official PyPI blocked or slow. Switching to alternative Mirror...${NC}"
        INDEX_URL="-i https://mirrors.aliyun.com/pypi/simple/"
    fi

    echo -e "${YELLOW}[*] Upgrading PIP and installing requirements...${NC}"
    $PIP_CMD install --upgrade pip $INDEX_URL
    $PIP_CMD install -r requirements.txt $INDEX_URL

    if [ $? -ne 0 ]; then
        echo -e "${RED}[✕] Failed to install Python dependencies. Check your network.${NC}"
        exit 1
    fi

    # 5. OS Level Configurations (IP Forwarding & Permissions)
    echo -e "${YELLOW}[*] Configuring OS Network Settings...${NC}"
    chmod -R 755 /etc/wireguard
    
    sed -i '/net.ipv6.ip_forward=1/d' /etc/sysctl.conf
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    sysctl -p > /dev/null

    # 6. Create robust Systemd Service (Fixed to Forking Mode)
    echo -e "${YELLOW}[*] Creating Systemd Service...${NC}"
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=WGDashboard Native Service
After=network.target wg-quick.target
ConditionPathIsDirectory=/etc/wireguard

[Service]
Type=forking
PIDFile=$SRC_DIR/gunicorn.pid
WorkingDirectory=$SRC_DIR
ExecStart=$SRC_DIR/venv/bin/python3.12 -m gunicorn --workers 2 --threads 4 --bind 0.0.0.0:10086 dashboard:app
Restart=always
RestartSec=5
SyslogIdentifier=wgdashboard

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wg-dashboard.service
    systemctl start wg-dashboard.service

    # Check final status
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if systemctl is-active --quiet wg-dashboard.service; then
        echo -e "\n${GREEN}====================================================${NC}"
        echo -e "${GREEN}[✔] WGDashboard Installed and Running Successfully!${NC}"
        echo -e "${NC}Panel URL : ${CYAN}http://${SERVER_IP}:10086${NC}"
        echo -e "${NC}Username  : ${YELLOW}admin${NC}"
        echo -e "${NC}Password  : ${YELLOW}admin${NC}"
        echo -e "${GREEN}====================================================${NC}\n"
    else
        echo -e "${RED}[✕] Service failed to start. Run: journalctl -u wg-dashboard --no-pager${NC}"
    fi
    read -p "Press Enter to return to menu..."
}

# ---------------------------------------------------------
# Uninstall Function
# ---------------------------------------------------------
uninstall_app() {
    echo -e "${RED}[!] Uninstalling WGDashboard...${NC}"
    systemctl stop wg-dashboard.service &>/dev/null
    systemctl disable wg-dashboard.service &>/dev/null
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    
    if [ -d "$APP_DIR" ]; then
        rm -rf "$APP_DIR"
        echo -e "${GREEN}[✔] Directory $APP_DIR removed.${NC}"
    fi
    echo -e "${GREEN}[✔] WGDashboard uninstalled completely.${NC}"
    read -p "Press Enter to return to menu..."
}

# ---------------------------------------------------------
# Main Loop
# ---------------------------------------------------------
while true; do
    display_menu
    case $choice in
        1) install_app ;;
        2) systemctl start wg-dashboard && echo -e "${GREEN}Service Started.${NC}" && sleep 2 ;;
        3) systemctl stop wg-dashboard && echo -e "${YELLOW}Service Stopped.${NC}" && sleep 2 ;;
        4) systemctl restart wg-dashboard && echo -e "${CYAN}Service Restarted.${NC}" && sleep 2 ;;
        5) uninstall_app ;;
        6) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done