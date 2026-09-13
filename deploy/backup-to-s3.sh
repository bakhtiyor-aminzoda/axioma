#!/usr/bin/env bash
# ==============================================================================
# Axioma Production Remote Disaster Recovery Backup Script
# ==============================================================================
# Performs automated PostgreSQL dumps, archives critical configs, compresses,
# and synchronizes to offsite Cloudflare R2 / AWS S3 storage with GFS retention.
# ==============================================================================

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/axioma/backups}"
DATE=$(date +%Y%m%d_%H%M%S)
DAY_OF_WEEK=$(date +%u) # 1=Monday, 7=Sunday
DAY_OF_MONTH=$(date +%d)
APP_DIR="${APP_DIR:-/opt/axioma}"
ENV_FILE="${APP_DIR}/.env"

# Ensure backup directories exist
mkdir -p "${BACKUP_DIR}/daily"
mkdir -p "${BACKUP_DIR}/weekly"
mkdir -p "${BACKUP_DIR}/monthly"
mkdir -p "${BACKUP_DIR}/configs"

echo "[$(date -u)] Starting Axioma backup..."

# 1. Dump PostgreSQL database directly from Docker container
DB_CONTAINER="axioma_postgres"
DB_NAME="chatwoot_production"
DB_USER="postgres"
DUMP_FILE="${BACKUP_DIR}/daily/axioma_db_${DATE}.sql.gz"

if docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "[$(date -u)] Exporting PostgreSQL database from ${DB_CONTAINER}..."
    docker exec "${DB_CONTAINER}" pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip -9 > "${DUMP_FILE}"
    echo "[$(date -u)] Database dump created: ${DUMP_FILE} ($(du -h "${DUMP_FILE}" | cut -f1))"
else
    echo "[$(date -u)] ERROR: PostgreSQL container ${DB_CONTAINER} is not running!" >&2
    exit 1
fi

# 2. Archive critical configuration files (excluding secrets from public logs)
CONFIG_ARCHIVE="${BACKUP_DIR}/configs/axioma_configs_${DATE}.tar.gz"
tar -czf "${CONFIG_ARCHIVE}" -C "${APP_DIR}" .env deploy/ 2>/dev/null || true
echo "[$(date -u)] Config archive created: ${CONFIG_ARCHIVE}"

# 3. GFS Rotation (Weekly on Sunday, Monthly on 1st)
if [ "${DAY_OF_MONTH}" = "01" ]; then
    echo "[$(date -u)] Archiving monthly snapshot..."
    cp "${DUMP_FILE}" "${BACKUP_DIR}/monthly/"
elif [ "${DAY_OF_WEEK}" = "7" ]; then
    echo "[$(date -u)] Archiving weekly snapshot..."
    cp "${DUMP_FILE}" "${BACKUP_DIR}/weekly/"
fi

# 4. Offsite Sync to Cloudflare R2 / AWS S3 (if S3_BACKUP_BUCKET is configured)
if [ -n "${S3_BACKUP_BUCKET:-}" ]; then
    echo "[$(date -u)] Uploading backups to remote S3/R2 bucket: ${S3_BACKUP_BUCKET}..."
    if command -v aws &> /dev/null; then
        aws s3 sync "${BACKUP_DIR}" "s3://${S3_BACKUP_BUCKET}/axioma-backups" \
            --endpoint-url="${S3_ENDPOINT:-https://s3.amazonaws.com}" \
            --delete
        echo "[$(date -u)] Offsite sync completed via AWS CLI."
    elif command -v rclone &> /dev/null; then
        rclone sync "${BACKUP_DIR}" "r2:axioma-backups"
        echo "[$(date -u)] Offsite sync completed via Rclone."
    else
        echo "[$(date -u)] WARNING: Neither 'aws' nor 'rclone' installed. Offsite upload skipped."
    fi
fi

# 5. Local Retention Pruning: Keep 7 daily, 4 weekly, 3 monthly
echo "[$(date -u)] Pruning expired local backups..."
find "${BACKUP_DIR}/daily" -type f -name "*.sql.gz" -mtime +7 -delete
find "${BACKUP_DIR}/weekly" -type f -name "*.sql.gz" -mtime +28 -delete
find "${BACKUP_DIR}/monthly" -type f -name "*.sql.gz" -mtime +90 -delete
find "${BACKUP_DIR}/configs" -type f -name "*.tar.gz" -mtime +30 -delete

echo "[$(date -u)] Backup completed successfully."