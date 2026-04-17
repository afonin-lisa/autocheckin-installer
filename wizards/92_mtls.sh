#!/bin/bash
# Wizard 92: mTLS Certificate Setup
header "Дополнительно: mTLS сертификаты"

CERT_DIR="$INSTALL_DIR/certs"
mkdir -p "$CERT_DIR"

if [ -f "$CERT_DIR/client.crt" ] && [ -f "$CERT_DIR/client.key" ]; then
    ok "mTLS сертификаты уже существуют"
    log_step "92_mtls" "exists"
    return 0
fi

info "Генерирую клиентский сертификат для mTLS..."

# Generate client private key (ECDSA P-256)
openssl ecparam -genkey -name prime256v1 -out "$CERT_DIR/client.key" 2>/dev/null

# Generate CSR
LICENSE_KEY="${INSTALL_STATE[license_key]:-autocheckin}"
openssl req -new -key "$CERT_DIR/client.key" \
    -out "$CERT_DIR/client.csr" \
    -subj "/CN=${LICENSE_KEY}/O=AutoCheckin Client" 2>/dev/null

# Request Hub to sign the CSR
info "Запрашиваю подпись у Hub CA..."
CSR_B64=$(base64 -w0 "$CERT_DIR/client.csr")
RESPONSE=$(curl -sf -X POST "https://license.afonin-lisa.ru/v1/mtls/sign" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${INSTALL_STATE[license_key]:-}" \
    -d "{\"csr\":\"${CSR_B64}\"}" 2>/dev/null) || {
    warn "Hub CA недоступен — mTLS отложен"
    warn "Продолжаю без mTLS (HTTPS + Bearer token)"
    log_step "92_mtls" "deferred"
    return 0
}

# Save signed certificate
echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['certificate'])" 2>/dev/null | base64 -d > "$CERT_DIR/client.crt"

# Save CA cert
echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['ca_cert'])" 2>/dev/null | base64 -d > "$CERT_DIR/ca.crt"

chmod 600 "$CERT_DIR/client.key"
chmod 644 "$CERT_DIR/client.crt" "$CERT_DIR/ca.crt"

save_state "mtls_cert" "$CERT_DIR/client.crt"
save_state "mtls_key" "$CERT_DIR/client.key"
save_state "mtls_ca" "$CERT_DIR/ca.crt"

ok "mTLS сертификат получен и подписан Hub CA"
log_step "92_mtls" "done"
