#!/bin/bash
# Wizard 00: Preflight checks
# Checks system requirements before installation

header "Предварительные проверки системы"
log_step "00_preflight" "start"

# --- Ubuntu 22.04+ ---
info "Проверка версии ОС..."
if [ -f /etc/os-release ]; then
    VERSION_ID_VAL=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
    OS_NAME=$(grep ^NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    # Compare major version: 22.04 → 22
    MAJOR_VER=$(echo "$VERSION_ID_VAL" | cut -d. -f1)
    if [[ "$OS_NAME" != *"Ubuntu"* ]]; then
        fail "Требуется Ubuntu. Обнаружена: $OS_NAME"
    fi
    if [ "$MAJOR_VER" -lt 22 ] 2>/dev/null; then
        fail "Требуется Ubuntu 22.04+. Обнаружена версия: $VERSION_ID_VAL"
    fi
    ok "ОС: $OS_NAME $VERSION_ID_VAL"
else
    fail "Не удалось определить версию ОС (/etc/os-release не найден)"
fi

# --- RAM >= 3GB ---
info "Проверка оперативной памяти..."
RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
if [ "$RAM_MB" -lt 3072 ]; then
    fail "Недостаточно RAM: ${RAM_MB}MB. Требуется минимум 3GB (3072MB)"
fi
ok "RAM: ${RAM_MB}MB (>= 3GB)"

# --- Disk >= 20GB free ---
info "Проверка свободного места на диске..."
DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
if [ "$DISK_GB" -lt 20 ]; then
    fail "Недостаточно свободного места: ${DISK_GB}GB. Требуется минимум 20GB"
fi
ok "Свободное место: ${DISK_GB}GB (>= 20GB)"

# --- Ports 80, 443 free ---
info "Проверка портов 80 и 443..."
for port in 80 443; do
    if ! validate_port_free "$port"; then
        fail "Порт $port уже занят. Освободите его перед установкой"
    fi
    ok "Порт $port свободен"
done

# --- Internet connectivity ---
info "Проверка подключения к интернету..."
if ! ping -c1 -W5 8.8.8.8 > /dev/null 2>&1; then
    fail "Нет доступа к интернету (ping 8.8.8.8 не прошёл)"
fi
ok "Интернет доступен"

# --- Hub connectivity ---
info "Проверка доступности хаба установщика (${HUB_URL})..."
if ! check_url "$HUB_URL"; then
    fail "Хаб установщика недоступен: ${HUB_URL}"
fi
ok "Хаб доступен: ${HUB_URL}"

log_step "00_preflight" "done"
ok "Все предварительные проверки пройдены"
