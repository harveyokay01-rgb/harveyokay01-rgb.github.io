#!/bin/bash
# ============================================================
#  Ubuntu Security Setup Script
#  Run from GitHub:
#  bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/ubuntu_setup.sh)
# ============================================================

set -e  # Exit on any error

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

# ── Helpers ───────────────────────────────────────────────────
log()     { echo -e "${GREEN}[✔] $1${NC}"; }
warn()    { echo -e "${YELLOW}[!] $1${NC}"; }
error()   { echo -e "${RED}[✘] $1${NC}"; exit 1; }
section() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; \
            echo -e "${BLUE}  $1${NC}"; \
            echo -e "${BLUE}══════════════════════════════════════${NC}\n"; }

# ── Root check ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "Please run as root: sudo bash ubuntu_setup.sh"
fi

# ─────────────────────────────────────────────────────────────
# 1. UPDATE & UPGRADE
# ─────────────────────────────────────────────────────────────
section "1. Updating & Upgrading System"

apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get autoremove -y
apt-get autoclean -y
log "System updated and upgraded."

# ─────────────────────────────────────────────────────────────
# 2. ENABLE HTTPS FOR APT SOURCES
# ─────────────────────────────────────────────────────────────
section "2. Switching APT Sources to HTTPS"

apt-get install -y apt-transport-https ca-certificates curl gnupg

# Handle both old and new source file formats
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  sed -i "s/http:/https:/g" /etc/apt/sources.list.d/ubuntu.sources
  log "Updated ubuntu.sources to HTTPS."
fi

if [ -f /etc/apt/sources.list ]; then
  sed -i "s/http:/https:/g" /etc/apt/sources.list
  log "Updated sources.list to HTTPS."
fi

# Update any .list files in sources.list.d
for f in /etc/apt/sources.list.d/*.list; do
  [ -f "$f" ] && sed -i "s/http:/https:/g" "$f"
done

apt-get update -y
log "APT sources now using HTTPS."

# ─────────────────────────────────────────────────────────────
# 3. ENABLE UNIVERSE REPOSITORY
# ─────────────────────────────────────────────────────────────
section "3. Enabling Universe Repository"

add-apt-repository universe -y
apt-get update -y
log "Universe repository enabled."

# ─────────────────────────────────────────────────────────────
# 4. INSTALL & CONFIGURE UFW FIREWALL
# ─────────────────────────────────────────────────────────────
section "4. Installing & Configuring UFW Firewall"

apt-get install -y ufw

# Reset to defaults first
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow essential services
ufw allow ssh        # Port 22
ufw allow http       # Port 80
ufw allow https      # Port 443

# Enable UFW
ufw --force enable

log "UFW firewall configured and enabled."
echo ""
warn "Current UFW rules:"
ufw status verbose

# ─────────────────────────────────────────────────────────────
# 5. INSTALL RKHUNTER
# ─────────────────────────────────────────────────────────────
section "5. Installing & Configuring RKHunter"

apt-get install -y rkhunter

# Update rkhunter database
rkhunter --update || warn "rkhunter database update had warnings (this can be normal)."

# Set baseline properties
rkhunter --propupd
log "RKHunter installed and database updated."

# Configure rkhunter
RKHUNTER_CONF="/etc/rkhunter.conf"
if [ -f "$RKHUNTER_CONF" ]; then
  # Enable daily cron updates
  sed -i 's/^#UPDATE_MIRRORS=.*/UPDATE_MIRRORS=1/' "$RKHUNTER_CONF"
  sed -i 's/^#MIRRORS_MODE=.*/MIRRORS_MODE=0/' "$RKHUNTER_CONF"
  sed -i 's/^#WEB_CMD=.*/WEB_CMD=curl/' "$RKHUNTER_CONF"
  log "RKHunter config updated."
fi

# Enable daily cron job
if [ -f /etc/default/rkhunter ]; then
  sed -i 's/^CRON_DAILY_RUN=.*/CRON_DAILY_RUN="true"/' /etc/default/rkhunter
  sed -i 's/^APT_AUTOGEN=.*/APT_AUTOGEN="true"/' /etc/default/rkhunter
  log "RKHunter daily cron enabled."
fi

# ─────────────────────────────────────────────────────────────
# 6. INSTALL CLAMAV
# ─────────────────────────────────────────────────────────────
section "6. Installing & Configuring ClamAV"

apt-get install -y clamav clamav-daemon clamav-freshclam

# Stop freshclam to allow manual update
systemctl stop clamav-freshclam || true

# Update virus definitions
freshclam || warn "freshclam had warnings, continuing..."

# Start and enable services
systemctl enable clamav-freshclam
systemctl start clamav-freshclam
systemctl enable clamav-daemon
systemctl start clamav-daemon

log "ClamAV installed and virus definitions updated."

# ─────────────────────────────────────────────────────────────
# 7. RUN SECURITY SCANS
# ─────────────────────────────────────────────────────────────
section "7. Running Security Scans"

# --- RKHunter scan ---
warn "Running RKHunter scan (this may take a minute)..."
rkhunter --check --skip-keypress --report-warnings-only 2>&1 | tee /var/log/rkhunter_setup_scan.log || true
log "RKHunter scan complete. Log saved to /var/log/rkhunter_setup_scan.log"

# --- ClamAV scan of /home ---
warn "Running ClamAV scan on /home (this may take a few minutes)..."
clamscan -r /home --log=/var/log/clamav_setup_scan.log --infected || true
log "ClamAV scan complete. Log saved to /var/log/clamav_setup_scan.log"

# ─────────────────────────────────────────────────────────────
# 8. SETUP AUTOMATIC UPDATES
# ─────────────────────────────────────────────────────────────
section "8. Enabling Automatic Security Updates"

apt-get install -y unattended-upgrades

cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

log "Automatic security updates enabled."

# ─────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────
section "✔ Setup Complete!"

echo -e "${GREEN}Summary of what was done:${NC}"
echo "  ✔ System updated and upgraded"
echo "  ✔ APT sources switched to HTTPS"
echo "  ✔ UFW firewall configured (SSH, HTTP, HTTPS allowed)"
echo "  ✔ RKHunter installed and scanned"
echo "  ✔ ClamAV installed and scanned"
echo "  ✔ Automatic security updates enabled"
echo ""
echo -e "${YELLOW}Scan logs:${NC}"
echo "  RKHunter: /var/log/rkhunter_setup_scan.log"
echo "  ClamAV:   /var/log/clamav_setup_scan.log"
echo ""
echo -e "${YELLOW}To run scans manually:${NC}"
echo "  sudo rkhunter --check --skip-keypress"
echo "  sudo clamscan -r /home --infected"
echo ""
echo -e "${YELLOW}To run this script again from GitHub:${NC}"
echo "  bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/ubuntu_setup.sh)"
