#!/bin/bash
# ============================================================
#  Apache Web Server Setup Script
#  Run from GitHub:
#  sudo bash <(curl -s https://raw.githubusercontent.com/harveyokay01-rgb/harveyokay01-rgb.github.io/main/apache_setup.sh)
# ============================================================

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Config ────────────────────────────────────────────────────
GITHUB_USER="harveyokay01-rgb"
GITHUB_REPO="harveyokay01-rgb.github.io"
HTML_FILE="test.html"
WEB_ROOT="/var/www/html"

# ── Helpers ───────────────────────────────────────────────────
log()     { echo -e "${GREEN}[✔] $1${NC}"; }
warn()    { echo -e "${YELLOW}[!] $1${NC}"; }
error()   { echo -e "${RED}[✘] $1${NC}"; exit 1; }
section() {
  echo -e "\n${BLUE}══════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}══════════════════════════════════════${NC}\n"
}

# ── Root check ────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  error "Please run as root: sudo bash apache_setup.sh"
fi

# ─────────────────────────────────────────────────────────────
# 1. UPDATE
# ─────────────────────────────────────────────────────────────
section "1. Updating Package List"
apt-get update -y && log "Package list updated." || error "Failed to update packages."

# ─────────────────────────────────────────────────────────────
# 2. INSTALL APACHE
# ─────────────────────────────────────────────────────────────
section "2. Installing Apache"
if DEBIAN_FRONTEND=noninteractive apt-get install -y apache2; then
  log "Apache installed successfully."
else
  error "Apache installation failed."
fi

# ─────────────────────────────────────────────────────────────
# 3. START & ENABLE APACHE
# ─────────────────────────────────────────────────────────────
section "3. Starting Apache"
systemctl start apache2 && log "Apache started." || error "Failed to start Apache."
systemctl enable apache2 && log "Apache enabled on boot." || warn "Failed to enable Apache on boot."

# ─────────────────────────────────────────────────────────────
# 4. OPEN FIREWALL
# ─────────────────────────────────────────────────────────────
section "4. Configuring Firewall"
if command -v ufw &>/dev/null; then
  ufw allow 80 && log "Port 80 (HTTP) opened."
  ufw allow 443 && log "Port 443 (HTTPS) opened."
else
  warn "UFW not found - skipping firewall config."
fi

# ─────────────────────────────────────────────────────────────
# 5. DOWNLOAD HTML FILE FROM GITHUB
# ─────────────────────────────────────────────────────────────
section "5. Downloading Website from GitHub"

# Remove default Apache page
rm -f "$WEB_ROOT/index.html"
log "Removed default Apache page."

# Download the HTML file
FILE_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/$HTML_FILE"
echo -e "${YELLOW}  >> Downloading $FILE_URL...${NC}"

if curl -s -o "$WEB_ROOT/index.html" "$FILE_URL"; then
  # Check it actually downloaded something and isn't a 404 page
  if grep -q "404" "$WEB_ROOT/index.html" && ! grep -q "<html" "$WEB_ROOT/index.html"; then
    error "File not found on GitHub - check the filename is correct."
  fi
  log "Downloaded $HTML_FILE and saved as index.html"
else
  error "Failed to download file from GitHub."
fi

# ─────────────────────────────────────────────────────────────
# 6. RESTART APACHE
# ─────────────────────────────────────────────────────────────
section "6. Restarting Apache"
systemctl restart apache2 && log "Apache restarted." || error "Failed to restart Apache."

# ─────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────
section "✔ Setup Complete!"

IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}  Your website is now live at:${NC}"
echo -e "${BLUE}  http://$IP${NC}"
echo ""
echo -e "${YELLOW}  Useful commands:${NC}"
echo "  Check Apache status : sudo systemctl status apache2"
echo "  Restart Apache      : sudo systemctl restart apache2"
echo "  Website files       : $WEB_ROOT"
echo ""
