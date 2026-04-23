#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  AutoCheckin Installer v2.0                                  ║
# ║  SaaS для автоматизации посуточной аренды                    ║
# ║                                                              ║
# ║  Установка:                                                  ║
# ║  curl -sSL https://install.afonin-lisa.ru -o install.sh      ║
# ║  bash install.sh                                             ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

INSTALLER_VERSION="2.0.0"
INSTALL_DIR="/opt/autocheckin"
INSTALLER_DIR="/opt/autocheckin-installer"
CONFIG_FILE="$INSTALL_DIR/.install-config"
HUB_URL="https://install.afonin-lisa.ru"

# ═══ Colors ═══
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()     { echo -e "${GREEN}✅ $1${NC}"; }
fail()   { echo -e "${RED}❌ $1${NC}"; exit 1; }
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
    read -rs REPLY; echo >&2
    echo "$REPLY"
}

confirm() {
    echo -en "${CYAN}▸ $1 [y/N]: ${NC}" >&2
    read -r REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

# ═══ Check root ═══
[ "$(id -u)" -eq 0 ] || fail "Запустите от root: sudo bash install.sh"
mkdir -p "$INSTALL_DIR"

# ═══ Self-bootstrap: download full installer ═══
if [ ! -f "$INSTALLER_DIR/templates/docker-compose.yml" ]; then
    echo "Скачиваю установщик..."
    apt-get update -qq && apt-get install -y -qq git curl > /dev/null 2>&1 || true
    if [ -d "$INSTALLER_DIR/.git" ]; then
        cd "$INSTALLER_DIR" && git fetch origin 2>/dev/null && git reset --hard origin/master 2>/dev/null || true
    else
        git clone https://github.com/afonin-lisa/autocheckin-installer.git "$INSTALLER_DIR" 2>/dev/null || true
    fi
fi

# ═══ Load saved config ═══
declare -A CFG
if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
        [ -n "$key" ] && CFG["$key"]="$value"
    done < "$CONFIG_FILE"
fi

save_cfg() {
    CFG["$1"]="$2"
    : > "$CONFIG_FILE"
    for k in "${!CFG[@]}"; do
        echo "${k}=${CFG[$k]}" >> "$CONFIG_FILE"
    done
    chmod 600 "$CONFIG_FILE"
}

header "AutoCheckin Installer v${INSTALLER_VERSION}"

# ═══════════════════════════════════════════════════════
# ЭТАП 1: ЧЕК-ЛИСТ (что нужно подготовить)
# ═══════════════════════════════════════════════════════

if [ "${CFG[checklist_done]:-}" != "done" ]; then
    header "Перед установкой"
    echo -e "${BOLD}Подготовьте эти данные ЗАРАНЕЕ:${NC}\n"
    echo -e "  ${BOLD}Обязательно:${NC}"
    echo -e "  ${RED}0.${NC} ${BOLD}Порты 80 и 443${NC} — откройте в Security Group сервера!"
    echo -e "     Cloud.ru: VM → Сеть → Security Groups → добавить TCP 80, 443"
    echo -e "     ⚠️  Без этого HTTPS не заработает!"
    echo -e "  ${GREEN}1.${NC} LICENSE_KEY — получите на ${BOLD}billing.afonin-lisa.ru/signup${NC}"
    echo -e "  ${GREEN}2.${NC} Домен — например ${BOLD}checkin.вашдомен.ru${NC}"
    echo -e "     Или мы создадим поддомен автоматически"
    echo -e "  ${GREEN}3.${NC} RealtyCalendar — логин и пароль от ${BOLD}realtycalendar.ru${NC}"
    echo -e "  ${GREEN}4.${NC} MAX Bot Token — создайте бота: ${BOLD}max.ru/botfather${NC}"
    echo ""
    echo -e "  ${BOLD}Опционально (можно настроить позже в admin панели):${NC}"
    echo -e "  ${YELLOW}5.${NC} TG Bot Token — через ${BOLD}@BotFather${NC} в Telegram"
    echo -e "  ${YELLOW}6.${NC} SMS — логин/пароль SMSC.ru или API ключ SMS.ru"
    echo -e "  ${YELLOW}7.${NC} Email — SMTP данные (Yandex: smtp.yandex.ru:465)"
    echo -e "  ${YELLOW}8.${NC} AI — ключ YandexGPT или GigaChat"
    echo -e "  ${YELLOW}9.${NC} Tripster — API ключ для экскурсий"
    echo -e "  ${YELLOW}10.${NC} Numbuster — логин/пароль для проверки номеров"
    echo ""

    if ! confirm "Всё подготовили? Начинаем установку?"; then
        echo ""
        info "Когда будете готовы — запустите снова: bash install.sh"
        exit 0
    fi
    save_cfg "checklist_done" "done"
fi

# ═══════════════════════════════════════════════════════
# ЭТАП 2: СБОР ДАННЫХ (по шагам, с сохранением)
# ═══════════════════════════════════════════════════════

header "Шаг 1/8: Лицензия"
if [ -z "${CFG[license_key]:-}" ]; then
    echo -e "  Получите ключ на ${BOLD}https://billing.afonin-lisa.ru/signup${NC}"
    LICENSE_KEY=$(ask "LICENSE_KEY")
    [ -z "$LICENSE_KEY" ] && fail "LICENSE_KEY обязателен"
    save_cfg "license_key" "$LICENSE_KEY"
    ok "Ключ сохранён"
else
    ok "LICENSE_KEY: ${CFG[license_key]:0:15}... (уже сохранён)"
fi

header "Шаг 2/8: Домен"
if [ -z "${CFG[domain]:-}" ]; then
    PUBLIC_IP=$(curl -sf --connect-timeout 5 https://ifconfig.me 2>/dev/null || echo "")
    [ -n "$PUBLIC_IP" ] && info "IP этого сервера: $PUBLIC_IP"
    echo ""
    echo -e "  ${BOLD}Выберите вариант:${NC}"
    echo -e "  ${GREEN}1)${NC} Свой домен (бесплатно) — вы сами настраиваете DNS"
    echo -e "  ${GREEN}2)${NC} Наш поддомен *.autocheckin.afonin-lisa.ru (+100₽/мес)"
    echo ""
    DOMAIN_CHOICE=$(ask "Выбор (1 или 2)" "2")

    if [ "$DOMAIN_CHOICE" = "1" ]; then
        echo -e "  Создайте DNS A-запись: ${BOLD}ваш-домен → $PUBLIC_IP${NC}"
        DOMAIN=$(ask "Ваш домен (например checkin.myhotel.ru)")
        if [ -z "$DOMAIN" ]; then
            warn "Домен не указан — будет работать только по IP"
            DOMAIN="$PUBLIC_IP"
        fi
    else
        SUBDOMAIN=$(ask "Придумайте имя (латиницей, 3-30 символов)")
        if [ -z "$SUBDOMAIN" ]; then
            fail "Имя обязательно"
        fi
        info "Создаю ${SUBDOMAIN}.autocheckin.afonin-lisa.ru → $PUBLIC_IP..."
        # Call hub API to create subdomain
        CREATE_RESULT=$(curl -sf -X POST "https://install.afonin-lisa.ru/v1/domain/create" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"${SUBDOMAIN}\",\"ip\":\"${PUBLIC_IP}\",\"license_key\":\"${CFG[license_key]:-}\"}" 2>/dev/null)
        DOMAIN_ERROR=$(echo "$CREATE_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',''))" 2>/dev/null)
        if [ -n "$DOMAIN_ERROR" ] && [ "$DOMAIN_ERROR" != "" ]; then
            fail "Ошибка создания домена: $DOMAIN_ERROR"
        fi
        DOMAIN="${SUBDOMAIN}.autocheckin.afonin-lisa.ru"
        ok "Домен создан: $DOMAIN"
        info "DNS обновится через 1-2 минуты"
    fi
    save_cfg "domain" "$DOMAIN"
    save_cfg "public_ip" "$PUBLIC_IP"
    ok "Домен: $DOMAIN"
else
    ok "Домен: ${CFG[domain]} (уже сохранён)"
fi

header "Шаг 3/8: RealtyCalendar"
if [ -z "${CFG[rc_email]:-}" ]; then
    echo -e "  Логин и пароль от ${BOLD}realtycalendar.ru${NC}"
    RC_EMAIL=$(ask "Email от RealtyCalendar")
    if [ -n "$RC_EMAIL" ]; then
        RC_PASSWORD=$(ask_secret "Пароль от RealtyCalendar")
        save_cfg "rc_email" "$RC_EMAIL"
        save_cfg "rc_password" "$RC_PASSWORD"
        ok "RealtyCalendar сохранён"
    else
        warn "Пропущено — настроите позже в admin панели"
        save_cfg "rc_email" ""
        save_cfg "rc_password" ""
    fi
else
    ok "RealtyCalendar: ${CFG[rc_email]} (уже сохранён)"
fi

header "Шаг 4/8: MAX бот"
if [ -z "${CFG[max_bot_token]:-}" ]; then
    echo -e "  Создайте бота: ${BOLD}https://max.ru/botfather${NC}"
    echo -e "  Скопируйте токен бота"
    MAX_TOKEN=$(ask_secret "MAX Bot Token")
    if [ -n "$MAX_TOKEN" ]; then
        save_cfg "max_bot_token" "$MAX_TOKEN"
        ok "MAX бот сохранён"
    else
        warn "Пропущено — бот не будет работать в MAX"
        save_cfg "max_bot_token" ""
    fi
else
    ok "MAX бот: настроен (уже сохранён)"
fi

header "Шаг 5/8: Telegram бот (опционально)"
if [ -z "${CFG[tg_bot_token]:-}" ]; then
    echo -e "  Создайте бота: ${BOLD}@BotFather${NC} в Telegram"
    TG_TOKEN=$(ask "TG Bot Token (Enter для пропуска)")
    save_cfg "tg_bot_token" "${TG_TOKEN:-}"
    [ -n "$TG_TOKEN" ] && ok "TG бот сохранён" || info "Пропущено"
else
    ok "TG бот: настроен (уже сохранён)"
fi

header "Шаг 6/8: SMS (опционально)"
if [ -z "${CFG[sms_provider]:-}" ]; then
    echo -e "  Провайдеры: ${BOLD}smsc.ru${NC} или ${BOLD}sms.ru${NC}"
    SMS_PROVIDER=$(ask "SMS провайдер (smsc_ru / sms_ru / Enter для пропуска)")
    if [ -n "$SMS_PROVIDER" ] && [ "$SMS_PROVIDER" != " " ]; then
        save_cfg "sms_provider" "$SMS_PROVIDER"
        if [ "$SMS_PROVIDER" = "smsc_ru" ]; then
            save_cfg "sms_login" "$(ask "SMSC логин")"
            save_cfg "sms_password" "$(ask_secret "SMSC пароль")"
        else
            save_cfg "sms_api_key" "$(ask_secret "SMS.ru API Key")"
        fi
        ok "SMS сохранён"
    else
        save_cfg "sms_provider" ""
        info "Пропущено"
    fi
else
    ok "SMS: ${CFG[sms_provider]:-не настроен} (уже сохранён)"
fi

header "Шаг 7/8: AI провайдер (опционально)"
if [ -z "${CFG[ai_primary]:-}" ]; then
    echo -e "  Провайдеры: ${BOLD}yandex_gpt${NC} или ${BOLD}gigachat${NC}"
    echo -e "  AI используется для: паспорт, FAQ, проверка фото"
    AI=$(ask "AI провайдер (yandex_gpt / gigachat / Enter для пропуска)")
    if [ -n "$AI" ] && [ "$AI" != " " ]; then
        save_cfg "ai_primary" "$AI"
        if [ "$AI" = "yandex_gpt" ]; then
            save_cfg "yandex_api_key" "$(ask_secret "YandexGPT API Key")"
            save_cfg "yandex_folder_id" "$(ask "Yandex Folder ID")"
        else
            save_cfg "gigachat_auth_key" "$(ask_secret "GigaChat Auth Key (base64)")"
        fi
        ok "AI сохранён"
    else
        save_cfg "ai_primary" ""
        info "Пропущено — AI фичи будут недоступны"
    fi
else
    ok "AI: ${CFG[ai_primary]:-не настроен} (уже сохранён)"
fi

header "Шаг 8/8: Email SMTP (опционально)"
if [ -z "${CFG[smtp_host]:-}" ]; then
    echo -e "  Yandex: ${BOLD}smtp.yandex.ru:465${NC}, Mail.ru: ${BOLD}smtp.mail.ru:465${NC}"
    SMTP_HOST=$(ask "SMTP хост (Enter для пропуска)")
    if [ -n "$SMTP_HOST" ] && [ "$SMTP_HOST" != " " ]; then
        save_cfg "smtp_host" "$SMTP_HOST"
        save_cfg "smtp_port" "$(ask "SMTP порт" "465")"
        save_cfg "smtp_user" "$(ask "SMTP логин (email)")"
        save_cfg "smtp_pass" "$(ask_secret "SMTP пароль")"
        save_cfg "smtp_from" "$(ask "Отправитель" "${CFG[smtp_user]:-}")"
        ok "Email сохранён"
    else
        save_cfg "smtp_host" ""
        info "Пропущено"
    fi
else
    ok "Email: ${CFG[smtp_host]:-не настроен} (уже сохранён)"
fi

# ═══════════════════════════════════════════════════════
# ЭТАП 3: ПОДТВЕРЖДЕНИЕ И УСТАНОВКА
# ═══════════════════════════════════════════════════════

header "Проверка конфигурации"
echo -e "  LICENSE_KEY:  ${BOLD}${CFG[license_key]:0:20}...${NC}"
echo -e "  Домен:        ${BOLD}${CFG[domain]}${NC}"
echo -e "  RC:           ${BOLD}${CFG[rc_email]:-не настроен}${NC}"
echo -e "  MAX бот:      ${BOLD}$([ -n "${CFG[max_bot_token]:-}" ] && echo "✅ настроен" || echo "❌ не настроен")${NC}"
echo -e "  TG бот:       ${BOLD}$([ -n "${CFG[tg_bot_token]:-}" ] && echo "✅ настроен" || echo "⏭ пропущен")${NC}"
echo -e "  SMS:          ${BOLD}${CFG[sms_provider]:-⏭ пропущен}${NC}"
echo -e "  AI:           ${BOLD}${CFG[ai_primary]:-⏭ пропущен}${NC}"
echo -e "  Email:        ${BOLD}${CFG[smtp_host]:-⏭ пропущен}${NC}"
echo ""

if ! confirm "Всё верно? Начинаю установку?"; then
    info "Чтобы изменить параметр — удалите его из $CONFIG_FILE и запустите снова"
    exit 0
fi

# ═══ Проверка портов ═══
header "Проверка сетевых портов"
PUBLIC_IP="${CFG[public_ip]:-$(curl -sf --connect-timeout 5 https://ifconfig.me 2>/dev/null)}"
info "Проверяю доступность портов 80/443 извне для $PUBLIC_IP..."

PORTS_JSON=$(curl -sf --connect-timeout 10 "https://install.afonin-lisa.ru/v1/check-ports" -X POST \
    -H "Content-Type: application/json" \
    -d "{\"host\":\"${PUBLIC_IP}\",\"ports\":[80,443]}" 2>/dev/null || echo "")

PORT80_OK=false
PORT443_OK=false
if [ -n "$PORTS_JSON" ]; then
    PORT80_OK=$(echo "$PORTS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('results',{}).get('80') or d.get('results',{}).get(80) else 'false')" 2>/dev/null || echo "false")
    PORT443_OK=$(echo "$PORTS_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('results',{}).get('443') or d.get('results',{}).get(443) else 'false')" 2>/dev/null || echo "false")
fi

if [ "$PORT80_OK" = "true" ] && [ "$PORT443_OK" = "true" ]; then
    ok "Порты 80 и 443 открыты"
else
    echo ""
    echo -e "  ${RED}${BOLD}⚠️  ПОРТЫ ЗАКРЫТЫ!${NC}"
    echo ""
    [ "$PORT80_OK"  != "true" ] && echo -e "  ${RED}❌ Порт 80 (HTTP) — ЗАКРЫТ${NC}"
    [ "$PORT443_OK" != "true" ] && echo -e "  ${RED}❌ Порт 443 (HTTPS) — ЗАКРЫТ${NC}"
    echo ""
    echo -e "  ${BOLD}Как открыть:${NC}"
    echo ""
    echo -e "  ${CYAN}Cloud.ru:${NC}"
    echo -e "    1. Панель управления → Виртуальные машины → ваша VM"
    echo -e "    2. Вкладка «Сеть» → Security Groups"
    echo -e "    3. Нажмите на группу → «Добавить правило»"
    echo -e "    4. Добавьте два правила:"
    echo -e "       ${BOLD}TCP 80${NC}  входящий, источник ${BOLD}0.0.0.0/0${NC}"
    echo -e "       ${BOLD}TCP 443${NC} входящий, источник ${BOLD}0.0.0.0/0${NC}"
    echo -e "    5. Сохраните"
    echo ""
    echo -e "  ${CYAN}Другие хостинги:${NC}"
    echo -e "    Найдите Firewall / Security Groups в панели управления"
    echo -e "    и разрешите входящий TCP на порты 80 и 443."
    echo ""

    if confirm "Порты открыты? Проверить ещё раз?"; then
        # Re-check
        PORTS_JSON2=$(curl -sf --connect-timeout 10 "https://install.afonin-lisa.ru/v1/check-ports" -X POST \
            -H "Content-Type: application/json" \
            -d "{\"host\":\"${PUBLIC_IP}\",\"ports\":[80,443]}" 2>/dev/null || echo "")
        P80=$(echo "$PORTS_JSON2" | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('results',{}).get('80') or d.get('results',{}).get(80) else 'false')" 2>/dev/null || echo "false")
        P443=$(echo "$PORTS_JSON2" | python3 -c "import sys,json; d=json.load(sys.stdin); print('true' if d.get('results',{}).get('443') or d.get('results',{}).get(443) else 'false')" 2>/dev/null || echo "false")
        if [ "$P80" = "true" ] && [ "$P443" = "true" ]; then
            ok "Порты открыты!"
        else
            warn "Порты всё ещё закрыты. Установка продолжится, но HTTPS не заработает."
            warn "Откройте порты и перезапустите: docker compose -f /opt/autocheckin/docker-compose.yml restart caddy"
        fi
    else
        warn "Продолжаю без открытых портов. HTTPS не будет работать до их открытия."
    fi
fi

# ═══ Preflight ═══
header "Проверка системы"
info "Docker..."
if ! command -v docker &>/dev/null; then
    info "Устанавливаю Docker..."
    apt-get update -qq && apt-get install -y docker.io > /dev/null 2>&1 || fail "Не удалось установить Docker"
fi
ok "Docker: $(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)"

if ! docker compose version &>/dev/null; then
    info "Устанавливаю Docker Compose..."
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null || \
    curl -fsSL "https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-linux-x86_64" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi
ok "Docker Compose: $(docker compose version --short)"
systemctl enable docker > /dev/null 2>&1 && systemctl start docker > /dev/null 2>&1
ok "Docker запущен"

# ═══ Generate secrets ═══
header "Генерация конфигурации"
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || openssl rand -hex 32)
DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))" 2>/dev/null || openssl rand -base64 24)
GUEST_DATA_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || python3 -c "import base64,os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())" 2>/dev/null || echo "")

# ═══ Create .env ═══
cat > "$INSTALL_DIR/.env" << ENVFILE
# AutoCheckin — сгенерировано installer v${INSTALLER_VERSION}
AC_DATABASE_URL=postgresql+psycopg://autocheckin:${DB_PASSWORD}@postgres:5432/autocheckin
AC_REDIS_URL=redis://redis:6379/0
AC_SECRET_KEY=${SECRET_KEY}
AC_GUEST_DATA_KEY=${GUEST_DATA_KEY}
AC_LICENSE_KEY=${CFG[license_key]}
AC_LICENSE_SERVER_URL=https://license.afonin-lisa.ru
AC_MODULES=guest,cleaning,master,admin_web
AC_LOG_LEVEL=INFO

# RealtyCalendar
AC_RC_EMAIL=${CFG[rc_email]:-}
AC_RC_PASSWORD=${CFG[rc_password]:-}

# Keysher
AC_KEYSHER_URL=https://keysher.afonin-lisa.ru/api/v2
AC_KEYSHER_TOKEN=${CFG[keysher_token]:-}

# Bots
AC_MAX_BOT_TOKEN=${CFG[max_bot_token]:-}
AC_TG_BOT_TOKEN=${CFG[tg_bot_token]:-}

# SMS
AC_SMS_PROVIDER=${CFG[sms_provider]:-}
AC_SMS_LOGIN=${CFG[sms_login]:-}
AC_SMS_PASSWORD=${CFG[sms_password]:-}
AC_SMS_FALLBACK_API_KEY=${CFG[sms_api_key]:-}

# Email
AC_SMTP_HOST=${CFG[smtp_host]:-}
AC_SMTP_PORT=${CFG[smtp_port]:-465}
AC_SMTP_USER=${CFG[smtp_user]:-}
AC_SMTP_PASS=${CFG[smtp_pass]:-}
AC_SMTP_FROM=${CFG[smtp_from]:-}

# AI
AC_AI_PRIMARY=${CFG[ai_primary]:-}
AC_YANDEX_API_KEY=${CFG[yandex_api_key]:-}
AC_YANDEX_FOLDER_ID=${CFG[yandex_folder_id]:-}
AC_GIGACHAT_AUTH_KEY=${CFG[gigachat_auth_key]:-}

# Docker
DOMAIN=${CFG[domain]}
DB_PASSWORD=${DB_PASSWORD}
IMAGE_TAG=latest
ENVFILE
chmod 600 "$INSTALL_DIR/.env"
# Clean up SKIP markers from web installer
sed -i 's/=SKIP$/=/' "$INSTALL_DIR/.env"
ok ".env создан"

# ═══ Create docker-compose.yml ═══
cp "$INSTALLER_DIR/templates/docker-compose.yml" "$INSTALL_DIR/" 2>/dev/null || {
    warn "Шаблон compose не найден — скачиваю..."
    curl -sf "https://install.afonin-lisa.ru/files/templates/docker-compose.yml" -o "$INSTALL_DIR/docker-compose.yml"
}

# ═══ Create Caddyfile ═══
DOMAIN="${CFG[domain]}"
cat > "$INSTALL_DIR/Caddyfile" << CADDYFILE
${DOMAIN} {
    reverse_proxy app:8000
    header {
        Strict-Transport-Security "max-age=31536000"
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        -Server
    }
}
CADDYFILE
ok "Caddyfile создан для $DOMAIN"

# ═══ Pull image from registry (no auth needed for pull) ═══
header "Загрузка AutoCheckin"
REGISTRY="registry.afonin-lisa.ru"
info "Скачиваю образ из $REGISTRY..."

# Update compose to use registry image
sed -i "s|image: autocheckin-app:latest|image: ${REGISTRY}/autocheckin:latest|g" "$INSTALL_DIR/docker-compose.yml" 2>/dev/null || true
sed -i "s|image: \${REGISTRY}/autocheckin|image: ${REGISTRY}/autocheckin|g" "$INSTALL_DIR/docker-compose.yml" 2>/dev/null || true

if docker pull "${REGISTRY}/autocheckin:latest" 2>/dev/null; then
    ok "Образ загружен из $REGISTRY"
else
    warn "Не удалось скачать образ из registry"
    if docker images | grep -q "autocheckin"; then
        ok "Используем локальный образ"
    else
        fail "Образ не найден. Обратитесь в поддержку: @autocheckin_support"
    fi
fi

info "Загружаю образы..."
cd "$INSTALL_DIR"
docker compose pull 2>&1 | tail -3 || warn "Не все образы загружены"

# ═══ Start services ═══
header "Запуск сервисов"
docker compose up -d 2>&1 | tail -5

info "Ожидаю запуска (до 2 мин)..."
HEALTHY=false
for i in $(seq 1 24); do
    # Check health via python (curl not in image)
    if docker compose exec -T app python -c "import httpx; r=httpx.get('http://localhost:8000/health',timeout=3); exit(0 if r.status_code==200 else 1)" 2>/dev/null; then
        HEALTHY=true
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

if [ "$HEALTHY" = true ]; then
    ok "Сервис запущен и работает!"
else
    warn "Сервис ещё запускается — проверьте через минуту: docker compose logs app"
fi

# ═══ Systemd unit ═══
if [ -f "$INSTALLER_DIR/templates/systemd/autocheckin.service" ]; then
    cp "$INSTALLER_DIR/templates/systemd/autocheckin.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable autocheckin 2>/dev/null
    ok "Автозапуск при ребуте настроен"
fi

# ═══ Backup cron ═══
BACKUP_DIR="$INSTALL_DIR/backups"
mkdir -p "$BACKUP_DIR"
cat > "$INSTALL_DIR/backup.sh" << 'BSCRIPT'
#!/bin/bash
BACKUP_DIR="/opt/autocheckin/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
docker compose -f /opt/autocheckin/docker-compose.yml exec -T postgres \
    pg_dump -U autocheckin autocheckin 2>/dev/null | gzip > "$BACKUP_DIR/autocheckin-${TIMESTAMP}.sql.gz"
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +14 -delete
BSCRIPT
chmod +x "$INSTALL_DIR/backup.sh"
(crontab -l 2>/dev/null | grep -v "autocheckin/backup.sh"; echo "0 3 * * * /opt/autocheckin/backup.sh >> /var/log/autocheckin/backup.log 2>&1") | crontab - 2>/dev/null
ok "Бэкапы: ежедневно в 03:00"

# ═══ Done! ═══
header "Установка завершена!"
echo ""
ok "AutoCheckin работает на https://${CFG[domain]}"
ok "Админ-панель: https://${CFG[domain]}/admin/"
echo ""
info "Настройки: https://${CFG[domain]}/admin/settings"
info "Замки: https://${CFG[domain]}/admin/locks"
info "Интеграции: https://${CFG[domain]}/admin/integrations"
echo ""
info "Документация: https://docs.afonin-lisa.ru"
info "Поддержка: @autocheckin_support"
echo ""
echo -e "${BOLD}Конфигурация сохранена в: $CONFIG_FILE${NC}"
echo -e "${BOLD}Чтобы изменить параметр — отредактируйте файл и запустите: bash install.sh${NC}"
