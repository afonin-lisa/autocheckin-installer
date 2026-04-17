#!/bin/bash
# AutoCheckin Auto-Update with pre-backup and auto-rollback
set -euo pipefail

INSTALLER_DIR="/opt/autocheckin-installer"
INSTALL_DIR="/opt/autocheckin"
LOGFILE="/var/log/autocheckin/update.log"

# Source libs
for lib in "$INSTALLER_DIR"/lib/*.sh; do source "$lib"; done

log_update() { echo "[$(date -Iseconds)] $1" >> "$LOGFILE"; }

cd "$INSTALL_DIR"
log_update "=== Update started ==="

# 1. Get current image tag
CURRENT_IMAGE=$(docker compose images app --format json 2>/dev/null | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['Tag'] if data else 'latest')" 2>/dev/null || echo "latest")
log_update "Current: $CURRENT_IMAGE"

# 2. Check for new image (dry-run pull)
info "Проверяю обновления..."
PULL_OUTPUT=$(docker compose pull app 2>&1)
if echo "$PULL_OUTPUT" | grep -q "up to date"; then
    log_update "No updates available"
    info "Обновлений нет"
    exit 0
fi
log_update "New image available"

# 3. Pre-update backup
info "Бэкап перед обновлением..."
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$INSTALL_DIR/backups/pre-update-${TIMESTAMP}.sql.gz"
docker compose exec -T postgres pg_dump -U autocheckin autocheckin 2>/dev/null | gzip > "$BACKUP_FILE"
if [ ! -s "$BACKUP_FILE" ]; then
    log_update "ABORT: backup failed"
    warn "Бэкап не удался — обновление отменено"
    rm -f "$BACKUP_FILE"
    exit 1
fi
log_update "Backup: $BACKUP_FILE"

# 4. Apply update
info "Применяю обновление..."
docker compose up -d app 2>&1 | tee -a "$LOGFILE"

# 5. Wait for healthy
info "Ожидаю запуска..."
sleep 10
HEALTHY=false
for i in $(seq 1 24); do
    if curl -sf http://localhost:8800/health > /dev/null 2>&1; then
        HEALTHY=true
        break
    fi
    sleep 5
done

# 6. Smoke test
if [ "$HEALTHY" = true ]; then
    # Additional smoke: check DB connection
    if docker compose exec -T app python -c "from app.core.db.engine import engine; print('db ok')" 2>/dev/null | grep -q "db ok"; then
        log_update "Update SUCCESS: healthy + DB ok"
        ok "Обновление успешно"

        # Update version history
        NEW_IMAGE=$(docker compose images app --format json 2>/dev/null | python3 -c "import sys,json; data=json.load(sys.stdin); print(data[0]['Tag'] if data else 'latest')" 2>/dev/null || echo "latest")
        python3 -c "
import json
from datetime import datetime
f = '$INSTALL_DIR/version-history.json'
try:
    d = json.load(open(f))
except:
    d = {'installations': [], 'current_version': 'unknown'}
d['installations'].append({
    'version': '$NEW_IMAGE',
    'image': '$(docker compose images app --format "{{.Repository}}:{{.Tag}}" 2>/dev/null || echo "unknown")',
    'timestamp': datetime.now().isoformat(),
    'action': 'auto-update',
    'db_backup': '$BACKUP_FILE'
})
d['current_version'] = '$NEW_IMAGE'
json.dump(d, open(f,'w'), indent=2)
" 2>/dev/null
        exit 0
    fi
fi

# 7. Auto-rollback
log_update "Update FAILED — rolling back"
warn "Обновление не прошло smoke-тесты — откат..."

# Restore DB
gunzip -c "$BACKUP_FILE" | docker compose exec -T postgres psql -U autocheckin -d autocheckin > /dev/null 2>&1

# Restore previous image
docker compose pull app 2>/dev/null  # re-pull with old tag
docker compose up -d app 2>&1

sleep 15
if curl -sf http://localhost:8800/health > /dev/null 2>&1; then
    log_update "Rollback SUCCESS"
    warn "Откат выполнен — работает на предыдущей версии"
else
    log_update "Rollback FAILED — manual intervention needed"
    fail "Откат не удался — требуется ручное вмешательство"
fi
