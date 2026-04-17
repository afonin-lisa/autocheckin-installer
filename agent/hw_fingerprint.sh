#!/bin/bash
# Generate hardware fingerprint for license binding
HW_UUID=$(cat /host/sys/class/dmi/id/product_uuid 2>/dev/null || echo "unknown")
HW_MAC=$(cat /host/sys/class/net/eth0/address 2>/dev/null || ip link show 2>/dev/null | awk '/ether/ {print $2; exit}' || echo "unknown")
HW_DISK=$(lsblk -ndo SERIAL /dev/sda 2>/dev/null || lsblk -ndo SERIAL /dev/vda 2>/dev/null || echo "unknown")
echo "${HW_UUID}|${HW_MAC}|${HW_DISK}" | sha256sum | awk '{print $1}'
