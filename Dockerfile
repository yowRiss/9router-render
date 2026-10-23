# Render deploy for 9router — runs official prebuilt image, no source build.
# Cold start data restore + 10-min backup of /app/data to a HF dataset repo.
FROM decolua/9router:latest

USER root
RUN apk add --no-cache python3 py3-pip \
    && pip3 install --break-system-packages --no-cache-dir "huggingface_hub"

WORKDIR /app

RUN cat > /app/sync.py <<'PY'
import os
import tarfile
import time
import sys
from pathlib import Path
from huggingface_hub import HfApi, hf_hub_download

REPO_ID = os.environ.get("DATASET_REPO")
TOKEN = os.environ.get("HF_TOKEN")
BACKUP_FILE = "/tmp/9router_backup.tar.gz"
DATA_DIR = Path("/app/data")

def safe_extract(tar, path):
    base = Path(path).resolve()
    for member in tar.getmembers():
        target = (base / member.name).resolve()
        if not str(target).startswith(str(base)):
            raise RuntimeError(f"Unsafe tar member: {member.name}")
    tar.extractall(path)

def upload():
    if not REPO_ID or not TOKEN:
        print(">>> [Sync] DATASET_REPO or HF_TOKEN not configured. Skipping backup.", flush=True)
        return
    if not DATA_DIR.exists():
        print(">>> [Sync] Data directory does not exist. Skipping backup.", flush=True)
        return
    try:
        with tarfile.open(BACKUP_FILE, "w:gz") as tar:
            tar.add(str(DATA_DIR), arcname="data")
        HfApi(token=TOKEN).upload_file(
            path_or_fileobj=BACKUP_FILE,
            path_in_repo="9router_backup.tar.gz",
            repo_id=REPO_ID,
            repo_type="dataset",
        )
        print(f">>> [Sync] Backup successful: {time.strftime('%Y-%m-%d %H:%M:%S')}", flush=True)
    except Exception as e:
        print(f">>> [Sync] Backup failed: {e}", flush=True)

def download():
    if not REPO_ID or not TOKEN:
        print(">>> [Sync] DATASET_REPO or HF_TOKEN not configured. Skipping restore.", flush=True)
        return
    try:
        print(">>> [Sync] Downloading data from Dataset...", flush=True)
        path = hf_hub_download(
            repo_id=REPO_ID,
            filename="9router_backup.tar.gz",
            repo_type="dataset",
            token=TOKEN,
        )
        with tarfile.open(path, "r:gz") as tar:
            safe_extract(tar, "/app")
        print(">>> [Sync] Data restore successful.", flush=True)
    except Exception as e:
        print(f">>> [Sync] Skipping restore (might be first run): {e}", flush=True)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "upload":
        upload()
    elif len(sys.argv) > 1 and sys.argv[1] == "download":
        download()
PY

RUN cat > /app/run.sh <<'SH'
#!/bin/sh
set -e
echo '=== 0. Preparing Local Data ==='
mkdir -p /app/data

echo '=== 1. Restoring Data from HF Dataset ==='
python3 /app/sync.py download

echo '=== 2. Starting Scheduled Backup (every 10 min) ==='
(while true; do sleep 600; python3 /app/sync.py upload; done) &

echo '=== 3. Starting 9router ==='
# Render injects PORT (default 10000) and RENDER_EXTERNAL_URL.
export PORT="${PORT:-10000}"
export HOSTNAME=0.0.0.0
export DATA_DIR=/app/data
export NEXT_PUBLIC_BASE_URL="${RENDER_EXTERNAL_URL:-http://localhost:${PORT}}"
export BASE_URL="${RENDER_EXTERNAL_URL:-http://localhost:${PORT}}"
# Random JWT secret per boot unless provided (keeps logins working across restarts when set)
if [ -z "$JWT_SECRET" ]; then
  export JWT_SECRET="$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")"
fi

exec node server.js
SH

RUN chmod +x /app/run.sh

EXPOSE 10000
CMD ["/bin/sh", "/app/run.sh"]
