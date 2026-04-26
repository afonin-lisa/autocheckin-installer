#!/bin/bash
# AutoCheckin Configure — изменить интеграции после установки.
#
# Запуск:  sudo /opt/autocheckin/configure.sh           (меню)
#          sudo /opt/autocheckin/configure.sh tripster  (только Tripster)
#
# После каждого изменения автоматически перезапускает app-контейнер чтобы
# подхватить новый .env. Не трогает сторонние файлы и БД.

set -uo pipefail

INSTALL_DIR="/opt/autocheckin"
ENV_FILE="$INSTALL_DIR/.env"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"

[ "$(id -u)" -eq 0 ] || { echo "Запустите от root: sudo $0"; exit 1; }
[ -f "$ENV_FILE" ] || { echo "Не найден $ENV_FILE — autocheckin не установлен?"; exit 1; }

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

ok()     { echo -e "${GREEN}✅ $1${NC}"; }
warn()   { echo -e "${YELLOW}⚠️  $1${NC}"; }
info()   { echo -e "${CYAN}▸ $1${NC}"; }
header() { echo -e "\n${BOLD}${CYAN}═══ $1 ═══${NC}\n"; }

ask() {
    local prompt="$1" default="${2:-}"
    if [ -n "$default" ]; then
        echo -en "${CYAN}▸ ${prompt} [${default}]: ${NC}" >&2
    else
        echo -en "${CYAN}▸ ${prompt}: ${NC}" >&2
    fi
    read -r REPLY
    echo "${REPLY:-$default}"
}

ask_secret() {
    echo -en "${CYAN}▸ $1: ${NC}" >&2
    read -rs REPLY
    echo >&2
    echo "$REPLY"
}

# Set environment variable in .env (idempotent: replaces if exists, adds if not)
set_env() {
    local key="$1" value="$2"
    if grep -qE "^${key}=" "$ENV_FILE"; then
        # escape & for sed
        local esc=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
        sed -i "s|^${key}=.*|${key}=${esc}|" "$ENV_FILE"
    else
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

get_env() {
    grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2-
}

is_set() {
    local v
    v=$(get_env "$1")
    [ -n "$v" ] && echo -e "${GREEN}✓${NC}" || echo -e "${DIM}—${NC}"
}

restart_app() {
    info "Перезапуск AutoCheckin для применения .env…"
    if cd "$INSTALL_DIR" 2>/dev/null && docker compose restart app >/dev/null 2>&1; then
        ok "AutoCheckin перезапущен"
    else
        warn "Не удалось перезапустить через docker compose. Перезапустите вручную: docker restart autocheckin-app"
    fi
}

# ───────────────────────── Конфигураторы ─────────────────────────

cfg_rc() {
    header "RealtyCalendar"
    set_env AC_RC_EMAIL    "$(ask        'Email RealtyCalendar' "$(get_env AC_RC_EMAIL)")"
    set_env AC_RC_PASSWORD "$(ask_secret 'Пароль RealtyCalendar')"
    ok "RealtyCalendar обновлён"
}

cfg_max() {
    header "MAX бот"
    set_env AC_MAX_BOT_TOKEN "$(ask_secret 'MAX_BOT_TOKEN')"
    ok "MAX бот обновлён"
}

cfg_tg() {
    header "Telegram бот"
    set_env AC_TG_BOT_TOKEN "$(ask_secret 'TG_BOT_TOKEN')"
    ok "TG бот обновлён"
}

cfg_ai() {
    header "AI провайдер"
    local prov
    prov=$(ask 'Провайдер (yandex_gpt / gigachat)' "$(get_env AC_AI_PRIMARY)")
    set_env AC_AI_PRIMARY "$prov"
    case "$prov" in
        yandex_gpt)
            set_env AC_YANDEX_API_KEY    "$(ask_secret 'YANDEX_API_KEY (AQVN…)')"
            set_env AC_YANDEX_FOLDER_ID  "$(ask        'YANDEX_FOLDER_ID (b1g…)' "$(get_env AC_YANDEX_FOLDER_ID)")"
            set_env AC_YANDEX_GPT_MODEL  "$(ask        'Модель (yandexgpt-lite / yandexgpt)' "$(get_env AC_YANDEX_GPT_MODEL || echo 'yandexgpt-lite')")"
            ;;
        gigachat)
            set_env AC_GIGACHAT_AUTH_KEY "$(ask_secret 'GIGACHAT_AUTH_KEY (base64)')"
            ;;
    esac
    ok "AI обновлён"
}

cfg_tbank() {
    header "T-Bank Internet Acquiring"
    set_env AC_TBANK_TERMINAL_KEY      "$(ask        'TBANK_TERMINAL_KEY' "$(get_env AC_TBANK_TERMINAL_KEY)")"
    set_env AC_TBANK_TERMINAL_PASSWORD "$(ask_secret 'TBANK_TERMINAL_PASSWORD')"
    set_env AC_TBANK_TEST_MODE         "$(ask        'Test mode (1/0)' "$(get_env AC_TBANK_TEST_MODE || echo '0')")"
    ok "T-Bank EACQ обновлён"
}

cfg_tbank_business() {
    header "T-Bank Business API (SBP)"
    set_env AC_TBANK_API_TOKEN        "$(ask_secret 'TBANK_API_TOKEN')"
    set_env AC_TBANK_BUSINESS_ACCOUNT "$(ask        'Расчётный счёт' "$(get_env AC_TBANK_BUSINESS_ACCOUNT)")"
    ok "T-Bank Business API обновлён"
}

cfg_moneta() {
    header "Moneta"
    set_env AC_MONETA_ACCOUNT_ID "$(ask        'MONETA_ACCOUNT_ID' "$(get_env AC_MONETA_ACCOUNT_ID)")"
    set_env AC_MONETA_SECRET_KEY "$(ask_secret 'MONETA_SECRET_KEY')"
    set_env AC_MONETA_TEST_MODE  "$(ask        'Test mode (1/0)' "$(get_env AC_MONETA_TEST_MODE || echo '0')")"
    ok "Moneta обновлён"
}

cfg_yookassa() {
    header "YooKassa"
    set_env AC_YOOKASSA_SHOP_ID    "$(ask        'YOOKASSA_SHOP_ID' "$(get_env AC_YOOKASSA_SHOP_ID)")"
    set_env AC_YOOKASSA_SECRET_KEY "$(ask_secret 'YOOKASSA_SECRET_KEY')"
    ok "YooKassa обновлён"
}

cfg_sbp() {
    header "Прямой SBP"
    set_env AC_SBP_PHONE "$(ask 'Номер телефона (+7…)' "$(get_env AC_SBP_PHONE)")"
    set_env AC_SBP_BANK  "$(ask 'Банк' "$(get_env AC_SBP_BANK)")"
    ok "Прямой SBP обновлён"
}

cfg_tripster() {
    header "Tripster (экскурсии)"
    set_env AC_TRIPSTER_TOKEN "$(ask_secret 'TRIPSTER_TOKEN')"
    set_env AC_TRIPSTER_CITY  "$(ask        'Город по умолчанию' "$(get_env AC_TRIPSTER_CITY || echo 'moscow')")"
    ok "Tripster обновлён"
}

cfg_yandex_go() {
    header "Yandex Go (такси)"
    set_env AC_YANDEX_GO_CLID   "$(ask        'YANDEX_GO_CLID' "$(get_env AC_YANDEX_GO_CLID)")"
    set_env AC_YANDEX_GO_APIKEY "$(ask_secret 'YANDEX_GO_APIKEY')"
    set_env AC_YANDEX_GO_REF    "$(ask        'Реф-метка (опц)' "$(get_env AC_YANDEX_GO_REF)")"
    ok "Yandex Go обновлён"
}

cfg_yandex_delivery() {
    header "Yandex Delivery"
    set_env AC_YANDEX_DELIVERY_API_KEY        "$(ask_secret 'YANDEX_DELIVERY_API_KEY')"
    set_env AC_YANDEX_DELIVERY_CLIENT_ID      "$(ask        'YANDEX_DELIVERY_CLIENT_ID' "$(get_env AC_YANDEX_DELIVERY_CLIENT_ID)")"
    set_env AC_YANDEX_DELIVERY_PICKUP_ADDRESS "$(ask        'Адрес склада' "$(get_env AC_YANDEX_DELIVERY_PICKUP_ADDRESS)")"
    set_env AC_YANDEX_DELIVERY_PICKUP_LAT     "$(ask        'Широта'  "$(get_env AC_YANDEX_DELIVERY_PICKUP_LAT  || echo '53.195878')")"
    set_env AC_YANDEX_DELIVERY_PICKUP_LON     "$(ask        'Долгота' "$(get_env AC_YANDEX_DELIVERY_PICKUP_LON  || echo '50.100202')")"
    ok "Yandex Delivery обновлён"
}

cfg_yandex_partners() {
    header "Yandex deep links (Eda / Market / Travel)"
    set_env AC_YANDEX_EDA_PROMO   "$(ask 'Eda promo (опц)'    "$(get_env AC_YANDEX_EDA_PROMO)")"
    set_env AC_YANDEX_MARKET_CLID "$(ask 'Market CLID (опц)'  "$(get_env AC_YANDEX_MARKET_CLID)")"
    set_env AC_YANDEX_TRAVEL_CLID "$(ask 'Travel CLID (опц)'  "$(get_env AC_YANDEX_TRAVEL_CLID)")"
    ok "Yandex deep links обновлены"
}

cfg_numbuster() {
    header "NumBuster"
    set_env AC_NUMBUSTER_TOKEN          "$(ask_secret 'NUMBUSTER_ACCESS_TOKEN')"
    set_env AC_NUMBUSTER_MIN_TRUST      "$(ask        'Минимальный trust index (0=отключено)' "$(get_env AC_NUMBUSTER_MIN_TRUST || echo '0')")"
    set_env AC_NUMBUSTER_EXTRA_DEPOSIT  "$(ask        'Доп. сумма залога при низком рейтинге (₽)' "$(get_env AC_NUMBUSTER_EXTRA_DEPOSIT || echo '0')")"
    ok "NumBuster обновлён"
}

cfg_zenmoney() {
    header "ZenMoney"
    set_env AC_ZENMONEY_TOKEN      "$(ask_secret 'ZENMONEY_DIRECT_TOKEN')"
    set_env AC_ZENMONEY_PROFILE_ID "$(ask        'ZENMONEY_PROFILE_ID' "$(get_env AC_ZENMONEY_PROFILE_ID || echo '0')")"
    ok "ZenMoney обновлён"
}

cfg_r2() {
    header "Cloudflare R2"
    set_env AC_R2_ACCOUNT_ID "$(ask        'R2_ACCOUNT_ID' "$(get_env AC_R2_ACCOUNT_ID)")"
    set_env AC_R2_ACCESS_KEY "$(ask_secret 'R2_ACCESS_KEY')"
    set_env AC_R2_SECRET_KEY "$(ask_secret 'R2_SECRET_KEY')"
    set_env AC_R2_BUCKET     "$(ask        'R2_BUCKET' "$(get_env AC_R2_BUCKET)")"
    ok "Cloudflare R2 обновлён"
}

cfg_aws() {
    header "AWS Rekognition"
    set_env AC_AWS_ACCESS_KEY "$(ask_secret 'AWS_ACCESS_KEY')"
    set_env AC_AWS_SECRET_KEY "$(ask_secret 'AWS_SECRET_KEY')"
    set_env AC_AWS_REGION     "$(ask        'AWS_REGION' "$(get_env AC_AWS_REGION || echo 'eu-central-1')")"
    ok "AWS Rekognition обновлён"
}

cfg_tuya() {
    header "Tuya"
    set_env AC_TUYA_ACCESS_ID     "$(ask_secret 'TUYA_ACCESS_ID')"
    set_env AC_TUYA_ACCESS_SECRET "$(ask_secret 'TUYA_ACCESS_SECRET')"
    set_env AC_TUYA_ENDPOINT      "$(ask        'TUYA_ENDPOINT' "$(get_env AC_TUYA_ENDPOINT || echo 'https://openapi.tuyaeu.com')")"
    ok "Tuya обновлён"
}

# ───────────────────────── Меню ─────────────────────────

show_menu() {
    clear
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║       AutoCheckin Configure (post-install)   ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Базовые${NC}"
    echo -e "   1) RealtyCalendar          $(is_set AC_RC_EMAIL)"
    echo -e "   2) MAX бот                 $(is_set AC_MAX_BOT_TOKEN)"
    echo -e "   3) Telegram бот            $(is_set AC_TG_BOT_TOKEN)"
    echo -e "   4) AI провайдер            $(is_set AC_AI_PRIMARY)"
    echo ""
    echo -e "  ${BOLD}Платежи${NC}"
    echo -e "  10) T-Bank Internet Acq.   $(is_set AC_TBANK_TERMINAL_KEY)"
    echo -e "  11) T-Bank Business API    $(is_set AC_TBANK_API_TOKEN)"
    echo -e "  12) Moneta                 $(is_set AC_MONETA_ACCOUNT_ID)"
    echo -e "  13) YooKassa               $(is_set AC_YOOKASSA_SHOP_ID)"
    echo -e "  14) Прямой SBP             $(is_set AC_SBP_PHONE)"
    echo ""
    echo -e "  ${BOLD}Партнёры${NC}"
    echo -e "  20) Tripster (экскурсии)   $(is_set AC_TRIPSTER_TOKEN)"
    echo -e "  21) Yandex Go (такси)      $(is_set AC_YANDEX_GO_APIKEY)"
    echo -e "  22) Yandex Delivery        $(is_set AC_YANDEX_DELIVERY_API_KEY)"
    echo -e "  23) Yandex deep links      $(is_set AC_YANDEX_MARKET_CLID)"
    echo ""
    echo -e "  ${BOLD}Прочее${NC}"
    echo -e "  30) NumBuster              $(is_set AC_NUMBUSTER_TOKEN)"
    echo -e "  31) ZenMoney               $(is_set AC_ZENMONEY_TOKEN)"
    echo -e "  40) Cloudflare R2          $(is_set AC_R2_BUCKET)"
    echo -e "  41) AWS Rekognition        $(is_set AC_AWS_ACCESS_KEY)"
    echo -e "  50) Tuya (камеры/розетки)  $(is_set AC_TUYA_ACCESS_ID)"
    echo ""
    echo -e "  ${BOLD}99) Перезапустить AutoCheckin${NC}"
    echo -e "  ${BOLD} 0) Выход${NC}"
    echo ""
}

run_one() {
    case "$1" in
        rc|1) cfg_rc ;;
        max|2) cfg_max ;;
        tg|3) cfg_tg ;;
        ai|4) cfg_ai ;;
        tbank|10) cfg_tbank ;;
        tbank_biz|11) cfg_tbank_business ;;
        moneta|12) cfg_moneta ;;
        yookassa|13) cfg_yookassa ;;
        sbp|14) cfg_sbp ;;
        tripster|20) cfg_tripster ;;
        yandex_go|21) cfg_yandex_go ;;
        yandex_delivery|22) cfg_yandex_delivery ;;
        yandex|23) cfg_yandex_partners ;;
        numbuster|30) cfg_numbuster ;;
        zenmoney|31) cfg_zenmoney ;;
        r2|40) cfg_r2 ;;
        aws|41) cfg_aws ;;
        tuya|50) cfg_tuya ;;
        restart|99) restart_app; return ;;
        *) echo "Неизвестный пункт: $1"; return ;;
    esac
    restart_app
}

# CLI mode: configure.sh <name>
if [ "$#" -gt 0 ]; then
    run_one "$1"
    exit 0
fi

# Interactive menu
while true; do
    show_menu
    choice=$(ask "Выберите пункт")
    [ -z "$choice" ] && continue
    [ "$choice" = "0" ] && exit 0
    run_one "$choice"
    echo ""
    ask "Нажмите Enter чтобы продолжить" >/dev/null
done
