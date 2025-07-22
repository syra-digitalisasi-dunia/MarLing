#!/bin/bash

# // Code for service
export RED='\033[0;31m';
export GREEN='\033[0;32m';
export YELLOW='\033[0;33m';
export BLUE='\033[0;34m';
export PURPLE='\033[0;35m';
export CYAN='\033[0;36m';
export LIGHT='\033[0;37m';
export NC='\033[0m';

# // Export Banner Status Information
export ERROR="[${RED} ERROR ${NC}]";
export INFO="[${YELLOW} INFO ${NC}]";
export OKEY="[${GREEN} OKEY ${NC}]";
export PENDING="[${YELLOW} PENDING ${NC}]";
export SEND="[${YELLOW} SEND ${NC}]";
export RECEIVE="[${YELLOW} RECEIVE ${NC}]";

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${ERROR} 'jq' tidak terinstal. Silakan instal menggunakan 'sudo dnf install jq' dan jalankan skrip lagi."
    exit 1
fi

# Check if /etc/data/domain exists and is not empty
if [[ ! -f /etc/data/domain ]] || [[ ! -s /etc/data/domain ]]; then
    echo -e "${ERROR} File '/etc/data/domain' tidak ditemukan atau kosong. Pastikan domain telah diatur."
    exit 1
fi
domain=$(cat /etc/data/domain)

# Check if /etc/data/token.json exists and contains a token
if [[ ! -f /etc/data/token.json ]] || [[ ! -s /etc/data/token.json ]]; then
    echo -e "${ERROR} File '/etc/data/token.json' tidak ditemukan atau kosong. Pastikan token API telah digenerate."
    exit 1
fi
token=$(cat /etc/data/token.json | jq -r .access_token)
if [[ -z "$token" ]]; then
    echo -e "${ERROR} Token akses tidak dapat diekstrak dari '/etc/data/token.json'. Pastikan formatnya benar."
    exit 1
fi

# // VAR
# Check Nginx service status
# Using grep -q for a simpler and more direct check of the process listening on the port
if netstat -ntlp | grep -q "0.0.0.0:8081.*nginx"; then
    NGINX="${GREEN}Okay${NC}";
else
    NGINX="${RED}Not Okay${NC}";
fi

# Check Marzban Panel service status
# Using grep -q for a simpler and more direct check of the process listening on the port
if netstat -ntlp | grep -q "127.0.0.1:7879.*python"; then
    MARZ="${GREEN}Okay${NC}";
else
    MARZ="${RED}Not Okay${NC}";
fi

# Check Firewall (iptables) status for AlmaLinux
# Using systemctl is-active --quiet for a more robust check of the service status
if systemctl is-active --quiet iptables; then
    FIREWALL_STATUS="${GREEN}Okay${NC}";
else
    FIREWALL_STATUS="${RED}Not Okay${NC}";
fi

# Function to fetch system information from Marzban API
function get_marzban_info() {
    local marzban_api="https://${domain}/api/system"
    local marzban_info=$(curl -s -X 'GET' "$marzban_api" -H 'accept: application/json' -H "Authorization: Bearer $token")

    if [[ $? -eq 0 ]]; then
        # Parsing Marzban API response
        marzban_version=$(echo "$marzban_info" | jq -r '.version')
    else
        echo -e "${ERROR} Gagal mengambil informasi Marzban. Periksa domain, token, atau layanan Marzban."
        exit 1
    fi
}
# Usage of the function
get_marzban_info

versimarzban=$(grep 'image: gozargah/marzban:' /opt/marzban/docker-compose.yml | awk -F: '{print $3}')
# Replace values and specific version
case "${versimarzban}" in
    "latest") versimarzban="Stable";;
    "dev") versimarzban="Beta";;
esac

# Function to get Xray Core version
function get_xray_core_version() {
    xray_core_info=$(curl -s -X 'GET' \
        "https://${domain}/api/core" \
        -H 'accept: application/json' \
        -H "Authorization: Bearer ${token}"
    )
    xray_core_version=$(echo "$xray_core_info" | jq -r '.version')

    echo "$xray_core_version"
}
# Get Xray Core version
xray_core_version=$(get_xray_core_version) # No need to pass domain and token as they are global variables

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "\E[44;1;39m          ⇱ Informasi Layanan ⇲            \E[0m"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "❇️ Versi Marzban         : ${GREEN}${marzban_version}${NC} ${BLUE}${versimarzban}${NC}"
echo -e "❇️ Versi Core            : ${GREEN}Xray ${xray_core_version}${NC}"
echo -e "❇️ Nginx                 : $NGINX"
echo -e "❇️ Firewall              : $FIREWALL_STATUS"
echo -e "❇️ Panel Marzban         : $MARZ"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo -e "SHARING PORT 443 MARZBAN VERSION AMAN SEMUA BOSSKUH"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m${NC}"
echo ""
