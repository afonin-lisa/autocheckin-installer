#!/bin/bash
# Wizard 95: Remote Access (stub for Phase 4D)
header "Шаг 11/12: Remote Access"

info "Генерирую SSH-ключ для будущего подключения к bastion..."
mkdir -p "$INSTALL_DIR/.ssh"
if [ ! -f "$INSTALL_DIR/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -f "$INSTALL_DIR/.ssh/id_ed25519" -N "" -q
    ok "SSH-ключ создан: $INSTALL_DIR/.ssh/id_ed25519.pub"
else
    ok "SSH-ключ уже существует"
fi
info "Remote access будет настроен после подключения к bastion (Phase 4D)"
log_step "95_remote_access" "stub"
