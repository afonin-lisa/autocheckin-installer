#!/bin/bash
# Wrapper for cron — auto-update with logging
exec /opt/autocheckin-installer/update.sh >> /var/log/autocheckin/update.log 2>&1
