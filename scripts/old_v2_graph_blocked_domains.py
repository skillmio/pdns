#!/usr/bin/env python3
"""
Script Name: graph_blocked_domains.py

Description:
- Pulls latest from GitHub (or clones if missing)
- Counts domains inside blocked_domains.txt
- Stores weekly history (auto-upgrades old CSV formats)
- Generates graphs (total blocked domains & weekly growth)
- Exports files to /tmp/CoSec/files/
- Syncs history CSV and graphs to GitHub under files/ folder
- Compatible with Python 3.6+
"""

import os
import datetime
import subprocess
import shutil
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ==============================
# CONFIGURATION
# ==============================

REPO_DIR = "/tmp/CoSec"
EXPORT_DIR = "/tmp/CoSec/files"

BLOCKED_FILE = os.path.join(REPO_DIR, "blocked_domains.txt")
HISTORY_FILE = os.path.join(EXPORT_DIR, "blocked_domains_history.csv")

GRAPH_TOTAL = os.path.join(EXPORT_DIR, "blocked_domains_graph.png")
GRAPH_GROWTH = os.path.join(EXPORT_DIR, "blocked_domains_growth_graph.png")

BRANCH = "main"
BOT_USER = "bot-updater"
BOT_EMAIL = "bot@skillmio.net"
COMMIT_MSG = "Update blocked domains statistics"

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN")
if not GITHUB_TOKEN:
    print("ERROR: GITHUB_TOKEN not set")
    exit(1)
REPO_URL = f"https://{GITHUB_TOKEN}@github.com/skillmio/CoSec.git"

# ==============================
# PREPARE DIRECTORIES
# ==============================

os.makedirs(EXPORT_DIR, exist_ok=True)
print(f"✅ Directory ready: {EXPORT_DIR}")

# ==============================
# CLONE OR UPDATE REPO
# ==============================

print("🔄 Syncing GitHub repository...")

if not os.path.exists(REPO_DIR):
    subprocess.run(["git", "clone", REPO_URL, REPO_DIR], check=True)
else:
    subprocess.run(["git", "-C", REPO_DIR, "checkout", BRANCH], check=True)
    subprocess.run(["git", "-C", REPO_DIR, "fetch"], check=True)
    subprocess.run(["git", "-C", REPO_DIR, "reset", "--hard", f"origin/{BRANCH}"], check=True)

print("✅ Repository ready")

# ==============================
# ENSURE BLOCKED FILE EXISTS
# ==============================

if not os.path.exists(BLOCKED_FILE):
    print("⚠️ blocked_domains.txt missing, creating empty file")
    os.makedirs(os.path.dirname(BLOCKED_FILE), exist_ok=True)
    with open(BLOCKED_FILE, "w") as f:
        pass

# ==============================
# COUNT BLOCKED DOMAINS
# ==============================

with open(BLOCKED_FILE) as f:
    domains = [line.strip() for line in f if line.strip()]
domain_count = len(domains)
print(f"Total blocked domains: {domain_count}")

# ==============================
# WEEK IDENTIFIER
# ==============================

today = datetime.date.today()
week_id = today.strftime("%Y-W%U")

# ==============================
# LOAD HISTORY (with old CSV migration)
# ==============================

new_row = pd.DataFrame({
    "week": [week_id],
    "date": [today],
    "count": [domain_count]
})

if os.path.exists(HISTORY_FILE):
    history = pd.read_csv(HISTORY_FILE)
    if "week" not in history.columns:
        print("⚠️ Old history format detected — upgrading file")
        history["date"] = pd.to_datetime(history["date"], errors="coerce")
        history = history.dropna(subset=["date"])
        history["week"] = history["date"].dt.strftime("%Y-W%U")
        history = history[["week","date","count"]]
else:
    print("⚠️ Creating new history file")
    history = pd.DataFrame(columns=["week","date","count"])

# ==============================
# CLEAN HISTORY
# ==============================

history["date"] = pd.to_datetime(history["date"], errors="coerce")
history = history.dropna(subset=["date"])
history = history.drop_duplicates(subset=["week"], keep="last")

# ==============================
# ADD CURRENT WEEK
# ==============================

history = pd.concat([history, new_row], ignore_index=True)
history = history.drop_duplicates(subset=["week"], keep="last")
history = history.sort_values("date")
history.to_csv(HISTORY_FILE, index=False)
print("✅ History updated")

# ==============================
# CALCULATE WEEKLY GROWTH
# ==============================

history["growth"] = history["count"].diff()

# ==============================
# GRAPH 1 - TOTAL BLOCKED DOMAINS
# ==============================

plt.figure()
plt.bar(history["week"], history["count"])
plt.xlabel("Week")
plt.ylabel("Total Blocked Domains")
plt.title("Total Blocked Domains Over Time")
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig(GRAPH_TOTAL)
plt.close()
print(f"✅ Total graph created: {GRAPH_TOTAL}")

# ==============================
# GRAPH 2 - WEEKLY GROWTH
# ==============================

plt.figure()
plt.bar(history["week"], history["growth"].fillna(0))
plt.xlabel("Week")
plt.ylabel("Weekly Growth")
plt.title("Weekly Growth of Blocked Domains")
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig(GRAPH_GROWTH)
plt.close()
print(f"✅ Growth graph created: {GRAPH_GROWTH}")

# ==============================
# COPY FILES TO REPO (files/ folder) SAFELY
# ==============================

REPO_FILES_DIR = os.path.join(REPO_DIR, "files")
os.makedirs(REPO_FILES_DIR, exist_ok=True)

for file in [HISTORY_FILE, GRAPH_TOTAL, GRAPH_GROWTH]:
    dest_file = os.path.join(REPO_FILES_DIR, os.path.basename(file))
    if os.path.abspath(file) != os.path.abspath(dest_file):
        shutil.copy(file, dest_file)

# ==============================
# PUSH TO GITHUB
# ==============================

subprocess.run(["git","-C",REPO_DIR,"config","user.name",BOT_USER], check=True)
subprocess.run(["git","-C",REPO_DIR,"config","user.email",BOT_EMAIL], check=True)

subprocess.run(["git","-C",REPO_DIR,"add","files/blocked_domains_history.csv"], check=True)
subprocess.run(["git","-C",REPO_DIR,"add","files/blocked_domains_graph.png"], check=True)
subprocess.run(["git","-C",REPO_DIR,"add","files/blocked_domains_growth_graph.png"], check=True)

commit = subprocess.run(
    ["git","-C",REPO_DIR,"commit","-m",COMMIT_MSG],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    universal_newlines=True
)

if "nothing to commit" in commit.stdout:
    print("No changes to commit")
else:
    subprocess.run(["git","-C",REPO_DIR,"push","origin",BRANCH], check=True)
    print("✅ GitHub updated")

print("Done.")
