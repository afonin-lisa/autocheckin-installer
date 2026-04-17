#!/bin/bash
# Wizard 30: Domain setup
# Asks for domain, validates DNS propagation, saves to state

header "Настройка домена"
log_step "30_domain" "start"

DNS_CHECK_INTERVAL=30   # seconds between DNS retries
DNS_CHECK_TIMEOUT=600   # max wait 10 minutes

# --- Get public IP ---
info "Определяю публичный IP-адрес сервера..."
PUBLIC_IP=$(get_public_ip)

if [ -z "$PUBLIC_IP" ]; then
    warn "Не удалось определить публичный IP"
    PUBLIC_IP="unknown"
else
    ok "Публичный IP: ${PUBLIC_IP}"
fi

save_state "server_ip" "$PUBLIC_IP"

# --- Ask for domain ---
DOMAIN=$(ask "Введите домен (например: autocheckin.example.com)" "")

# --- If empty → use IP ---
if [ -z "$DOMAIN" ]; then
    if [ "$PUBLIC_IP" = "unknown" ]; then
        warn "Домен не введён и IP не определён — используется localhost"
        save_state "domain" "localhost"
        save_state "domain_type" "localhost"
    else
        warn "Домен не введён — использую IP-адрес: ${PUBLIC_IP}"
        save_state "domain" "$PUBLIC_IP"
        save_state "domain_type" "ip"
    fi
    log_step "30_domain" "done-ip"
    ok "Домен не задан, используется: ${INSTALL_STATE[domain]}"
    return 0
fi

# --- Validate domain format ---
if ! validate_domain "$DOMAIN"; then
    fail "Некорректный формат домена: '$DOMAIN'. Пример: autocheckin.example.com"
fi
ok "Формат домена корректен: ${DOMAIN}"

# --- If IP is unknown, skip DNS check ---
if [ "$PUBLIC_IP" = "unknown" ]; then
    warn "Пропускаю проверку DNS (публичный IP неизвестен)"
    save_state "domain" "$DOMAIN"
    save_state "domain_type" "domain-no-dns-check"
    log_step "30_domain" "done-no-dns-check"
    return 0
fi

# --- Check DNS matches IP ---
info "Проверяю DNS: ${DOMAIN} → ${PUBLIC_IP}"
info "(Ожидаю до $((DNS_CHECK_TIMEOUT / 60)) минут, интервал ${DNS_CHECK_INTERVAL}с)"

elapsed=0
dns_ok=false

while [ $elapsed -lt $DNS_CHECK_TIMEOUT ]; do
    if check_dns_matches_ip "$DOMAIN" "$PUBLIC_IP"; then
        dns_ok=true
        break
    fi

    RESOLVED=$(dig +short "$DOMAIN" 2>/dev/null | head -1 || echo "не разрешается")
    echo -ne "\r  DNS: ${DOMAIN} → ${RESOLVED:-не разрешается} (ожидаем ${PUBLIC_IP}) | ${elapsed}s / ${DNS_CHECK_TIMEOUT}s  "

    sleep "$DNS_CHECK_INTERVAL"
    elapsed=$((elapsed + DNS_CHECK_INTERVAL))
done

echo  # newline after progress line

if $dns_ok; then
    ok "DNS настроен корректно: ${DOMAIN} → ${PUBLIC_IP}"
    save_state "domain" "$DOMAIN"
    save_state "domain_type" "domain"
    log_step "30_domain" "done-dns-ok"
else
    warn "DNS не совпадает с ожидаемым IP за ${DNS_CHECK_TIMEOUT}s"
    warn "  Домен: ${DOMAIN}"
    warn "  Ожидался IP: ${PUBLIC_IP}"
    RESOLVED=$(dig +short "$DOMAIN" 2>/dev/null | head -1 || echo "не разрешается")
    warn "  Получен: ${RESOLVED:-не разрешается}"
    warn "Продолжаю установку — настройте DNS самостоятельно и перезапустите installer при необходимости"
    save_state "domain" "$DOMAIN"
    save_state "domain_type" "domain-dns-pending"
    log_step "30_domain" "warn-dns-timeout"
fi

ok "Домен сохранён: ${INSTALL_STATE[domain]}"
