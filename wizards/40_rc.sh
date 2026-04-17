#!/bin/bash
# Wizard 40: RealtyCalendar credentials
# Collects and validates RC_EMAIL / RC_PASSWORD

header "RealtyCalendar — учётные данные"
log_step "40_rc" "start"

info "RealtyCalendar нужен для синхронизации броней и управления ценами."

RC_EMAIL=$(ask "Email от RealtyCalendar" "${INSTALL_STATE[rc_email]:-}")
RC_PASSWORD=$(ask_secret "Пароль от RealtyCalendar")

if [ -z "$RC_EMAIL" ] || [ -z "$RC_PASSWORD" ]; then
    warn "Учётные данные RealtyCalendar не введены."
    warn "Вы сможете настроить их позже в admin_web → Интеграции → RealtyCalendar."
    log_step "40_rc" "skipped (empty)"
else
    info "Проверяю подключение к RealtyCalendar..."
    RC_RESPONSE=$(curl -sf --connect-timeout 10 \
        -X POST "https://realtycalendar.ru/api/v2/sign_in" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${RC_EMAIL}\",\"password\":\"${RC_PASSWORD}\"}" \
        2>/dev/null)
    RC_STATUS=$?

    if [ $RC_STATUS -ne 0 ] || [ -z "$RC_RESPONSE" ]; then
        warn "Не удалось подключиться к RealtyCalendar (нет ответа)."
        warn "Учётные данные сохранены — проверьте вручную в admin_web."
    else
        # Check for token in response (successful auth returns token)
        if echo "$RC_RESPONSE" | grep -q '"token"'; then
            ok "RealtyCalendar: авторизация успешна"
        else
            RC_ERROR=$(echo "$RC_RESPONSE" | grep -o '"error":"[^"]*"' | head -1)
            warn "RealtyCalendar: ошибка авторизации. ${RC_ERROR:-Проверьте email и пароль.}"
            warn "Учётные данные сохранены — исправьте в admin_web при необходимости."
        fi
    fi

    save_state "rc_email" "$RC_EMAIL"
    save_state "rc_password" "$RC_PASSWORD"
    ok "Учётные данные RealtyCalendar сохранены"
fi

log_step "40_rc" "done"
