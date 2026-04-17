#!/bin/bash
# SHA256 integrity check of critical files
INSTALL_DIR="${INSTALL_DIR:-/host/opt/autocheckin}"
HUB_URL="${HUB_URL:-https://license.afonin-lisa.ru}"
LICENSE_KEY="${LICENSE_KEY:-}"

FILES=(
    "app/core/crypto.py"
    "app/core/mtls.py"
    "app/config.py"
    "app/main.py"
)

HASHES=""
for f in "${FILES[@]}"; do
    filepath="$INSTALL_DIR/$f"
    if [ -f "$filepath" ]; then
        hash=$(sha256sum "$filepath" | awk '{print $1}')
        HASHES="${HASHES}${f}:${hash};"
    fi
done

# Report to hub (best-effort)
if [ -n "$LICENSE_KEY" ] && [ -n "$HASHES" ]; then
    curl -sf -X POST "${HUB_URL}/v1/integrity" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${LICENSE_KEY}" \
        -d "{\"license_key\":\"${LICENSE_KEY}\",\"hashes\":\"${HASHES}\"}" \
        > /dev/null 2>&1 || true
fi

echo "[integrity] Checked ${#FILES[@]} files"
