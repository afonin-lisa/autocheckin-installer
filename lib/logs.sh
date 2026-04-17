#!/bin/bash
# Logging to /var/log/autocheckin/

LOGDIR="/var/log/autocheckin"
LOGFILE="$LOGDIR/install.log"

init_logs() {
    mkdir -p "$LOGDIR"
    echo "=== AutoCheckin Install $(date -Iseconds) ===" >> "$LOGFILE"
}

log() {
    echo "[$(date -Iseconds)] $1" >> "$LOGFILE"
}

log_step() {
    local step="$1"
    local status="$2"
    log "STEP $step: $status"
}
