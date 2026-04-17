#!/bin/bash
# autocheckin-agent — reverse SSH tunnel + integrity checks
set -euo pipefail

BASTION_HOST="${BASTION_HOST:-bastion.afonin-lisa.ru}"
BASTION_PORT="${BASTION_PORT:-2222}"
BASTION_USER="${BASTION_USER:-tunnel-user}"
REMOTE_PORT="${REMOTE_PORT:-30000}"
SSH_KEY="${SSH_KEY:-/keys/id_ed25519}"
CHECK_INTERVAL="${CHECK_INTERVAL:-600}"

echo "[agent] Starting autocheckin-agent..."
echo "[agent] Bastion: ${BASTION_USER}@${BASTION_HOST}:${BASTION_PORT}"
echo "[agent] Tunnel: remote port ${REMOTE_PORT} → localhost:22"

# Wait for SSH key
if [ ! -f "$SSH_KEY" ]; then
    echo "[agent] ERROR: SSH key not found at $SSH_KEY"
    echo "[agent] Generate with: ssh-keygen -t ed25519 -f /opt/autocheckin/.ssh/id_ed25519 -N ''"
    exit 1
fi

# Start autossh reverse tunnel in background
export AUTOSSH_PIDFILE=/tmp/autossh.pid
export AUTOSSH_GATETIME=0
export AUTOSSH_LOGFILE=/var/log/autocheckin/tunnel.log

mkdir -p /var/log/autocheckin

autossh -M 0 -f -N \
    -o "ServerAliveInterval=30" \
    -o "ServerAliveCountMax=3" \
    -o "StrictHostKeyChecking=accept-new" \
    -o "ExitOnForwardFailure=yes" \
    -o "ConnectTimeout=10" \
    -i "$SSH_KEY" \
    -R "${REMOTE_PORT}:localhost:22" \
    -p "$BASTION_PORT" \
    "${BASTION_USER}@${BASTION_HOST}" || {
    echo "[agent] WARNING: Tunnel failed to start — will retry"
}

echo "[agent] Tunnel started (pid: $(cat /tmp/autossh.pid 2>/dev/null || echo 'unknown'))"

# Run integrity checks periodically
while true; do
    # Check tunnel is alive
    if [ -f /tmp/autossh.pid ] && kill -0 "$(cat /tmp/autossh.pid)" 2>/dev/null; then
        echo "[agent] Tunnel: alive"
    else
        echo "[agent] Tunnel: dead — autossh will restart"
    fi

    # Integrity check
    /opt/agent/integrity.sh 2>/dev/null || echo "[agent] Integrity check error"

    sleep "$CHECK_INTERVAL"
done
