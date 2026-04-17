#!/bin/bash
# Wizard 99: Backup setup
header "Шаг 12/12: Резервное копирование"

BACKUP_DIR="$INSTALL_DIR/backups"
mkdir -p "$BACKUP_DIR"

# Create backup script
cat > "$INSTALL_DIR/backup.sh" << 'BSCRIPT'
#!/bin/bash
# AutoCheckin Daily Backup
BACKUP_DIR="/opt/autocheckin/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/autocheckin-${TIMESTAMP}.sql.gz"

# Dump database
docker compose -f /opt/autocheckin/docker-compose.yml exec -T postgres \
    pg_dump -U autocheckin autocheckin 2>/dev/null | gzip > "$BACKUP_FILE"

if [ -s "$BACKUP_FILE" ]; then
    echo "[$(date -Iseconds)] Backup OK: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | awk '{print $1}'))"
else
    echo "[$(date -Iseconds)] Backup FAILED: empty file"
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Retention: keep 14 days
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +14 -delete
BSCRIPT
chmod +x "$INSTALL_DIR/backup.sh"
ok "Скрипт бэкапа создан"

# Add cron (avoid duplicates)
CRON_LINE="0 3 * * * /opt/autocheckin/backup.sh >> /var/log/autocheckin/backup.log 2>&1"
(crontab -l 2>/dev/null | grep -v "autocheckin/backup.sh"; echo "$CRON_LINE") | crontab -
ok "Cron: ежедневно в 03:00"

# Auto-update cron (daily at 04:00)
info "Настраиваю автообновление..."
UPDATE_CRON="0 4 * * * /opt/autocheckin-installer/update-cron.sh"
(crontab -l 2>/dev/null | grep -v "update-cron.sh"; echo "$UPDATE_CRON") | crontab -
ok "Auto-update: ежедневно в 04:00"

# Test backup
info "Тестовый бэкап..."
if "$INSTALL_DIR/backup.sh" >> /var/log/autocheckin/backup.log 2>&1; then
    LATEST=$(ls -t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | head -1)
    ok "Тестовый бэкап: $(du -h "$LATEST" | awk '{print $1}')"
else
    warn "Тестовый бэкап не удался — проверьте позже"
fi

info "Хранение: 14 дней, директория: $BACKUP_DIR"
log_step "99_backup" "done"
