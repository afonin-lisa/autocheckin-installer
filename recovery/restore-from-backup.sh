#!/bin/bash
# Restore AutoCheckin database from backup
set -euo pipefail

INSTALLER_DIR="/opt/autocheckin-installer"
INSTALL_DIR="/opt/autocheckin"
BACKUP_DIR="$INSTALL_DIR/backups"

for lib in "$INSTALLER_DIR"/lib/*.sh; do source "$lib"; done

cd "$INSTALL_DIR"
header "Восстановление из бэкапа"

BACKUP_FILE="${1:-}"

# Interactive selection if no argument
if [ -z "$BACKUP_FILE" ]; then
    BACKUPS=($(ls -t "$BACKUP_DIR"/*.sql.gz 2>/dev/null))
    if [ ${#BACKUPS[@]} -eq 0 ]; then
        fail "Нет бэкапов в $BACKUP_DIR"
    fi
    info "Доступные бэкапы:"
    for i in "${!BACKUPS[@]}"; do
        SIZE=$(du -h "${BACKUPS[$i]}" | awk '{print $1}')
        DATE=$(stat -c %y "${BACKUPS[$i]}" | cut -d. -f1)
        echo -e "  ${BOLD}$((i+1)))${NC} $(basename "${BACKUPS[$i]}") (${SIZE}, ${DATE})"
    done
    echo
    CHOICE=$(ask "Номер бэкапа [1]" "1")
    IDX=$((CHOICE - 1))
    BACKUP_FILE="${BACKUPS[$IDX]}"
fi

if [ ! -f "$BACKUP_FILE" ]; then
    fail "Файл не найден: $BACKUP_FILE"
fi

info "Восстанавливаю из: $(basename "$BACKUP_FILE")"
warn "Текущие данные в БД будут ПЕРЕЗАПИСАНЫ!"
if ! confirm "Продолжить?"; then
    info "Отмена"
    exit 0
fi

# Stop app to prevent writes
docker compose stop app 2>/dev/null || true

# Restore
info "Восстанавливаю БД..."
gunzip -c "$BACKUP_FILE" | docker compose exec -T postgres psql -U autocheckin -d autocheckin > /dev/null 2>&1
ok "БД восстановлена"

# Start app
docker compose start app

# Run pending migrations
info "Применяю миграции..."
docker compose exec -T app alembic upgrade head 2>/dev/null || true

# Verify
if wait_for_healthy "http://localhost:8800/health" 60; then
    ok "Восстановление завершено — сервис работает"
else
    warn "Сервис не ответил — проверьте логи: docker compose logs app"
fi
