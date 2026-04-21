#!/bin/bash
# Wizard 10: Docker installation
# Installs Docker >= 24 if not already present

header "Установка Docker"
log_step "10_docker" "start"

_docker_version_ge_24() {
    local ver
    ver=$(docker --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
    local major
    major=$(echo "$ver" | cut -d. -f1)
    [ -n "$major" ] && [ "$major" -ge 24 ] 2>/dev/null
}

# --- Check existing Docker ---
if command -v docker &>/dev/null && _docker_version_ge_24; then
    DOCKER_VER=$(docker --version)
    ok "Docker уже установлен: $DOCKER_VER — пропускаю установку"
else
    if command -v docker &>/dev/null; then
        OLD_VER=$(docker --version 2>/dev/null || echo "неизвестна")
        warn "Установлена старая версия Docker ($OLD_VER), обновляю..."
    else
        info "Docker не найден, устанавливаю..."
    fi

    info "Обновление пакетов и установка docker.io..."
    apt-get update -qq || fail "Не удалось выполнить apt-get update"
    apt-get install -y docker.io > /dev/null 2>&1 \
        || fail "Не удалось установить Docker"

    ok "Docker установлен"
fi

# --- Verify docker compose (install manually if missing) ---
info "Проверка docker compose..."
if ! docker compose version &>/dev/null; then
    info "docker-compose-plugin не найден, устанавливаю вручную..."
    COMPOSE_VERSION="v2.32.4"
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose 2>/dev/null \
        || curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
            -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

if ! docker compose version &>/dev/null; then
    fail "docker compose недоступен. Установите вручную: https://docs.docker.com/compose/install/"
fi
COMPOSE_VER=$(docker compose version --short 2>/dev/null || docker compose version | grep -oP '\d+\.\d+\.\d+' | head -1)
ok "docker compose: $COMPOSE_VER"

# --- Enable and start docker service ---
info "Включение и запуск сервиса Docker..."
systemctl enable docker > /dev/null 2>&1 || warn "Не удалось включить автозапуск docker (systemctl enable)"
systemctl start docker  > /dev/null 2>&1 || warn "Не удалось запустить docker (systemctl start)"

if systemctl is-active --quiet docker; then
    ok "Сервис docker активен"
else
    fail "Сервис docker не запустился. Проверьте: systemctl status docker"
fi

log_step "10_docker" "done"
ok "Docker готов к работе"
