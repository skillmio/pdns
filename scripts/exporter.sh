#!/bin/bash
# pihole-export-clean.sh - Export Pi-hole blocked domains with exempt filtering
# to download this script wget https://raw.githubusercontent.com/skillmio/dns/master/scripts/exporter.sh

set -e  # Exit on error

cd /tmp/

echo "=== Pi-hole Blocked Domains Exporter ==="
echo "Date: $(date)"

# Step 1: Export all blocked domains from gravity
echo "1. Exporting all gravity domains..."
sudo sqlite3 /etc/pihole/gravity.db "SELECT DISTINCT domain FROM gravity;" > all_blocked_domains.txt

# Step 2: Add 0.0.0.0 prefix (hosts format)
echo "2. Adding 0.0.0.0 prefix..."
sed -i.bak 's/^/0.0.0.0 /' all_blocked_domains.txt

# Step 3: Download exempt list
echo "3. Downloading exempt list..."
wget -O exempt.txt https://raw.githubusercontent.com/skillmio/dns/master/files/exempt.txt

# Step 4: Filter out exempt domains
echo "4. Excluding exempt domains..."
grep -Fvx -f exempt.txt all_blocked_domains.txt > clean_blocked_domains.txt

# Step 5: Sort & deduplicate
echo "5. Sorting & removing duplicates..."
sort -u clean_blocked_domains.txt -o clean_blocked_domains.txt

# Stats
echo ""
echo "=== RESULTS ==="
echo "Total gravity domains: $(wc -l < all_blocked_domains.txt)"
echo "Clean domains (after exempt filter): $(wc -l < clean_blocked_domains.txt)"
echo ""
echo "Files created:"
echo "  all_blocked_domains.txt ($(wc -l < all_blocked_domains.txt) lines)"
echo "  clean_blocked_domains.txt ($(wc -l < clean_blocked_domains.txt) lines) - READY FOR UPLOAD"
echo "  exempt.txt (downloaded)"
echo "  all_blocked_domains.txt.bak (backup)"

echo ""
echo "Next: scp $(whoami)@$(hostname):/tmp/clean_blocked_domains.txt ."

