#!/bin/bash
# Wizard 20: License validation
# Asks for license key, computes hardware hash, registers with license server

header "Активация лицензии"
log_step "20_license" "start"

LICENSE_SERVER="https://license.afonin-lisa.ru/v1/register"

# --- Compute hardware hash ---
info "Вычисление аппаратного идентификатора..."

_hw_product_uuid() {
    cat /sys/class/dmi/id/product_uuid 2>/dev/null \
        || cat /proc/sys/kernel/random/boot_id 2>/dev/null \
        || echo "unknown-uuid"
}

_hw_mac() {
    ip link 2>/dev/null \
        | awk '/ether/ {print $2; exit}' \
        || echo "00:00:00:00:00:00"
}

_hw_disk_serial() {
    local serial
    # Try udevadm first (non-destructive, no root i/o)
    serial=$(udevadm info --query=all --name=/dev/sda 2>/dev/null \
        | grep -i 'ID_SERIAL=' | head -1 | cut -d= -f2)
    if [ -z "$serial" ]; then
        serial=$(cat /sys/block/sda/device/serial 2>/dev/null \
              || lsblk -ndo SERIAL /dev/sda 2>/dev/null \
              || echo "unknown-serial")
    fi
    echo "$serial"
}

HW_UUID=$(_hw_product_uuid)
HW_MAC=$(_hw_mac)
HW_DISK=$(_hw_disk_serial)
HARDWARE_HASH=$(echo -n "${HW_UUID}${HW_MAC}${HW_DISK}" | sha256sum | awk '{print $1}')
ok "Hardware ID: ${HARDWARE_HASH:0:16}..."

# --- Ask for license key ---
LICENSE_KEY=$(ask "Введите лицензионный ключ (LIC-XXXXXXXX)" "")

if [ -z "$LICENSE_KEY" ]; then
    warn "Лицензионный ключ не введён — продолжаю в режиме без лицензии"
    save_state "license_tier" "free"
    save_state "license_status" "offline"
    log_step "20_license" "skipped-no-key"
    return 0
fi

# --- Register with license server ---
info "Регистрация лицензии на сервере..."

HTTP_RESPONSE=$(curl -sf --connect-timeout 10 -w "\n%{http_code}" \
    -X POST "$LICENSE_SERVER" \
    -H "Content-Type: application/json" \
    -d "{\"license_key\": \"${LICENSE_KEY}\", \"hardware_hash\": \"${HARDWARE_HASH}\"}" \
    2>/dev/null) || true

HTTP_BODY=$(echo "$HTTP_RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ] && [ -n "$HTTP_BODY" ]; then
    # Parse JSON fields from response
    LICENSE_TIER=$(echo "$HTTP_BODY" | grep -oP '"tier"\s*:\s*"\K[^"]+' | head -1 || echo "")
    KEYSHER_TOKEN=$(echo "$HTTP_BODY" | grep -oP '"keysher_token"\s*:\s*"\K[^"]+' | head -1 || echo "")
    MODULES=$(echo "$HTTP_BODY" | grep -oP '"modules"\s*:\s*\[\K[^\]]+' | head -1 | tr -d '"' | tr ',' ' ' || echo "")

    if [ -n "$LICENSE_TIER" ]; then
        save_state "license_key"      "$LICENSE_KEY"
        save_state "license_tier"     "$LICENSE_TIER"
        save_state "hardware_hash"    "$HARDWARE_HASH"
        [ -n "$KEYSHER_TOKEN" ] && save_state "keysher_token" "$KEYSHER_TOKEN"
        [ -n "$MODULES" ]       && save_state "license_modules" "$MODULES"
        save_state "license_status"   "active"

        ok "Лицензия активирована!"
        ok "Тариф: ${LICENSE_TIER}"
        [ -n "$MODULES" ] && info "Модули: $MODULES"
        log_step "20_license" "done-tier=${LICENSE_TIER}"
    else
        warn "Сервер вернул 200, но тариф не удалось определить — продолжаю"
        save_state "license_key"    "$LICENSE_KEY"
        save_state "license_status" "unknown-response"
        log_step "20_license" "warn-parse-failed"
    fi
else
    warn "Не удалось активировать лицензию (HTTP ${HTTP_CODE:-нет ответа})"
    warn "Продолжаю установку без подтверждённой лицензии"
    save_state "license_key"    "$LICENSE_KEY"
    save_state "license_status" "offline"
    save_state "license_tier"   "free"
    log_step "20_license" "warn-offline"
fi
