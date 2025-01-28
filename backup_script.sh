#!/bin/bash

# Load environment variables
load_env() {
    if [ -f .env ]; then
        source .env
    fi
}

# Validate required variables
validate_env() {
    if [[ -z "$RESTIC_REPO" || -z "$RCLONE_REMOTE" || -z "$RESTIC_PASSWORD" ]]; then
        echo "[$DATE] ERROR: One or more required variables are not set. Check your environment or .env file." | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Log setup
setup_logging() {
    exec > >(tee -a "$LOG_FILE") 2>&1
}

# Run Restic backup
run_backup() {
    echo "[$DATE] Running Restic backup..."
    if restic -r "$RESTIC_REPO" backup "$BACKUP_DIR"; then
        echo "[$DATE] Restic backup completed successfully."
        BACKUP_STATUS="success"
    else
        echo "[$DATE] Restic backup failed."
        BACKUP_STATUS="failure"
    fi
}

# Verify Restic repository
verify_backup() {
    echo "[$DATE] Verifying Restic repository..."
    if ! restic -r "$RESTIC_REPO" check; then
        echo "[$DATE] Restic repository check failed!"
        BACKUP_STATUS="failure"
    fi
}

# Run Rclone sync as fallback
run_rclone_sync() {
    echo "[$DATE] Running Rclone sync as a fallback..."
    if rclone sync "$BACKUP_DIR" "$RCLONE_REMOTE/docker-backups"; then
        echo "[$DATE] Rclone sync completed successfully."
    else
        echo "[$DATE] Rclone sync failed!"
        BACKUP_STATUS="failure"
    fi
}

# Prune old backups in Restic
prune_old_backups() {
    echo "[$DATE] Pruning old backups in Restic..."
    if restic -r "$RESTIC_REPO" forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune; then
        echo "[$DATE] Old backups pruned successfully."
    else
        echo "[$DATE] Failed to prune old backups!"
        BACKUP_STATUS="failure"
    fi
}

main() {
    DATE=$(date +'%Y-%m-%d_%H-%M-%S')
    LOG_FILE="${LOG_FILE:-/var/log/backup.log}"
    BACKUP_DIR="${BACKUP_DIR:-/srv/docker}"
    BACKUP_STATUS="success"

    load_env
    validate_env
    setup_logging

    echo "[$DATE] Starting backup process..."
    run_backup
    verify_backup
    run_rclone_sync
    prune_old_backups
    echo "[$DATE] Backup process completed."
}

main "$@"