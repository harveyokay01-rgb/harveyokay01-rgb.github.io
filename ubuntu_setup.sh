#!/bin/bash
# ============================================================
#  Ubuntu Security Setup Script
#  Run from GitHub:
#  sudo bash <(curl -s https://raw.githubusercontent.com/harveyokay01-rgb/harveyokay01-rgb.github.io/main/ubuntu_setup.sh)
# ============================================================

set -e  # Exit on any error

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# ── Report File ───────────────────────────────────────────────
REPORT="/var/log/ubuntu_setup_report.txt"
RKHUNTER_SCAN_LOG="/var/log/rkhunter_scan.log"
CLAMAV_SCAN_LOG="/var/log/clamav_scan.log"
FAILED_INSTALLS=()

# ── Helpers ───────────────────────────────────────────────────
log()     { echo -e "${GREEN}[✔] $1${NC}"; echo "[✔] $1" >> "$REPORT"; }
warn()    { echo -e "${YELLOW}[!] $1${NC}"; echo "[!] $1" >> "$REPORT"; }
error()   { echo -e "${RED}[✘] $1${NC}"; echo "[✘] $1" >> "$REPORT"; exit 1; }
section() {
  echo -e "\n${BLUE}══════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}══════════════════════════════════════${NC}\n"
  {
    echo ""
    echo "══════════════════════════════════════"
    echo "  $1"
    echo "══════════════════════════════════════"
  } >> "$REPORT"
}

# Safe install - tracks failures instead of crashing
safe_install() {
  PACKAGE=$1
  echo -e "${YELLOW}  >> Installing $PACKAGE...${NC}"
  if DEBIAN_FRONTEND=noninteractive apt-get install -y "$PACKAGE" >> "$REPORT" 2>&1; then
    log "$PACKAGE installed successfully."
  else
    warn "$PACKAGE installation FAILED."
    FAILED_INSTALLS+=("$PACKAGE")
  fi
}

# ── Root check ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "Please run as root: sudo bash ubuntu_setup.sh"
fi

# ── Start Report ──────────────────────────────────────────────
{
  echo "============================================================"
  echo "  UBUNTU SECURITY SETUP REPORT"
  echo "  Generated: $(date)"
  echo "============================================================"
} > "$REPORT"

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
  echo "  ── OS ──────────────────────────────────"
  echo "  OS              : $(lsb_release -d | cut -f2)"
  echo "  Kernel          : $(uname -r)"
  echo "  Architecture    : $(uname -m)"
  echo ""
  echo "  ── CPU ─────────────────────────────────"
  echo "  CPU Model       : $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
  echo "  CPU Cores       : $(nproc)"
  echo "  CPU Usage       : $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}')% used"
  echo ""
  echo "  ── Memory ──────────────────────────────"
  echo "  Total RAM       : $(free -h | awk '/^Mem:/{print $2}')"
  echo "  Used RAM        : $(free -h | awk '/^Mem:/{print $3}')"
  echo "  Free RAM        : $(free -h | awk '/^Mem:/{print $4}')"
  echo ""
  echo "  ── Disk ────────────────────────────────"
  df -h | grep -v tmpfs | grep -v udev
  echo ""
  echo "  ── Network ─────────────────────────────"
  ip -br addr show | grep -v lo
  echo ""
  echo "  ── Logged In Users ─────────────────────"
  who
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
# 3. ENABLE UNIVERSE REPOSITORY
# ─────────────────────────────────────────────────────────────
section "3. Enabling Universe Repository"

add-apt-repository universe -y >> "$REPORT" 2>&1
apt-get update -y >> "$REPORT" 2>&1
log "Universe repository enabled."

# ─────────────────────────────────────────────────────────────
# 4. INSTALL & CONFIGURE UFW FIREWALL
# ─────────────────────────────────────────────────────────────
section "4. Installing & Configuring UFW Firewall"

safe_install ufw

ufw --force reset >> "$REPORT" 2>&1
ufw default deny incoming >> "$REPORT" 2>&1
ufw default allow outgoing >> "$REPORT" 2>&1
ufw allow ssh >> "$REPORT" 2>&1
ufw allow http >> "$REPORT" 2>&1
ufw allow https >> "$REPORT" 2>&1
ufw --force enable >> "$REPORT" 2>&1

log "UFW firewall configured and enabled."

{
  echo ""
  echo "  ── UFW Rules ───────────────────────────"
  ufw status verbose
  echo ""
} | tee -a "$REPORT"

# ─────────────────────────────────────────────────────────────
# 5. INSTALL RKHUNTER
# ─────────────────────────────────────────────────────────────
section "5. Installing & Configuring RKHunter"

safe_install rkhunter

rkhunter --update >> "$REPORT" 2>&1 || warn "rkhunter database update had warnings."
rkhunter --propupd >> "$REPORT" 2>&1
log "RKHunter installed and database updated."

RKHUNTER_CONF="/etc/rkhunter.conf"
if [ -f "$RKHUNTER_CONF" ]; then
  sed -i 's/^#UPDATE_MIRRORS=.*/UPDATE_MIRRORS=1/' "$RKHUNTER_CONF"
  sed -i 's/^#MIRRORS_MODE=.*/MIRRORS_MODE=0/' "$RKHUNTER_CONF"
  sed -i 's/^#WEB_CMD=.*/WEB_CMD=curl/' "$RKHUNTER_CONF"
  log "RKHunter config updated."
fi

if [ -f /etc/default/rkhunter ]; then
  sed -i 's/^CRON_DAILY_RUN=.*/CRON_DAILY_RUN="true"/' /etc/default/rkhunter
  sed -i 's/^APT_AUTOGEN=.*/APT_AUTOGEN="true"/' /etc/default/rkhunter
  log "RKHunter daily cron enabled."
fi

# ─────────────────────────────────────────────────────────────
# 6. INSTALL CLAMAV
# ─────────────────────────────────────────────────────────────
section "6. Installing & Configuring ClamAV"

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
# 7. RUN SECURITY SCANS
# ─────────────────────────────────────────────────────────────
section "7. Running Security Scans"

# ── RKHunter Scan ─────────────────────────────────────────────
warn "Running RKHunter scan (this may take a minute)..."
rkhunter --check --skip-keypress 2>&1 | tee "$RKHUNTER_SCAN_LOG" || true

{
  echo ""
  echo "  ── RKHunter Full Scan Results ──────────"
  cat "$RKHUNTER_SCAN_LOG"
  echo ""
} >> "$REPORT"

log "RKHunter scan complete. Log: $RKHUNTER_SCAN_LOG"

# ── ClamAV Scan ───────────────────────────────────────────────
warn "Running ClamAV scan on entire system (this may take several minutes)..."
clamscan -r / \
  --exclude-dir="^/sys" \
  --exclude-dir="^/proc" \
  --exclude-dir="^/dev" \
  --log="$CLAMAV_SCAN_LOG" \
  --infected \
  --bell \
  2>&1 || true

{
  echo ""
  echo "  ── ClamAV Full Scan Results ────────────"
  cat "$CLAMAV_SCAN_LOG"
  echo ""
} >> "$REPORT"

log "ClamAV scan complete. Log: $CLAMAV_SCAN_LOG"

# ─────────────────────────────────────────────────────────────
# 8. AUTOMATIC UPDATES
# ─────────────────────────────────────────────────────────────
section "8. Enabling Automatic Security Updates"

safe_install unattended-upgrades

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

log "Automatic security updates enabled."

# ─────────────────────────────────────────────────────────────
# FINAL SUMMARY
# ─────────────────────────────────────────────────────────────
section "FINAL SUMMARY"

# Installation results
{
  echo ""
  echo "  ── Installation Results ────────────────"
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

# Service status
{
  echo ""
  echo "  ── Services Status ─────────────────────"
  echo "  UFW           : $(ufw status | head -1)"
  echo "  ClamAV Daemon : $(systemctl is-active clamav-daemon)"
  echo "  Freshclam     : $(systemctl is-active clamav-freshclam)"
  echo ""
  echo "  ── Scan Summary ────────────────────────"
  echo "  RKHunter Warnings : $(grep -c 'Warning' $RKHUNTER_SCAN_LOG 2>/dev/null || echo 0)"
  echo "  ClamAV Infected   : $(grep 'Infected files' $CLAMAV_SCAN_LOG 2>/dev/null || echo 'See log')"
  echo ""
  echo "  ── Log File Locations ──────────────────"
  echo "  Full Report  : $REPORT"
  echo "  RKHunter     : $RKHUNTER_SCAN_LOG"
  echo "  ClamAV       : $CLAMAV_SCAN_LOG"
  echo ""
  echo "  ── Run Scans Manually ──────────────────"
  echo "  sudo rkhunter --check --skip-keypress"
  echo "  sudo clamscan -r /home --infected"
  echo ""
  echo "  ── Run Script Again From GitHub ────────"
  echo "  sudo bash <(curl -s https://raw.githubusercontent.com/harveyokay01-rgb/harveyokay01-rgb.github.io/main/ubuntu_setup.sh)"
  echo ""
  echo "  Report completed: $(date)"
  echo "============================================================"
} | tee -a "$REPORT"

echo -e "\n${GREEN}Full report saved to: $REPORT${NC}\n"
