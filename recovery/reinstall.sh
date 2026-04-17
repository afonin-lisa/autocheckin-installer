#!/bin/bash
# Full reinstall AutoCheckin (preserves data via backup/restore)
set -euo pipefail

INSTALLER_DIR="/opt/autocheckin-installer"
INSTALL_DIR="/opt/autocheckin"

for lib in "$INSTALLER_DIR"/lib/*.sh; do source "$lib"; done

header "Полная переустановка AutoCheckin"

if ! confirm "Это удалит контейнеры и volumes, но сохранит данные через бэкап. Продолжить?"; then
    info "Отмена"
    exit 0
fi

# Save config and backups
info "Сохраняю конфигурацию..."
cp "$INSTALL_DIR/.env" /tmp/autocheckin-env-backup 2>/dev/null || true
mkdir -p /tmp/autocheckin-backups
cp -r "$INSTALL_DIR/backups/"* /tmp/autocheckin-backups/ 2>/dev/null || true

# Create fresh backup
info "Бэкап перед переустановкой..."
cd "$INSTALL_DIR"
./backup.sh 2>/dev/null || warn "Бэкап не удался"
cp "$INSTALL_DIR/backups/"*.sql.gz /tmp/autocheckin-backups/ 2>/dev/null || true

# Tear down
info "Останавливаю и удаляю контейнеры..."
docker compose down -v 2>/dev/null || true

# Reinstall with saved env
info "Запускаю переустановку..."
"$INSTALLER_DIR/install.sh" --keep-env

# Restore latest backup
LATEST_BACKUP=$(ls -t /tmp/autocheckin-backups/*.sql.gz 2>/dev/null | head -1)
if [ -n "$LATEST_BACKUP" ]; then
    info "Восстанавливаю БД из $LATEST_BACKUP..."
    cd "$INSTALL_DIR"
    gunzip -c "$LATEST_BACKUP" | docker compose exec -T postgres psql -U autocheckin -d autocheckin > /dev/null 2>&1
    docker compose exec -T app alembic upgrade head 2>/dev/null || true
    ok "Данные восстановлены"
fi

# Restore backups directory
cp /tmp/autocheckin-backups/*.sql.gz "$INSTALL_DIR/backups/" 2>/dev/null || true

ok "Переустановка завершена"
