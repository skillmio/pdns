#!/bin/bash
# export-banned-ips.sh - Ban new SSH IPs + export all banned IPs to GitHub (token auth)
# Only SSH jail, one IP per line

set -e  # Exit on error

TMP_DIR="/tmp"
REPO_DIR="$TMP_DIR/CoSec"
FILE_TO_UPLOAD="banned_ips.txt"
BRANCH="main"
BOT_COMMIT_MSG="Update banned IPs via bot-updater"
LOGFILE="/var/log/secure"
JAILS=("sshd")  # Only SSH

# --- Token & Repo ---
if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN not defined in environment!"
    exit 1
fi
REPO_URL="https://$GITHUB_TOKEN@github.com/skillmio/CoSec.git"

echo "=== CoSec Banned IPs Exporter ==="
echo "Date: $(date)"

# Step 1: Collect existing banned IPs from Fail2ban
echo "1. Collecting currently banned IPs from Fail2ban..."
EXISTING_BANNED=""
for JAIL in "${JAILS[@]}"; do
    EXISTING_BANNED+=$(sudo fail2ban-client get "$JAIL" banip || echo "")$'\n'
done
EXISTING_BANNED=$(echo "$EXISTING_BANNED" | tr ' ' '\n' | grep -v '^$' | sort -u)
echo "Found $(echo "$EXISTING_BANNED" | wc -l) IPs already banned in Fail2ban."

# Step 2: Extract new failed login IPs
echo "2. Extracting new failed login IPs..."
NEW_IPS=$(grep -E 'Failed password' "$LOGFILE" \
          | grep -oE '(::ffff:)?([0-9]{1,3}\.){3}[0-9]{1,3}' \
          | sed 's/^::ffff://' \
          | tr ' ' '\n' \
          | grep -v '^$' \
          | sort -u)

# Step 3: Ban only new offenders in Fail2ban
TO_BAN=$(echo "$NEW_IPS" | grep -v -F -f <(echo "$EXISTING_BANNED") || echo "")
if [[ -n "$TO_BAN" ]]; then
    echo "$TO_BAN" | xargs -r -n1 sudo fail2ban-client set sshd banip
    echo "Banned new IPs:"
    echo "$TO_BAN"
else
    echo "No new IPs to ban."
fi

# Step 4: Merge all banned IPs for export (one per line)
echo "3. Merging all banned IPs..."
ALL_BANNED=$(echo -e "$EXISTING_BANNED\n$TO_BAN" | tr ' ' '\n' | grep -v '^$' | sort -u)
echo "$ALL_BANNED" > "$TMP_DIR/$FILE_TO_UPLOAD"
echo "Total IPs in export file: $(wc -l < $TMP_DIR/$FILE_TO_UPLOAD)"

# Step 5: Upload to GitHub
echo "4. Uploading to GitHub..."
# Clone or update repo
if [ ! -d "$REPO_DIR" ]; then
    git clone "$REPO_URL" "$REPO_DIR"
else
    cd "$REPO_DIR"
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
fi

cp "$TMP_DIR/$FILE_TO_UPLOAD" "$REPO_DIR/"

cd "$REPO_DIR"
git config user.name "Skillmio"
git config user.email "skillmiocfs@gmail.com"

git add "$FILE_TO_UPLOAD"
git commit -m "$BOT_COMMIT_MSG" || echo "No changes to commit."
git push origin "$BRANCH"

echo ""
echo "✅ All banned IPs merged and exported to GitHub!"
echo "Cleaning"
rm -rf /tmp/banned_ips.txt
cat /dev/null > /var/log/secure
