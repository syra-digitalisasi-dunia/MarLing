#!/bin/bash
colorized_echo() {
    local color=$1
    local text=$2
    
    case $color in
        "red")
        printf "\e[91m${text}\e[0m\n";;
        "green")
        printf "\e[92m${text}\e[0m\n";;
        "yellow")
        printf "\e[93m${text}\e[0m\n";;
        "blue")
        printf "\e[94m${text}\e[0m\n";;
        "magenta")
        printf "\e[95m${text}\e[0m\n";;
        "cyan")
        printf "\e[96m${text}\e[0m\n";;
        *)
            echo "${text}"
        ;;
    esac
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    colorized_echo red "Error: Skrip ini harus dijalankan sebagai root."
    exit 1
fi

# Check supported operating system
supported_os=false

if [ -f /etc/os-release ]; then
    os_name=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    os_version=$(grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

    # Debugging: Print detected OS name and version
    echo "Detected OS Name: $os_name"
    echo "Detected OS Version: $os_version"

    if [ "$os_name" == "debian" ] && ([ "$os_version" == "11" ] || [ "$os_version" == "12" ]); then
        supported_os=true
    elif [ "$os_name" == "ubuntu" ] && [ "$os_version" == "20.04" ]; then
        supported_os=true
    # Modified the AlmaLinux version check to support minor versions (e.g., 8.x, 9.x)
    elif [ "$os_name" == "almalinux" ] && ([[ "$os_version" =~ ^8.*$ ]] || [[ "$os_version" =~ ^9.*$ ]]); then
        supported_os=true
    fi
fi

# Asumsi sudo dan curl sudah tersedia di AlmaLinux. Jika tidak, instalasi dnf akan menanganinya.
# Baris "apt install sudo curl -y" dihapus karena tidak relevan untuk AlmaLinux dan ditempatkan sebelum pemeriksaan OS.

if [ "$supported_os" != true ]; then
    colorized_echo red "Error: Skrip ini hanya support di Debian 11/12, Ubuntu 20.04, dan AlmaLinux 8/9. Mohon gunakan OS yang di support."
    exit 1
fi

mkdir -p /etc/data

#domain
read -rp "Masukkan Domain: " domain
echo "$domain" > /etc/data/domain
domain=$(cat /etc/data/domain)

#email
read -rp "Masukkan Email anda: " email

#username
while true; do
    read -rp "Masukkan UsernamePanel (hanya huruf dan angka): " userpanel

    # Memeriksa apakah userpanel hanya mengandung huruf dan angka
    if [[ ! "$userpanel" =~ ^[A-Za-z0-9]+$ ]]; then
        echo "UsernamePanel hanya boleh berisi huruf dan angka. Silakan masukkan kembali."
    elif [[ "$userpanel" =~ [Aa][Dd][Mm][Ii][Nn] ]]; then
        echo "UsernamePanel tidak boleh mengandung kata 'admin'. Silakan masukkan kembali."
    else
        echo "$userpanel" > /etc/data/userpanel
        break
    fi
done

read -rp "Masukkan Password Panel: " passpanel
echo "$passpanel" > /etc/data/passpanel

#Preparation
clear
cd;
# Gunakan dnf untuk AlmaLinux
dnf update -y;

#Remove unused Module
# Gunakan dnf untuk AlmaLinux
dnf remove -y samba* httpd* sendmail* bind*;

#install bbr
echo 'fs.file-max = 500000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 4000000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
sysctl -p;

#install toolkit
# Gunakan dnf untuk AlmaLinux dan sesuaikan nama paket
dnf install -y perl-IO-Socket-INET6 perl-Socket6 perl-Net-SSLeay perl-Net-LibIDN perl-IO-Socket-SSL perl-LWP-Protocol-https pcre pcre-devel zlib-devel dbus iftop zip unzip wget net-tools curl nano sed screen gnupg2 bc gcc make dirmngr bind-utils sudo at htop iptables util-linux cronie lsof lnav

#Set Timezone GMT+7
timedatectl set-timezone Asia/Jakarta;

#Install Marzban
# CATATAN: Skrip Marzban itu sendiri mungkin berisi perintah apt.
# Jika skrip ini gagal, Anda mungkin perlu memeriksa marzban.sh secara manual
# dan mengadaptasinya untuk manajer paket AlmaLinux (dnf).
sudo bash -c "$(curl -sL https://github.com/GawrAme/Marzban-scripts/raw/master/marzban.sh)" @ install

#Install Subs
wget -N -P /var/lib/marzban/templates/subscription/  https://raw.githubusercontent.com/GawrAme/MarLing/main/index.html

#install env
wget -O /opt/marzban/.env "https://raw.githubusercontent.com/GawrAme/MarLing/main/env"

#install Assets folder
mkdir -p /var/lib/marzban/assets
cd

#profile
echo -e 'profile' >> /root/.profile
wget -O /usr/bin/profile "https://raw.githubusercontent.com/GawrAme/MarLing/main/profile";
chmod +x /usr/bin/profile
# Gunakan dnf untuk AlmaLinux
dnf install -y neofetch
wget -O /usr/bin/cekservice "https://raw.githubusercontent.com/GawrAme/MarLing/main/cekservice.sh"
chmod +x /usr/bin/cekservice

#install compose
wget -O /opt/marzban/docker-compose.yml "https://raw.githubusercontent.com/GawrAme/MarLing/main/docker-compose.yml"

#Install VNSTAT
# Gunakan dnf untuk AlmaLinux
dnf install -y vnstat
systemctl restart vnstat # Menggunakan systemctl untuk konsistensi
# Gunakan dnf untuk AlmaLinux
dnf install -y sqlite-devel
wget https://github.com/GawrAme/MarLing/raw/main/vnstat-2.6.tar.gz
tar zxvf vnstat-2.6.tar.gz
cd vnstat-2.6
./configure --prefix=/usr --sysconfdir=/etc && make && make install
cd
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
systemctl restart vnstat
rm -f /root/vnstat-2.6.tar.gz
rm -rf /root/vnstat-2.6

#Install Speedtest
# Gunakan script.rpm.sh untuk AlmaLinux
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | sudo bash
# Gunakan dnf untuk AlmaLinux
sudo dnf install -y speedtest

#install nginx
mkdir -p /var/log/nginx
touch /var/log/nginx/access.log
touch /var/log/nginx/error.log
wget -O /opt/marzban/nginx.conf "https://raw.githubusercontent.com/GawrAme/MarLing/main/nginx.conf"
wget -O /opt/marzban/default.conf "https://raw.githubusercontent.com/GawrAme/MarLing/main/vps.conf"
wget -O /opt/marzban/xray.conf "https://raw.githubusercontent.com/GawrAme/MarLing/main/xray.conf"
mkdir -p /var/www/html
echo "<pre>Setup by AutoScript LingVPN</pre>" > /var/www/html/index.html

#install socat
# Gunakan dnf untuk AlmaLinux
dnf install -y iptables
# Gunakan dnf untuk AlmaLinux dan sesuaikan nama paket
dnf install -y curl socat xz-utils wget gnupg2 bind-utils redhat-lsb-core -y
# Gunakan dnf untuk AlmaLinux dan sesuaikan nama paket
dnf install -y socat cronie bash-completion -y

#install cert
curl https://get.acme.sh | sh -s email=$email
/root/.acme.sh/acme.sh --server letsencrypt --register-account -m $email --issue -d $domain --standalone -k ec-256 --debug
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /var/lib/marzban/xray.crt --keypath /var/lib/marzban/xray.key --ecc
wget -O /var/lib/marzban/xray_config.json "https://raw.githubusercontent.com/GawrAme/MarLing/main/xray_config.json"

#install firewall
# Gunakan iptables sebagai firewall
# Hentikan dan nonaktifkan firewalld jika berjalan, untuk menghindari konflik
if systemctl is-active --quiet firewalld; then
    colorized_echo yellow "Firewalld terdeteksi dan aktif. Menonaktifkan firewalld..."
    systemctl stop firewalld
    systemctl disable firewalld
    colorized_echo green "Firewalld berhasil dinonaktifkan."
fi

# Instal iptables-services untuk persistensi aturan
dnf install -y iptables-services

# Bersihkan semua aturan iptables yang ada
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Setel kebijakan default ke DROP untuk INPUT dan FORWARD, ACCEPT untuk OUTPUT
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Izinkan lalu lintas loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Izinkan koneksi yang sudah ada dan terkait
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Izinkan SSH (port 22)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Izinkan HTTP (port 80)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Izinkan HTTPS (port 443)
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Izinkan port 8081 (TCP)
iptables -A INPUT -p tcp --dport 8081 -j ACCEPT

# Izinkan port 1080 (TCP)
iptables -A INPUT -p tcp --dport 1080 -j ACCEPT

# Izinkan port 1080 (UDP)
iptables -A INPUT -p udp --dport 1080 -j ACCEPT

# Simpan aturan iptables agar persisten setelah reboot
# Untuk AlmaLinux, ini biasanya dilakukan dengan service iptables-persistent atau dengan mengaktifkan dan menyimpan via systemctl
systemctl enable iptables # Pastikan layanan iptables diaktifkan
systemctl start iptables  # Mulai layanan iptables
iptables-save > /etc/sysconfig/iptables # Simpan aturan ke file konfigurasi default

colorized_echo green "Firewall iptables telah dikonfigurasi dan diaktifkan."

#install database
wget -O /var/lib/marzban/db.sqlite3 "https://github.com/GawrAme/MarLing/raw/main/db.sqlite3"

#install WARP Proxy
wget -O /root/warp "https://raw.githubusercontent.com/hamid-gh98/x-ui-scripts/main/install_warp_proxy.sh"
sudo chmod +x /root/warp
sudo bash /root/warp -y

#finishing
# Gunakan dnf untuk AlmaLinux
dnf autoremove -y
dnf clean all -y
cd /opt/marzban
sed -i "s/# SUDO_USERNAME = \"admin\"/SUDO_USERNAME = \"${userpanel}\"/" /opt/marzban/.env
sed -i "s/# SUDO_PASSWORD = \"admin\"/SUDO_PASSWORD = \"${passpanel}\"/" /opt/marzban/.env
docker compose down && docker compose up -d
marzban cli admin import-from-env -y
sed -i "s/SUDO_USERNAME = \"${userpanel}\"/# SUDO_USERNAME = \"admin\"/" /opt/marzban/.env
sed -i "s/SUDO_PASSWORD = \"${passpanel}\"/# SUDO_PASSWORD = \"admin\"/" /opt/marzban/.env
docker compose down && docker compose up -d
cd
echo "Tunggu 30 detik untuk generate token API"
sleep 30s

#instal token
curl -X 'POST' \
  "https://${domain}/api/admin/token" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password&username=${userpanel}&password=${passpanel}&scope=&client_id=string&client_secret=string" > /etc/data/token.json
cd
touch /root/log-install.txt
echo -e "Untuk data login dashboard Marzban:
-=================================-
URL HTTPS : https://${domain}/dashboard
username  : ${userpanel}
password  : ${passpanel}
-=================================-
Jangan lupa join Channel & Grup Telegram saya juga di
Telegram Channel: https://t.me/LingVPN
Telegram Group: https://t.me/LingVPN_Group
-=================================-" > /root/log-install.txt
profile
colorized_echo green "Script telah berhasil di install"
rm /root/mar.sh
colorized_echo blue "Menghapus admin bawaan db.sqlite"
marzban cli admin delete -u admin -y
echo -e "[\e[1;31mWARNING\e[0m] Reboot sekali biar ga error lur [default y](y/n)? "
read answer
if [ "$answer" == "${answer#[Yy]}" ] ;then
exit 0
else
cat /dev/null > ~/.bash_history && history -c && reboot
fi
