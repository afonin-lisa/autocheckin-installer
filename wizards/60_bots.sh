#!/bin/bash
# Wizard 60: Bot tokens (MAX + Telegram)
# MAX required; Telegram only for Pro+ tier

header "Боты — MAX и Telegram"
log_step "60_bots" "start"

CURRENT_TIER="${INSTALL_STATE[tier]:-base}"

# ── MAX Bot Token (required) ─────────────────────────────────────────────────
info "MAX Bot Token требуется для работы чат-бота с гостями."

MAX_BOT_TOKEN=$(ask_secret "MAX Bot Token")

if [ -z "$MAX_BOT_TOKEN" ]; then
    warn "MAX Bot Token не введён. Бот будет недоступен."
    warn "Настройте позже в admin_web → Боты → MAX."
else
    info "Проверяю MAX Bot Token..."
    MAX_RESPONSE=$(curl -sf --connect-timeout 10 \
        -H "Authorization: Bearer ${MAX_BOT_TOKEN}" \
        "https://api.max.ru/bot/v1/me" \
        2>/dev/null)
    MAX_STATUS=$?

    if [ $MAX_STATUS -ne 0 ] || [ -z "$MAX_RESPONSE" ]; then
        warn "Не удалось проверить MAX Bot Token (нет ответа от API)."
        warn "Токен сохранён — проверьте вручную в admin_web."
    else
        if echo "$MAX_RESPONSE" | grep -q '"user_id"'; then
            MAX_NAME=$(echo "$MAX_RESPONSE" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
            ok "MAX бот подключён: ${MAX_NAME:-OK}"
        else
            warn "MAX Bot Token отклонён. Проверьте токен в настройках бота MAX."
        fi
    fi

    save_state "max_bot_token" "$MAX_BOT_TOKEN"
    ok "MAX Bot Token сохранён"
fi

# ── Telegram Bot Token (Pro+ only) ──────────────────────────────────────────
if [ "$CURRENT_TIER" = "base" ]; then
    info "Telegram бот доступен в тарифе Pro и выше."
    info "Текущий тариф: ${CURRENT_TIER}. Шаг пропущен."
    log_step "60_bots" "done (tg skipped, base tier)"
else
    info "Telegram Bot Token (опционально — можно пропустить)."

    TG_BOT_TOKEN=$(ask_secret "Telegram Bot Token (Enter — пропустить)")

    if [ -z "$TG_BOT_TOKEN" ]; then
        info "Telegram Bot Token не введён. Пропускаю."
    else
        info "Проверяю Telegram Bot Token..."
        TG_RESPONSE=$(curl -sf --connect-timeout 10 \
            "https://api.telegram.org/bot${TG_BOT_TOKEN}/getMe" \
            2>/dev/null)
        TG_STATUS=$?

        if [ $TG_STATUS -ne 0 ] || [ -z "$TG_RESPONSE" ]; then
            warn "Не удалось проверить Telegram Bot Token (нет ответа)."
            warn "Токен сохранён — проверьте вручную в admin_web."
        else
            if echo "$TG_RESPONSE" | grep -q '"ok":true'; then
                TG_NAME=$(echo "$TG_RESPONSE" | grep -o '"username":"[^"]*"' | head -1 | cut -d'"' -f4)
                ok "Telegram бот подключён: @${TG_NAME:-OK}"
            else
                TG_DESC=$(echo "$TG_RESPONSE" | grep -o '"description":"[^"]*"' | head -1 | cut -d'"' -f4)
                warn "Telegram Bot Token отклонён: ${TG_DESC:-неверный токен}."
            fi
        fi

        save_state "tg_bot_token" "$TG_BOT_TOKEN"
        ok "Telegram Bot Token сохранён"
    fi

    log_step "60_bots" "done"
fi
