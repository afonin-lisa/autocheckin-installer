#!/bin/bash
# Wizard 91: Server Hardening (UFW + fail2ban + SSH)
header "Дополнительно: Hardening сервера"

# --- UFW ---
info "Настраиваю firewall (UFW)..."
if ! command -v ufw &> /dev/null; then
    apt-get install -y -qq ufw > /dev/null 2>&1
fi

ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow 22/tcp comment "SSH" > /dev/null 2>&1
ufw allow 80/tcp comment "HTTP" > /dev/null 2>&1
ufw allow 443/tcp comment "HTTPS" > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
ok "UFW: только SSH(22), HTTP(80), HTTPS(443)"

# --- fail2ban ---
info "Устанавливаю fail2ban..."
if ! command -v fail2ban-client &> /dev/null; then
    apt-get install -y -qq fail2ban > /dev/null 2>&1
fi

cat > /etc/fail2ban/jail.local << 'F2B'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 7200
F2B

systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban > /dev/null 2>&1
ok "fail2ban: SSH brute-force protection"

# --- SSH hardening ---
info "Усиливаю SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONFIG"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONFIG"
sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "$SSHD_CONFIG"

systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
ok "SSH: root password disabled, key-only auth, max 3 tries"

log_step "91_hardening" "done"
