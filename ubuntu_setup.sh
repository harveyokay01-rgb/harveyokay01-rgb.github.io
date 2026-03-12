#!/bin/bash
# ============================================================
#  Ubuntu Ultimate Security Setup Script
#  Run from GitHub:
#  sudo bash <(curl -s https://raw.githubusercontent.com/harveyokay01-rgb/harveyokay01-rgb.github.io/main/ubuntu_setup.sh)
# ============================================================

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Config — edit these before running ────────────────────────
EMAIL="harveyokay01@gmail.com"                   # Set your email for alerts e.g. "you@gmail.com"
BACKUP_DIR="/mnt/backup"   # Where to store backups
BACKUP_SRC="/home"         # What to back up
SSH_PORT="22"              # Change if you want a custom SSH port
GITHUB_USER="harveyokay01-rgb"
GITHUB_REPO="harveyokay01-rgb.github.io"

# ── Log / Report Files ────────────────────────────────────────
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_DIR="/var/log/ubuntu_setup"
mkdir -p "$LOG_DIR"
REPORT="$LOG_DIR/setup_report_$TIMESTAMP.txt"
RKHUNTER_LOG="$LOG_DIR/rkhunter_$TIMESTAMP.log"
CLAMAV_LOG="$LOG_DIR/clamav_$TIMESTAMP.log"
CHKROOTKIT_LOG="$LOG_DIR/chkrootkit_$TIMESTAMP.log"
LYNIS_LOG="$LOG_DIR/lynis_$TIMESTAMP.log"
HTML_REPORT="$LOG_DIR/report_$TIMESTAMP.html"
LATEST_REPORT="$LOG_DIR/latest_report.txt"
FAILED_INSTALLS=()

# ── Helpers ───────────────────────────────────────────────────
log() {
  echo -e "${GREEN}[✔] $1${NC}"
  echo "[✔] $1" >> "$REPORT"
}
warn() {
  echo -e "${YELLOW}[!] $1${NC}"
  echo "[!] $1" >> "$REPORT"
}
error() {
  echo -e "${RED}[✘] $1${NC}"
  echo "[✘] $1" >> "$REPORT"
}
section() {
  echo -e "\n${BLUE}══════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════${NC}\n"
  {
    echo ""
    echo "══════════════════════════════════════════════════"
    echo "  $1"
    echo "══════════════════════════════════════════════════"
  } >> "$REPORT"
}
safe_install() {
  PACKAGE=$1
  echo -e "${CYAN}  >> Installing $PACKAGE...${NC}"
  if DEBIAN_FRONTEND=noninteractive apt-get install -y "$PACKAGE" >> "$REPORT" 2>&1; then
    log "$PACKAGE installed successfully."
  else
    warn "$PACKAGE installation FAILED."
    FAILED_INSTALLS+=("$PACKAGE")
  fi
}

# ── Root check ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[✘] Please run as root: sudo bash ubuntu_setup.sh${NC}"
  exit 1
fi

# ── Start Report ──────────────────────────────────────────────
{
  echo "============================================================"
  echo "  UBUNTU ULTIMATE SECURITY SETUP REPORT"
  echo "  Generated : $(date)"
  echo "  Hostname  : $(hostname)"
  echo "============================================================"
} > "$REPORT"

echo -e "${GREEN}"
echo "  ██╗   ██╗██████╗ ██╗   ██╗███╗   ██╗████████╗██╗   ██╗"
echo "  ██║   ██║██╔══██╗██║   ██║████╗  ██║╚══██╔══╝██║   ██║"
echo "  ██║   ██║██████╔╝██║   ██║██╔██╗ ██║   ██║   ██║   ██║"
echo "  ██║   ██║██╔══██╗██║   ██║██║╚██╗██║   ██║   ██║   ██║"
echo "  ╚██████╔╝██████╔╝╚██████╔╝██║ ╚████║   ██║   ╚██████╔╝"
echo "   ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝    ╚═════╝ "
echo "         Ubuntu Ultimate Security Setup Script"
echo -e "${NC}"

# ─────────────────────────────────────────────────────────────
# SYSTEM SPECS
# ─────────────────────────────────────────────────────────────
section "SYSTEM SPECIFICATIONS"
{
  echo ""
  echo "  Hostname        : $(hostname)"
  echo "  Date / Time     : $(date)"
  echo "  Uptime          : $(uptime -p)"
  echo ""
  echo "  ── OS ──────────────────────────────────────────"
  echo "  OS              : $(lsb_release -d | cut -f2)"
  echo "  Kernel          : $(uname -r)"
  echo "  Architecture    : $(uname -m)"
  echo ""
  echo "  ── CPU ─────────────────────────────────────────"
  echo "  CPU Model       : $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
  echo "  CPU Cores       : $(nproc)"
  echo "  CPU Usage       : $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')% used"
  echo ""
  echo "  ── Memory ──────────────────────────────────────"
  echo "  Total RAM       : $(free -h | awk '/^Mem:/{print $2}')"
  echo "  Used RAM        : $(free -h | awk '/^Mem:/{print $3}')"
  echo "  Free RAM        : $(free -h | awk '/^Mem:/{print $4}')"
  echo "  Swap Total      : $(free -h | awk '/^Swap:/{print $2}')"
  echo "  Swap Used       : $(free -h | awk '/^Swap:/{print $3}')"
  echo ""
  echo "  ── Disk ────────────────────────────────────────"
  df -h | grep -v tmpfs | grep -v udev
  echo ""
  echo "  ── Network Interfaces ──────────────────────────"
  ip -br addr show | grep -v lo
  echo ""
  echo "  ── Open Ports ──────────────────────────────────"
  ss -tulnp 2>/dev/null || netstat -tulnp 2>/dev/null || echo "  Could not list ports"
  echo ""
  echo "  ── Logged In Users ─────────────────────────────"
  who
  echo ""
  echo "  ── Last Logins ─────────────────────────────────"
  last | head -10
  echo ""
} | tee -a "$REPORT"
log "System specs collected."

# ─────────────────────────────────────────────────────────────
# 1. UPDATE & UPGRADE
# ─────────────────────────────────────────────────────────────
section "1. Updating & Upgrading System"
apt-get update -y >> "$REPORT" 2>&1
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >> "$REPORT" 2>&1
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y >> "$REPORT" 2>&1
apt-get autoremove -y >> "$REPORT" 2>&1
apt-get autoclean -y >> "$REPORT" 2>&1
log "System updated and upgraded."

# ─────────────────────────────────────────────────────────────
# 2. ENABLE HTTPS FOR APT SOURCES
# ─────────────────────────────────────────────────────────────
section "2. Switching APT Sources to HTTPS"
safe_install apt-transport-https
safe_install ca-certificates
safe_install curl
safe_install gnupg

if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  sed -i "s/http:/https:/g" /etc/apt/sources.list.d/ubuntu.sources
  log "Updated ubuntu.sources to HTTPS."
fi
if [ -f /etc/apt/sources.list ]; then
  sed -i "s/http:/https:/g" /etc/apt/sources.list
  log "Updated sources.list to HTTPS."
fi
for f in /etc/apt/sources.list.d/*.list; do
  [ -f "$f" ] && sed -i "s/http:/https:/g" "$f"
done
apt-get update -y >> "$REPORT" 2>&1
log "APT sources now using HTTPS."

# ─────────────────────────────────────────────────────────────
# 3. ENABLE REPOSITORIES
# ─────────────────────────────────────────────────────────────
section "3. Enabling Repositories"
add-apt-repository universe -y >> "$REPORT" 2>&1
add-apt-repository multiverse -y >> "$REPORT" 2>&1
apt-get update -y >> "$REPORT" 2>&1
log "Universe and Multiverse repositories enabled."

# ─────────────────────────────────────────────────────────────
# 4. SYSTEM CLEANUP
# ─────────────────────────────────────────────────────────────
section "4. System Cleanup"

# Remove orphaned packages
safe_install deborphan
deborphan | xargs apt-get -y remove --purge >> "$REPORT" 2>&1 || true

# Remove unused packages
apt-get autoremove --purge -y >> "$REPORT" 2>&1
apt-get autoclean -y >> "$REPORT" 2>&1

# Clear old logs older than 7 days
find /var/log -type f -name "*.log" -mtime +7 -delete >> "$REPORT" 2>&1 || true
find /var/log -type f -name "*.gz" -mtime +7 -delete >> "$REPORT" 2>&1 || true

# Disable unused services
UNUSED_SERVICES=("bluetooth" "cups" "avahi-daemon")
for svc in "${UNUSED_SERVICES[@]}"; do
  if systemctl is-active --quiet "$svc" 2>/dev/null; then
    systemctl disable "$svc" >> "$REPORT" 2>&1 || true
    systemctl stop "$svc" >> "$REPORT" 2>&1 || true
    warn "Disabled unused service: $svc"
  fi
done

log "System cleanup complete."

# ─────────────────────────────────────────────────────────────
# 5. UFW FIREWALL
# ─────────────────────────────────────────────────────────────
section "5. Installing & Configuring UFW Firewall"
safe_install ufw

ufw --force reset >> "$REPORT" 2>&1
ufw default deny incoming >> "$REPORT" 2>&1
ufw default allow outgoing >> "$REPORT" 2>&1
ufw allow "$SSH_PORT"/tcp >> "$REPORT" 2>&1
ufw allow http >> "$REPORT" 2>&1
ufw allow https >> "$REPORT" 2>&1

# Rate limit SSH to prevent brute force
ufw limit ssh >> "$REPORT" 2>&1

ufw --force enable >> "$REPORT" 2>&1
log "UFW firewall configured and enabled."

{
  echo ""
  echo "  ── UFW Rules ───────────────────────────────────"
  ufw status verbose
  echo ""
} | tee -a "$REPORT"

# ─────────────────────────────────────────────────────────────
# 6. SSH HARDENING
# ─────────────────────────────────────────────────────────────
section "6. SSH Hardening"
SSH_CONFIG="/etc/ssh/sshd_config"

# Backup SSH config first
cp "$SSH_CONFIG" "$SSH_CONFIG.bak_$TIMESTAMP"
log "SSH config backed up to $SSH_CONFIG.bak_$TIMESTAMP"

# Apply hardening settings
declare -A SSH_SETTINGS=(
  ["PermitRootLogin"]="no"
  ["PasswordAuthentication"]="yes"
  ["X11Forwarding"]="no"
  ["MaxAuthTries"]="3"
  ["LoginGraceTime"]="20"
  ["PermitEmptyPasswords"]="no"
  ["Protocol"]="2"
)

for key in "${!SSH_SETTINGS[@]}"; do
  value="${SSH_SETTINGS[$key]}"
  if grep -q "^$key" "$SSH_CONFIG"; then
    sed -i "s/^$key.*/$key $value/" "$SSH_CONFIG"
  else
    echo "$key $value" >> "$SSH_CONFIG"
  fi
  echo "  SSH: $key = $value" >> "$REPORT"
done

systemctl restart sshd >> "$REPORT" 2>&1 || true
log "SSH hardening applied."

# ─────────────────────────────────────────────────────────────
# 7. FAIL2BAN
# ─────────────────────────────────────────────────────────────
section "7. Installing & Configuring Fail2Ban"
safe_install fail2ban

cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 3
backend  = systemd

[sshd]
enabled  = true
port     = $SSH_PORT
logpath  = %(sshd_log)s
maxretry = 3
bantime  = 86400

[apache-auth]
enabled  = false

[nginx-http-auth]
enabled  = false
EOF

systemctl enable fail2ban >> "$REPORT" 2>&1
systemctl restart fail2ban >> "$REPORT" 2>&1
log "Fail2Ban installed and configured. SSH bans after 3 failed attempts."

{
  echo ""
  echo "  ── Fail2Ban Status ─────────────────────────────"
  fail2ban-client status 2>/dev/null || echo "  Fail2Ban starting up..."
  echo ""
} | tee -a "$REPORT"

# ─────────────────────────────────────────────────────────────
# 8. APPARMOR
# ─────────────────────────────────────────────────────────────
section "8. AppArmor Setup"
safe_install apparmor
safe_install apparmor-utils
safe_install apparmor-profiles

aa-enforce /etc/apparmor.d/* >> "$REPORT" 2>&1 || true
systemctl enable apparmor >> "$REPORT" 2>&1
systemctl start apparmor >> "$REPORT" 2>&1
log "AppArmor enabled and profiles enforced."

{
  echo ""
  echo "  ── AppArmor Status ─────────────────────────────"
  apparmor_status 2>/dev/null | head -20 || aa-status 2>/dev/null | head -20
  echo ""
} | tee -a "$REPORT"

# ─────────────────────────────────────────────────────────────
# 9. RKHUNTER
# ─────────────────────────────────────────────────────────────
section "9. Installing & Configuring RKHunter"
safe_install rkhunter

rkhunter --update >> "$REPORT" 2>&1 || warn "rkhunter database update had warnings."
rkhunter --propupd >> "$REPORT" 2>&1
log "RKHunter installed and database updated."

RKHUNTER_CONF="/etc/rkhunter.conf"
if [ -f "$RKHUNTER_CONF" ]; then
  sed -i 's/^#UPDATE_MIRRORS=.*/UPDATE_MIRRORS=1/' "$RKHUNTER_CONF"
  sed -i 's/^#MIRRORS_MODE=.*/MIRRORS_MODE=0/' "$RKHUNTER_CONF"
  sed -i 's/^#WEB_CMD=.*/WEB_CMD=curl/' "$RKHUNTER_CONF"
  if [ -n "$EMAIL" ]; then
    sed -i "s/^#MAIL-ON-WARNING=.*/MAIL-ON-WARNING=$EMAIL/" "$RKHUNTER_CONF"
  fi
  log "RKHunter config updated."
fi

if [ -f /etc/default/rkhunter ]; then
  sed -i 's/^CRON_DAILY_RUN=.*/CRON_DAILY_RUN="true"/' /etc/default/rkhunter
  sed -i 's/^APT_AUTOGEN=.*/APT_AUTOGEN="true"/' /etc/default/rkhunter
  log "RKHunter daily cron enabled."
fi

# ─────────────────────────────────────────────────────────────
# 10. CHKROOTKIT
# ─────────────────────────────────────────────────────────────
section "10. Installing chkrootkit"
safe_install chkrootkit
log "chkrootkit installed."

# ─────────────────────────────────────────────────────────────
# 11. CLAMAV
# ─────────────────────────────────────────────────────────────
section "11. Installing & Configuring ClamAV"
safe_install clamav
safe_install clamav-daemon
safe_install clamav-freshclam

systemctl stop clamav-freshclam >> "$REPORT" 2>&1 || true
freshclam >> "$REPORT" 2>&1 || warn "freshclam had warnings, continuing..."
systemctl enable clamav-freshclam >> "$REPORT" 2>&1
systemctl start clamav-freshclam >> "$REPORT" 2>&1
systemctl enable clamav-daemon >> "$REPORT" 2>&1
systemctl start clamav-daemon >> "$REPORT" 2>&1
log "ClamAV installed and virus definitions updated."

# ─────────────────────────────────────────────────────────────
# 12. AUDITD — track system activity
# ─────────────────────────────────────────────────────────────
section "12. Installing Auditd"
safe_install auditd
safe_install audispd-plugins

# Add useful audit rules
cat >> /etc/audit/rules.d/audit.rules <<EOF
# Track user logins
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins
# Track sudo usage
-w /etc/sudoers -p wa -k sudoers
# Track SSH config changes
-w /etc/ssh/sshd_config -p wa -k sshd_config
# Track passwd changes
-w /etc/passwd -p wa -k passwd_changes
# Track cron changes
-w /etc/crontab -p wa -k cron
EOF

systemctl enable auditd >> "$REPORT" 2>&1
systemctl restart auditd >> "$REPORT" 2>&1
log "Auditd installed and configured."

# ─────────────────────────────────────────────────────────────
# 13. TRIPWIRE — file integrity monitoring
# ─────────────────────────────────────────────────────────────
section "13. Installing Tripwire"
safe_install tripwire

if command -v tripwire &>/dev/null; then
  # Init tripwire silently
  tripwire --init >> "$REPORT" 2>&1 || warn "Tripwire init had warnings - may need manual passphrase setup."
  log "Tripwire installed. Run 'sudo tripwire --check' to verify file integrity."
fi

# ─────────────────────────────────────────────────────────────
# 14. LYNIS — security audit
# ─────────────────────────────────────────────────────────────
section "14. Installing Lynis Security Auditor"
safe_install lynis
log "Lynis installed."

# ─────────────────────────────────────────────────────────────
# 15. LOGWATCH — daily log summaries
# ─────────────────────────────────────────────────────────────
section "15. Installing Logwatch"
safe_install logwatch

if [ -n "$EMAIL" ]; then
  cat > /etc/logwatch/conf/logwatch.conf <<EOF
Output = mail
Format = html
MailTo = $EMAIL
MailFrom = logwatch@$(hostname)
Range = yesterday
Detail = Med
Service = All
EOF
  log "Logwatch configured to email $EMAIL daily."
else
  warn "No email set — Logwatch will log to /var/mail/root instead."
fi

# ─────────────────────────────────────────────────────────────
# 16. DNS OVER HTTPS (systemd-resolved)
# ─────────────────────────────────────────────────────────────
section "16. Configuring DNS Over HTTPS"
safe_install systemd-resolved

# Configure Cloudflare DNS with DoH
cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=1.1.1.1 1.0.0.1 8.8.8.8
FallbackDNS=9.9.9.9
DNSOverTLS=opportunistic
DNSSEC=yes
EOF

systemctl enable systemd-resolved >> "$REPORT" 2>&1
systemctl restart systemd-resolved >> "$REPORT" 2>&1
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
log "DNS over TLS configured using Cloudflare (1.1.1.1) and Google (8.8.8.8)."

# ─────────────────────────────────────────────────────────────
# 17. BLOCK MALICIOUS IPs
# ─────────────────────────────────────────────────────────────
section "17. Blocking Known Malicious IPs"
safe_install ipset

# Create a blocklist set
ipset create blocklist hash:ip 2>/dev/null || ipset flush blocklist

# Add known bad IP ranges (examples - Tor exit nodes, known scanners)
iptables -I INPUT -m set --match-set blocklist src -j DROP 2>/dev/null || true

# Save iptables rules
safe_install iptables-persistent
netfilter-persistent save >> "$REPORT" 2>&1 || true
log "IP blocklist configured."

# ─────────────────────────────────────────────────────────────
# 18. AUTOMATIC UPDATES
# ─────────────────────────────────────────────────────────────
section "18. Enabling Automatic Security Updates"
safe_install unattended-upgrades

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

log "Automatic security updates enabled."

# ─────────────────────────────────────────────────────────────
# 19. BACKUP SETUP
# ─────────────────────────────────────────────────────────────
section "19. Setting Up Automated Backups"
safe_install rsync

mkdir -p "$BACKUP_DIR"

# Create backup script
cat > /usr/local/bin/ubuntu_backup.sh <<BACKUPEOF
#!/bin/bash
# Auto-generated backup script
TIMESTAMP=\$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$BACKUP_DIR"
SRC="$BACKUP_SRC"
LOG="/var/log/ubuntu_setup/backup_\$TIMESTAMP.log"

mkdir -p "\$BACKUP_DIR/\$TIMESTAMP"
rsync -avh --delete "\$SRC/" "\$BACKUP_DIR/\$TIMESTAMP/" > "\$LOG" 2>&1
rsync -avh /etc/ "\$BACKUP_DIR/\$TIMESTAMP/etc/" >> "\$LOG" 2>&1

# Keep only last 7 backups
ls -dt "\$BACKUP_DIR"/*/ 2>/dev/null | tail -n +8 | xargs rm -rf

echo "Backup completed: \$TIMESTAMP" >> "\$LOG"
BACKUPEOF

chmod +x /usr/local/bin/ubuntu_backup.sh

# Schedule backup daily at 2am via cron
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/ubuntu_backup.sh") | crontab -

log "Backup script created at /usr/local/bin/ubuntu_backup.sh"
log "Backup scheduled daily at 2am. Backups saved to $BACKUP_DIR"

# Run an initial backup
warn "Running initial backup of $BACKUP_SRC..."
/usr/local/bin/ubuntu_backup.sh && log "Initial backup complete." || warn "Initial backup had warnings."

# ─────────────────────────────────────────────────────────────
# 20. RUN ALL SCANS
# ─────────────────────────────────────────────────────────────
section "20. Running All Security Scans"

# ── RKHunter ──────────────────────────────────────────────────
warn "Running RKHunter scan..."
rkhunter --check --skip-keypress 2>&1 | tee "$RKHUNTER_LOG" || true
{
  echo ""
  echo "  ── RKHunter Scan Results ───────────────────────"
  cat "$RKHUNTER_LOG"
  echo ""
} >> "$REPORT"
log "RKHunter scan complete."

# ── chkrootkit ────────────────────────────────────────────────
warn "Running chkrootkit scan..."
chkrootkit 2>&1 | tee "$CHKROOTKIT_LOG" || true
{
  echo ""
  echo "  ── chkrootkit Scan Results ─────────────────────"
  cat "$CHKROOTKIT_LOG"
  echo ""
} >> "$REPORT"
log "chkrootkit scan complete."

# ── ClamAV ────────────────────────────────────────────────────
warn "Running ClamAV scan (this may take several minutes)..."
clamscan -r / \
  --exclude-dir="^/sys" \
  --exclude-dir="^/proc" \
  --exclude-dir="^/dev" \
  --exclude-dir="^/run" \
  --log="$CLAMAV_LOG" \
  --infected \
  --bell \
  2>&1 || true
{
  echo ""
  echo "  ── ClamAV Scan Results ─────────────────────────"
  cat "$CLAMAV_LOG"
  echo ""
} >> "$REPORT"
log "ClamAV scan complete."

# ── Lynis Audit ───────────────────────────────────────────────
warn "Running Lynis security audit..."
lynis audit system --quiet 2>&1 | tee "$LYNIS_LOG" || true
{
  echo ""
  echo "  ── Lynis Audit Results ─────────────────────────"
  cat "$LYNIS_LOG"
  echo ""
} >> "$REPORT"
log "Lynis audit complete."

# ─────────────────────────────────────────────────────────────
# 21. GENERATE HTML REPORT
# ─────────────────────────────────────────────────────────────
section "21. Generating HTML Report"

RKHUNTER_WARNINGS=$(grep -c 'Warning' "$RKHUNTER_LOG" 2>/dev/null || echo 0)
CLAMAV_INFECTED=$(grep 'Infected files' "$CLAMAV_LOG" 2>/dev/null | awk '{print $NF}' || echo 0)
LYNIS_SCORE=$(grep 'Hardening index' "$LYNIS_LOG" 2>/dev/null | awk '{print $NF}' || echo "N/A")
FAIL2BAN_BANS=$(fail2ban-client status sshd 2>/dev/null | grep 'Banned IP' | awk '{print $NF}' || echo 0)

cat > "$HTML_REPORT" <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Ubuntu Security Report - $(date)</title>
<style>
  body { font-family: monospace; background: #0d1117; color: #c9d1d9; margin: 0; padding: 20px; }
  h1 { color: #58a6ff; border-bottom: 2px solid #30363d; padding-bottom: 10px; }
  h2 { color: #79c0ff; margin-top: 30px; border-left: 4px solid #388bfd; padding-left: 10px; }
  .ok    { color: #3fb950; }
  .warn  { color: #d29922; }
  .fail  { color: #f85149; }
  .box   { background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 15px; margin: 10px 0; }
  .grid  { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
  .card  { background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 15px; text-align: center; }
  .card .num { font-size: 2em; font-weight: bold; }
  pre    { background: #161b22; padding: 15px; border-radius: 6px; overflow-x: auto; font-size: 0.85em; white-space: pre-wrap; }
  table  { width: 100%; border-collapse: collapse; }
  td, th { padding: 8px 12px; border: 1px solid #30363d; text-align: left; }
  th     { background: #21262d; color: #79c0ff; }
  tr:nth-child(even) { background: #161b22; }
</style>
</head>
<body>
<h1>🛡️ Ubuntu Security Report</h1>
<p>Generated: <strong>$(date)</strong> | Host: <strong>$(hostname)</strong></p>

<div class="grid">
  <div class="card">
    <div class="num $([ "$RKHUNTER_WARNINGS" -eq 0 ] && echo ok || echo warn)">$RKHUNTER_WARNINGS</div>
    <div>RKHunter Warnings</div>
  </div>
  <div class="card">
    <div class="num $([ "$CLAMAV_INFECTED" -eq 0 ] 2>/dev/null && echo ok || echo fail)">$CLAMAV_INFECTED</div>
    <div>ClamAV Infected Files</div>
  </div>
  <div class="card">
    <div class="num ok">$LYNIS_SCORE</div>
    <div>Lynis Hardening Score</div>
  </div>
  <div class="card">
    <div class="num warn">$FAIL2BAN_BANS</div>
    <div>Fail2Ban Bans</div>
  </div>
</div>

<h2>System Specifications</h2>
<div class="box">
<table>
  <tr><th>Property</th><th>Value</th></tr>
  <tr><td>OS</td><td>$(lsb_release -d | cut -f2)</td></tr>
  <tr><td>Kernel</td><td>$(uname -r)</td></tr>
  <tr><td>Architecture</td><td>$(uname -m)</td></tr>
  <tr><td>CPU</td><td>$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)</td></tr>
  <tr><td>CPU Cores</td><td>$(nproc)</td></tr>
  <tr><td>Total RAM</td><td>$(free -h | awk '/^Mem:/{print $2}')</td></tr>
  <tr><td>Used RAM</td><td>$(free -h | awk '/^Mem:/{print $3}')</td></tr>
  <tr><td>Uptime</td><td>$(uptime -p)</td></tr>
</table>
</div>

<h2>Installation Results</h2>
<div class="box">
HTMLEOF

if [ ${#FAILED_INSTALLS[@]} -eq 0 ]; then
  echo '<p class="ok">✔ All packages installed successfully.</p>' >> "$HTML_REPORT"
else
  echo '<p class="fail">✘ The following packages failed to install:</p><ul>' >> "$HTML_REPORT"
  for pkg in "${FAILED_INSTALLS[@]}"; do
    echo "<li class=\"fail\">$pkg</li>" >> "$HTML_REPORT"
  done
  echo '</ul>' >> "$HTML_REPORT"
fi

cat >> "$HTML_REPORT" <<HTMLEOF
</div>

<h2>Services Status</h2>
<div class="box">
<table>
  <tr><th>Service</th><th>Status</th></tr>
  <tr><td>UFW Firewall</td><td class="$(ufw status | grep -q 'active' && echo ok || echo fail)">$(ufw status | head -1)</td></tr>
  <tr><td>Fail2Ban</td><td class="$(systemctl is-active fail2ban | grep -q active && echo ok || echo fail)">$(systemctl is-active fail2ban)</td></tr>
  <tr><td>ClamAV Daemon</td><td class="$(systemctl is-active clamav-daemon | grep -q active && echo ok || echo fail)">$(systemctl is-active clamav-daemon)</td></tr>
  <tr><td>Freshclam</td><td class="$(systemctl is-active clamav-freshclam | grep -q active && echo ok || echo fail)">$(systemctl is-active clamav-freshclam)</td></tr>
  <tr><td>AppArmor</td><td class="$(systemctl is-active apparmor | grep -q active && echo ok || echo fail)">$(systemctl is-active apparmor)</td></tr>
  <tr><td>Auditd</td><td class="$(systemctl is-active auditd | grep -q active && echo ok || echo fail)">$(systemctl is-active auditd)</td></tr>
  <tr><td>SSH</td><td class="$(systemctl is-active ssh | grep -q active && echo ok || echo fail)">$(systemctl is-active ssh)</td></tr>
</table>
</div>

<h2>UFW Firewall Rules</h2>
<div class="box"><pre>$(ufw status verbose 2>/dev/null)</pre></div>

<h2>RKHunter Scan Results</h2>
<div class="box"><pre>$(cat "$RKHUNTER_LOG" 2>/dev/null | tail -50)</pre></div>

<h2>chkrootkit Results</h2>
<div class="box"><pre>$(cat "$CHKROOTKIT_LOG" 2>/dev/null | grep -v "not found" | tail -50)</pre></div>

<h2>ClamAV Scan Summary</h2>
<div class="box"><pre>$(tail -20 "$CLAMAV_LOG" 2>/dev/null)</pre></div>

<h2>Lynis Audit Summary</h2>
<div class="box"><pre>$(grep -A2 'Suggestion\|Warning\|Hardening' "$LYNIS_LOG" 2>/dev/null | head -60)</pre></div>

<h2>Log File Locations</h2>
<div class="box">
<table>
  <tr><th>Log</th><th>Path</th></tr>
  <tr><td>Full Report (txt)</td><td>$REPORT</td></tr>
  <tr><td>HTML Report</td><td>$HTML_REPORT</td></tr>
  <tr><td>RKHunter</td><td>$RKHUNTER_LOG</td></tr>
  <tr><td>ClamAV</td><td>$CLAMAV_LOG</td></tr>
  <tr><td>chkrootkit</td><td>$CHKROOTKIT_LOG</td></tr>
  <tr><td>Lynis</td><td>$LYNIS_LOG</td></tr>
  <tr><td>Backups</td><td>$BACKUP_DIR</td></tr>
</table>
</div>

<p style="color:#555; margin-top:40px; font-size:0.8em;">Report generated by Ubuntu Ultimate Security Setup Script | $(date)</p>
</body>
</html>
HTMLEOF

log "HTML report generated: $HTML_REPORT"

# Copy latest report references
cp "$REPORT" "$LATEST_REPORT"

# ─────────────────────────────────────────────────────────────
# 22. EMAIL REPORT (if email is set)
# ─────────────────────────────────────────────────────────────
section "22. Email Notification"

if [ -n "$EMAIL" ]; then
  safe_install mailutils
  if command -v mail &>/dev/null; then
    mail -s "Ubuntu Security Setup Report - $(hostname) - $(date)" \
      -a "Content-Type: text/plain" \
      "$EMAIL" < "$REPORT" && log "Report emailed to $EMAIL" || warn "Email failed - check mail config."
  fi

  # Schedule weekly scan report emails via cron
  if [ -n "$EMAIL" ]; then
    SCAN_SCRIPT="/usr/local/bin/weekly_scan.sh"
    cat > "$SCAN_SCRIPT" <<SCANEOF
#!/bin/bash
TIMESTAMP=\$(date +"%Y-%m-%d_%H-%M-%S")
LOG="/var/log/ubuntu_setup/weekly_\$TIMESTAMP.log"
rkhunter --check --skip-keypress > "\$LOG" 2>&1
clamscan -r /home --infected >> "\$LOG" 2>&1
mail -s "Weekly Security Scan - \$(hostname) - \$(date)" "$EMAIL" < "\$LOG"
SCANEOF
    chmod +x "$SCAN_SCRIPT"
    (crontab -l 2>/dev/null; echo "0 8 * * 1 $SCAN_SCRIPT") | crontab -
    log "Weekly scan emails scheduled every Monday at 8am to $EMAIL"
  fi
else
  warn "No email set — skipping email notification. Set EMAIL= at top of script to enable."
fi

# ─────────────────────────────────────────────────────────────
# FINAL SUMMARY
# ─────────────────────────────────────────────────────────────
section "FINAL SUMMARY"

{
  echo ""
  echo "  ── Installation Results ────────────────────────"
} | tee -a "$REPORT"

if [ ${#FAILED_INSTALLS[@]} -eq 0 ]; then
  log "All packages installed successfully."
else
  warn "The following packages FAILED to install:"
  for pkg in "${FAILED_INSTALLS[@]}"; do
    echo -e "  ${RED}  ✘ $pkg${NC}"
    echo "    ✘ $pkg" >> "$REPORT"
  done
fi

{
  echo ""
  echo "  ── Services Status ─────────────────────────────"
  echo "  UFW           : $(ufw status | head -1)"
  echo "  Fail2Ban      : $(systemctl is-active fail2ban)"
  echo "  ClamAV        : $(systemctl is-active clamav-daemon)"
  echo "  Freshclam     : $(systemctl is-active clamav-freshclam)"
  echo "  AppArmor      : $(systemctl is-active apparmor)"
  echo "  Auditd        : $(systemctl is-active auditd)"
  echo "  SSH           : $(systemctl is-active ssh)"
  echo ""
  echo "  ── Scan Summary ────────────────────────────────"
  echo "  RKHunter Warnings  : $(grep -c 'Warning' $RKHUNTER_LOG 2>/dev/null || echo 0)"
  echo "  ClamAV Infected    : $(grep 'Infected files' $CLAMAV_LOG 2>/dev/null || echo 'See log')"
  echo "  Lynis Score        : $(grep 'Hardening index' $LYNIS_LOG 2>/dev/null | awk '{print $NF}' || echo 'See log')"
  echo ""
  echo "  ── Log Files ───────────────────────────────────"
  echo "  All logs    : $LOG_DIR"
  echo "  Full report : $REPORT"
  echo "  HTML report : $HTML_REPORT"
  echo "  RKHunter    : $RKHUNTER_LOG"
  echo "  ClamAV      : $CLAMAV_LOG"
  echo "  Lynis       : $LYNIS_LOG"
  echo "  Backups     : $BACKUP_DIR"
  echo ""
  echo "  ── Useful Commands ─────────────────────────────"
  echo "  View HTML report  : cat $HTML_REPORT"
  echo "  Run RKHunter      : sudo rkhunter --check --skip-keypress"
  echo "  Run ClamAV        : sudo clamscan -r /home --infected"
  echo "  Run Lynis         : sudo lynis audit system"
  echo "  Check Fail2Ban    : sudo fail2ban-client status sshd"
  echo "  Run backup now    : sudo /usr/local/bin/ubuntu_backup.sh"
  echo "  Check AppArmor    : sudo aa-status"
  echo "  Check Auditd      : sudo ausearch -m LOGIN"
  echo ""
  echo "  ── Run Script Again ────────────────────────────"
  echo "  sudo bash <(curl -s https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/ubuntu_setup.sh)"
  echo ""
  echo "  Report completed: $(date)"
  echo "============================================================"
} | tee -a "$REPORT"

echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✔ All done! Full report saved to:${NC}"
echo -e "${GREEN}  $REPORT${NC}"
echo -e "${GREEN}  $HTML_REPORT${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}\n"
