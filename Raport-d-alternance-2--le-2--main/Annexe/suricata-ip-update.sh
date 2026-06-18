#!/bin/bash
# /usr/local/bin/suricata-ip-update.sh

# Configuration et initialisation
RULES_DIR="/var/lib/suricata/rules"
CUSTOM_LIST="/etc/suricata/custom-blocklist.txt"
LOG_FILE="/var/log/suricata/threat-feeds-update.log"
SID_COUNTER=67000000

touch $LOG_FILE

echo "$(date): Starting threat feed update" >> $LOG_FILE

# Supprimer l'ancienne liste d'ip
> $CUSTOM_LIST

# 1. Emerging Threats Compromised IPs
echo "Fetching Emerging Threats compromised IPs..." >> $LOG_FILE
curl -s https://rules.emergingthreats.net/blockrules/compromised-ips.txt >> $CUSTOM_LIST

# 2. Feodo Tracker (abuse.ch)
echo "Fetching Feodo Tracker C2 IPs..." >> $LOG_FILE
curl -s feodotracker.abuse.ch/downloads/ipblocklist.csv | \
    grep -v "^#" | cut -d',' -f1 >> $CUSTOM_LIST

# 3. Open Threat Exchange (OTX) AlienVault
echo "Fetching AlienVault OTX pulses..." >> $LOG_FILE
curl -s https://reputation.alienvault.com/reputation.generic | \
    grep -v "^#" | awk -F ' # ' '{print $1}' >> $CUSTOM_LIST

# 4. Greensnow
echo "Fetching Greensnow list..." >> $LOG_FILE
curl -s https://blocklist.greensnow.co/greensnow.txt | \
    grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >> $CUSTOM_LIST

# Supprimer les doubons
sort -u $CUSTOM_LIST -o $CUSTOM_LIST

# Total nombre ip
IP_COUNT=$(wc -l < $CUSTOM_LIST)
echo "$(date): Added $IP_COUNT unique IPs to blocklist" >> $LOG_FILE
echo "Converting IPs to Suricata rules..." >> $LOG_FILE

> "$RULES_DIR/ip-reputation.rules"

while IFS= read -r ip
do
    # igorer les lignes vides et commentées
    [[ -z "$ip" || "$ip" == \#* ]] && continue

    SID_COUNTER=$((SID_COUNTER + 2))
    SID_OUTBOUND=$((SID_COUNTER + 1))

    echo "alert ip $ip any -> any any (msg:\"REPUTATION Known malicious IP (inbound)- $ip\"; reference:url,emergingthreats.net; classtype:bad-unknown; sid:$SID_COUNTER; rev:1;)" >> \
        "$RULES_DIR/ip-reputation.rules"

    echo "alert any any -> ip $ip any (msg:\"REPUTATION Known malicious IP (outbound)- $ip\"; reference:url,emergingthreats.net; classtype:bad-unknown; sid:$SID_OUTBOUND; rev:1;)" >> \
        "$RULES_DIR/ip-reputation.rules"
done < $CUSTOM_LIST

echo "$(date): Generated $(wc -l < $RULES_DIR/ip-reputation.rules) rules" >> $LOG_FILE

docker kill --signal=USR2 suricata && \
    echo "$(date): Reload signal sent successfully" >> $LOG_FILE || \
    echo "$(date): ERROR - Suricata container is not running!" >> $LOG_FILE

echo "$(date): Update complete" >> $LOG_FILE
exit 0