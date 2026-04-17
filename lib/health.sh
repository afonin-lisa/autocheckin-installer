#!/bin/bash
# Health check helpers

check_url() {
    local url="$1"
    local timeout="${2:-5}"
    curl -sf --connect-timeout "$timeout" "$url" > /dev/null 2>&1
}

wait_for_healthy() {
    local url="$1"
    local max_wait="${2:-120}"
    local elapsed=0
    while [ $elapsed -lt $max_wait ]; do
        if check_url "$url"; then
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -ne "\r  Ожидание... ${elapsed}s / ${max_wait}s"
    done
    echo
    return 1
}

get_public_ip() {
    curl -sf --connect-timeout 5 https://ifconfig.me 2>/dev/null || \
    curl -sf --connect-timeout 5 https://api.ipify.org 2>/dev/null || \
    echo ""
}

check_dns_matches_ip() {
    local domain="$1"
    local expected_ip="$2"
    local resolved
    resolved=$(dig +short "$domain" 2>/dev/null | head -1)
    [ "$resolved" = "$expected_ip" ]
}
