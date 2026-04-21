#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  AutoCheckin Installer v1.0.0                                ║
# ║  SaaS для автоматизации посуточной аренды                    ║
# ║                                                              ║
# ║  curl -sSL https://install.afonin-lisa.ru | sudo bash        ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

INSTALLER_VERSION="1.0.0"
INSTALL_DIR="/opt/autocheckin"
INSTALLER_DIR="/opt/autocheckin-installer"
STATE_FILE="$INSTALL_DIR/.install-state"
HUB_URL="https://install.afonin-lisa.ru"

# Self-bootstrap: download full installer and re-exec with real terminal
if [ ! -f "$INSTALLER_DIR/lib/colors.sh" ]; then
    echo "Скачиваю установщик..."
    apt-get update -qq && apt-get install -y -qq git curl > /dev/null 2>&1 || true
    if [ -d "$INSTALLER_DIR/.git" ]; then
        cd "$INSTALLER_DIR" && git pull --ff-only 2>/dev/null || true
    else
        git clone https://github.com/afonin-lisa/autocheckin-installer.git "$INSTALLER_DIR" 2>/dev/null || true
    fi
fi

# If running from pipe (stdin is not a terminal), re-exec with terminal
if [ ! -t 0 ]; then
    echo "Установщик скачан. Запускаю интерактивный режим..."
    exec bash "$INSTALLER_DIR/install.sh" "$@" < /dev/tty
fi

# Source libraries
for lib in "$INSTALLER_DIR"/lib/*.sh; do
    source "$lib"
done

init_logs
header "AutoCheckin Installer v${INSTALLER_VERSION}"

# Check root
[ "$(id -u)" -eq 0 ] || fail "Запустите от root: sudo bash install.sh"

# Create install dir
mkdir -p "$INSTALL_DIR"

# Load state (resume support)
declare -A INSTALL_STATE
if [ -f "$STATE_FILE" ]; then
    while IFS='=' read -r key value; do
        [ -n "$key" ] && INSTALL_STATE["$key"]="$value"
    done < "$STATE_FILE"
    info "Обнаружена предыдущая установка, продолжаем..."
fi

save_state() {
    local key="$1" value="$2"
    INSTALL_STATE["$key"]="$value"
    : > "$STATE_FILE"
    for k in "${!INSTALL_STATE[@]}"; do
        echo "${k}=${INSTALL_STATE[$k]}" >> "$STATE_FILE"
    done
}

step_done() {
    [ "${INSTALL_STATE[$1]:-}" = "done" ]
}

# Parse flags
UPDATE_MODE=false
KEEP_ENV=false
for arg in "$@"; do
    case "$arg" in
        --update) UPDATE_MODE=true ;;
        --keep-env) KEEP_ENV=true ;;
    esac
done

# Run wizards
for wizard in "$INSTALLER_DIR"/wizards/[0-9]*.sh; do
    [ -f "$wizard" ] || continue
    step_name=$(basename "$wizard" .sh)
    if step_done "$step_name" && [ "$UPDATE_MODE" = false ]; then
        info "Пропускаю $step_name (уже выполнен)"
        continue
    fi
    log "Running wizard: $step_name"
    source "$wizard" || {
        warn "Шаг $step_name завершился с ошибкой"
        if ! confirm "Продолжить установку?"; then
            fail "Установка прервана на шаге $step_name"
        fi
    }
    save_state "$step_name" "done"
done

header "Установка завершена!"
ok "AutoCheckin работает на https://${INSTALL_STATE[domain]:-localhost}"
ok "Админ-панель: https://${INSTALL_STATE[domain]:-localhost}/admin/"
info "Логи: /var/log/autocheckin/install.log"
info "Recovery: /opt/autocheckin-installer/recovery/"
