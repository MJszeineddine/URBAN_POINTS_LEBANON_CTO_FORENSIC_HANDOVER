#!/bin/bash

###############################################################################
# Firestore Backup Automation Script
# 
# Purpose: Export Firestore data to Google Cloud Storage for backup
# Schedule: Run daily via cron or Cloud Scheduler
# 
# Requirements:
# - gcloud CLI installed and authenticated
# - IAM roles: datastore.importExportAdmin, storage.admin
# - Cloud Storage bucket created
###############################################################################

set -e

# Configuration
PROJECT_ID="${FIREBASE_PROJECT_ID:-urbangenspark}"
BUCKET_NAME="${BACKUP_BUCKET:-gs://urbanpoints-backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_PATH="${BUCKET_NAME}/firestore-backups/${TIMESTAMP}"

# Collections to backup (all by default, or specify specific ones)
COLLECTIONS="${BACKUP_COLLECTIONS:-}"

# Logging
LOG_FILE="/var/log/firestore-backup.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "========================================="
echo "Firestore Backup Started: $(date)"
echo "Project: $PROJECT_ID"
echo "Destination: $BACKUP_PATH"
echo "========================================="

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "ERROR: gcloud CLI not found. Please install it first."
    exit 1
fi

# Check if authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "ERROR: Not authenticated with gcloud. Run 'gcloud auth login' first."
    exit 1
fi

# Set project
gcloud config set project "$PROJECT_ID"

# Create backup
echo "Creating Firestore export..."

if [ -z "$COLLECTIONS" ]; then
    # Backup all collections
    gcloud firestore export "$BACKUP_PATH" \
        --async \
        --project="$PROJECT_ID"
else
    # Backup specific collections
    gcloud firestore export "$BACKUP_PATH" \
        --collection-ids="$COLLECTIONS" \
        --async \
        --project="$PROJECT_ID"
fi

EXPORT_STATUS=$?

if [ $EXPORT_STATUS -eq 0 ]; then
    echo "✅ Backup export initiated successfully!"
    echo "Backup location: $BACKUP_PATH"
    
    # Log backup metadata to Firestore
    cat > /tmp/backup-metadata.json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "backup_path": "$BACKUP_PATH",
  "project_id": "$PROJECT_ID",
  "collections": "$COLLECTIONS",
  "status": "initiated"
}
EOF
    
    # Optional: Send notification
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"✅ Firestore backup initiated: $BACKUP_PATH\"}" \
            "$SLACK_WEBHOOK_URL"
    fi
    
    echo "========================================="
    echo "Backup Completed: $(date)"
    echo "========================================="
else
    echo "❌ Backup export failed with status $EXPORT_STATUS"
    
    # Send failure notification
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"❌ Firestore backup FAILED: $PROJECT_ID\"}" \
            "$SLACK_WEBHOOK_URL"
    fi
    
    exit 1
fi

# Cleanup old backups (keep last 30 days)
echo "Cleaning up old backups (older than 30 days)..."
THIRTY_DAYS_AGO=$(date -d "30 days ago" +%Y%m%d 2>/dev/null || date -v-30d +%Y%m%d)

gsutil ls "$BUCKET_NAME/firestore-backups/" | while read backup_dir; do
    backup_date=$(basename "$backup_dir" | cut -d'-' -f1)
    if [ "$backup_date" -lt "$THIRTY_DAYS_AGO" ]; then
        echo "Deleting old backup: $backup_dir"
        gsutil -m rm -r "$backup_dir" || echo "Warning: Failed to delete $backup_dir"
    fi
done

echo "Cleanup completed"

# Verify backup integrity (optional)
echo "Verifying backup integrity..."
BACKUP_SIZE=$(gsutil du -s "$BACKUP_PATH" 2>/dev/null | awk '{print $1}')

if [ -n "$BACKUP_SIZE" ] && [ "$BACKUP_SIZE" -gt 0 ]; then
    echo "✅ Backup integrity verified (size: $BACKUP_SIZE bytes)"
else
    echo "⚠️  Warning: Could not verify backup size immediately (export may still be in progress)"
fi

exit 0
