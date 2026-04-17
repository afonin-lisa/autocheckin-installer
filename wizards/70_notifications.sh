#!/bin/bash
# Wizard 70: SMS + Email notifications
# SMS: smsc_ru / sms_ru / skip
# Email: SMTP (Yandex defaults)

header "Уведомления — SMS и Email"
log_step "70_notifications" "start"

info "Настройте SMS и Email для отправки уведомлений гостям и администраторам."
info "Все поля опциональны — можно пропустить и настроить позже в admin_web."

# ── SMS Provider ─────────────────────────────────────────────────────────────
echo
SMS_CHOICE=$(choose "Провайдер SMS-рассылки" "smsc.ru" "sms.ru" "Пропустить")

case "$SMS_CHOICE" in
    "smsc.ru")
        info "Настройка SMSC.RU"
        SMSC_LOGIN=$(ask "SMSC логин")
        SMSC_PASSWORD=$(ask_secret "SMSC пароль")
        if [ -n "$SMSC_LOGIN" ] && [ -n "$SMSC_PASSWORD" ]; then
            save_state "sms_provider" "smsc_ru"
            save_state "smsc_login" "$SMSC_LOGIN"
            save_state "smsc_password" "$SMSC_PASSWORD"
            ok "SMSC.RU сохранён: логин ${SMSC_LOGIN}"
        else
            warn "SMSC.RU: не все данные введены, SMS-провайдер не сохранён."
        fi
        ;;

    "sms.ru")
        info "Настройка SMS.RU"
        SMS_RU_API_ID=$(ask "SMS.RU API ID")
        if [ -n "$SMS_RU_API_ID" ]; then
            save_state "sms_provider" "sms_ru"
            save_state "sms_ru_api_id" "$SMS_RU_API_ID"
            ok "SMS.RU сохранён: API ID ${SMS_RU_API_ID}"
        else
            warn "SMS.RU: API ID не введён, SMS-провайдер не сохранён."
        fi
        ;;

    "Пропустить"|*)
        info "SMS-провайдер пропущен. Настройте в admin_web → Уведомления → SMS."
        ;;
esac

# ── Email / SMTP ─────────────────────────────────────────────────────────────
echo
if confirm "Настроить SMTP для email-уведомлений?"; then
    info "Настройка SMTP (по умолчанию: Яндекс.Почта)"

    SMTP_HOST=$(ask "SMTP хост" "smtp.yandex.ru")
    SMTP_PORT=$(ask "SMTP порт" "465")
    SMTP_USER=$(ask "SMTP пользователь (email)")
    SMTP_PASSWORD=$(ask_secret "SMTP пароль")
    SMTP_FROM=$(ask "Email отправителя" "${SMTP_USER}")

    if [ -n "$SMTP_HOST" ] && [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASSWORD" ]; then
        save_state "smtp_host" "$SMTP_HOST"
        save_state "smtp_port" "$SMTP_PORT"
        save_state "smtp_user" "$SMTP_USER"
        save_state "smtp_password" "$SMTP_PASSWORD"
        save_state "smtp_from" "${SMTP_FROM:-$SMTP_USER}"
        ok "SMTP сохранён: ${SMTP_USER}@${SMTP_HOST}:${SMTP_PORT}"
    else
        warn "SMTP: не все обязательные поля заполнены (хост, пользователь, пароль)."
        warn "Email-уведомления будут недоступны. Настройте в admin_web → Уведомления → Email."
    fi
else
    info "SMTP пропущен. Настройте в admin_web → Уведомления → Email."
fi

log_step "70_notifications" "done"
ok "Шаг уведомлений завершён"
