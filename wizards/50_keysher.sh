#!/bin/bash
# Wizard 50: Keysher token
# Uses token from license step or asks manually; shows lock count

header "Keysher — токен доступа"
log_step "50_keysher" "start"

info "Keysher управляет умными замками (TTLock) для автоматической выдачи кодов гостям."

# Use token from license step if available
KEYSHER_TOKEN="${INSTALL_STATE[keysher_token]:-}"

if [ -z "$KEYSHER_TOKEN" ]; then
    info "Токен Keysher не найден в лицензии. Введите вручную."
    KEYSHER_TOKEN=$(ask_secret "Keysher API токен")
fi

if [ -z "$KEYSHER_TOKEN" ]; then
    warn "Токен Keysher не введён. Управление замками будет недоступно."
    warn "Настройте позже в admin_web → Интеграции → Keysher."
    log_step "50_keysher" "skipped (empty)"
else
    info "Проверяю подключение к Keysher..."
    KEYSHER_RESPONSE=$(curl -sf --connect-timeout 10 \
        -H "Authorization: Bearer ${KEYSHER_TOKEN}" \
        "https://keysher.afonin-lisa.ru/api/v2/locks" \
        2>/dev/null)
    KEYSHER_STATUS=$?

    if [ $KEYSHER_STATUS -ne 0 ] || [ -z "$KEYSHER_RESPONSE" ]; then
        warn "Не удалось подключиться к Keysher (нет ответа)."
        warn "Токен сохранён — проверьте вручную в admin_web."
    else
        # Count locks in response
        LOCK_COUNT=$(echo "$KEYSHER_RESPONSE" | grep -o '"id"' | wc -l)
        if echo "$KEYSHER_RESPONSE" | grep -q '"error"'; then
            ERR=$(echo "$KEYSHER_RESPONSE" | grep -o '"error":"[^"]*"' | head -1)
            warn "Keysher: ошибка. ${ERR:-Неверный токен.}"
            warn "Токен сохранён — исправьте в admin_web при необходимости."
        else
            ok "Keysher: подключено. Замков найдено: ${LOCK_COUNT}"
        fi
    fi

    save_state "keysher_token" "$KEYSHER_TOKEN"
    ok "Токен Keysher сохранён"
fi

log_step "50_keysher" "done"
