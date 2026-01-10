#!/bin/bash
###############################################################################
# Firestore Restore Script - Urban Points Lebanon
#
# Purpose: Restore Firestore database from Google Cloud Storage backup
# Usage: ./restore_firestore.sh <backup_timestamp> [environment]
# Example: ./restore_firestore.sh 20250103_020000 prod
#
# Prerequisites:
# - gcloud CLI installed and authenticated
# - Backup exists in Cloud Storage
# - IAM permissions: datastore.databases.import
#
# CAUTION: This will OVERWRITE existing data in Firestore!
# Always test restore in a non-production environment first.
###############################################################################

set -euo pipefail

# Configuration
PROJECT_ID="urbangenspark"
BACKUP_TIMESTAMP="${1:-}"
ENVIRONMENT="${2:-prod}"
BACKUP_BUCKET="gs://urbanpoints-backups"
BACKUP_PREFIX="firestore/${ENVIRONMENT}"
LOG_FILE="restore_firestore_$(date +%Y%m%d_%H%M%S).log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$LOG_FILE"
}

# Show usage
show_usage() {
    cat <<EOF
Usage: $0 <backup_timestamp> [environment]

Arguments:
  backup_timestamp    Timestamp of backup to restore (format: YYYYMMDD_HHMMSS)
  environment         Target environment: dev, staging, prod (default: prod)

Example:
  $0 20250103_020000 prod

Available backups:
EOF
    gsutil ls "${BACKUP_BUCKET}/${BACKUP_PREFIX}/" | grep -oP '\d{8}_\d{6}' | tail -10
}

# Validate arguments
validate_arguments() {
    if [ -z "$BACKUP_TIMESTAMP" ]; then
        log_error "Missing required argument: backup_timestamp"
        show_usage
        exit 1
    fi
    
    if [[ ! "$BACKUP_TIMESTAMP" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        log_error "Invalid timestamp format: $BACKUP_TIMESTAMP"
        log_error "Expected format: YYYYMMDD_HHMMSS (e.g., 20250103_020000)"
        exit 1
    fi
    
    case $ENVIRONMENT in
        dev|staging|prod)
            log_info "Restoring to environment: $ENVIRONMENT"
            ;;
        *)
            log_error "Invalid environment: $ENVIRONMENT. Must be: dev, staging, or prod"
            exit 1
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
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
    
    log_info "Prerequisites check passed"
}

# Verify backup exists
verify_backup_exists() {
    log_step "Verifying backup exists..."
    
    BACKUP_PATH="${BACKUP_BUCKET}/${BACKUP_PREFIX}/${BACKUP_TIMESTAMP}"
    
    if ! gsutil ls "${BACKUP_PATH}/" &> /dev/null; then
        log_error "Backup not found: $BACKUP_PATH"
        log_error "Available backups:"
        gsutil ls "${BACKUP_BUCKET}/${BACKUP_PREFIX}/" | grep -oP '\d{8}_\d{6}' | tail -10
        exit 1
    fi
    
    # Show backup details
    FILE_COUNT=$(gsutil ls -r "${BACKUP_PATH}/" | wc -l)
    BACKUP_SIZE=$(gsutil du -sh "${BACKUP_PATH}/" | awk '{print $1}')
    
    log_info "Backup found:"
    log_info "  - Path: $BACKUP_PATH"
    log_info "  - Files: $FILE_COUNT"
    log_info "  - Size: $BACKUP_SIZE"
}

# Show pre-restore checklist
pre_restore_checklist() {
    log_step "Pre-Restore Checklist"
    echo -e "${YELLOW}┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  PRE-RESTORE CHECKLIST - PLEASE REVIEW CAREFULLY             │${NC}"
    echo -e "${YELLOW}├──────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${YELLOW}│                                                              │${NC}"
    echo -e "${YELLOW}│  1. ✓ Backup verified in Cloud Storage                      │${NC}"
    echo -e "${YELLOW}│  2. ⚠ This will OVERWRITE all current Firestore data        │${NC}"
    echo -e "${YELLOW}│  3. ⚠ Users will experience downtime during restore          │${NC}"
    echo -e "${YELLOW}│  4. ⚠ Always test restore in non-prod environment first     │${NC}"
    echo -e "${YELLOW}│  5. ⚠ Ensure you have a recent backup of current state      │${NC}"
    echo -e "${YELLOW}│                                                              │${NC}"
    echo -e "${YELLOW}│  Environment: ${ENVIRONMENT}                                 │${NC}"
    echo -e "${YELLOW}│  Backup: ${BACKUP_TIMESTAMP}                                 │${NC}"
    echo -e "${YELLOW}│  Source: ${BACKUP_PATH}                                      │${NC}"
    echo -e "${YELLOW}│                                                              │${NC}"
    echo -e "${YELLOW}└──────────────────────────────────────────────────────────────┘${NC}"
}

# Get user confirmation
get_confirmation() {
    pre_restore_checklist
    
    echo ""
    echo -e "${RED}⚠️  WARNING: This operation will OVERWRITE existing Firestore data!${NC}"
    echo ""
    echo -n "Type 'RESTORE' to confirm (or anything else to cancel): "
    read -r confirmation
    
    if [ "$confirmation" != "RESTORE" ]; then
        log_warn "Restore cancelled by user"
        exit 0
    fi
    
    log_info "User confirmed restore operation"
}

# Create backup of current state (before restore)
backup_current_state() {
    log_step "Creating safety backup of current state..."
    
    SAFETY_BACKUP_PATH="${BACKUP_BUCKET}/${BACKUP_PREFIX}/pre-restore_$(date +%Y%m%d_%H%M%S)"
    
    log_info "Safety backup destination: $SAFETY_BACKUP_PATH"
    
    if gcloud firestore export "$SAFETY_BACKUP_PATH" \
        --project="$PROJECT_ID" \
        --async 2>&1 | tee -a "$LOG_FILE"; then
        
        log_info "Safety backup initiated"
        
        # Get operation name
        OPERATION_NAME=$(gcloud firestore operations list --project="$PROJECT_ID" --format="value(name)" --limit=1)
        
        # Wait for completion (with timeout)
        TIMEOUT=300  # 5 minutes
        ELAPSED=0
        while [ $ELAPSED -lt $TIMEOUT ]; do
            STATUS=$(gcloud firestore operations describe "$OPERATION_NAME" --project="$PROJECT_ID" --format="value(metadata.operationState)")
            
            case $STATUS in
                SUCCESSFUL)
                    log_info "Safety backup completed"
                    return 0
                    ;;
                FAILED)
                    log_error "Safety backup failed - aborting restore!"
                    exit 1
                    ;;
                *)
                    echo -n "." | tee -a "$LOG_FILE"
                    sleep 5
                    ELAPSED=$((ELAPSED + 5))
                    ;;
            esac
        done
        
        log_warn "Safety backup timeout - proceeding anyway (backup may complete in background)"
    else
        log_error "Failed to initiate safety backup - aborting restore!"
        exit 1
    fi
}

# Perform restore
perform_restore() {
    log_step "Starting Firestore restore..."
    log_info "Source: $BACKUP_PATH"
    log_info "Target: $PROJECT_ID (Firestore default database)"
    
    # Import from backup
    if gcloud firestore import "$BACKUP_PATH" \
        --project="$PROJECT_ID" \
        --async 2>&1 | tee -a "$LOG_FILE"; then
        
        log_info "Firestore import initiated successfully"
        
        # Get operation name
        OPERATION_NAME=$(gcloud firestore operations list --project="$PROJECT_ID" --format="value(name)" --limit=1)
        log_info "Operation ID: $OPERATION_NAME"
        
        # Monitor import progress
        log_info "Monitoring restore progress (this may take several minutes)..."
        while true; do
            STATUS=$(gcloud firestore operations describe "$OPERATION_NAME" --project="$PROJECT_ID" --format="value(metadata.operationState)")
            
            case $STATUS in
                SUCCESSFUL)
                    log_info "Restore completed successfully!"
                    break
                    ;;
                FAILED)
                    log_error "Restore failed!"
                    ERROR_MSG=$(gcloud firestore operations describe "$OPERATION_NAME" --project="$PROJECT_ID" --format="value(error.message)")
                    log_error "Error: $ERROR_MSG"
                    log_error "Safety backup available at: $SAFETY_BACKUP_PATH"
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
        log_error "Failed to initiate Firestore import"
        log_error "Safety backup available at: $SAFETY_BACKUP_PATH"
        exit 1
    fi
}

# Verify restore
verify_restore() {
    log_step "Verifying restore..."
    
    # Check document count in key collections
    COLLECTIONS=("customers" "merchants" "offers" "redemptions" "subscriptions")
    
    for collection in "${COLLECTIONS[@]}"; do
        log_info "Checking collection: $collection"
        # Note: This requires firestore-admin or a Cloud Function to count documents
        # For now, we'll just log that verification is manual
    done
    
    log_warn "Manual verification required:"
    log_warn "  1. Check Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID/firestore"
    log_warn "  2. Verify key collections exist: ${COLLECTIONS[*]}"
    log_warn "  3. Spot-check document counts and sample data"
    log_warn "  4. Test critical application flows (login, redemptions, etc.)"
}

# Send notification
send_notification() {
    local status=$1
    local message=$2
    
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        curl -X POST "$SLACK_WEBHOOK_URL" \
            -H 'Content-Type: application/json' \
            -d "{\"text\": \"Firestore Restore [$ENVIRONMENT] - $status\n$message\"}" \
            &> /dev/null || true
    fi
}

# Post-restore steps
post_restore_steps() {
    log_step "Post-Restore Steps"
    echo -e "${GREEN}┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│  POST-RESTORE CHECKLIST                                      │${NC}"
    echo -e "${GREEN}├──────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${GREEN}│                                                              │${NC}"
    echo -e "${GREEN}│  1. Verify data in Firebase Console                         │${NC}"
    echo -e "${GREEN}│  2. Test critical application flows                          │${NC}"
    echo -e "${GREEN}│  3. Check application logs for errors                        │${NC}"
    echo -e "${GREEN}│  4. Monitor error rates in Cloud Logging                     │${NC}"
    echo -e "${GREEN}│  5. Notify stakeholders of restore completion                │${NC}"
    echo -e "${GREEN}│  6. Update incident documentation                            │${NC}"
    echo -e "${GREEN}│                                                              │${NC}"
    echo -e "${GREEN}│  Safety Backup: ${SAFETY_BACKUP_PATH}                        │${NC}"
    echo -e "${GREEN}│  Restored From: ${BACKUP_PATH}                               │${NC}"
    echo -e "${GREEN}│                                                              │${NC}"
    echo -e "${GREEN}└──────────────────────────────────────────────────────────────┘${NC}"
}

# Main execution
main() {
    log_info "======================================"
    log_info "Firestore Restore Script - Urban Points Lebanon"
    log_info "======================================"
    log_info "Environment: $ENVIRONMENT"
    log_info "Backup Timestamp: $BACKUP_TIMESTAMP"
    log_info "Project: $PROJECT_ID"
    log_info "======================================"
    
    validate_arguments
    check_prerequisites
    verify_backup_exists
    get_confirmation
    backup_current_state
    perform_restore
    verify_restore
    
    log_info "======================================"
    log_info "Restore completed successfully!"
    log_info "Restored from: $BACKUP_PATH"
    log_info "Safety backup: $SAFETY_BACKUP_PATH"
    log_info "Log file: $LOG_FILE"
    log_info "======================================"
    
    post_restore_steps
    
    send_notification "SUCCESS" "Restore completed from backup: $BACKUP_TIMESTAMP"
    
    # Upload log to GCS
    gsutil cp "$LOG_FILE" "${BACKUP_PATH}/restore.log"
    log_info "Log uploaded to: ${BACKUP_PATH}/restore.log"
    
    exit 0
}

# Error handler
trap 'log_error "Restore failed with exit code $?"; send_notification "FAILED" "Restore failed. Check logs: $LOG_FILE. Safety backup: $SAFETY_BACKUP_PATH"; exit 1' ERR

# Run main function
main
