#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

DEBUG=false

API_KEY="c411d540b654cd20ffca8054704add0647720"
EMAIL="extdomin@gmail.com"
ZONE_ID="b2a3bee783684815f867e225b8b515d4"
DOMAIN="sylnetrj.top"

API="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
FILE="ip.txt"

DNS_CREATED=()
XRP_CREATED=()

command -v jq >/dev/null || { echo -e "${RED}Install jq first${NC}"; exit 1; }
command -v curl >/dev/null || { echo -e "${RED}Install curl first${NC}"; exit 1; }

valid_ip() {
local ip=$1
local stat=1

if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
OIFS=$IFS
IFS='.'
ip=($ip)
IFS=$OIFS

[ ${ip[0]} -le 255 ] && \
[ ${ip[1]} -le 255 ] && \
[ ${ip[2]} -le 255 ] && \
[ ${ip[3]} -le 255 ]

stat=$?
fi

return $stat
}

get_next_num(){

RESPONSE=$(curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

NEXT=$(echo "$RESPONSE" | jq -r '.result[].name' \
| grep -E "^(dns|xrp)[0-9]*\." \
| sed -E 's/(dns|xrp)//;s/\..*//' \
| sort -n | tail -n1)

if [ -z "$NEXT" ]; then
echo 1
else
echo $((NEXT+1))
fi
}

ip_exists(){

CHECK_IP=$1

RESPONSE=$(curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

EXIST=$(echo "$RESPONSE" | jq -r '.result[].content' | grep -w "$CHECK_IP")

if [ ! -z "$EXIST" ]; then
return 0
else
return 1
fi

}

create_dns(){

IP=$1

# check duplicate IP
if ip_exists "$IP"; then
echo -e "${YELLOW}⚠ Duplicate IP skipped:${NC} $IP"
return
fi

DNS_SUB="dns$COUNT"
XRP_SUB="xrp$COUNT"

DNS_FULL="$DNS_SUB.$DOMAIN"
XRP_FULL="$XRP_SUB.$DOMAIN"

echo -e "${CYAN}Creating:${NC} $DNS_FULL"

JSON1="{\"type\":\"A\",\"name\":\"$DNS_SUB\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}"

RES1=$(curl -s -X POST "$API" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
--data "$JSON1")

SUCCESS1=$(echo "$RES1" | jq -r '.success')

echo -e "${CYAN}Creating:${NC} $XRP_FULL"

JSON2="{\"type\":\"A\",\"name\":\"$XRP_SUB\",\"content\":\"$IP\",\"ttl\":1,\"proxied\":false}"

RES2=$(curl -s -X POST "$API" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
--data "$JSON2")

SUCCESS2=$(echo "$RES2" | jq -r '.success')

if [ "$SUCCESS1" = "true" ] && [ "$SUCCESS2" = "true" ]; then

DNS_CREATED+=("$DNS_FULL -> $IP")
XRP_CREATED+=("$XRP_FULL -> $IP")

echo -e "${GREEN}✔ Success${NC}"

else

echo -e "${RED}❌ Failed creating record for $IP${NC}"

fi

COUNT=$((COUNT+1))
}

view_dns(){

echo -e "${CYAN}DNS Records:${NC}"

curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
| jq -r '.result[].name' \
| grep "^dns"

}

view_xrp(){

echo -e "${CYAN}XRP Records:${NC}"

curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" \
| jq -r '.result[].name' \
| grep "^xrp"

}

delete_all_records(){

echo -e "${RED}⚠ WARNING! Delete ALL dns/xrp records${NC}"
read -p "Type DELETE to confirm: " CONFIRM

[ "$CONFIRM" != "DELETE" ] && return

RESPONSE=$(curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

IDS=$(echo "$RESPONSE" | jq -r '.result[] | select(.name | test("^(dns|xrp)[0-9]+\\.")) | .id')

for ID in $IDS
do
curl -s -X DELETE "$API/$ID" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" > /dev/null

echo -e "${RED}Deleted:${NC} $ID"
done

echo -e "${GREEN}All records deleted.${NC}"
}

delete_single_record(){

read -p "Enter full record (example dns10.sylnetrj.top): " RECORD

RESPONSE=$(curl -s "$API?per_page=1000" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json")

ID=$(echo "$RESPONSE" | jq -r --arg r "$RECORD" '.result[] | select(.name==$r) | .id')

if [ -z "$ID" ]; then
echo -e "${RED}Record not found.${NC}"
return
fi

curl -s -X DELETE "$API/$ID" \
-H "X-Auth-Email: $EMAIL" \
-H "X-Auth-Key: $API_KEY" \
-H "Content-Type: application/json" > /dev/null

echo -e "${GREEN}Deleted $RECORD${NC}"
}

COUNT=$(get_next_num)

echo ""
echo -e "${CYAN}"
echo "██╗  ██╗███████╗██████╗ ███████╗ ██████╗"
echo "╚██╗██╔╝██╔════╝██╔══██╗██╔════╝██╔════╝"
echo " ╚███╔╝ █████╗  ██████╔╝█████╗  ██║"
echo " ██╔██╗ ██╔══╝  ██╔══██╗██╔══╝  ██║"
echo "██╔╝ ██╗███████╗██████╔╝███████╗╚██████╗"
echo "╚═╝  ╚═╝╚══════╝╚═════╝ ╚══════╝ ╚═════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}Cloudflare DNS Automation Tool${NC}"
echo ""

echo -e "${YELLOW}1) Manual Add IP${NC}"
echo -e "${YELLOW}2) Import from ip.txt${NC}"
echo -e "${YELLOW}3) Delete ALL dns/xrp records${NC}"
echo -e "${YELLOW}4) View DNS records${NC}"
echo -e "${YELLOW}5) View XRP records${NC}"
echo -e "${YELLOW}6) Delete single record${NC}"
echo ""

read -p "Choose option: " OPTION

case $OPTION in

1)

read -p "Enter IP: " IP

if ! valid_ip "$IP"; then
echo -e "${RED}Invalid IP${NC}"
exit
fi

create_dns "$IP"
;;

2)

while IFS= read -r IP; do

IP=$(echo "$IP" | tr -d '\r')
[ -z "$IP" ] && continue

if ! valid_ip "$IP"; then
echo -e "${RED}Invalid IP skipped: $IP${NC}"
continue
fi

create_dns "$IP"

done < "$FILE"

;;

3)

delete_all_records
;;

4)

view_dns
;;

5)

view_xrp
;;

6)

delete_single_record
;;

*)

echo -e "${RED}Invalid option${NC}"
;;

esac