#!/bin/bash
# export-blocked-domains.sh - Merge blocked domains (external + candidate + current - exempt) and upload to GitHub
# Fully preserves 0.0.0.0 <domain> format
set -e

TMP_DIR="/tmp"
REPO_DIR="$TMP_DIR/CoSec"
FILE_TO_UPLOAD="blocked_domains.txt"
BRANCH="main"
BOT_COMMIT_MSG="Update blocked domains"

EXTERNAL_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
CANDIDATE_URL="https://raw.githubusercontent.com/skillmio/CoSec/master/files/candidate_domains"
EXEMPT_URL="https://raw.githubusercontent.com/skillmio/CoSec/master/files/exempt_domains"
CURRENT_URL="https://raw.githubusercontent.com/skillmio/CoSec/master/blocked_domains.txt"

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GITHUB_TOKEN not defined!"
    exit 1
fi

REPO_URL="https://$GITHUB_TOKEN@github.com/skillmio/CoSec.git"

echo "=== CoSec Blocked Domains Exporter ==="
echo "Date: $(date)"

# --- Helper ---
normalize_file() { sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$1" | sort -u; }

# Domains to ignore — matched against the domain field only (column 2), not the full line.
# "^0\.0\.0\.0$" catches the "0.0.0.0 0.0.0.0" self-entry without filtering real domains.
IGNORE_DOMAINS='^0\.0\.0\.0$'

# --- Helper: fetch hosts-format file, filter to valid 0.0.0.0 lines, drop ignored domains ---
fetch_hosts() {
    local url="$1" out="$2"
    curl -s "$url" \
        | grep '^0\.0\.0\.0 ' \
        | awk '{print $2}' \
        | grep -v "$IGNORE_DOMAINS" \
        | awk '{print "0.0.0.0 "$1}' > "$out" || true
}

# Step 1: External domains
echo "1. Fetching external blocked domains..."
fetch_hosts "$EXTERNAL_URL" "$TMP_DIR/external_blocked_domains.txt"
normalize_file "$TMP_DIR/external_blocked_domains.txt" > "$TMP_DIR/external_norm.txt"
echo "External blocked domains: $(wc -l < "$TMP_DIR/external_norm.txt")"

# Step 2: Candidate domains
echo "2. Fetching candidate domains..."
fetch_hosts "$CANDIDATE_URL" "$TMP_DIR/candidate_domains.txt"
normalize_file "$TMP_DIR/candidate_domains.txt" > "$TMP_DIR/candidate_norm.txt"
echo "Candidate domains: $(wc -l < "$TMP_DIR/candidate_norm.txt")"

# Step 3: Current blocked domains
echo "3. Fetching current blocked domains..."
fetch_hosts "$CURRENT_URL" "$TMP_DIR/current_blocked_domains.txt"
normalize_file "$TMP_DIR/current_blocked_domains.txt" > "$TMP_DIR/current_norm.txt"
echo "Current blocked domains: $(wc -l < "$TMP_DIR/current_norm.txt")"

# Step 4: Exempt domains
echo "4. Fetching exempt domains..."
curl -s "$EXEMPT_URL" \
    | grep '^0\.0\.0\.0 ' > "$TMP_DIR/exempt_domains.txt" || true
awk '{print $2}' "$TMP_DIR/exempt_domains.txt" | sort -u > "$TMP_DIR/exempt_norm.txt" || true
echo "Exempt domains: $(wc -l < "$TMP_DIR/exempt_norm.txt")"

# Step 5: Merge all, exclude exempt
echo "5. Merging external + candidate + current domains, excluding exempt domains..."

if [ -s "$TMP_DIR/exempt_norm.txt" ]; then
    EXEMPT_FILTER="grep -v -F -f $TMP_DIR/exempt_norm.txt"
else
    EXEMPT_FILTER="cat"
fi

cat "$TMP_DIR/external_norm.txt" "$TMP_DIR/candidate_norm.txt" "$TMP_DIR/current_norm.txt" 2>/dev/null \
    | awk '{print $2}' \
    | $EXEMPT_FILTER \
    | sort -u \
    | awk '{print "0.0.0.0 "$1}' > "$TMP_DIR/$FILE_TO_UPLOAD" || true
echo "Total blocked domains after merge: $(wc -l < "$TMP_DIR/$FILE_TO_UPLOAD")"

# Step 6: Upload to GitHub
echo "6. Uploading blocked domains to GitHub..."
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Cloning repository using token..."
    git clone "$REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
    git checkout "$BRANCH"
else
    cd "$REPO_DIR"
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
fi

cd "$REPO_DIR"

cp "$TMP_DIR/$FILE_TO_UPLOAD" "$REPO_DIR/"

git config user.name "Skillmio"
git config user.email "skillmiocfs@gmail.com"
git add "$FILE_TO_UPLOAD"

if ! git diff --cached --quiet; then
    git commit -m "$BOT_COMMIT_MSG"
    git push origin "$BRANCH"
    echo ""
    echo "✅ Blocked domains merged and exported to GitHub!"
else
    echo "ℹ️  No changes to commit."
fi

# Cleanup
rm -f /tmp/candidate_domains.txt
rm -f /tmp/candidate_norm.txt
rm -f /tmp/current_blocked_domains.txt
rm -f /tmp/current_norm.txt
rm -f /tmp/exempt_domains.txt
rm -f /tmp/exempt_norm.txt
rm -f /tmp/external_blocked_domains.txt
rm -f /tmp/external_norm.txt
rm -f /tmp/blocked_domains.txt
