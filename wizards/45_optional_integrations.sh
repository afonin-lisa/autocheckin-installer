#!/bin/bash
# Wizard 45: Optional integrations (payments, partners, anti-fraud, vision, IoT)
# All sections are optional and can be skipped. Re-run later via /opt/autocheckin/configure.sh
#
# Reads existing values from $CONFIG_FILE (so re-run preserves choices).
# Writes selected values back to $CONFIG_FILE for later use by 90_deploy.sh.

set -uo pipefail

CONFIG_FILE="${CONFIG_FILE:-/opt/autocheckin/.install-config}"
NONI="${AUTOCHECKIN_NONINTERACTIVE:-0}"

# Inherit color/printer helpers from caller; provide fallbacks if used standalone
type ok      >/dev/null 2>&1 || ok()      { echo -e "\033[0;32m✅ $1\033[0m"; }
type warn    >/dev/null 2>&1 || warn()    { echo -e "\033[1;33m⚠️  $1\033[0m"; }
type info    >/dev/null 2>&1 || info()    { echo -e "\033[0;36m▸ $1\033[0m"; }
type header  >/dev/null 2>&1 || header()  { echo -e "\n\033[1;36m═══ $1 ═══\033[0m\n"; }
type ask     >/dev/null 2>&1 || ask()     { local p="$1" d="${2:-}"; if [ "$NONI" = "1" ]; then echo "$d"; return; fi; if [ -n "$d" ]; then echo -en "\033[0;36m▸ $p [$d]: \033[0m" >&2; else echo -en "\033[0;36m▸ $p: \033[0m" >&2; fi; read -r r; echo "${r:-$d}"; }
type ask_secret >/dev/null 2>&1 || ask_secret() { if [ "$NONI" = "1" ]; then echo ""; return; fi; echo -en "\033[0;36m▸ $1: \033[0m" >&2; read -rs r; echo >&2; echo "$r"; }
type save_cfg   >/dev/null 2>&1 || save_cfg() { local k="$1" v="$2"; touch "$CONFIG_FILE"; sed -i "/^$k=/d" "$CONFIG_FILE"; echo "$k=$v" >> "$CONFIG_FILE"; }
type get_cfg    >/dev/null 2>&1 || get_cfg() { grep "^$1=" "$CONFIG_FILE" 2>/dev/null | tail -1 | cut -d= -f2-; }

# Skip wizard entirely in non-interactive mode unless --force passed
if [ "$NONI" = "1" ] && [ "${WIZARD_45_FORCE:-0}" != "1" ]; then
    exit 0
fi

ask_yn() {
    local p="$1" d="${2:-n}"
    local r
    r=$(ask "$p (y/N)" "$d")
    [[ "${r,,}" =~ ^(y|yes|да|д)$ ]]
}

header "Дополнительные интеграции (всё опционально)"
echo "Любую секцию можно пропустить — добавите потом через"
echo "  sudo /opt/autocheckin/configure.sh"
echo ""

# ───────────────────────── Платежи ─────────────────────────
if ask_yn "Настроить платежи (T-Bank / Moneta / YooKassa)?"; then
    header "Платежи"

    if ask_yn "T-Bank Internet Acquiring (терминал)?"; then
        save_cfg tbank_terminal_key       "$(ask        'TBANK_TERMINAL_KEY (TerminalKey)')"
        save_cfg tbank_terminal_password  "$(ask_secret 'TBANK_TERMINAL_PASSWORD (Password)')"
        save_cfg tbank_test_mode          "$(ask        'Test mode (1/0)' '0')"
        ok "T-Bank EACQ сохранён"
    fi

    if ask_yn "T-Bank Business API (SBP-ссылки, баланс)?"; then
        save_cfg tbank_api_token              "$(ask_secret 'TBANK_API_TOKEN')"
        save_cfg tbank_business_account       "$(ask        'Номер расчётного счёта')"
        ok "T-Bank Business API сохранён"
    fi

    if ask_yn "Moneta?"; then
        save_cfg moneta_account_id  "$(ask        'MONETA_ACCOUNT_ID')"
        save_cfg moneta_secret_key  "$(ask_secret 'MONETA_SECRET_KEY')"
        save_cfg moneta_test_mode   "$(ask        'Test mode (1/0)' '0')"
        ok "Moneta сохранён"
    fi

    if ask_yn "YooKassa (резервный gateway)?"; then
        save_cfg yookassa_shop_id    "$(ask        'YOOKASSA_SHOP_ID')"
        save_cfg yookassa_secret_key "$(ask_secret 'YOOKASSA_SECRET_KEY')"
        ok "YooKassa сохранён"
    fi

    if ask_yn "Прямой SBP по номеру (без эквайринга)?"; then
        save_cfg sbp_phone "$(ask 'Номер телефона для SBP (+7…)')"
        save_cfg sbp_bank  "$(ask 'Банк (например: Tinkoff, Sber)')"
        ok "Прямой SBP сохранён"
    fi
fi

# ───────────────────────── Партнёры ─────────────────────────
if ask_yn "Настроить партнёров (такси/доставка/экскурсии)?"; then
    header "Партнёры"

    if ask_yn "Tripster (экскурсии)?"; then
        save_cfg tripster_token "$(ask_secret 'TRIPSTER_TOKEN (X-Auth-Token)')"
        save_cfg tripster_city  "$(ask        'Город по умолчанию (например moscow, samara)' 'moscow')"
        ok "Tripster сохранён"
    fi

    if ask_yn "Yandex Go (такси) — расчёт стоимости + deep links?"; then
        save_cfg yandex_go_clid    "$(ask        'YANDEX_GO_CLID')"
        save_cfg yandex_go_apikey  "$(ask_secret 'YANDEX_GO_APIKEY')"
        save_cfg yandex_go_ref     "$(ask        'Реф-метка (для AppMetrica), Enter для пропуска')"
        ok "Yandex Go сохранён"
    fi

    if ask_yn "Yandex Delivery (доставка из магазина)?"; then
        save_cfg yandex_delivery_apikey      "$(ask_secret 'YANDEX_DELIVERY_API_KEY')"
        save_cfg yandex_delivery_client_id   "$(ask        'YANDEX_DELIVERY_CLIENT_ID')"
        save_cfg yandex_delivery_pickup_addr "$(ask        'Адрес склада (откуда забирают)')"
        save_cfg yandex_delivery_pickup_lat  "$(ask        'Широта склада'  '53.195878')"
        save_cfg yandex_delivery_pickup_lon  "$(ask        'Долгота склада' '50.100202')"
        ok "Yandex Delivery сохранён"
    fi

    if ask_yn "Yandex Eda / Market / Travel (партнёрские deep links)?"; then
        save_cfg yandex_eda_promo     "$(ask 'Промо-код Yandex Eda, Enter для пропуска')"
        save_cfg yandex_market_clid   "$(ask 'Yandex Market CLID, Enter для пропуска')"
        save_cfg yandex_travel_clid   "$(ask 'Yandex Travel CLID, Enter для пропуска')"
        ok "Yandex deep links сохранены"
    fi
fi

# ────────────────── Проверка гостей ──────────────────
if ask_yn "Подключить NumBuster (репутация телефонов)?"; then
    header "NumBuster"
    save_cfg numbuster_token       "$(ask_secret 'NUMBUSTER_ACCESS_TOKEN')"
    save_cfg numbuster_min_trust   "$(ask        'Минимальный trust index (0-100, 0=отключено)' '0')"
    save_cfg numbuster_extra_dep   "$(ask        'Доп. сумма залога при низком рейтинге (₽)' '0')"
    ok "NumBuster сохранён"
fi

# ────────────────── ZenMoney ──────────────────
if ask_yn "ZenMoney (учёт фактических поступлений)?"; then
    header "ZenMoney"
    save_cfg zenmoney_token       "$(ask_secret 'ZENMONEY_DIRECT_TOKEN (zerro, бессрочный)')"
    save_cfg zenmoney_profile_id  "$(ask        'ZENMONEY_PROFILE_ID' '0')"
    ok "ZenMoney сохранён"
fi

# ────────────────── Vision (паспорта/камеры) ──────────────────
if ask_yn "Vision: распознавание паспортов и/или лиц гостей?"; then
    header "Vision"

    if ask_yn "Cloudflare R2 (хранение фото/видео)?"; then
        save_cfg r2_account_id   "$(ask        'R2_ACCOUNT_ID')"
        save_cfg r2_access_key   "$(ask_secret 'R2_ACCESS_KEY')"
        save_cfg r2_secret_key   "$(ask_secret 'R2_SECRET_KEY')"
        save_cfg r2_bucket       "$(ask        'R2_BUCKET (имя bucket)')"
        ok "Cloudflare R2 сохранён"
    fi

    if ask_yn "AWS Rekognition (распознавание лиц гостей)?"; then
        save_cfg aws_access_key  "$(ask_secret 'AWS_ACCESS_KEY')"
        save_cfg aws_secret_key  "$(ask_secret 'AWS_SECRET_KEY')"
        save_cfg aws_region      "$(ask        'AWS_REGION' 'eu-central-1')"
        ok "AWS Rekognition сохранён"
    fi
fi

# ────────────────── Tuya (камеры/розетки) ──────────────────
if ask_yn "Tuya Smart (камеры, умные розетки)?"; then
    header "Tuya"
    save_cfg tuya_access_id     "$(ask_secret 'TUYA_ACCESS_ID')"
    save_cfg tuya_access_secret "$(ask_secret 'TUYA_ACCESS_SECRET')"
    save_cfg tuya_endpoint      "$(ask        'TUYA_ENDPOINT' 'https://openapi.tuyaeu.com')"
    ok "Tuya сохранён"
fi

ok "Дополнительные интеграции — готово (всё опционально, можно дополнить позже)"
exit 0
