#!/bin/bash
set -euo pipefail

### Default Configurable Variables
NEW_USER="devadmin"
SSH_KEY_URL=""
SSH_PORT="2200"
TIMEZONE="America/Jamaica"
OPEN_PORTS=("$SSH_PORT" "80" "443")
F2B_EMAIL="root@localhost"
IGNORED_IPS="127.0.0.1/8"

### Fetch SSH Public Key (from URL)
fetch_ssh_key() {
  echo "[+] Fetching SSH public key"
  curl -fsSL "$SSH_KEY_URL" -o /tmp/sshkey.pub
}

### Add new user and set up SSH
add_user() {
  echo "[+] Creating user: $NEW_USER"
  adduser --disabled-password --gecos "" "$NEW_USER"
  usermod -aG sudo "$NEW_USER"
  mkdir -p /home/$NEW_USER/.ssh
  cp /tmp/sshkey.pub "/home/$NEW_USER/.ssh/authorized_keys"
  chmod 700 /home/$NEW_USER/.ssh
  chmod 600 /home/$NEW_USER/.ssh/authorized_keys
  chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
}

### Harden SSH
harden_ssh() {
  echo "[+] Hardening SSH"
  sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
  sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
  sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
  echo "UseDNS no" >> /etc/ssh/sshd_config
  systemctl reload sshd || systemctl restart sshd
}

### Configure UFW Firewall
setup_firewall() {
  echo "[+] Setting up UFW"
  apt install -y ufw
  ufw default deny incoming
  ufw default allow outgoing
  for port in "${OPEN_PORTS[@]}"; do
    ufw allow "$port"
  done
  ufw --force enable
}

### Configure Fail2Ban
configure_fail2ban() {
  echo "[+] Installing Fail2Ban"
  apt install -y fail2ban
  mkdir -p /etc/fail2ban/jail.d

  cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
ignoreip = $IGNORED_IPS
bantime  = 3600
findtime = 600
maxretry = 3
backend = auto
destemail = $F2B_EMAIL
sender = fail2ban@$(hostname -f)
mta = sendmail
banaction = ufw
loglevel = INFO
logtarget = /var/log/fail2ban.log
EOF

  cat > /etc/fail2ban/jail.d/sshd.local <<EOF
[sshd]
enabled = true
port    = $SSH_PORT
filter  = sshd
logpath = /var/log/auth.log
EOF

  cat > /etc/fail2ban/jail.d/recidive.local <<EOF
[recidive]
enabled  = true
filter   = recidive
logpath  = /var/log/fail2ban.log
bantime  = 86400
findtime = 86400
maxretry = 5
EOF

  systemctl enable fail2ban
  systemctl restart fail2ban
}

### Enable automatic security updates
auto_updates() {
  echo "[+] Enabling auto-updates"
  apt install -y unattended-upgrades
  dpkg-reconfigure -f noninteractive unattended-upgrades
}

### Add helper scripts
install_helpers() {
  echo "[+] Installing helper utilities"
  cat > /usr/local/bin/open-port <<'EOF'
#!/bin/bash
ufw allow "$1" && ufw reload
EOF
  chmod +x /usr/local/bin/open-port

  cat > /usr/local/bin/install-app <<'EOF'
#!/bin/bash
case "$1" in
  docker)
    apt update
    apt install -y docker.io
    systemctl enable docker
    systemctl start docker
    ;;
  nginx)
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
    ;;
  htop)
    apt install -y htop
    ;;
  monit)
    apt install -y monit
    systemctl enable monit
    systemctl start monit
    ;;
  *)
    echo "No handler for $1"
    ;;
esac
EOF
  chmod +x /usr/local/bin/install-app
}

### Initial setup wrapper
initial_setup() {
  echo "[+] Running initial setup"
  apt update && apt upgrade -y
  timedatectl set-timezone "$TIMEZONE"
  fetch_ssh_key
  add_user
  harden_ssh
  setup_firewall
  configure_fail2ban
  auto_updates
  install_helpers
  echo "Server setup complete. Login via: ssh -p $SSH_PORT $NEW_USER@<server-ip>"
}

initial_setup
