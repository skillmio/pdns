#!/bin/bash
# ---------------------------------------------------
# Script: ban_dns_abuse.sh
# Purpose: Detect DNS abuse patterns and ban IPs
# ---------------------------------------------------
set -e

# -------------------------------
# Full paths — required for cron (minimal PATH environment)
# -------------------------------
TCPDUMP=/usr/sbin/tcpdump
STDBUF=/usr/bin/stdbuf
FAIL2BAN=/usr/bin/fail2ban-client
GIT=/usr/bin/git

# -------------------------------
# Configurable Variables
# -------------------------------
IFACE="eth0"
CAPTURE_TIME=120
BAN_THRESHOLD=5
JAIL="sshd"
TMP_RAW="/tmp/dns_raw.log"
TMP_IPS="/tmp/dns_scored_ips.txt"
TMP_NEW="/tmp/dns_new_ips.txt"
GIT_REPO="/tmp/CoSec"
DATE=$(date +%F)
DDOS_DIR="$GIT_REPO/files/ddos"
DDOS_FILE="$DDOS_DIR/$DATE.txt"
BRANCH="main"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting DNS abuse detection..."

# -------------------------------
# Require root
# -------------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ ERROR: Must be run as root"
    exit 1
fi

# -------------------------------
# Verify required tools exist
# -------------------------------
for bin in "$TCPDUMP" "$STDBUF" "$FAIL2BAN" "$GIT"; do
    if [[ ! -x "$bin" ]]; then
        echo "❌ ERROR: Required binary not found: $bin"
        exit 1
    fi
done

# -------------------------------
# Capture + filter in one pipe
# stdbuf -oL forces line-buffered output — prevents data loss on pipe close
# Full paths used so cron can find all binaries
# -------------------------------
> "$TMP_RAW"

$STDBUF -oL timeout "$CAPTURE_TIME" \
    $TCPDUMP -i "$IFACE" -Z root -nn -l \
    udp port 53 and 'udp[10] & 0x80 = 0' 2>/dev/null \
    | $STDBUF -oL grep -E " ANY\?| TXT\?| DNSKEY\?| RRSIG\?" \
    >> "$TMP_RAW" || true

LINE_COUNT=$(wc -l < "$TMP_RAW")
echo "Raw matching lines captured: $LINE_COUNT"

if [[ "$LINE_COUNT" -eq 0 ]]; then
    echo "⚠️  No DNS abuse lines captured."
    echo "   Test manually: $TCPDUMP -i $IFACE -Z root -nn udp port 53 and 'udp[10] & 0x80 = 0'"
    exit 0
fi

echo "--- Sample captured lines ---"
head -5 "$TMP_RAW"
echo "-----------------------------"

# -------------------------------
# Extract source IPs, count per IP, apply threshold
# Field $3 = src.port e.g. 177.54.122.14.37015
# -------------------------------
awk -v threshold="$BAN_THRESHOLD" '
{
    split($3, parts, ".")
    ip = parts[1] "." parts[2] "." parts[3] "." parts[4]
    if (ip ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)
        count[ip]++
}
END {
    for (i in count)
        if (count[i] >= threshold)
            print i
}
' "$TMP_RAW" | sort -u > "$TMP_IPS"

# -------------------------------
# Remove private/internal IPs
# -------------------------------
grep -Ev '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' "$TMP_IPS" \
    > "${TMP_IPS}.clean" || true
mv "${TMP_IPS}.clean" "$TMP_IPS"

TOTAL_FOUND=$(wc -l < "$TMP_IPS")
echo "Suspicious public IPs detected: $TOTAL_FOUND"

# -------------------------------
# Ensure Git repo exists
# -------------------------------
if [ ! -d "$GIT_REPO" ]; then
    $GIT clone "https://$GITHUB_TOKEN@github.com/skillmio/CoSec.git" "$GIT_REPO"
fi

mkdir -p "$DDOS_DIR"
cd "$GIT_REPO"
$GIT config user.name "Skillmio"
$GIT config user.email "skillmiocfs@gmail.com"
$GIT pull --rebase origin "$BRANCH"
touch "$DDOS_FILE"

# -------------------------------
# Filter only new IPs
# -------------------------------
grep -vxFf "$DDOS_FILE" "$TMP_IPS" > "$TMP_NEW" || true
NEW_COUNT=$(wc -l < "$TMP_NEW")
echo "New attacking IPs: $NEW_COUNT"

# -------------------------------
# Ban new IPs via fail2ban
# -------------------------------
BAN_COUNT=0
while read -r ip; do
    [ -z "$ip" ] && continue
    if $FAIL2BAN status "$JAIL" 2>/dev/null | grep -q "$ip"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already banned: $ip"
        continue
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Banning IP: $ip"
    $FAIL2BAN set "$JAIL" banip "$ip" || true
    BAN_COUNT=$((BAN_COUNT+1))
done < "$TMP_NEW"

# -------------------------------
# Update Git log
# -------------------------------
if [ "$NEW_COUNT" -gt 0 ]; then
    cat "$TMP_NEW" >> "$DDOS_FILE"
    $GIT add "$DDOS_FILE"
    $GIT commit -m "DNS abuse batch $(date '+%Y-%m-%d %H:%M:%S')" || true
    for i in 1 2 3; do
        if $GIT push origin "$BRANCH"; then
            echo "✅ GitHub updated with $NEW_COUNT new IPs"
            break
        fi
        $GIT pull --rebase origin "$BRANCH"
    done
else
    echo "No new IPs to ban"
fi

echo "Total banned this run: $BAN_COUNT"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished"
echo "------------------------------------------------"
