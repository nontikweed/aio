#!/bin/bash
    
# TANG INA MO MAHIYA KANAMAN HAHAHAHA
    # TARANTADO GAGO MANG-MANG MAGNANAKAW

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[0;33m'
    NC='\033[0m' # No Color
    
    #PORT OPENVPN
    PORT_TCP='1194';
    PORT_UDP='25222';

    # Script Version
    SCRIPT_VERSION="v20231230"
    SCRIPT_NAME="Nontikweed"


    timedatectl set-timezone Asia/Manila 2>/dev/null || true
    server_ip=$(curl -s https://api.ipify.org)
    server_interface=$(ip route | grep default | awk '{print $5}' | head -n1)
    date=$(date '+%Y-%m-%d %H:%M:%S')

    # Auto change repo
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "ubuntu" ]; then
            sed -i 's/mirrors.ucloud.cn/archive.ubuntu.com/g' /etc/apt/sources.list        
        fi
    fi

    if [ "$(id -u)" -ne 0 ]; then
        echo "Please run this installer as root."
        exit 1
    fi

    SSH_SERVICE="ssh"
    if systemctl list-unit-files sshd.service >/dev/null 2>&1; then
        SSH_SERVICE="sshd"
    fi

    PYTHON_BIN="$(command -v python2 || true)"
    if [ -z "$PYTHON_BIN" ] && command -v python >/dev/null 2>&1; then
        PYTHON_BIN="$(command -v python)"
    fi

    # Fixed Downloading Github
    if [ -f /etc/resolv.conf ] && [ ! -f /etc/resolv.conf.bak.popotworks ]; then
        cp /etc/resolv.conf /etc/resolv.conf.bak.popotworks
    fi
    chattr -i /etc/resolv.conf 2>/dev/null
    cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
    

    install_dependencies () {
    printf "%b\n" "\e[32m[\e[0mInfo\e[32m]\e[0m\e[97m Please wait..\e[0m"
    {   
        export DEBIAN_FRONTEND=noninteractive 
        rm -rf /var/lib/dpkg/lock /var/{lib/apt/lists/lock,cache/apt/archives/lock}
        apt-get update
        apt install -y dos2unix dnsutils nginx php-cli 2>/dev/null
        apt install -y sudo openvpn openssl libpam-script
        apt install -y netcat-openbsd httpie neofetch vnstat
        apt install -y screen squid stunnel4 dropbear gnutls-bin 2>/dev/null
        apt install -y nano unzip jq virt-what net-tools 2>/dev/null
        apt install -y plocate dh-make libaudit-dev build-essential fail2ban 2>/dev/null || apt install -y mlocate dh-make libaudit-dev build-essential 2>/dev/null
        apt install -y git curl wget cron python3 python3-minimal python-is-python3 2>/dev/null
        apt install squid -y 2>/dev/null
        apt install lolcat figlet ruby -y 2>/dev/null || true
        command -v lolcat >/dev/null 2>&1 || gem install lolcat || true
        apt install iptables-persistent -y -f 2>/dev/null
        PYTHON_BIN="$(command -v python2 || command -v python || true)"
        if [ -z "$PYTHON_BIN" ]; then
            echo -e "[\e[31mError\e[0m] Python2 installation failed."
            exit 1
        fi
        systemctl restart netfilter-persistent &>/dev/null
        systemctl enable netfilter-persistent &>/dev/null

        echo -e "[\e[32mInfo\e[0m] All required packages installed."
        sleep 5
        reset
    } #&>/dev/null
        echo -e "[\e[32mInfo\e[0m] Installing Complete."
        reset
    }

  install_dropbear() {


reset

echo -n -e "[\e[32mInfo\e[0m]"
echo -e " Installing Dropbear." | lolcat

{

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Configuring Dropbear." | lolcat

    cat <<'EOFDropbear' > /etc/default/dropbear
NO_START=0
DROPBEAR_PORT=555
DROPBEAR_EXTRA_ARGS="-p 550"
DROPBEAR_BANNER="/etc/banner"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
EOFDropbear

    systemctl enable dropbear >/dev/null 2>&1
    systemctl restart dropbear
}

echo -n -e "[\e[32mInfo\e[0m]"
echo -e " Installation Complete Dropbear." | lolcat

reset

}

install_user_api() {
echo -n -e "[\e[32mInfo\e[0m]"
echo -e " Installing User API." | lolcat

{

    mkdir -p /root/api

    cat <<'EOFAPI' > /root/api/create-user.php
<?php

header('Content-Type: application/json');

$apiKey = $_POST['api_key'] ?? '';

if ($apiKey !== 'xebecc') {

    http_response_code(403);

    exit(json_encode([

        'status' => false,

        'message' => 'Invalid API key'

    ]));
}

$username = $_POST['username'] ?? '';
$password = $_POST['password'] ?? '';
$expiry  = $_POST['expiry'] ?? '';

if (
    empty($username) ||
    empty($password) ||
    empty($expiry)
) {

    exit(json_encode([

        'status' => false,

        'message' => 'Missing fields'

    ]));
}

$usernameSafe = escapeshellarg($username);

$passwordSafe = escapeshellarg($password);

shell_exec("
    id {$usernameSafe} >/dev/null 2>&1 || \
    useradd -e {$expiry} -M -s /bin/bash {$usernameSafe}
");

shell_exec("
    echo {$usernameSafe}:{$passwordSafe} | chpasswd
");

shell_exec("
    chage -E {$expiry} {$usernameSafe}
");

echo json_encode([

    'status' => true,

    'message' => 'User created'

]);
EOFAPI

        cat <<'EOFSERVICE' > /etc/systemd/system/userapi.service
[Unit]
Description=User API Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/api
ExecStart=/usr/bin/php -S 0.0.0.0:8888 -t /root/api
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOFSERVICE

        systemctl daemon-reload

        systemctl enable userapi >/dev/null 2>&1

        systemctl restart userapi

    }

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Installation Complete User API." | lolcat
}


install_ssh() {


echo -n -e "[\e[32mInfo\e[0m]"
echo -e " Installing OpenSSH." | lolcat

{

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Configuring OpenSSH." | lolcat

    cp /etc/ssh/sshd_config \
    /etc/ssh/sshd_config.bak 2>/dev/null

    cat <<'EOFSSH' > /etc/ssh/sshd_config


# OpenSSH Configuration

Port 22
Port 225
Port 2121

ListenAddress 0.0.0.0

Protocol 2

HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key

SyslogFacility AUTH
LogLevel INFO

PermitRootLogin yes
StrictModes yes

PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no

KbdInteractiveAuthentication no
ChallengeResponseAuthentication no

UsePAM yes

X11Forwarding yes
X11DisplayOffset 10

PrintMotd no
PrintLastLog yes

AcceptEnv LANG LC_*

Subsystem sftp internal-sftp

Banner /etc/banner

TCPKeepAlive yes
ClientAliveInterval 120
ClientAliveCountMax 2

UseDNS no
AllowTcpForwarding yes
VersionAddendum NontikweedScript
EOFSSH


    rm -f /etc/banner 2>/dev/null

    wget -qO /etc/banner \
    "https://raw.githubusercontent.com/nontikweed/blaire69/master/banner"

    chmod 644 /etc/banner

    cat <<'EOFPROFILE' > /etc/profile.d/blaire.sh


#!/bin/bash

clear

if command -v screenfetch >/dev/null 2>&1; then
screenfetch -p -A Arch
elif command -v neofetch >/dev/null 2>&1; then
neofetch
fi
EOFPROFILE

   sed -i 's/^password.*pam_script.so/#&/g' /etc/pam.d/common-password

    sed -i 's/ obscure//g' /etc/pam.d/common-password

    sed -i 's/use_authtok //g' /etc/pam.d/common-password

    chmod +x /etc/profile.d/blaire.sh

    rm -f /usr/local/bin/ssh-auth.sh 2>/dev/null

    sshd -t || exit 1

    systemctl enable ssh >/dev/null 2>&1
    systemctl restart ssh

}

echo -n -e "[\e[32mInfo\e[0m]"
echo -e " Installation Complete OpenSSH." | lolcat

reset


}


install_squid() {

    reset

    echo -e "[\e[32mInfo\e[0m] Installing SquidProxy."

    {

        echo -e "[\e[32mInfo\e[0m] Configuring Squid.."

        if [ -f /etc/squid/squid.conf ] && \
        [ ! -f /etc/squid/squid.conf.bak.popotworks ]; then

            cp /etc/squid/squid.conf \
            /etc/squid/squid.conf.bak.popotworks

        fi

        rm -rf /etc/squid/sq*

cat <<mySquid >/etc/squid/squid.conf
acl VPN dst $(wget -4qO- http://ipinfo.io/ip)/32
http_access allow VPN
http_access deny all

http_port 0.0.0.0:8080
http_port 0.0.0.0:8000

acl kweed src 0.0.0.0/0.0.0.0
no_cache deny kweed

dns_nameservers 1.1.1.1 1.0.0.1

visible_hostname localhost
mySquid

        echo -e "[\e[33mNotice\e[0m] Restarting Squid Service.."

        systemctl restart squid

        cd /etc || exit

        wget -q -O /usr/sbin/sshws \
        "https://raw.githubusercontent.com/nontikweed/aio/main/socks.py"

        wget -q -O /usr/sbin/openvpnws \
        "https://raw.githubusercontent.com/nontikweed/aio/main/openvpnws"

        dos2unix /usr/sbin/sshws >/dev/null 2>&1
        dos2unix /usr/sbin/openvpnws >/dev/null 2>&1

        chmod +x /usr/sbin/sshws >/dev/null 2>&1
        chmod +x /usr/sbin/openvpnws >/dev/null 2>&1

        sed -i '1s|#!/usr/bin/python|#!/usr/bin/python3|' /usr/sbin/sshws
        sed -i '1s|#!/usr/bin/python|#!/usr/bin/python3|' /usr/sbin/openvpnws

        2to3 -w /usr/sbin/sshws >/dev/null 2>&1
        2to3 -w /usr/sbin/openvpnws >/dev/null 2>&1

echo "[Unit]
Description=SSH Websocket
Documentation=https://google.com
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 -O /usr/sbin/sshws
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/sshws.service

echo "[Unit]
Description=OVPN Websocket
Documentation=https://google.com
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 -O /usr/sbin/openvpnws
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/openvpnws.service

        echo -e "[\e[33mNotice\e[0m] Reloading systemd daemon."

        systemctl daemon-reload >/dev/null 2>&1

        echo -e "[\e[33mNotice\e[0m] Enabling Websocket Services."

        systemctl enable sshws >/dev/null 2>&1
        systemctl enable openvpnws >/dev/null 2>&1

        echo -e "[\e[33mNotice\e[0m] Restarting Websocket Services."

        systemctl restart sshws >/dev/null 2>&1
        systemctl restart openvpnws >/dev/null 2>&1

    }

    echo -e "[\e[32mInfo\e[0m] Installation SquidProxy Complete."

    sleep 5
}

    install_openvpn2()
    {
    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing OpenVPN Server." | lolcat
    if [[ ! -e /etc/openvpn ]]; then
    mkdir -p /etc/openvpn
else
    if [ ! -e /etc/openvpn.bak.popotworks ]; then
        cp -a /etc/openvpn /etc/openvpn.bak.popotworks
    fi
    rm -f /etc/openvpn/*.conf
fi

    mkdir -p /etc/openvpn/server

    grep -q "DNSStubListener=no" /etc/systemd/resolved.conf || cat <<'EOF' >> /etc/systemd/resolved.conf
DNS=1.1.1.1
DNSStubListener=no
EOF


echo '# OpenVPN UDP Configuration

port 110
proto udp

dev tun
topology subnet

server 10.30.0.0 255.255.252.0

ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key

dh none

tls-server
tls-version-min 1.2

verify-client-cert none
username-as-common-name

auth-user-pass-verify /etc/openvpn/auth.sh via-env
script-security 3

data-ciphers AES-256-GCM:AES-128-GCM
data-ciphers-fallback AES-256-GCM

sndbuf 0
rcvbuf 0

keepalive 10 180

persist-key
persist-tun

client-to-client
duplicate-cn

push "redirect-gateway def1 bypass-dhcp"

push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"

push "persist-key"
push "persist-tun"

push "sndbuf 0"
push "rcvbuf 0"

user nobody
group nogroup

status /etc/openvpn/server/client.log 5
status-version 3

log /etc/openvpn/server/udpserver.log

ifconfig-pool-persist /etc/openvpn/server/udpip.txt

verb 3
max-clients 450' > /etc/openvpn/server/server_udp.conf

    echo '# OpenVPN TCP Configuration
port 1194
proto tcp

dev tun
topology subnet

server 10.20.0.0 255.255.252.0

ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key

dh none

tls-server
tls-version-min 1.2

verify-client-cert none
username-as-common-name

auth-user-pass-verify /etc/openvpn/auth.sh via-env
script-security 3

data-ciphers AES-256-GCM:AES-128-GCM
data-ciphers-fallback AES-256-GCM

keepalive 10 120

persist-key
persist-tun

sndbuf 0
rcvbuf 0

socket-flags TCP_NODELAY

client-to-client
duplicate-cn

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

push "persist-key"
push "persist-tun"

push "sndbuf 0"
push "rcvbuf 0"

user nobody
group nogroup

status /etc/openvpn/server/client.log 5
status-version 3

log /etc/openvpn/server/tcpserver.log

ifconfig-pool-persist /etc/openvpn/server/tcpip.txt

verb 3
max-clients 450' > /etc/openvpn/server/server_tcp.conf

    cat <<'EOF' > /etc/openvpn/server/ca.crt
-----BEGIN CERTIFICATE-----
MIICMTCCAZqgAwIBAgIUAaQBApMS2dYBqYPcA3Pa7cjjw7cwDQYJKoZIhvcNAQEL
BQAwDzENMAsGA1UEAwwES29iWjAeFw0yMDA3MjIyMjIzMzNaFw0zMDA3MjAyMjIz
MzNaMA8xDTALBgNVBAMMBEtvYlowgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGB
AMF46UVi2O5pZpddOPyzU2EyIrr8NrpXqs8BlYhUjxOcCrkMjFu2G9hk7QIZ4qO0
GWVZpPhYk5qWk+LxCsryrSoe0a5HaqIye8BFJmXV0k+O/3e6k06UGNii3gxBWQpF
7r/2CyQLus9OSpQPYszByBvtkwiBAo/V98jdpm+EVu6tAgMBAAGjgYkwgYYwHQYD
VR0OBBYEFGRJMm/+ZmLxV027kahdvSY+UaTSMEoGA1UdIwRDMEGAFGRJMm/+ZmLx
V027kahdvSY+UaTSoROkETAPMQ0wCwYDVQQDDARLb2JaghQBpAECkxLZ1gGpg9wD
c9rtyOPDtzAMBgNVHRMEBTADAQH/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsF
AAOBgQC0f8wb5hyEOEEX64l8QCNpyd/WLjoeE5bE+xnIcKE+XpEoDRZwugLoyQdc
HKa3aRHNqKpR7H696XJReo4+pocDeyj7rATbO5dZmSMNmMzbsjQeXux0XjwmZIHu
eDKMefDi0ZfiZmnU2njmTncyZKxv18Ikjws0Myc8PtAxy2qdcA==
-----END CERTIFICATE-----
EOF

    cat <<'EOF' > /etc/openvpn/server/server.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            40:26:da:91:18:2b:77:9c:85:6a:0c:bb:ca:90:53:fe
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=KobZ
        Validity
            Not Before: Jul 22 22:23:55 2020 GMT
            Not After : Jul 20 22:23:55 2030 GMT
        Subject: CN=server
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (1024 bit)
                Modulus:
                    00:ce:35:23:d8:5d:9f:b6:9b:cb:6a:89:e1:90:af:
                    42:df:5f:f8:bd:ad:a7:78:9a:ca:20:f0:3d:5b:d6:
                    c9:ef:4c:4a:99:96:c3:38:fd:59:b4:d7:65:ed:d4:
                    a7:fa:ab:03:e2:be:88:2f:ca:fc:90:dd:b0:b7:bc:
                    23:cb:83:ac:36:e2:01:57:69:64:b8:e1:9e:51:f0:
                    a6:9d:13:d9:92:6b:4d:04:a6:10:64:a3:3f:6b:ff:
                    fe:32:ac:91:63:c2:71:24:be:9e:76:4f:87:cc:3a:
                    03:a1:9e:48:3f:11:92:33:3b:19:16:9c:d0:5d:16:
                    ee:c1:42:67:99:47:66:67:67
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Subject Key Identifier: 
                6B:08:C0:64:10:71:A8:32:7F:0B:FE:1E:98:1F:BD:72:74:0F:C8:66
            X509v3 Authority Key Identifier: 
                keyid:64:49:32:6F:FE:66:62:F1:57:4D:BB:91:A8:5D:BD:26:3E:51:A4:D2
                DirName:/CN=KobZ
                serial:01:A4:01:02:93:12:D9:D6:01:A9:83:DC:03:73:DA:ED:C8:E3:C3:B7

            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Key Usage: 
                Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name: 
                DNS:server
    Signature Algorithm: sha256WithRSAEncryption
         a1:3e:ac:83:0b:e5:5d:ca:36:b7:d0:ab:d0:d9:73:66:d1:62:
         88:ce:3d:47:9e:08:0b:a0:5b:51:13:fc:7e:d7:6e:17:0e:bd:
         f5:d9:a9:d9:06:78:52:88:5a:e5:df:d3:32:22:4a:4b:08:6f:
         b1:22:80:4f:19:d1:5f:9d:b6:5a:17:f7:ad:70:a9:04:00:ff:
         fe:84:aa:e1:cb:0e:74:c0:1a:75:0b:3e:98:90:1d:22:ba:a4:
         7a:26:65:7d:d1:3b:5c:45:a1:77:22:ed:b6:6b:18:a3:c4:ee:
         3e:06:bb:0b:ec:12:ac:16:a5:50:b3:ed:46:43:87:72:fd:75:
         8c:38
-----BEGIN CERTIFICATE-----
MIICVDCCAb2gAwIBAgIQQCbakRgrd5yFagy7ypBT/jANBgkqhkiG9w0BAQsFADAP
MQ0wCwYDVQQDDARLb2JaMB4XDTIwMDcyMjIyMjM1NVoXDTMwMDcyMDIyMjM1NVow
ETEPMA0GA1UEAwwGc2VydmVyMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDO
NSPYXZ+2m8tqieGQr0LfX/i9rad4msog8D1b1snvTEqZlsM4/Vm012Xt1Kf6qwPi
vogvyvyQ3bC3vCPLg6w24gFXaWS44Z5R8KadE9mSa00EphBkoz9r//4yrJFjwnEk
vp52T4fMOgOhnkg/EZIzOxkWnNBdFu7BQmeZR2ZnZwIDAQABo4GuMIGrMAkGA1Ud
EwQCMAAwHQYDVR0OBBYEFGsIwGQQcagyfwv+HpgfvXJ0D8hmMEoGA1UdIwRDMEGA
FGRJMm/+ZmLxV027kahdvSY+UaTSoROkETAPMQ0wCwYDVQQDDARLb2JaghQBpAEC
kxLZ1gGpg9wDc9rtyOPDtzATBgNVHSUEDDAKBggrBgEFBQcDATALBgNVHQ8EBAMC
BaAwEQYDVR0RBAowCIIGc2VydmVyMA0GCSqGSIb3DQEBCwUAA4GBAKE+rIML5V3K
NrfQq9DZc2bRYojOPUeeCAugW1ET/H7XbhcOvfXZqdkGeFKIWuXf0zIiSksIb7Ei
gE8Z0V+dtloX961wqQQA//6EquHLDnTAGnULPpiQHSK6pHomZX3RO1xFoXci7bZr
GKPE7j4GuwvsEqwWpVCz7UZDh3L9dYw4
-----END CERTIFICATE-----
EOF

   cat <<'EOF' > /etc/openvpn/server/server.key
-----BEGIN PRIVATE KEY-----
MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAM41I9hdn7aby2qJ
4ZCvQt9f+L2tp3iayiDwPVvWye9MSpmWwzj9WbTXZe3Up/qrA+K+iC/K/JDdsLe8
I8uDrDbiAVdpZLjhnlHwpp0T2ZJrTQSmEGSjP2v//jKskWPCcSS+nnZPh8w6A6Ge
SD8RkjM7GRac0F0W7sFCZ5lHZmdnAgMBAAECgYAFNrC+UresDUpaWjwaxWOidDG8
0fwu/3Lm3Ewg21BlvX8RXQ94jGdNPDj2h27r1pEVlY2p767tFr3WF2qsRZsACJpI
qO1BaSbmhek6H++Fw3M4Y/YY+JD+t1eEBjJMa+DR5i8Vx3AE8XOdTXmkl/xK4jaB
EmLYA7POyK+xaDCeEQJBAPJadiYd3k9OeOaOMIX+StCs9OIMniRz+090AJZK4CMd
jiOJv0mbRy945D/TkcqoFhhScrke9qhgZbgFj11VbDkCQQDZ0aKBPiZdvDMjx8WE
y7jaltEDINTCxzmjEBZSeqNr14/2PG0X4GkBL6AAOLjEYgXiIvwfpoYE6IIWl3re
ebCfAkAHxPimrixzVGux0HsjwIw7dl//YzIqrwEugeSG7O2Ukpz87KySOoUks3Z1
yV2SJqNWskX1Q1Xa/gQkyyDWeCeZAkAbyDBI+ctc8082hhl8WZunTcs08fARM+X3
FWszc+76J1F2X7iubfIWs6Ndw95VNgd4E2xDATNg1uMYzJNgYvcTAkBoE8o3rKkp
em2n0WtGh6uXI9IC29tTQGr3jtxLckN/l9KsJ4gabbeKNoes74zdena1tRdfGqUG
JQbf7qSE3mg2
-----END PRIVATE KEY-----
EOF

    cat <<'EOF' > /etc/openvpn/server/dh.pem
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA14VaIGRxzoAjo28NiVCBAJNK9c49hweMSg1HcLo3eoudjZ82cqf9
BYkCBhfWFIiOu0DbUJrbEJGlmeoZ4pmOE2153GpIkrobRmpZZykaB2h5ymXEGEPV
nRmve2J5UqJ/VQA6GUskIlGthc1370MgsZ/HBaoJSCa1zqGRB92D1R2TiK2oBH5h
+tiW6Y7sOz3QXAV5tfCksqw3gZalb4Ol6hVfTPgeEH2XrgOgG4Zxpajn0KCJVUSF
wd7H6pMnFzU3p6TQoxr9myntkPoo+0HHuyW2GE8sbnZPLOvurXcvchkwz+vBX4Rl
bwprMqHounF1ZATclFUdzIxukXtXW7NeMwIBAg==
-----END DH PARAMETERS-----
EOF

    chmod 644 /etc/openvpn/server/*
    chmod 600 /etc/openvpn/server/server.key
    chmod 755 /etc/openvpn/
    cat <<'EOF' > /etc/openvpn/auth.sh
#!/bin/bash

response=$(curl --connect-timeout 10 --max-time 15 -s -X POST \
-H "X-API-KEY: xebecc" \
-d "username=$username" \
-d "password=$password" \
https://walanakongmaisip.info/api/auth)

if [[ "$response" == "OK" ]]; then
    exit 0
else
    exit 1
fi
EOF

chmod +x /etc/openvpn/auth.sh
chmod 755 /etc/openvpn/server_udp.conf
chmod 755 /etc/openvpn/server_tcp.conf

modprobe tun
mkdir -p /dev/net

echo -n -e "[\e[33mNotice\e[0m]" && echo -e " Enabling and starting OpenVPN UDP." | lolcat
systemctl daemon-reload >/dev/null 2>&1
systemctl enable openvpn-server@server_udp.service >/dev/null 2>&1
systemctl start openvpn-server@server_udp.service >/dev/null 2>&1

echo -n -e "[\e[33mNotice\e[0m]" && echo -e " Enabling and starting OpenVPN TCP." | lolcat
systemctl enable openvpn-server@server_tcp.service >/dev/null 2>&1
systemctl start openvpn-server@server_tcp.service >/dev/null 2>&1


echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing OpenVPN Complete." | lolcat
reset
}

install_openvpn1()
    {
    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing OpenVPN Server V1." | lolcat
    if [[ ! -e /etc/openvpn ]]; then
    mkdir -p /etc/openvpn
else
    if [ ! -e /etc/openvpn.bak.popotworks ]; then
        cp -a /etc/openvpn /etc/openvpn.bak.popotworks
    fi
    rm -f /etc/openvpn/*.conf
fi

    mkdir -p /etc/openvpn/server

    grep -q "DNSStubListener=no" /etc/systemd/resolved.conf || cat <<'EOF' >> /etc/systemd/resolved.conf
DNS=1.1.1.1
DNSStubListener=no
EOF


echo '# OpenVPN UDP Configuration

port 110
proto udp

dev tun
topology subnet

server 10.30.0.0 255.255.252.0

ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key

dh /etc/openvpn/server/dh.pem

tls-server
tls-version-min 1.2

verify-client-cert none
username-as-common-name

auth-user-pass-verify /etc/openvpn/auth.sh via-env
script-security 3

data-ciphers AES-256-GCM:AES-128-GCM
data-ciphers-fallback AES-256-GCM

sndbuf 0
rcvbuf 0

keepalive 10 180

persist-key
persist-tun

client-to-client
duplicate-cn

push "redirect-gateway def1 bypass-dhcp"

push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"

push "persist-key"
push "persist-tun"

push "sndbuf 0"
push "rcvbuf 0"

user nobody
group nogroup

status /etc/openvpn/server/client.log 5
status-version 3

log /etc/openvpn/server/udpserver.log

ifconfig-pool-persist /etc/openvpn/server/udpip.txt

verb 3
max-clients 450' > /etc/openvpn/server/server_udp.conf

    echo '# OpenVPN Nontikweed Configuration
port 1194
proto tcp

dev tun
topology subnet

server 10.20.0.0 255.255.252.0

ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key

dh /etc/openvpn/server/dh.pem

tls-server
tls-version-min 1.2

verify-client-cert none
username-as-common-name

auth-user-pass-verify /etc/openvpn/auth.sh via-env
script-security 3

data-ciphers AES-256-GCM:AES-128-GCM
data-ciphers-fallback AES-256-GCM

keepalive 10 120

persist-key
persist-tun

sndbuf 0
rcvbuf 0

socket-flags TCP_NODELAY

client-to-client
duplicate-cn

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

push "persist-key"
push "persist-tun"

push "sndbuf 0"
push "rcvbuf 0"

user nobody
group nogroup

     5
status-version 3

log /etc/openvpn/server/tcpserver.log

ifconfig-pool-persist /etc/openvpn/server/tcpip.txt

verb 3
max-clients 450' > /etc/openvpn/server/server_tcp.conf

cat << EOF > /etc/openvpn/server/ca.crt
-----BEGIN CERTIFICATE-----
MIIDSDCCAjCgAwIBAgIUXKh6tJLj3JobFaM6r18ylFWsGRswDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAwwKbm9udGlrd2VlZDAeFw0yMzEyMTMwODM4MzFaFw0zMzEy
MTAwODM4MzFaMBUxEzARBgNVBAMMCm5vbnRpa3dlZWQwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQCuaWqJaxsrb77AKu9/yUbERQ83yAG7dp3ZGKl/B3k0
lrS66nDvFLt7h2F9ST1RRm50B1YJsHjrl/f+taI6sapIyoZnLu0WrXaJld8Rgf0h
OA6oNEix1Godah/KsVfDpGbiTBjpUin+/qf6xBAjKjNeP7jqdIfEdtFjSS9X4Ymz
W23Nv0XyPsWKy5uefIxnXjUDkKiRxveSazdnOKLsLixsR/9FQvfr3u3DO9Xujudv
5l96Ccae2XwusiE7decjGboqaA6ci45IU9eZiSK8tD+BIBQEWLrbDMIzdirEAvgn
Sl/vUHUw/tdA0Du5GYHYNfPVNkGI4N3HSgRjWDTEgmR7AgMBAAGjgY8wgYwwHQYD
VR0OBBYEFBk6fQhlvyX3waYYaqNk14mHP86vMFAGA1UdIwRJMEeAFBk6fQhlvyX3
waYYaqNk14mHP86voRmkFzAVMRMwEQYDVQQDDApub250aWt3ZWVkghRcqHq0kuPc
mhsVozqvXzKUVawZGzAMBgNVHRMEBTADAQH/MAsGA1UdDwQEAwIBBjANBgkqhkiG
9w0BAQsFAAOCAQEAMFIiy0BEKieAVya05b8kWleoKX4WxehX2/2TSvqQaFPch2Qj
gsU2Xaee90lMxkLvciY2zjq1RMmzdd3p/t9HvnoyBMbcU2R1SEjWAoo5T3nEEkXo
n8/Rgqhxy1N8OYMd4VaqwclzwTzN2lZ2CHzxHrIk1ivg3f9pv0eRFJ6QfTrIpQ0M
KfkFbMuwnH9BQJSb93spLiU2nY+xgU4dEe6VgFjYDbOcyRN7E5uE/2ottieMLkDZ
PHxw8CG5fM+iSIm29HmnEdi7oxEf17gcM1HegUY89G9V15EE/kJNOXBF/63rMRSl
86Qd/8HD6QztaOCDf1EuyJ8DdVlQQmeEtftdbg==
-----END CERTIFICATE-----
EOF

    cat << EOF > /etc/openvpn/server/server.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            b4:0b:fe:7c:30:e5:9b:3a:a4:5f:c7:d9:a2:61:45:94
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=nontikweed
        Validity
            Not Before: Dec 13 08:38:55 2023 GMT
            Not After : Nov 27 08:38:55 2026 GMT
        Subject: CN=nontikweed
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:a3:85:82:57:d8:b2:d7:4c:17:bd:f4:56:f6:4d:
                    a3:1c:a2:cc:78:64:8a:d2:94:9a:48:50:75:2a:c7:
                    05:ff:36:e2:a3:48:6d:41:1d:c1:79:e4:78:f2:cb:
                    4d:e0:8f:b3:ed:6b:25:3d:00:1a:05:c9:e5:e5:7a:
                    0d:5b:7f:b4:28:f4:49:20:21:3a:b0:b9:b4:e2:6d:
                    bd:d0:c6:94:ff:6f:8f:04:51:9b:45:fd:c8:46:ca:
                    7c:55:af:89:2e:13:50:5a:47:e2:9a:5f:a1:d0:8f:
                    9a:2d:b0:c7:5c:a7:4a:74:64:64:22:20:9e:2d:b8:
                    61:18:35:b5:e9:3b:a8:77:b5:0a:09:de:e0:e1:10:
                    5b:1d:e0:bf:74:d6:73:3b:7a:e7:a9:6f:f2:74:91:
                    b3:6f:42:14:59:4f:63:ec:b3:59:01:11:82:1c:57:
                    fc:c9:52:c8:e8:f3:ab:c7:77:a4:fc:ad:f8:5b:44:
                    eb:fa:29:56:ea:2e:c6:c8:e9:79:ac:51:42:9f:c5:
                    dd:b5:d8:f0:cf:91:e3:6f:3f:5f:92:7d:6a:f4:3a:
                    1c:3b:7a:6f:a3:5c:e7:0d:f1:64:0d:27:77:7e:23:
                    c0:3f:12:1d:cd:c0:1e:b1:18:a3:e9:d8:fc:34:fc:
                    38:f4:17:78:e6:69:e8:a4:0d:48:a8:31:df:7a:86:
                    c1:9f
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Subject Key Identifier: 
                21:D3:88:DE:9C:B0:8D:C8:07:4F:C4:50:54:E1:4A:7D:CF:62:5B:8F
            X509v3 Authority Key Identifier: 
                keyid:19:3A:7D:08:65:BF:25:F7:C1:A6:18:6A:A3:64:D7:89:87:3F:CE:AF
                DirName:/CN=nontikweed
                serial:5C:A8:7A:B4:92:E3:DC:9A:1B:15:A3:3A:AF:5F:32:94:55:AC:19:1B

            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Key Usage: 
                Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name: 
                DNS:nontikweed
    Signature Algorithm: sha256WithRSAEncryption
         73:99:9c:8d:76:2a:08:dd:01:d5:ca:34:6a:24:f2:0c:f4:9e:
         4c:68:69:90:28:7e:49:b2:e2:4b:ef:c3:e4:2a:0e:65:44:ea:
         0b:4a:04:87:61:c7:4a:a5:ea:a1:ab:0d:d8:3c:b4:af:26:9c:
         c2:d7:15:66:cd:6e:f3:fb:01:be:f1:18:1d:69:47:31:67:fe:
         ab:50:f7:9a:7d:d4:0e:68:77:83:84:41:ac:66:f4:79:ba:fd:
         62:c2:a4:55:a4:5b:17:53:0e:e9:e8:b1:2f:91:dd:d7:12:be:
         a1:7e:ea:13:13:58:53:3d:04:75:14:2d:6a:f5:8b:e7:b1:b9:
         19:e3:06:7f:ae:61:e0:d5:8b:38:a7:a6:07:e3:38:97:18:2e:
         42:80:e8:ed:7d:4c:9c:69:a3:75:b2:fb:a3:c8:aa:8c:9f:64:
         7e:88:90:81:c4:a9:b8:27:b1:d1:16:b7:e5:84:c2:56:9e:71:
         83:9b:78:0b:65:78:04:78:30:50:48:6f:e8:b9:30:1a:ce:95:
         47:24:1c:82:3b:7d:c7:11:d7:b0:d8:0f:2e:45:eb:e0:4e:bc:
         30:89:e0:0f:62:30:4d:a7:e5:83:f2:63:ca:e0:e8:a8:58:4f:
         cd:e1:b5:05:00:f6:e4:b6:1c:c2:3d:bd:b7:2f:08:da:49:61:
         07:dc:d9:38
-----BEGIN CERTIFICATE-----
MIIDbjCCAlagAwIBAgIRALQL/nww5Zs6pF/H2aJhRZQwDQYJKoZIhvcNAQELBQAw
FTETMBEGA1UEAwwKbm9udGlrd2VlZDAeFw0yMzEyMTMwODM4NTVaFw0yNjExMjcw
ODM4NTVaMBUxEzARBgNVBAMMCm5vbnRpa3dlZWQwggEiMA0GCSqGSIb3DQEBAQUA
A4IBDwAwggEKAoIBAQCjhYJX2LLXTBe99Fb2TaMcosx4ZIrSlJpIUHUqxwX/NuKj
SG1BHcF55Hjyy03gj7PtayU9ABoFyeXleg1bf7Qo9EkgITqwubTibb3QxpT/b48E
UZtF/chGynxVr4kuE1BaR+KaX6HQj5otsMdcp0p0ZGQiIJ4tuGEYNbXpO6h3tQoJ
3uDhEFsd4L901nM7euepb/J0kbNvQhRZT2Pss1kBEYIcV/zJUsjo86vHd6T8rfhb
ROv6KVbqLsbI6XmsUUKfxd212PDPkeNvP1+SfWr0Ohw7em+jXOcN8WQNJ3d+I8A/
Eh3NwB6xGKPp2Pw0/Dj0F3jmaeikDUioMd96hsGfAgMBAAGjgbgwgbUwCQYDVR0T
BAIwADAdBgNVHQ4EFgQUIdOI3pywjcgHT8RQVOFKfc9iW48wUAYDVR0jBEkwR4AU
GTp9CGW/JffBphhqo2TXiYc/zq+hGaQXMBUxEzARBgNVBAMMCm5vbnRpa3dlZWSC
FFyoerSS49yaGxWjOq9fMpRVrBkbMBMGA1UdJQQMMAoGCCsGAQUFBwMBMAsGA1Ud
DwQEAwIFoDAVBgNVHREEDjAMggpub250aWt3ZWVkMA0GCSqGSIb3DQEBCwUAA4IB
AQBzmZyNdioI3QHVyjRqJPIM9J5MaGmQKH5JsuJL78PkKg5lROoLSgSHYcdKpeqh
qw3YPLSvJpzC1xVmzW7z+wG+8RgdaUcxZ/6rUPeafdQOaHeDhEGsZvR5uv1iwqRV
pFsXUw7p6LEvkd3XEr6hfuoTE1hTPQR1FC1q9YvnsbkZ4wZ/rmHg1Ys4p6YH4ziX
GC5CgOjtfUycaaN1svujyKqMn2R+iJCBxKm4J7HRFrflhMJWnnGDm3gLZXgEeDBQ
SG/ouTAazpVHJByCO33HEdew2A8uRevgTrwwieAPYjBNp+WD8mPK4OioWE/N4bUF
APbkthzCPb23LwjaSWEH3Nk4
-----END CERTIFICATE-----
EOF

cat << EOF > /etc/openvpn/server/server.key
-----BEGIN PRIVATE KEY-----
MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCjhYJX2LLXTBe9
9Fb2TaMcosx4ZIrSlJpIUHUqxwX/NuKjSG1BHcF55Hjyy03gj7PtayU9ABoFyeXl
eg1bf7Qo9EkgITqwubTibb3QxpT/b48EUZtF/chGynxVr4kuE1BaR+KaX6HQj5ot
sMdcp0p0ZGQiIJ4tuGEYNbXpO6h3tQoJ3uDhEFsd4L901nM7euepb/J0kbNvQhRZ
T2Pss1kBEYIcV/zJUsjo86vHd6T8rfhbROv6KVbqLsbI6XmsUUKfxd212PDPkeNv
P1+SfWr0Ohw7em+jXOcN8WQNJ3d+I8A/Eh3NwB6xGKPp2Pw0/Dj0F3jmaeikDUio
Md96hsGfAgMBAAECggEACDgHqx6rLoMWlmeXj12rmx7bpBl5mMf7UTMqEHJcbM13
armTNDioptXC9oEdcvIGGyLNhllg9XWGZphR3411orFUk5bX+lX7L35QkhPJHWWg
DJmFcmklDdnTkgL2pCg4W7FNRHEWEwOEvlMqUg/egCcjmUuGZ8nip3Lbp9Nlzk5o
kKJvk6pXOlaQ9nKTZZmguaz1aDbBl5rF94Dx360KQgEN2+C45KLuk96sdCgiEOYg
WwXy3yZoUvtLOJZ86hIXDQXql+dViYDjjiwGjtMguFoK34Omr75r1A5KN5psgMJm
so1CgyLyBT1x6vt1sJH1Ob78ij8UfOD9UMN1wO7xsQKBgQDXTpNpJBnT/jJfOx8n
CKdnawHlJRQXZ1i6dOOTZS8lRptbzHslm3otnHHTcPQFnfEkrX55WMEj1w0qN6yZ
N1KfHG7APaSxEVj3EkuP0KOcyhLVL9CIHuNVk6nDZkb4oN9d7sPRsrHrCSYKeNKS
7Q/Lf+KxwDHLnHCPNYiaJ8hclQKBgQDCbVgyaBo1UAmDvbcngJ54/hrPgxUEdGBK
o2D7iU+D2eml2dfOhk0+SXTrPILT+2Z2o83C55BXpjOgTpRE+r7S1X1huBfZF2iP
LPSv+4qRvcGvEMCVB2t0/wLnicLMpRXLx4bys0SDiOcB3Cri0/9APuAzFId7sTtA
ihJN124kYwKBgH8ez34WaIF35fnACGadf2laDqZiO/iNdh+wf+U4qptRksyicFsF
7x8a7UGvwQPH+uZy4Od4daBZilZQxME5nrh+qw0p2CELYwGNdbuVreQWkwP31SFp
S0PtiR/rNR/6q6bkIA2hedaRcjpgl8NT4C2AdjIIjd3voa2MJ/kMYAn5AoGAW2Es
/LP07W2qqyJ1fLl0wgUb8L/5FtjjkPDs2gwVNTEsIWkbhtOUZlv7+bu8+YjFBanD
QYG4U5mn1gZYpXr8SPdSMKVnf/8Cg5hrgHLHE+yNpYxIF0MffCOG5+/VgH1umxIy
GMusve2QNU2XUni1FSr4EMnrS3VnFdRO+grwl2UCgYBg8zUOBeqYrAvM/6QRYuKs
0doZj3MYvV+6mQbgdfCBcnmhl/TSlCxw0T8uUpAe4qEbkF4+q8d5qfV8x8VsFaat
EiwKG+74Jbm+7BZlf7srtZLrkq+ypHHNpVMcUTKOyvWF10evXQ+KrZt4mlhzrBxI
V3GMjpctESgBNqoxDWpH0w==
-----END PRIVATE KEY-----
EOF

cat << EOF > /etc/openvpn/server/dh.pem
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAhib7LHZ4gotyERBsW33c0QpZ3cH/DU4vhzPZHPWyDA+auoSmEQxw
if0Py+qM3PU/MM8Vid9TbUJJ09qOPan6hy36d9yMfp/NDrnwofpu/hSgxu+sVx+j
1VPO2KqAsbCfslpYV6JYaZxa9oLMA7vweCv+XyFphAnHoGoRGodKHLxOyymkRIAb
6KzZJyfqGj2Foy36EHp2t+w8aQZN8l3m29Zx19H/sPCURDKrF7ii3DHR8F6b8vGB
rEzoyg1qv+Hl9Jm/oneZ4FZKxcXhRy7cpQWsve01iboBAsrcVx1OI4KQlbpcEtzf
n/406HSgtsB8yWPDNga/N7OONk8aTJtbWwIBAg==
-----END DH PARAMETERS-----
EOF

    chmod 644 /etc/openvpn/server/*
    chmod 600 /etc/openvpn/server/server.key
    chmod 755 /etc/openvpn/
    cat <<'EOF' > /etc/openvpn/auth.sh
#!/bin/bash

response=$(curl --connect-timeout 10 --max-time 15 -s -X POST \
-H "X-API-KEY: xebecc" \
-d "username=$username" \
-d "password=$password" \
https://walanakongmaisip.info/api/auth)

if [[ "$response" == "OK" ]]; then
    exit 0
else
    exit 1
fi
EOF

chmod +x /etc/openvpn/auth.sh
chmod 644 /etc/openvpn/server/server_udp.conf
chmod 644 /etc/openvpn/server/server_tcp.conf

modprobe tun
mkdir -p /dev/net

echo -n -e "[\e[33mNotice\e[0m]" && echo -e " Enabling and starting OpenVPN UDP." | lolcat
systemctl daemon-reload >/dev/null 2>&1
systemctl enable openvpn-server@server_udp.service >/dev/null 2>&1
systemctl start openvpn-server@server_udp.service >/dev/null 2>&1

echo -n -e "[\e[33mNotice\e[0m]" && echo -e " Enabling and starting OpenVPN TCP." | lolcat
systemctl enable openvpn-server@server_tcp.service >/dev/null 2>&1
systemctl start openvpn-server@server_tcp.service >/dev/null 2>&1


echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing OpenVPN Complete." | lolcat
reset
}


   install_firewall_kvm () {

    reset
    echo -e "[Info] Installing Iptables." | lolcat

    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || \
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    grep -q "^net.ipv4.conf.all.rp_filter=0" /etc/sysctl.conf || \
    echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf

    grep -q "^net.ipv4.conf.${server_interface}.rp_filter=0" /etc/sysctl.conf || \
    echo "net.ipv4.conf.${server_interface}.rp_filter=0" >> /etc/sysctl.conf

    sysctl -p >/dev/null 2>&1
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1

    # FORCE IPTABLES LEGACY
    update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null 2>&1
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >/dev/null 2>&1

    # RESET IPTABLES
    iptables -t nat -F
    iptables -F
    iptables -X

    # DEFAULT POLICIES
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT

    # ACCEPT ESTABLISHED
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

    # TUN INTERFACES
    iptables -A FORWARD -i tun0 -j ACCEPT
    iptables -A FORWARD -o tun0 -j ACCEPT

    iptables -A FORWARD -i tun1 -j ACCEPT
    iptables -A FORWARD -o tun1 -j ACCEPT

    # UDPGW → HYSTERIA
    iptables -t nat -A PREROUTING -i "$server_interface" -p udp --dport 20000:50000 -j DNAT --to-destination :5666

    iptables -t nat -A PREROUTING -i "$server_interface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667

    # OPENVPN TCP NAT
    iptables -t nat -A POSTROUTING -s 10.20.0.0/22 -o "$server_interface" -j MASQUERADE

    # OPENVPN UDP NAT
    iptables -t nat -A POSTROUTING -s 10.30.0.0/22 -o "$server_interface" -j MASQUERADE

    # OPENVPN TCP FORWARD
    iptables -A FORWARD -s 10.20.0.0/22 -j ACCEPT
    iptables -A FORWARD -d 10.20.0.0/22 -j ACCEPT

    # OPENVPN UDP FORWARD
    iptables -A FORWARD -s 10.30.0.0/22 -j ACCEPT
    iptables -A FORWARD -d 10.30.0.0/22 -j ACCEPT

    # FULL TUN INTERNET ACCESS

    iptables -A FORWARD -i tun0 -o "$server_interface" -j ACCEPT
    iptables -A FORWARD -i "$server_interface" -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT

    iptables -A FORWARD -i tun1 -o "$server_interface" -j ACCEPT
    iptables -A FORWARD -i "$server_interface" -o tun1 -m state --state RELATED,ESTABLISHED -j ACCEPT


    # DNS REDIRECT
    iptables -t nat -A PREROUTING -i "$server_interface" -p udp --dport 53 -j REDIRECT --to-ports 5300

    iptables -A INPUT -p udp --dport 5300 -j ACCEPT

    # BADVPN
    iptables -t nat -A PREROUTING -d "$server_ip" -p udp --dport 5300 -j REDIRECT --to-ports 2121

    iptables -A FORWARD -p udp --dport 2121 -j ACCEPT

    # MSS FIX
    iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
    -j TCPMSS --clamp-mss-to-pmtu

    # SAVE RULES
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4

    reset
    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Installing Iptables Complete." | lolcat
    reset
}


   install_stunnel() {
    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing Stunnel." | lolcat

    {
        apt install -y stunnel4 nginx >/dev/null 2>&1

        systemctl enable nginx >/dev/null 2>&1
        systemctl restart nginx >/dev/null 2>&1

        if command -v stunnel4 >/dev/null 2>&1; then
            StunnelDir='stunnel4'
        else
            StunnelDir='stunnel'
        fi

        mkdir -p /etc/stunnel

        echo -e "[\e[32mInfo\e[0m] Configuring Stunnel.."

        cat <<'EOFStunnel1' > "/etc/default/$StunnelDir"
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/banner"
PPP_RESTART=0
# RLIMITS="-n 4096 -d unlimited"
RLIMITS=""
EOFStunnel1

        rm -f /etc/stunnel/*.conf

        echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Cloning Stunnel.pem." | lolcat

        openssl req -new -x509 -days 9999 -nodes \
        -subj "/C=PH/ST=Nontikweed/L=DEV/O=Nethub/CN=Blaire VPN" \
        -out /etc/stunnel/stunnel.pem \
        -keyout /etc/stunnel/stunnel.pem >/dev/null 2>&1

        chmod 600 /etc/stunnel/stunnel.pem

        echo -e "[\e[32mInfo\e[0m] Creating Stunnel server config.."

        cat <<'EOFStunnel3' > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
TIMEOUTclose = 0

[websocket]
accept = 443
connect = 127.0.0.1:80

[dropbear]
accept = 446
connect = 127.0.0.1:550

[openssh]
accept = 445
connect = 127.0.0.1:225

[openvpn]
accept = 587
connect = 127.0.0.1:1194
EOFStunnel3

        echo -n -e "[\e[33mNotice\e[0m]" && echo -e " Restarting Stunnel." | lolcat

        systemctl enable stunnel4 >/dev/null 2>&1 || \
        systemctl enable stunnel >/dev/null 2>&1

        systemctl restart stunnel4 >/dev/null 2>&1 || \
        systemctl restart stunnel >/dev/null 2>&1
    }

    reset
    echo -e "[\e[32mInfo\e[0m] Installing Stunnel Complete."
    reset
}

    install_badvpn(){
    reset
    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing BadVPN." | lolcat
    {
    wget -q -O /usr/bin/badvpn-udpgw  "https://raw.githubusercontent.com/nontikweed/aio/main/badvpn-udpgw64"
    chmod +x /usr/bin/badvpn-udpgw
    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Configuring BadVPN." | lolcat
    echo "[Unit]
    Description=BadVPN UDP Gateway by Nontikweed

    [Service]
    ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 10000 --max-connections-for-client 10 --client-socket-sndbuf 10000
    Restart=always
    User=nobody
    Group=nogroup

    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/badvpn.service

            echo -e "[\e[33mNotice\e[0m] Reloading systemd daemon."
            systemctl daemon-reload > /dev/null 2>&1

            echo -e "[\e[33mNotice\e[0m] Enabling BadVPN Service..."
            sudo systemctl enable badvpn > /dev/null 2>&1

            echo -e "[\e[33mNotice\e[0m] Starting BadVPN Service..."
            sudo systemctl start badvpn.service > /dev/null 2>&1

            echo -e "[\e[33mNotice\e[0m] Checking the status of BadVPN Service."
            if sudo systemctl is-active badvpn.service &> /dev/null; then
            echo -e "[\e[33mNotice\e[0m] BadVPN service is running."
            else
            echo -e "[\e[33mNotice\e[0m] BadVPN service is not running."
            fi
    }
    reset
    echo -e "[\e[32mInfo\e[0m] Installing BadVPN Complete."
    reset
    }

    install_slowdns() {
        reset
        echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing SlowDNS." | lolcat
        {  

            echo -e "[\e[32mInfo\e[0m] Creating SlowDNS directory."
            mkdir -p -m 755 /etc/slowdns
            cd /etc/slowdns
            curl -s -o dns.sh "https://raw.githubusercontent.com/nontikweed/aio/main/autodns" && chmod +x dns.sh && ./dns.sh  
            echo -e "[\e[32mInfo\e[0m] Downloading SlowDNS Files."
            wget -O /etc/slowdns/slowdns https://raw.githubusercontent.com/nontikweed/aio/main/slowdns > /dev/null 2>&1
            echo '39a475f6c980d39007ae00e1c8f922b5eb1bd88b33071919a735cdafb5ab2389' >> server.key
            echo '15f2caeefeb017bab2ca8f5c72e3d3719333f3f56a8ca2078480109772f6406c' >> server.pub
            sudo chmod +x /etc/slowdns/slowdns

            NSNAME="$(cat /etc/slowdns/ns.txt)"
            echo "Configuring SlowDNS service..."
            echo "[Unit]
    Description=Server SlowDNS By Nontikweed
    Documentation=https://nethubvpn.net
    After=network.target nss-lookup.target

    [Service]
    Type=simple
    User=root
    CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
    AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
    NoNewPrivileges=true
    ExecStart=/etc/slowdns/slowdns -udp :5300 -privkey-file /etc/slowdns/server.key $NSNAME 127.0.0.1:2121
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target" > /etc/systemd/system/slowdns.service

            echo -e "[\e[33mNotice\e[0m] Reloading systemd daemon."
            systemctl daemon-reload > /dev/null 2>&1 

            echo -e "[\e[33mNotice\e[0m] Enabling SlowDNS service..."
            sudo systemctl enable slowdns > /dev/null 2>&1

            echo -e "[\e[33mNotice\e[0m] Starting SlowDNS service..."
            sudo systemctl start slowdns.service > /dev/null 2>&1

            echo -e "[\e[33mNotice\e[0m] Checking the status of SlowDNS service..."
            if sudo systemctl is-active slowdns.service &> /dev/null; then
            echo -e "[\e[33mNotice\e[0m] SlowDNS service is running."
            else
            echo -e "[\e[33mNotice\e[0m] SlowDNS service is not running."
            fi
        }
        reset
        echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing SlowDNS Complete." | lolcat
        reset
    }

install_hysteria() {

    reset

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Installing Hysteria." | lolcat

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Downloading Hysteria." | lolcat

    wget -N --no-check-certificate \
    -q -O ~/install_server.sh \
    https://raw.githubusercontent.com/nontikweed/blaire69/master/install_server.sh

    chmod +x ~/install_server.sh

    ~/install_server.sh --version v1.3.5

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Configuring Hysteria." | lolcat

    mkdir -p /etc/hysteria

    openssl req -new \
    -newkey rsa:4096 \
    -days 365 \
    -nodes \
    -x509 \
    -subj "/C=PH/ST=Bulacan/L=Central Luzon/O=Nethub VPN/OU=IT Department/CN=Nontikweed" \
    -keyout /etc/hysteria/hysteria.key \
    -out /etc/hysteria/hysteria.crt >/dev/null 2>&1

    OBFS="${HY2_OBFS:-nontikweed}"

    cat <<EOF > /etc/hysteria/config.json
{
    "listen": ":5666",
    "cert": "/etc/hysteria/hysteria.crt",
    "key": "/etc/hysteria/hysteria.key",

    "up_mbps": 100,
    "down_mbps": 100,

    "disable_udp": false,

    "obfs": "${OBFS}",

    "auth": {
        "mode": "passwords",
        "config": [
            "blaire"
        ]
    }
}
EOF

    chmod 644 /etc/hysteria/config.json
    chmod 644 /etc/hysteria/hysteria.crt
    chmod 644 /etc/hysteria/hysteria.key

    chown root:root /etc/hysteria/config.json 
    chown root:root /etc/hysteria/hysteria.crt 
    chown root:root /etc/hysteria/hysteria.key

    sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1
    sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Reloading Systemd." | lolcat

    systemctl daemon-reexec >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Enabling Hysteria Server." | lolcat

    systemctl enable hysteria-server.service >/dev/null 2>&1

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Restarting Hysteria Server." | lolcat

    systemctl restart hysteria-server.service >/dev/null 2>&1

    sleep 2

    if systemctl is-active --quiet hysteria-server.service; then

        echo -n -e "[\e[32mInfo\e[0m]"
        echo -e " Hysteria is running successfully." | lolcat

    else

        echo -n -e "[\e[31mError\e[0m]"
        echo -e " Hysteria failed to start." | lolcat

        journalctl -u hysteria-server.service \
        -n 20 --no-pager
    fi

    echo -n -e "[\e[32mInfo\e[0m]"
    echo -e " Hysteria installation complete." | lolcat

    reset
}

  install_hysteria2() {

    reset
    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing Hysteria2." | lolcat

    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Downloading Hysteria2." | lolcat

    bash <(curl -fsSL https://get.hy2.sh/)

    mkdir -p /etc/hysteria

    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Generating Certificate." | lolcat

    openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout /etc/hysteria/server.key \
    -out /etc/hysteria/server.crt \
    -days 3650 \
    -subj "/C=PH/ST=Manila/L=Manila/O=Nontikweed/OU=VPN/CN=bing.com" >/dev/null 2>&1

    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Creating Config." | lolcat

cat <<EOF > /etc/hysteria/config.yaml
listen: :5666

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: blaire

obfs:
  type: salamander
  salamander:
    password: ${HY2_OBFS:-nontikweed}

bandwidth:
  up: 100 mbps
  down: 100 mbps

ignoreClientBandwidth: false

quic:
  initStreamReceiveWindow: 26843545
  maxStreamReceiveWindow: 26843545
  initConnReceiveWindow: 67108864
  maxConnReceiveWindow: 67108864

masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
EOF

    chmod 755 /etc/hysteria/config.yaml
    chmod 755 /etc/hysteria/server.key
    chmod 755 /etc/hysteria/server.crt

    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Enabling Hysteria2." | lolcat

    systemctl enable hysteria-server.service >/dev/null 2>&1

    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Restarting Hysteria2." | lolcat

    systemctl restart hysteria-server.service >/dev/null 2>&1

    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Hysteria2 Installation Complete." | lolcat
}

    start_service () {
    reset
    {
    rm -rf /root/*.sh
    rm -rf /root/*.sh.x
    rm -rf /etc/slowdns/*.sh
    echo -e ""
    echo -e "\033[0;35m═══════════════════════════════════════════════\033[0m" | lolcat
    echo -e "\033[0;31m  ██████╗ ██╗      █████╗ ██╗██████╗ ███████╗\033[0m" | lolcat
    echo -e "\033[0;33m  ██╔══██╗██║     ██╔══██╗██║██╔══██╗██╔════╝\033[0m" | lolcat
    echo -e "\033[0;32m  ██████╔╝██║     ███████║██║██████╔╝█████╗  \033[0m" | lolcat
    echo -e "\033[0;36m  ██╔══██╗██║     ██╔══██║██║██╔══██╗██╔══╝  \033[0m" | lolcat
    echo -e "\033[0;34m  ██████╔╝███████╗██║  ██║██║██║  ██║███████╗\033[0m" | lolcat
    echo -e "\033[0;35m  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════╝\033[0m" | lolcat
    echo -e "\033[0;35m═════════════════════════════════════════════\033[0m" | lolcat
    echo -e ""
    echo -e "AIO Script Successfully Installed! | Date : $date " | lolcat 
    echo -e ""
    echo -e "Operating System: $(neofetch --stdout | grep 'OS' | awk -F ':' '{print $2}' | tr -d '[:space:]')" | lolcat
    echo -e "CPU: $(neofetch --stdout | grep 'CPU' | awk -F ':' '{print $2}' | tr -d '[:space:]')" | lolcat
    echo -e "Disk: $(neofetch disk --stdout | grep -oP '(\d+(\.\d+)?[GMKB])? /\s*\d+(\.\d+)?[GMKB] \(\d+%\) ')" | lolcat
    echo -e "Uptime: $(neofetch --uptime --stdout | grep 'Uptime' | awk -F ': ' '{print $2}')" | lolcat
    echo -e ""
    echo -e "OpenSSH Port: $(netstat -ntlp | grep -i ssh | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g' )" | lolcat
    echo -e "Stunnel Port: $(netstat -nlpt | grep -i stunnel | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g')" | lolcat
    echo -e "DropbearSSH Port: $(netstat -nlpt | grep -i dropbear | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g')" | lolcat
    echo -e "Squid Port: $(cat /etc/squid/squid.conf | grep -i http_port | awk '{print $2}' | cut -d: -f2 | xargs | sed -e 's/ /, /g')" | lolcat
    echo -e "BadVPN Port: $(netstat -nlpt | grep -i badvpn-udpgw | grep -i 0.0.0.0 | awk '{print $4}' | cut -d: -f2 | xargs | sed -e 's/ /, /g')" | lolcat
    echo -e "SSH WS Port: 80" | lolcat
    echo -e "OpenVPN WS Port: 81" | lolcat
    echo -e ""
    echo -e "SlowDNS Configuration" | lolcat
    echo -e "Host: $(wget -4qO- http://ipinfo.io/ip)" | lolcat 
    echo -e "SlowDNS Port: $(netstat -nlptu | awk '/slowdns/ && /udp6/ {gsub(/.*:/, "", $4); print $4}')" | lolcat 
    echo -e "Public Key: $(cat /etc/slowdns/server.pub)" | lolcat
    echo -e "Nameserver : $(cat /etc/slowdns/ns.txt)" | lolcat
    echo -e "Subdomain : $(cat /etc/slowdns/subd.txt)" | lolcat 
    echo -e ""
    echo -e "Hysteria Configuration" | lolcat

HY_PORT=$(netstat -nlptu 2>/dev/null | awk '
/hysteria/ && /udp/ {
    split($4,a,":");
    port=a[length(a)];
    print port;
    exit
}')

if [ -f /etc/hysteria/config.json ]; then

    HY_OBFS=$(jq -r '.obfs' /etc/hysteria/config.json 2>/dev/null)

    HY_PASS=$(jq -r '.auth.config[0]' /etc/hysteria/config.json 2>/dev/null)

elif [ -f /etc/hysteria/config.yaml ]; then

    HY_OBFS=$(grep 'password:' /etc/hysteria/config.yaml \
    | head -1 | awk '{print $2}')

    HY_PASS=$(grep '^  password:' /etc/hysteria/config.yaml \
    | awk '{print $2}')

else

    HY_OBFS="Not Found"

    HY_PASS="Not Found"

fi
    echo -e "Hysteria Port: ${HY_PORT:-5666} [20000-50000]" | lolcat
    echo -e "Hysteria OBFS: ${HY_OBFS}" | lolcat
    echo -e "Hysteria Password: ${HY_PASS}" | lolcat
    echo -e ""
    echo -e "OpenVPN Configuration" | lolcat

OVPN_TCP=$(ss -tlpn 2>/dev/null | awk '
/openvpn/ {
    split($4,a,":");
    ports=ports a[length(a)] ", "
}
END {
    print substr(ports,1,length(ports)-2)
}')

OVPN_UDP=$(ss -ulpn 2>/dev/null | awk '
/openvpn/ {
    split($5,a,":");
    ports=ports a[length(a)] ", "
}
END {
    print substr(ports,1,length(ports)-2)
}')

    echo -e "OpenVPN TCP Ports: ${OVPN_TCP:-Not Running}" | lolcat
    echo -e "OpenVPN UDP Ports: ${OVPN_UDP:-Not Running}" | lolcat
    echo -e ""
    }
    }

install_dependencies
install_ssh
install_dropbear
install_user_api
install_squid
case "$OPENVPN_VERSION" in
    1)
        echo -e "[\e[32mInfo\e[0m] Installing OpenVPN1..."
        install_openvpn1
    ;;
    
    2)
        echo -e "[\e[32mInfo\e[0m] Installing OpenVPN2..."
        install_openvpn2
    ;;
    
    *)
        echo -e "[\e[33mNotice\e[0m] No OpenVPN version selected. Defaulting to OpenVPN1..."
        install_openvpn1
    ;;
esac
install_stunnel
install_badvpn
install_slowdns
if [[ "$HYSTERIA_VERSION" == "v2" ]]; then
    install_hysteria2
else
    install_hysteria
fi
install_firewall_kvm
start_service
