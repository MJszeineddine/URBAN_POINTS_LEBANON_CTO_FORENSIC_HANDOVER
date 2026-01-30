#!/bin/bash
###############################################################################
# Firestore Backup Script - Urban Points Lebanon
# 
# Purpose: Automated daily backup of Firestore database to Google Cloud Storage
# Usage: ./backup_firestore.sh [environment]
# Environment: dev | staging | prod (default: prod)
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Cloud Storage bucket created: gs://urbanpoints-backups/
# - IAM permissions: datastore.databases.export, storage.buckets.create
#
# Scheduling: Run via Cloud Scheduler daily at 2 AM UTC
# Retention: 30 days (configurable via RETENTION_DAYS)
###############################################################################

set -euo pipefail

# Configuration
PROJECT_ID="urbangenspark"
ENVIRONMENT="${1:-prod}"
BACKUP_BUCKET="gs://urbanpoints-backups"
BACKUP_PREFIX="firestore/${ENVIRONMENT}"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_BUCKET}/${BACKUP_PREFIX}/${TIMESTAMP}"
LOG_FILE="backup_firestore_${TIMESTAMP}.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Validate environment
validate_environment() {
    case $ENVIRONMENT in
        dev|staging|prod)
            log_info "Backing up Firestore for environment: $ENVIRONMENT"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT. Must be: dev, staging, or prod"
            exit 1
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check gcloud CLI
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found. Install from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log_error "gcloud not authenticated. Run: gcloud auth login"
        exit 1
    fi
    
    # Check project access
    if ! gcloud projects describe "$PROJECT_ID" &> /dev/null; then
        log_error "Cannot access project: $PROJECT_ID. Check permissions."
        exit 1
    fi
    
    # Check bucket exists
    if ! gsutil ls "$BACKUP_BUCKET" &> /dev/null; then
        log_warn "Backup bucket does not exist. Creating: $BACKUP_BUCKET"
        gsutil mb -p "$PROJECT_ID" -l us-central1 "$BACKUP_BUCKET"
        
        # Set lifecycle policy (auto-delete after RETENTION_DAYS)
        cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": ${RETENTION_DAYS}}
      }
    ]
  }
}
EOF
        gsutil lifecycle set /tmp/lifecycle.json "$BACKUP_BUCKET"
        rm /tmp/lifecycle.json
        log_info "Bucket created with ${RETENTION_DAYS}-day retention policy"
    fi
    
    log_info "Prerequisites check passed"
}

# Perform Firestore export
perform_backup() {
    log_info "Starting Firestore export..."
    log_info "Destination: $BACKUP_PATH"
    
    # Export all collections
    if gcloud firestore export "$BACKUP_PATH" \
        --project="$PROJECT_ID" \
        --async 2>&1 | tee -a "$LOG_FILE"; then
        
        log_info "Firestore export initiated successfully"
        log_info "Export path: $BACKUP_PATH"
        
        # Get operation name from output
        OPERATION_NAME=$(gcloud firestore operations list --project="$PROJECT_ID" --format="value(name)" --limit=1)
        log_info "Operation ID: $OPERATION_NAME"
        
        # Monitor export progress
        log_info "Monitoring export progress (this may take several minutes)..."
        while true; do
            STATUS=$(gcloud firestore operations describe "$OPERATION_NAME" --project="$PROJECT_ID" --format="value(metadata.operationState)")
            
            case $STATUS in
                SUCCESSFUL)
                    log_info "Backup completed successfully!"
                    break
                    ;;
                FAILED)
                    log_error "Backup failed!"
                    ERROR_MSG=$(gcloud firestore operations describe "$OPERATION_NAME" --project="$PROJECT_ID" --format="value(error.message)")
                    log_error "Error: $ERROR_MSG"
                    exit 1
                    ;;
                PROCESSING)
                    echo -n "." | tee -a "$LOG_FILE"
                    sleep 10
                    ;;
                *)
                    log_warn "Unknown status: $STATUS"
                    sleep 10
                    ;;
            esac
        done
        
    else
        log_error "Failed to initiate Firestore export"
        exit 1
    fi
}

# Verify backup
verify_backup() {
    log_info "Verifying backup..."
    
    # Check if backup files exist
    if gsutil ls "${BACKUP_PATH}/" &> /dev/null; then
        FILE_COUNT=$(gsutil ls -r "${BACKUP_PATH}/" | wc -l)
        BACKUP_SIZE=$(gsutil du -sh "${BACKUP_PATH}/" | awk '{print $1}')
        
        log_info "Backup verified:"
        log_info "  - Files: $FILE_COUNT"
        log_info "  - Size: $BACKUP_SIZE"
        log_info "  - Location: $BACKUP_PATH"
    else
        log_error "Backup verification failed: No files found at $BACKUP_PATH"
        exit 1
    fi
}

# Cleanup old backups (beyond retention period)
cleanup_old_backups() {
    log_info "Checking for old backups to clean up..."
    
    # List all backup directories older than RETENTION_DAYS
    CUTOFF_DATE=$(date -d "${RETENTION_DAYS} days ago" +%Y%m%d)
    
    OLD_BACKUPS=$(gsutil ls "${BACKUP_BUCKET}/${BACKUP_PREFIX}/" | grep -oP '\d{8}_\d{6}' | while read backup_ts; do
        backup_date=$(echo "$backup_ts" | cut -d'_' -f1)
        if [ "$backup_date" -lt "$CUTOFF_DATE" ]; then
            echo "${BACKUP_BUCKET}/${BACKUP_PREFIX}/${backup_ts}/"
        fi
    done)
    
    if [ -n "$OLD_BACKUPS" ]; then
        log_info "Found old backups to delete:"
        echo "$OLD_BACKUPS" | tee -a "$LOG_FILE"
        
        echo "$OLD_BACKUPS" | while read old_backup; do
            log_info "Deleting: $old_backup"
            gsutil -m rm -r "$old_backup"
        done
        
        log_info "Old backups cleaned up"
    else
        log_info "No old backups to clean up"
    fi
}

# Send notification (optional - requires configuration)
send_notification() {
    local status=$1
    local message=$2
    
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"Firestore Backup [$ENVIRONMENT] - $status\n$message\"}" \
            &> /dev/null || true
    fi
}

# Main execution
main() {
    log_info "======================================"
    log_info "Firestore Backup Script - Urban Points Lebanon"
    log_info "======================================"
    log_info "Environment: $ENVIRONMENT"
    log_info "Timestamp: $TIMESTAMP"
    log_info "Project: $PROJECT_ID"
    log_info "======================================"
    
    validate_environment
    check_prerequisites
    perform_backup
    verify_backup
    cleanup_old_backups
    
    log_info "======================================"
    log_info "Backup completed successfully!"
    log_info "Backup path: $BACKUP_PATH"
    log_info "Log file: $LOG_FILE"
    log_info "======================================"
    
    send_notification "SUCCESS" "Backup completed: $BACKUP_PATH"
    
    # Upload log to GCS
    gsutil cp "$LOG_FILE" "${BACKUP_PATH}/backup.log"
    log_info "Log uploaded to: ${BACKUP_PATH}/backup.log"
    
    exit 0
}

# Error handler
trap 'log_error "Backup failed with exit code $?"; send_notification "FAILED" "Backup failed. Check logs: $LOG_FILE"; exit 1' ERR

# Run main function
main
