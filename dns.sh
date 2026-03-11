#!/bin/bash
clear

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ACCOUNTS=(
"extdomin@gmail.com|c411d540b654cd20ffca8054704add0647720"
"dyna99771@gmail.com|544210738aa839f53263a1b882dea9535c5ac"
)

FILE="ip.txt"
MODE="single"
DNS_CREATED=()
XRP_CREATED=()

command -v jq >/dev/null || { echo "Installing jq..."; apt update -y && apt install jq -y; }
command -v curl >/dev/null || { echo "Installing curl..."; apt update -y && apt install curl -y; }
command -v lolcat >/dev/null || {
echo "Installing lolcat..."
apt update -y
apt install ruby -y
gem install lolcat
}

# --------------------------------
# Check API Status
# --------------------------------

check_api_status(){

EMAIL_CHECK=$1
KEY_CHECK=$2

RESULT=$(curl -s https://api.cloudflare.com/client/v4/user \
-H "X-Auth-Email: $EMAIL_CHECK" \
-H "X-Auth-Key: $KEY_CHECK" \
-H "Content-Type: application/json")

OK=$(echo "$RESULT" | jq -r '.success')

if [ "$OK" = "true" ]; then
echo -e "${GREEN}API: OK${NC}"
else
echo -e "${RED}API: INVALID${NC}"
fi

}

# --------------------------------
# Select Account
# --------------------------------
select_account(){
clear
echo ""

echo "
██╗  ██╗███████╗██████╗ ███████╗ ██████╗
╚██╗██╔╝██╔════╝██╔══██╗██╔════╝██╔════╝
 ╚███╔╝ █████╗  ██████╔╝█████╗  ██║
 ██╔██╗ ██╔══╝  ██╔══██╗██╔══╝  ██║
██╔╝ ██╗███████╗██████╔╝███████╗╚██████╗
╚═╝  ╚═╝╚══════╝╚═════╝ ╚══════╝ ╚═════╝
" | lolcat -a -d 5

echo ""
echo "=============================================="
echo "        CLOUDFLARE ACCOUNT SELECTOR"
echo "=============================================="
echo ""

for i in "${!ACCOUNTS[@]}"
do

NUM=$((i+1))
EMAIL_ACC=$(echo "${ACCOUNTS[$i]}" | cut -d'|' -f1)
KEY_ACC=$(echo "${ACCOUNTS[$i]}" | cut -d'|' -f2)

printf " %s) %-30s " "$NUM" "$EMAIL_ACC"
check_api_status "$EMAIL_ACC" "$KEY_ACC"

done

echo ""
echo "=============================================="
echo ""

read -p "Select account: " CHOICE

INDEX=$((CHOICE-1))

EMAIL=$(echo "${ACCOUNTS[$INDEX]}" | cut -d'|' -f1)
API_KEY=$(echo "${ACCOUNTS[$INDEX]}" | cut -d'|' -f2)

echo ""
echo -e "${GREEN}✔ Using account:${NC} $EMAIL"
echo "=============================================="
echo ""

}
# --------------------------------
# Fetch Domains
# --------------------------------

fetch_zones(){

RESPONSE=$(curl -s "https://api.cloudflare.com/client/v4/zones?per_page=50" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

DOMAINS=($(echo "$RESPONSE" | jq -r '.result[].name'))
ZONES=($(echo "$RESPONSE" | jq -r '.result[].id'))

TOTAL=${#DOMAINS[@]}

if [ "$TOTAL" = "0" ]; then
echo -e "${RED}No domains found${NC}"
exit
fi

}

# --------------------------------
# Domain Selector
# --------------------------------

select_domains(){
clear
echo ""
echo "
██╗  ██╗███████╗██████╗ ███████╗ ██████╗
╚██╗██╔╝██╔════╝██╔══██╗██╔════╝██╔════╝
 ╚███╔╝ █████╗  ██████╔╝█████╗  ██║
 ██╔██╗ ██╔══╝  ██╔══██╗██╔══╝  ██║
██╔╝ ██╗███████╗██████╔╝███████╗╚██████╗
╚═╝  ╚═╝╚══════╝╚═════╝ ╚══════╝ ╚═════╝
" | lolcat -a -d 5
echo ""
echo "=============================================="
echo "              DOMAIN MODE" | lolcat
echo "=============================================="
echo ""
echo "1) Single Domain"
echo "2) Multi Domain"

echo "=============================================="
read -p "Choose mode: " MODE_CHOICE

echo ""
echo "Available Domains" | lolcat
echo "=============================================="

for ((i=0;i<TOTAL;i++))
do

ZONE=${ZONES[$i]}

COUNT_DNS=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE/dns_records?per_page=1" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
| jq -r '.result_info.total_count')

NUM=$((i+1))

printf "%2s) %-30s DNS: %4s/1000\n" "$NUM" "${DOMAINS[$i]}" "$COUNT_DNS"

done

echo "==============================================" | lolcat

if [ "$MODE_CHOICE" = "1" ]; then

MODE="single"

echo ""
read -p "Select domain number: " CHOICE
INDEX=$((CHOICE-1))

SELECTED_DOMAINS=("${DOMAINS[$INDEX]}")
SELECTED_ZONES=("${ZONES[$INDEX]}")

else

MODE="multi"

echo ""
read -p "Select domains (example: 1 3 5): " CHOICES

SELECTED_DOMAINS=()
SELECTED_ZONES=()

for C in $CHOICES
do
INDEX=$((C-1))
SELECTED_DOMAINS+=("${DOMAINS[$INDEX]}")
SELECTED_ZONES+=("${ZONES[$INDEX]}")
done

fi

echo ""
echo "==============================================" | lolcat
echo "Selected Domains" | lolcat
echo "==============================================" | lolcat

for D in "${SELECTED_DOMAINS[@]}"
do
echo "✔ $D" | lolcat
done

echo ""
}

# --------------------------------
# Delete All DNS/XRP Records
# --------------------------------

delete_all_records(){
clear
echo ""
echo -e "${RED}WARNING: This will delete ALL dns/xrp records${NC}"
read -p "Type YES to confirm: " CONFIRM

[ "$CONFIRM" != "YES" ] && { echo "Cancelled."; return; }

for i in "${!SELECTED_DOMAINS[@]}"
do

DOMAIN=${SELECTED_DOMAINS[$i]}
ZONE_ID=${SELECTED_ZONES[$i]}

API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"

echo ""
echo "Scanning records for $DOMAIN..."

DATA=$(curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

IDS=$(echo "$DATA" | jq -r '.result[] | select(.name | test("^(dns|xrp)[0-9]+")) | .id')

TOTAL=$(echo "$IDS" | wc -l)

COUNT=1

for ID in $IDS
do

echo -ne "Deleting record [$COUNT/$TOTAL] ... "

RESULT=$(curl -s -X DELETE "$API/$ID" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

OK=$(echo "$RESULT" | jq -r '.success')

if [ "$OK" = "true" ]; then
echo -e "${GREEN}✔ Deleted${NC}"
else
echo -e "${RED}✖ Failed${NC}"
fi

COUNT=$((COUNT+1))

done

echo ""
echo -e "${YELLOW}Finished cleaning records for $DOMAIN${NC}"

done

}

# --------------------------------
# record_exists
# --------------------------------

record_exists(){

NAME_CHECK=$1

RESULT=$(curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

FOUND=$(echo "$RESULT" | jq -r --arg NAME "$NAME_CHECK" '.result[] | select(.name==$NAME) | .name')

if [ -n "$FOUND" ]; then
return 0
else
return 1
fi

}

# --------------------------------
# Validate IP
# --------------------------------

valid_ip(){

[[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

IFS='.' read -r o1 o2 o3 o4 <<< "$1"

[ "$o1" -le 255 ] && [ "$o2" -le 255 ] && [ "$o3" -le 255 ] && [ "$o4" -le 255 ]

}

# --------------------------------
# Get Next Number
# --------------------------------

get_next_num(){

RESPONSE=$(curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

NEXT=$(echo "$RESPONSE" | jq -r '.result[].name' \
| grep -E "^(dns|xrp)[0-9]+" \
| sed -E 's/(dns|xrp)//' \
| cut -d'.' -f1 \
| sort -n | tail -n1)

if [ -z "$NEXT" ]; then
echo 1
else
echo $((NEXT+1))
fi

}


# --------------------------------
# create_dns
# --------------------------------
create_dns(){

IP=$1

for i in "${!SELECTED_DOMAINS[@]}"
do

DOMAIN=${SELECTED_DOMAINS[$i]}
ZONE_ID=${SELECTED_ZONES[$i]}

API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"

while true
do
clear

DNS_SUB="dns$COUNT"
XRP_SUB="xrp$COUNT"

DNS_FULL="$DNS_SUB.$DOMAIN"
XRP_FULL="$XRP_SUB.$DOMAIN"

# Check if DNS already exists
if record_exists "$DNS_FULL"; then
COUNT=$((COUNT+1))
continue
fi

# Check if XRP already exists
if record_exists "$XRP_FULL"; then
COUNT=$((COUNT+1))
continue
fi

echo -e "${CYAN}Creating:${NC} $DNS_FULL"

curl -s -X POST "$API" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
--data "{\"type\":\"A\",\"name\":\"$DNS_SUB\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}" > /dev/null

echo -e "${CYAN}Creating:${NC} $XRP_FULL"

curl -s -X POST "$API" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
--data "{\"type\":\"A\",\"name\":\"$XRP_SUB\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}" > /dev/null

echo -e "${GREEN}✔ $DNS_FULL / $XRP_FULL${NC}"

COUNT=$((COUNT+1))
break

done

done

}

bulk_ip_input(){
clear
echo ""
echo "Bulk IP Generator" | lolcat
echo "------------------------------------------------"
echo "Select Base Record Type"
echo "------------------------------------------------"
echo "1) DNS Records  (dns1.domain.com)"
echo "2) XRP Records  (xrp1.domain.com)"
echo "------------------------------------------------"

read -p "Choose option: " BASE_OPT

case $BASE_OPT in
1) BASE="dns" ;;
2) BASE="xrp" ;;
*) echo "Invalid option"; return ;;
esac

IPS=()

echo ""
echo "Paste IP list (press ENTER on empty line to start)"
echo ""

# collect pasted IPs
while true
do
read IP
[ -z "$IP" ] && break
IP=$(echo "$IP" | xargs)
IPS+=("$IP")
done

TOTAL=${#IPS[@]}
COUNT=$(get_next_num)
SUCCESS=0
FAILED=0
INDEX=1

for IP in "${IPS[@]}"
do

if ! valid_ip "$IP"; then
echo "[${INDEX}/${TOTAL}] ✖ Invalid IP: $IP"
FAILED=$((FAILED+1))
INDEX=$((INDEX+1))
continue
fi

for i in "${!SELECTED_DOMAINS[@]}"
do

DOMAIN=${SELECTED_DOMAINS[$i]}
ZONE_ID=${SELECTED_ZONES[$i]}
API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"

while true
do

SUB="${BASE}${COUNT}"

echo -ne "[${INDEX}/${TOTAL}] Creating ${SUB}.${DOMAIN} -> $IP ... "

RESULT=$(curl -s -X POST "$API" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
--data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}")

OK=$(echo "$RESULT" | jq -r '.success')

if [ "$OK" = "true" ]; then
echo "✔ Success"
SUCCESS=$((SUCCESS+1))
COUNT=$((COUNT+1))
break
else

ERROR=$(echo "$RESULT" | jq -r '.errors[0].message')

if [[ "$ERROR" == *"identical record already exists"* ]]; then
COUNT=$((COUNT+1))
continue
else
echo "✖ Failed ($ERROR)"
FAILED=$((FAILED+1))
break
fi

fi

done

done

INDEX=$((INDEX+1))

done

echo ""
echo "--------------------------------"
echo "✔ Created : $SUCCESS"
echo "✖ Failed  : $FAILED"
echo "Bulk creation finished." | lolcat
echo "--------------------------------"

}

# --------------------------------
# Slash IP Bulk
# --------------------------------
bulk_slash_ips(){
clear
echo ""
echo "Slash IP Bulk Generator" | lolcat
echo "------------------------------------------------"
echo "Select Base Record Type"
echo "------------------------------------------------"
echo "1) DNS Records  (dns1.domain.com)"
echo "2) XRP Records  (xrp1.domain.com)"
echo "------------------------------------------------"

read -p "Choose option: " BASE_OPT

case $BASE_OPT in
1)
BASE="dns"
;;
2)
BASE="xrp"
;;
*)
echo -e "${RED}Invalid option${NC}"
return
;;
esac

echo ""
read -p "Paste IPs separated by / : " IP_LIST

IFS='/' read -ra IPS <<< "$IP_LIST"

TOTAL=${#IPS[@]}
COUNT=$(get_next_num)
SUCCESS=0
FAILED=0
INDEX=1

for IP in "${IPS[@]}"
do

IP=$(echo "$IP" | xargs)

if ! valid_ip "$IP"; then
echo -e "${RED}[$INDEX/$TOTAL] ✖ Invalid IP: $IP${NC}"
FAILED=$((FAILED+1))
INDEX=$((INDEX+1))
continue
fi

for i in "${!SELECTED_DOMAINS[@]}"
do

DOMAIN=${SELECTED_DOMAINS[$i]}
ZONE_ID=${SELECTED_ZONES[$i]}

API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"

while true
do

SUB="${BASE}${COUNT}"

echo -ne "${CYAN}[$INDEX/$TOTAL] Creating ${SUB}.${DOMAIN} -> $IP ... ${NC}"

RESULT=$(curl -s -X POST "$API" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
--data "{\"type\":\"A\",\"name\":\"$SUB\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}")

OK=$(echo "$RESULT" | jq -r '.success')

if [ "$OK" = "true" ]; then
echo -e "${GREEN}✔ Success${NC}"
SUCCESS=$((SUCCESS+1))
COUNT=$((COUNT+1))
break
else

ERROR=$(echo "$RESULT" | jq -r '.errors[0].message')

if [[ "$ERROR" == *"identical record already exists"* ]]; then
COUNT=$((COUNT+1))
continue
else
echo -e "${RED}✖ Failed (${ERROR})${NC}"
FAILED=$((FAILED+1))
break
fi

fi

done

done

INDEX=$((INDEX+1))

done

echo ""
echo "--------------------------------"
echo -e "${GREEN}✔ Created : $SUCCESS${NC}"
echo -e "${RED}✖ Failed  : $FAILED${NC}"
echo -e "${YELLOW}Bulk creation finished.${NC}"
echo "--------------------------------"

}

# --------------------------------
# View Records
# --------------------------------

view_records(){
clear
echo ""
echo "DNS / XRP Records"
echo "--------------------------------"

for i in "${!SELECTED_DOMAINS[@]}"
do

DOMAIN=${SELECTED_DOMAINS[$i]}
ZONE_ID=${SELECTED_ZONES[$i]}

API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"

echo ""
echo "Domain: $DOMAIN"
echo "--------------------------------"

DATA=$(curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

NUMBERS=$(echo "$DATA" | jq -r '.result[].name' \
| grep -E '^(dns|xrp)[0-9]+' \
| sed -E 's/(dns|xrp)//' \
| cut -d'.' -f1 \
| sort -n | uniq)

COUNT=1

for N in $NUMBERS
do

DNS=$(echo "$DATA" | jq -r --arg n "dns$N.$DOMAIN" '.result[] | select(.name==$n) | "\(.name) -> \(.content)"')
XRP=$(echo "$DATA" | jq -r --arg n "xrp$N.$DOMAIN" '.result[] | select(.name==$n) | "\(.name) -> \(.content)"')

echo "$COUNT)"
echo " $DNS"
echo " $XRP"
echo ""

COUNT=$((COUNT+1))

done

done

}

# --------------------------------
# Start
# --------------------------------

select_account
fetch_zones
select_domains

COUNT=$(get_next_num)

while true
do
clear

echo "
██╗  ██╗███████╗██████╗ ███████╗ ██████╗
╚██╗██╔╝██╔════╝██╔══██╗██╔════╝██╔════╝
 ╚███╔╝ █████╗  ██████╔╝█████╗  ██║
 ██╔██╗ ██╔══╝  ██╔══██╗██╔══╝  ██║
██╔╝ ██╗███████╗██████╔╝███████╗╚██████╗
╚═╝  ╚═╝╚══════╝╚═════╝ ╚══════╝ ╚═════╝
" | lolcat -a -d 2

echo "Cloudflare DNS Automation Tool" | lolcat

echo ""

for i in "${!SELECTED_DOMAINS[@]}"
do

DOMAIN=${SELECTED_DOMAINS[$i]}
ZONE_ID=${SELECTED_ZONES[$i]}

COUNT_DNS=$(curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?per_page=1" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
| jq -r '.result_info.total_count')

echo "Domain: $DOMAIN  |  DNS Usage: $COUNT_DNS / 1000" | lolcat

done

echo ""
echo "----------------------------------------------" | lolcat

echo "1) Manual Add IP"
echo "2) Import from ip.txt"
echo "3) View DNS/XRP records"
echo "4) Bulk paste IP"
echo "5) Slash IP bulk generator"
echo "6) Delete ALL DNS/XRP records"
echo "0) Exit"
echo ""

read -p "Choose option: " OPTION

case $OPTION in

1)
read -p "Enter IP: " IP
valid_ip "$IP" || { echo "Invalid IP"; continue; }
create_dns "$IP"
;;

2)
while read IP
do
valid_ip "$IP" || continue
create_dns "$IP"
done < "$FILE"
;;

3)
view_records
;;

4)
bulk_ip_input
;;

5)
bulk_slash_ips
;;

6)
delete_all_records
;;

0)
echo "Exiting..." | lolcat
exit
;;

*)
echo "Invalid option"
;;

esac

echo ""
read -p "Press Enter to return to menu..."

done
