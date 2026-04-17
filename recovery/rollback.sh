#!/bin/bash
# Rollback AutoCheckin to previous version
set -euo pipefail

INSTALLER_DIR="/opt/autocheckin-installer"
INSTALL_DIR="/opt/autocheckin"

# Source libs
for lib in "$INSTALLER_DIR"/lib/*.sh; do source "$lib"; done

cd "$INSTALL_DIR"
header "Откат на предыдущую версию"

# Check version history
if [ ! -f version-history.json ]; then
    fail "Нет истории версий (version-history.json)"
fi

CURRENT=$(python3 -c "import json; d=json.load(open('version-history.json')); print(d['current_version'])")
PREVIOUS_IMAGE=$(python3 -c "
import json
d=json.load(open('version-history.json'))
installs = d['installations']
if len(installs) < 2:
    print('')
else:
    print(installs[-2]['image'])
")

if [ -z "$PREVIOUS_IMAGE" ]; then
    fail "Нет предыдущей версии для отката"
fi

info "Текущая: $CURRENT"
info "Откат к: $PREVIOUS_IMAGE"

# Pre-rollback backup
info "Бэкап перед откатом..."
./backup.sh 2>/dev/null || warn "Бэкап не удался"
BACKUP_FILE=$(ls -t backups/*.sql.gz 2>/dev/null | head -1)
[ -n "$BACKUP_FILE" ] && ok "Бэкап: $BACKUP_FILE"

# Restore pre-update backup if exists
PRE_UPDATE=$(ls -t backups/pre-update-*.sql.gz 2>/dev/null | head -1)
if [ -n "$PRE_UPDATE" ]; then
    info "Восстанавливаю БД из $PRE_UPDATE..."
    gunzip -c "$PRE_UPDATE" | docker compose exec -T postgres psql -U autocheckin -d autocheckin > /dev/null 2>&1
    ok "БД восстановлена"
fi

# Pull previous image
IMAGE_TAG=$(echo "$PREVIOUS_IMAGE" | sed 's|.*/autocheckin:||')
sed -i "s|IMAGE_TAG=.*|IMAGE_TAG=${IMAGE_TAG}|" .env
docker compose pull || fail "Не удалось скачать предыдущий образ"
docker compose up -d || fail "Не удалось запустить"

# Wait for healthy
if wait_for_healthy "http://localhost:8800/health" 60; then
    ok "Откат успешен"
else
    fail "Сервис не запустился после отката — требуется ручное вмешательство"
fi

# Update history
python3 -c "
import json
from datetime import datetime
d = json.load(open('version-history.json'))
d['installations'].append({
    'version': '$IMAGE_TAG',
    'image': '$PREVIOUS_IMAGE',
    'timestamp': datetime.now().isoformat(),
    'action': 'rollback',
    'db_backup': '${BACKUP_FILE:-none}'
})
d['current_version'] = '$IMAGE_TAG'
json.dump(d, open('version-history.json','w'), indent=2)
"
ok "История версий обновлена"
