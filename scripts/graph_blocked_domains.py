#!/usr/bin/env python3
"""
Script Name: graph_blocked_domains.py

Description:
1. Pulls latest from GitHub (or clones if repo doesn't exist) safely with stash
2. Counts domains inside blocked_domains.txt
3. Stores weekly history
4. Generates a BAR graph
5. Exports graph and history CSV to /tmp/CoSec/files/
6. Syncs history CSV and graph PNG to GitHub

Designed for Linux headless environments.

Requirements:
dnf install -y python3-pip git
pip3 install matplotlib pandas
"""

import os
import datetime
import subprocess
import shutil
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Required for headless servers
import matplotlib.pyplot as plt

# ==============================
# CONFIGURATION
# ==============================

BLOCKED_DOMAINS_FILE = "/tmp/CoSec/blocked_domains.txt"
HISTORY_FILE = "/tmp/CoSec/files/blocked_domains_history.csv"
EXPORT_DIR = "/tmp/CoSec/files"
GRAPH_FILE = os.path.join(EXPORT_DIR, "blocked_domains_graph.png")

# GitHub Settings
REPO_DIR = "/tmp/CoSec"
BRANCH = "main"
BOT_USER = "bot-updater"
BOT_EMAIL = "bot@skillmio.net"
COMMIT_MSG = "Update blocked domains history and graph via bot-updater"

# ==============================
# ENSURE EXPORT DIRECTORY EXISTS
# ==============================

os.makedirs(EXPORT_DIR, exist_ok=True)
print(f"✅ Directory ready: {EXPORT_DIR}")

# ==============================
# GITHUB SYNC (Pull first, clone if needed, using stash)
# ==============================

print("🔄 Pulling latest changes from GitHub safely...")

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
if not GITHUB_TOKEN:
    print("ERROR: GITHUB_TOKEN environment variable not set.")
    exit(1)

REPO_URL = f"https://{GITHUB_TOKEN}@github.com/skillmio/CoSec.git"

if not os.path.exists(REPO_DIR):
    subprocess.run(["git", "clone", REPO_URL, REPO_DIR], check=True)
else:
    subprocess.run(["git", "-C", REPO_DIR, "checkout", BRANCH], check=True)

    # Stash local changes before pull
    stash_result = subprocess.run(
        ["git", "-C", REPO_DIR, "stash"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True
    )
    if "No local changes" not in stash_result.stdout:
        print("🗄 Local changes stashed to allow pull.")

    # Pull latest changes
    subprocess.run(["git", "-C", REPO_DIR, "pull", "origin", BRANCH], check=True)

    # Apply stashed changes back
    pop_result = subprocess.run(
        ["git", "-C", REPO_DIR, "stash", "pop"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True
    )
    if "conflict" in pop_result.stdout.lower() or "conflict" in pop_result.stderr.lower():
        print("⚠️ Conflicts detected when applying stashed changes. Please resolve manually.")

# ==============================
# CHECK IF BLOCKED DOMAINS FILE EXISTS, CREATE IF MISSING
# ==============================

if not os.path.exists(BLOCKED_DOMAINS_FILE):
    print(f"⚠️ {BLOCKED_DOMAINS_FILE} not found. Creating empty file.")
    os.makedirs(os.path.dirname(BLOCKED_DOMAINS_FILE), exist_ok=True)
    with open(BLOCKED_DOMAINS_FILE, "w") as f:
        f.write("")

# ==============================
# COUNT DOMAIN ENTRIES
# ==============================

with open(BLOCKED_DOMAINS_FILE, "r") as f:
    domains = [line.strip() for line in f if line.strip()]

domain_count = len(domains)
print(f"Total blocked domains: {domain_count}")

# ==============================
# GET CURRENT DATE
# ==============================

today = datetime.date.today()

# ==============================
# UPDATE HISTORY (create if missing)
# ==============================

new_data = pd.DataFrame({"date": [today], "count": [domain_count]})

if os.path.exists(HISTORY_FILE):
    history = pd.read_csv(HISTORY_FILE)
    history = pd.concat([history, new_data], ignore_index=True)
else:
    print(f"⚠️ {HISTORY_FILE} not found. Creating new history.")
    history = new_data

# Remove duplicate dates
history = history.drop_duplicates(subset=["date"], keep="last")
history.to_csv(HISTORY_FILE, index=False)
print("✅ History updated.")

# ==============================
# GENERATE BAR GRAPH
# ==============================

history["date"] = pd.to_datetime(history["date"])

plt.figure()
plt.bar(history["date"].dt.strftime("%Y-%m-%d"), history["count"])
plt.xlabel("Date")
plt.ylabel("Number of Blocked Domains")
plt.title("Blocked Domains Trend Over Time")
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig(GRAPH_FILE)
print(f"✅ Graph exported to: {GRAPH_FILE}")

# ==============================
# COPY AND PUSH TO GITHUB
# ==============================

# Copy only CSV and graph to repo
for file_path in [HISTORY_FILE, GRAPH_FILE]:
    shutil.copy(file_path, REPO_DIR)

# Configure Git user
subprocess.run(["git", "-C", REPO_DIR, "config", "user.name", BOT_USER], check=True)
subprocess.run(["git", "-C", REPO_DIR, "config", "user.email", BOT_EMAIL], check=True)

# Commit & push
subprocess.run(["git", "-C", REPO_DIR, "add", "."], check=True)

commit = subprocess.run(
    ["git", "-C", REPO_DIR, "commit", "-m", COMMIT_MSG],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    universal_newlines=True
)

if "nothing to commit" in commit.stdout:
    print("No changes to commit.")
else:
    subprocess.run(["git", "-C", REPO_DIR, "push", "origin", BRANCH], check=True)

print("✅ History CSV and graph PNG synced to GitHub!")
print("Done.")
