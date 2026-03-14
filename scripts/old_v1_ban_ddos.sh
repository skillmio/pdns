#!/bin/bash
# ---------------------------------------------------
# Script: ban_ddos.sh (High Performance Version)
# Purpose: Detect abusive DNS queries and ban IPs
# ---------------------------------------------------

set -e

DB_SOURCE="/etc/dns/apps/Query Logs (Sqlite)/querylogs.db"
DB_COPY="/tmp/querylogs_copy.db"

TMP_IPS="/tmp/abuse_ips_raw.txt"
TMP_NEW="/tmp/abuse_ips_new.txt"

GIT_REPO="/tmp/CoSec"

DATE=$(date +%F)
DDOS_DIR="$GIT_REPO/files/ddos"
DDOS_FILE="$DDOS_DIR/$DATE.txt"

BRANCH="main"

NOW=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$NOW] Starting ban_ddos.sh"

# ---------------------------------------------------
# Copy DB
# ---------------------------------------------------

/bin/cp -f "$DB_SOURCE" "$DB_COPY"

# ---------------------------------------------------
# Extract attacking IPs
# ---------------------------------------------------

sqlite3 "$DB_COPY" <<'EOF' > "$TMP_IPS"
SELECT client_ip
FROM dns_logs
WHERE qname='dhl.com';
EOF

# Remove duplicates
sort -u "$TMP_IPS" -o "$TMP_IPS"

# ---------------------------------------------------
# Ensure repo exists
# ---------------------------------------------------

if [ ! -d "$GIT_REPO" ]; then
    git clone "https://$GITHUB_TOKEN@github.com/skillmio/CoSec.git" "$GIT_REPO"
fi

mkdir -p "$DDOS_DIR"

cd "$GIT_REPO"

# ---------------------------------------------------
# Configure Git identity (for automation commits)
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
