#!/bin/bash
# Wizard 80: AI provider
# yandex_gpt / gigachat / skip

header "AI-провайдер"
log_step "80_ai" "start"

info "AI используется для автоматических ответов гостям и генерации описаний."
info "Можно пропустить — сервис работает без AI, с шаблонными ответами."

echo
AI_CHOICE=$(choose "Выберите AI-провайдер" "YandexGPT" "GigaChat" "Пропустить")

case "$AI_CHOICE" in
    "YandexGPT")
        info "Настройка YandexGPT"
        info "Получить API Key и Folder ID: https://console.yandex.cloud/"

        YAGPT_API_KEY=$(ask_secret "YandexGPT API Key")
        YAGPT_FOLDER_ID=$(ask "YandexGPT Folder ID")

        if [ -n "$YAGPT_API_KEY" ] && [ -n "$YAGPT_FOLDER_ID" ]; then
            info "Проверяю YandexGPT..."
            YAGPT_RESPONSE=$(curl -sf --connect-timeout 10 \
                -X POST "https://llm.api.cloud.yandex.net/foundationModels/v1/completion" \
                -H "Authorization: Api-Key ${YAGPT_API_KEY}" \
                -H "Content-Type: application/json" \
                -d "{\"modelUri\":\"gpt://${YAGPT_FOLDER_ID}/yandexgpt-lite\",\"completionOptions\":{\"maxTokens\":1},\"messages\":[{\"role\":\"user\",\"text\":\"ping\"}]}" \
                2>/dev/null)
            YAGPT_STATUS=$?

            if [ $YAGPT_STATUS -ne 0 ] || [ -z "$YAGPT_RESPONSE" ]; then
                warn "Не удалось проверить YandexGPT (нет ответа)."
                warn "Ключи сохранены — проверьте вручную в admin_web."
            elif echo "$YAGPT_RESPONSE" | grep -qiE '"error"|"code":[^0]'; then
                ERR=$(echo "$YAGPT_RESPONSE" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
                warn "YandexGPT: ошибка — ${ERR:-неверный ключ или folder_id}."
                warn "Ключи сохранены — исправьте в admin_web при необходимости."
            else
                ok "YandexGPT: подключено"
            fi

            save_state "ai_primary" "yandex_gpt"
            save_state "yandex_gpt_api_key" "$YAGPT_API_KEY"
            save_state "yandex_gpt_folder_id" "$YAGPT_FOLDER_ID"
            ok "YandexGPT сохранён"
        else
            warn "YandexGPT: не все данные введены. AI-провайдер не настроен."
            warn "Настройте в admin_web → AI → YandexGPT."
        fi
        ;;

    "GigaChat")
        info "Настройка GigaChat (Сбер)"
        info "Получить Authorization Key: https://developers.sber.ru/portal/products/gigachat"

        GIGACHAT_AUTH_KEY=$(ask_secret "GigaChat Authorization Key (base64)")

        if [ -n "$GIGACHAT_AUTH_KEY" ]; then
            info "Проверяю GigaChat (получение токена)..."
            GIGA_TOKEN_RESPONSE=$(curl -sf --connect-timeout 10 \
                -X POST "https://ngw.devices.sberbank.ru:9443/api/v2/oauth" \
                -H "Authorization: Basic ${GIGACHAT_AUTH_KEY}" \
                -H "RqUID: $(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo 'install-wizard')" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "scope=GIGACHAT_API_PERS" \
                --insecure \
                2>/dev/null)
            GIGA_STATUS=$?

            if [ $GIGA_STATUS -ne 0 ] || [ -z "$GIGA_TOKEN_RESPONSE" ]; then
                warn "Не удалось проверить GigaChat (нет ответа)."
                warn "Ключ сохранён — проверьте вручную в admin_web."
            elif echo "$GIGA_TOKEN_RESPONSE" | grep -q '"access_token"'; then
                ok "GigaChat: авторизация успешна"
            else
                ERR=$(echo "$GIGA_TOKEN_RESPONSE" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4)
                warn "GigaChat: ошибка — ${ERR:-неверный ключ}."
                warn "Ключ сохранён — исправьте в admin_web при необходимости."
            fi

            save_state "ai_primary" "gigachat"
            save_state "gigachat_auth_key" "$GIGACHAT_AUTH_KEY"
            ok "GigaChat сохранён"
        else
            warn "GigaChat: Authorization Key не введён. AI-провайдер не настроен."
            warn "Настройте в admin_web → AI → GigaChat."
        fi
        ;;

    "Пропустить"|*)
        info "AI-провайдер пропущен."
        info "Сервис будет работать на шаблонных ответах без AI."
        info "Настройте AI в любой момент в admin_web → AI."
        ;;
esac

log_step "80_ai" "done"
ok "Шаг AI-провайдера завершён"
