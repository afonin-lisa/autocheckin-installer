#!/bin/bash
# Wizard 95: Remote Access Setup
header "Шаг 11/12: Remote Access"

CERT_DIR="$INSTALL_DIR/.ssh"
mkdir -p "$CERT_DIR"

# Generate SSH key if not exists
if [ ! -f "$CERT_DIR/id_ed25519" ]; then
    ssh-keygen -t ed25519 -f "$CERT_DIR/id_ed25519" -N "" -q
    ok "SSH-ключ создан"
else
    ok "SSH-ключ уже существует"
fi

# Register key with bastion via Hub API
info "Регистрирую SSH-ключ на bastion..."
PUB_KEY=$(cat "$CERT_DIR/id_ed25519.pub")
RESPONSE=$(curl -sf -X POST "https://license.afonin-lisa.ru/v1/bastion/register" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${INSTALL_STATE[license_key]:-}" \
    -d "{\"public_key\":\"${PUB_KEY}\"}" 2>/dev/null) || {
    warn "Не удалось зарегистрировать ключ на bastion"
    warn "Remote access будет настроен позже"
    save_state "bastion_remote_port" "30000"
    log_step "95_remote_access" "deferred"
    return 0
}

# Get allocated port
BASTION_PORT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('bastion_port', 30000))" 2>/dev/null || echo "30000")
save_state "bastion_remote_port" "$BASTION_PORT"

ok "Remote access: port $BASTION_PORT на bastion"
info "Подключение: ssh -p $BASTION_PORT root@bastion.afonin-lisa.ru"

log_step "95_remote_access" "port=$BASTION_PORT"
