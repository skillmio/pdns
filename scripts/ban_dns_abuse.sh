#!/bin/bash
# ---------------------------------------------------
# Script: dns_abuse_guard.sh
# Purpose: Detect DNS abuse patterns and ban IPs
# ---------------------------------------------------
set -e

# -------------------------------
# Configurable Variables
# -------------------------------
CAPTURE_TIME=120
BAN_THRESHOLD=5
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
    echo "❌ ERROR: This script must be run as root (tcpdump requires it)"
    exit 1
fi

# -------------------------------
# Capture live DNS ANY queries
# Write RAW tcpdump lines to file — do NOT pre-process here
# -------------------------------
> "$TMP_RAW"  # truncate/create fresh

timeout "$CAPTURE_TIME" tcpdump -i eth0 -Z root -nn -l udp port 53 and 'udp[10] & 0x80 = 0' 2>/dev/null \
    | grep --line-buffered -E " ANY\?| TXT\?| DNSKEY\?| RRSIG\?" \
    >> "$TMP_RAW" || true


LINE_COUNT=$(wc -l < "$TMP_RAW")
echo "Raw matching lines captured: $LINE_COUNT"

if [[ "$LINE_COUNT" -eq 0 ]]; then
    echo "⚠️  No DNS abuse lines captured. Check: is tcpdump seeing traffic on this interface?"
    echo "   Test manually: tcpdump -nn -l udp port 53 and 'udp[10] & 0x80 = 0'"
    exit 0
fi

# Debug: show a few sample lines
echo "--- Sample captured lines ---"
head -5 "$TMP_RAW"
echo "-----------------------------"

# -------------------------------
# Analyze: extract source IP from raw tcpdump lines, count per IP
# tcpdump line format: HH:MM:SS.us IP src.port > dst.port: query
# Source IP is field $3, format: 1.2.3.4.PORT — strip the port
# -------------------------------
awk -v threshold="$BAN_THRESHOLD" '
{
    # Field $3 is src.port — extract IP by removing trailing .PORT
    split($3, parts, ".")
    # Rebuild just the first 4 octets
    ip = parts[1] "." parts[2] "." parts[3] "." parts[4]
    if (ip ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)
        count[ip]++
}
END {
    for (i in count) {
        if (count[i] >= threshold)
            print i
    }
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
    git clone "https://$GITHUB_TOKEN@github.com/skillmio/CoSec.git" "$GIT_REPO"
fi

mkdir -p "$DDOS_DIR"
cd "$GIT_REPO"
git config user.name "Skillmio"
git config user.email "skillmiocfs@gmail.com"
git pull --rebase origin "$BRANCH"
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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Banning IP: $ip"
    fail2ban-client set sshd banip "$ip" || true
    BAN_COUNT=$((BAN_COUNT+1))
done < "$TMP_NEW"

# -------------------------------
# Update Git log
# -------------------------------
if [ "$NEW_COUNT" -gt 0 ]; then
    cat "$TMP_NEW" >> "$DDOS_FILE"
    git add "$DDOS_FILE"
    git commit -m "DNS abuse batch $(date '+%Y-%m-%d %H:%M:%S')" || true
    for i in 1 2 3; do
        if git push origin "$BRANCH"; then
            echo "✅ GitHub updated with $NEW_COUNT new IPs"
            break
        fi
        git pull --rebase origin "$BRANCH"
    done
else
    echo "No new IPs to ban"
fi

echo "Total banned this run: $BAN_COUNT"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished"
echo "------------------------------------------------"
