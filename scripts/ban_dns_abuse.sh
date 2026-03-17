#!/bin/bash
# ---------------------------------------------------
# Script: ban_ddos.sh (tcpdump version)
# Purpose: Detect abusive DNS ANY queries and ban IPs
# ---------------------------------------------------

set -e

TMP_IPS="/tmp/abuse_ips_raw.txt"
TMP_NEW="/tmp/abuse_ips_new.txt"

GIT_REPO="/tmp/CoSec"

DATE=$(date +%F)
DDOS_DIR="$GIT_REPO/files/ddos"
DDOS_FILE="$DDOS_DIR/$DATE.txt"

BRANCH="main"

CAPTURE_TIME=60   # seconds to listen

NOW=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$NOW] Starting ban_ddos.sh"

# ---------------------------------------------------
# Capture DNS ANY query IPs (threshold > 5)
# ---------------------------------------------------

echo "Capturing DNS ANY queries for $CAPTURE_TIME seconds..."

timeout "$CAPTURE_TIME" tcpdump -nn -l udp port 53 and 'udp[10] & 0x80 = 0' 2>/dev/null \
| grep "ANY?" \
| awk '{print $3}' \
| cut -d. -f1-4 \
| sort \
| uniq -c \
| awk '$1 > 5 {print $2}' \
> "$TMP_IPS"

# ---------------------------------------------------
# Remove private/local IPs
# ---------------------------------------------------

grep -Ev '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)' "$TMP_IPS" > "${TMP_IPS}.clean" || true
mv "${TMP_IPS}.clean" "$TMP_IPS"

TOTAL_FOUND=$(wc -l < "$TMP_IPS")
echo "Suspicious IPs found: $TOTAL_FOUND"

# ---------------------------------------------------
# Ensure repo exists
# ---------------------------------------------------

if [ ! -d "$GIT_REPO" ]; then
    git clone "https://$GITHUB_TOKEN@github.com/skillmio/CoSec.git" "$GIT_REPO"
fi

mkdir -p "$DDOS_DIR"

cd "$GIT_REPO"

# ---------------------------------------------------
# Configure Git identity
# ---------------------------------------------------

git config user.name "Skillmio"
git config user.email "skillmiocfs@gmail.com"

# ---------------------------------------------------
# Sync with remote
# ---------------------------------------------------

git pull --rebase origin "$BRANCH"

touch "$DDOS_FILE"

# ---------------------------------------------------
# Find NEW IPs only
# ---------------------------------------------------

grep -vxFf "$DDOS_FILE" "$TMP_IPS" > "$TMP_NEW" || true

NEW_COUNT=$(wc -l < "$TMP_NEW")
echo "New attacking IPs detected: $NEW_COUNT"

# ---------------------------------------------------
# Ban IPs
# ---------------------------------------------------

BAN_COUNT=0

while read -r ip; do
    [ -z "$ip" ] && continue

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Banning IP: $ip"

    fail2ban-client set sshd banip "$ip" || true

    BAN_COUNT=$((BAN_COUNT+1))

done < "$TMP_NEW"

# ---------------------------------------------------
# Update Git repo
# ---------------------------------------------------

if [ "$NEW_COUNT" -gt 0 ]; then

    cat "$TMP_NEW" >> "$DDOS_FILE"

    git add "$DDOS_FILE"

    git commit -m "DDOS batch $(date '+%Y-%m-%d %H:%M:%S')" || true

    for i in 1 2 3; do
        if git push origin "$BRANCH"; then
            echo "✅ GitHub updated with $NEW_COUNT new IPs"
            break
        fi

        echo "Push conflict — retrying..."
        git pull --rebase origin "$BRANCH"
    done

else
    echo "No new IPs"
fi

echo "Total banned this run: $BAN_COUNT"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished"
echo "------------------------------------------------"
