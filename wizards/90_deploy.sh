#!/bin/bash
# Wizard 90: Deploy AutoCheckin
header "Шаг 10/12: Развёртывание"

cd "$INSTALL_DIR"

# 1. Generate secrets
info "Генерирую секреты..."
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
GUEST_DATA_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || python3 -c "import base64,os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())")
save_state "secret_key" "$SECRET_KEY"
save_state "db_password" "$DB_PASSWORD"
save_state "guest_data_key" "$GUEST_DATA_KEY"
ok "Секреты сгенерированы"

# 2. Fill .env from template
info "Создаю конфигурацию..."
cp "$INSTALLER_DIR/templates/.env.template" "$INSTALL_DIR/.env"

# Core
sed -i "s|__DB_PASSWORD__|${DB_PASSWORD}|g" "$INSTALL_DIR/.env"
sed -i "s|__SECRET_KEY__|${SECRET_KEY}|g" "$INSTALL_DIR/.env"
sed -i "s|__GUEST_DATA_KEY__|${GUEST_DATA_KEY}|g" "$INSTALL_DIR/.env"
sed -i "s|__LICENSE_KEY__|${INSTALL_STATE[license_key]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__DOMAIN__|${INSTALL_STATE[domain]:-localhost}|g" "$INSTALL_DIR/.env"
sed -i "s|__MODULES__|${INSTALL_STATE[modules]:-guest,cleaning,admin_web}|g" "$INSTALL_DIR/.env"

# RealtyCalendar
sed -i "s|__RC_EMAIL__|${INSTALL_STATE[rc_email]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__RC_PASSWORD__|${INSTALL_STATE[rc_password]:-}|g" "$INSTALL_DIR/.env"

# Keysher
sed -i "s|__KEYSHER_TOKEN__|${INSTALL_STATE[keysher_token]:-}|g" "$INSTALL_DIR/.env"

# Bots
sed -i "s|__MAX_BOT_TOKEN__|${INSTALL_STATE[max_bot_token]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__TG_BOT_TOKEN__|${INSTALL_STATE[tg_bot_token]:-}|g" "$INSTALL_DIR/.env"

# SMS
sed -i "s|__SMS_PROVIDER__|${INSTALL_STATE[sms_provider]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__SMS_LOGIN__|${INSTALL_STATE[sms_login]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__SMS_PASSWORD__|${INSTALL_STATE[sms_password]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__SMS_FALLBACK__|${INSTALL_STATE[sms_fallback_provider]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__SMS_FALLBACK_KEY__|${INSTALL_STATE[sms_api_key]:-}|g" "$INSTALL_DIR/.env"

# Email
sed -i "s|__SMTP_HOST__|${INSTALL_STATE[smtp_host]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__SMTP_PORT__|${INSTALL_STATE[smtp_port]:-465}|g" "$INSTALL_DIR/.env"
sed -i "s|__SMTP_USER__|${INSTALL_STATE[smtp_user]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__SMTP_PASS__|${INSTALL_STATE[smtp_pass]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__SMTP_FROM__|${INSTALL_STATE[smtp_from]:-}|g" "$INSTALL_DIR/.env"

# AI
sed -i "s|__AI_PRIMARY__|${INSTALL_STATE[ai_primary]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__YANDEX_API_KEY__|${INSTALL_STATE[yandex_api_key]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__YANDEX_FOLDER_ID__|${INSTALL_STATE[yandex_folder_id]:-}|g" "$INSTALL_DIR/.env"
sed -i "s|__GIGACHAT_AUTH_KEY__|${INSTALL_STATE[gigachat_auth_key]:-}|g" "$INSTALL_DIR/.env"

chmod 600 "$INSTALL_DIR/.env"
ok ".env создан (chmod 600)"

# 3. Copy docker-compose + Caddyfile
cp "$INSTALLER_DIR/templates/docker-compose.yml" "$INSTALL_DIR/"
DOMAIN="${INSTALL_STATE[domain]:-localhost}"
sed "s|__DOMAIN__|${DOMAIN}|g" "$INSTALLER_DIR/templates/Caddyfile" > "$INSTALL_DIR/Caddyfile"
ok "docker-compose.yml + Caddyfile скопированы"

# 4. Docker registry login
REGISTRY="registry.afonin-lisa.ru"
info "Подключаюсь к Docker Registry..."
if echo "${INSTALL_STATE[license_key]:-}" | docker login "$REGISTRY" -u license --password-stdin 2>/dev/null; then
    ok "Registry: $REGISTRY"
else
    warn "Наш registry недоступен, пробую GitHub Container Registry..."
    REGISTRY="ghcr.io/afonin-lisa"
    GITHUB_TOKEN=$(ask_secret "GitHub Token (для ghcr.io, или Enter для пропуска)")
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "$GITHUB_TOKEN" | docker login ghcr.io -u autocheckin --password-stdin 2>/dev/null || {
            fail "Не удалось войти ни в один registry. Проверьте LICENSE_KEY или GITHUB_TOKEN"
        }
        ok "Registry: ghcr.io"
    else
        fail "Docker registry недоступен. Установка невозможна без образа."
    fi
fi
sed -i "s|__REGISTRY__|${REGISTRY}|g" "$INSTALL_DIR/.env"

# 5. Pull images
info "Скачиваю образы (это может занять 2-5 мин)..."
cd "$INSTALL_DIR"
docker compose pull || fail "Не удалось скачать образы"
ok "Образы загружены"

# 6. Start services
info "Запускаю сервисы..."
docker compose up -d || fail "Не удалось запустить сервисы"

# 7. Wait for healthy
info "Ожидаю запуска приложения..."
if wait_for_healthy "http://localhost:8800/health" 120; then
    ok "Приложение запущено"
else
    warn "Приложение не ответило за 120 сек"
    echo "  Проверьте логи: docker compose -f $INSTALL_DIR/docker-compose.yml logs app"
fi

# 8. Database migrations
info "Миграции БД..."
docker compose exec -T app alembic upgrade head 2>/dev/null && ok "Миграции применены" || warn "Миграции уже применены или ошибка"

# 9. Systemd unit
info "Устанавливаю systemd unit..."
cp "$INSTALLER_DIR/templates/systemd/autocheckin.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable autocheckin 2>/dev/null
ok "Systemd: autocheckin.service enabled"

# 10. Smoke tests
info "Smoke-тесты..."
SMOKE_OK=true
check_url "http://localhost:8800/health" || { warn "Health endpoint не отвечает"; SMOKE_OK=false; }
check_url "http://localhost:8800/admin/" || { warn "Admin panel не отвечает"; SMOKE_OK=false; }
if [ "$SMOKE_OK" = true ]; then
    ok "Все smoke-тесты пройдены"
else
    warn "Некоторые тесты не пройдены — проверьте логи"
fi

# 11. Version history
INSTALLER_VERSION="${INSTALLER_VERSION:-1.0.0}"
cat > "$INSTALL_DIR/version-history.json" << VJSON
{
  "installations": [{
    "version": "$INSTALLER_VERSION",
    "image": "${REGISTRY}/autocheckin:latest",
    "timestamp": "$(date -Iseconds)",
    "action": "install"
  }],
  "current_version": "$INSTALLER_VERSION"
}
VJSON
ok "Version history записан"

log_step "90_deploy" "success"
