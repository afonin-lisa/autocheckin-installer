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

    info "Обновление пакетов и установка docker.io docker-compose-plugin..."
    apt-get update -qq || fail "Не удалось выполнить apt-get update"
    apt-get install -y docker.io docker-compose-plugin > /dev/null 2>&1 \
        || fail "Не удалось установить Docker"

    ok "Docker установлен"
fi

# --- Verify docker compose ---
info "Проверка docker compose..."
if ! docker compose version &>/dev/null; then
    fail "docker compose недоступен после установки. Проверьте пакет docker-compose-plugin"
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
