#!/usr/bin/env php
<?php
// ============================================================
//  Ubuntu Security Setup Script (PHP)
//  Run from GitHub:
//  php <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/ubuntu_setup.php)
//
//  Or locally:
//  sudo php ubuntu_setup.php
// ============================================================

// ── Colours ──────────────────────────────────────────────────
define('RED',    "\033[0;31m");
define('GREEN',  "\033[0;32m");
define('YELLOW', "\033[1;33m");
define('BLUE',   "\033[0;34m");
define('NC',     "\033[0m");

// ── Helpers ───────────────────────────────────────────────────
function log_success(string $msg): void {
    echo GREEN . "[✔] $msg" . NC . "\n";
}

function log_warn(string $msg): void {
    echo YELLOW . "[!] $msg" . NC . "\n";
}

function log_error(string $msg): void {
    echo RED . "[✘] $msg" . NC . "\n";
    exit(1);
}

function section(string $title): void {
    echo "\n" . BLUE . "══════════════════════════════════════" . NC . "\n";
    echo BLUE . "  $title" . NC . "\n";
    echo BLUE . "══════════════════════════════════════" . NC . "\n\n";
}

function run(string $cmd, bool $ignoreErrors = false): string {
    echo YELLOW . "  >> $cmd" . NC . "\n";
    exec($cmd . " 2>&1", $output, $exitCode);
    $result = implode("\n", $output);
    echo $result . "\n";
    if (!$ignoreErrors && $exitCode !== 0) {
        log_error("Command failed: $cmd");
    }
    return $result;
}

// ── Root check ────────────────────────────────────────────────
if (posix_getuid() !== 0) {
    log_error("Please run as root: sudo php ubuntu_setup.php");
}

// ── PHP version check ─────────────────────────────────────────
if (PHP_VERSION_ID < 70400) {
    log_error("PHP 7.4 or higher is required. Current: " . PHP_VERSION);
}

// ─────────────────────────────────────────────────────────────
// 1. UPDATE & UPGRADE
// ─────────────────────────────────────────────────────────────
section("1. Updating & Upgrading System");

run("apt-get update -y");
run("DEBIAN_FRONTEND=noninteractive apt-get upgrade -y");
run("DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y");
run("apt-get autoremove -y");
run("apt-get autoclean -y");
log_success("System updated and upgraded.");

// ─────────────────────────────────────────────────────────────
// 2. ENABLE HTTPS FOR APT SOURCES
// ─────────────────────────────────────────────────────────────
section("2. Switching APT Sources to HTTPS");

run("apt-get install -y apt-transport-https ca-certificates curl gnupg");

// Handle both old and new source file formats
$sourceFiles = [
    "/etc/apt/sources.list.d/ubuntu.sources",
    "/etc/apt/sources.list",
];

foreach ($sourceFiles as $file) {
    if (file_exists($file)) {
        $content = file_get_contents($file);
        $updated = str_replace("http:", "https:", $content);
        file_put_contents($file, $updated);
        log_success("Updated $file to HTTPS.");
    }
}

// Handle .list files in sources.list.d
$listFiles = glob("/etc/apt/sources.list.d/*.list");
foreach ($listFiles as $file) {
    $content = file_get_contents($file);
    $updated = str_replace("http:", "https:", $content);
    file_put_contents($file, $updated);
    log_success("Updated $file to HTTPS.");
}

run("apt-get update -y");
log_success("APT sources now using HTTPS.");

// ─────────────────────────────────────────────────────────────
// 3. ENABLE UNIVERSE REPOSITORY
// ─────────────────────────────────────────────────────────────
section("3. Enabling Universe Repository");

run("add-apt-repository universe -y");
run("apt-get update -y");
log_success("Universe repository enabled.");

// ─────────────────────────────────────────────────────────────
// 4. INSTALL & CONFIGURE UFW FIREWALL
// ─────────────────────────────────────────────────────────────
section("4. Installing & Configuring UFW Firewall");

run("apt-get install -y ufw");
run("ufw --force reset");
run("ufw default deny incoming");
run("ufw default allow outgoing");
run("ufw allow ssh");
run("ufw allow http");
run("ufw allow https");
run("ufw --force enable");

log_success("UFW firewall configured and enabled.");
log_warn("Current UFW rules:");
run("ufw status verbose", true);

// ─────────────────────────────────────────────────────────────
// 5. INSTALL RKHUNTER
// ─────────────────────────────────────────────────────────────
section("5. Installing & Configuring RKHunter");

run("apt-get install -y rkhunter");
run("rkhunter --update", true);
run("rkhunter --propupd", true);
log_success("RKHunter installed and database updated.");

// Configure rkhunter
$rkhunterConf = "/etc/rkhunter.conf";
if (file_exists($rkhunterConf)) {
    $conf = file_get_contents($rkhunterConf);
    $conf = preg_replace('/^#?UPDATE_MIRRORS=.*/m',  'UPDATE_MIRRORS=1',  $conf);
    $conf = preg_replace('/^#?MIRRORS_MODE=.*/m',    'MIRRORS_MODE=0',    $conf);
    $conf = preg_replace('/^#?WEB_CMD=.*/m',         'WEB_CMD=curl',      $conf);
    file_put_contents($rkhunterConf, $conf);
    log_success("RKHunter config updated.");
}

// Enable daily cron
$rkhunterDefault = "/etc/default/rkhunter";
if (file_exists($rkhunterDefault)) {
    $conf = file_get_contents($rkhunterDefault);
    $conf = preg_replace('/^CRON_DAILY_RUN=.*/m', 'CRON_DAILY_RUN="true"', $conf);
    $conf = preg_replace('/^APT_AUTOGEN=.*/m',    'APT_AUTOGEN="true"',    $conf);
    file_put_contents($rkhunterDefault, $conf);
    log_success("RKHunter daily cron enabled.");
}

// ─────────────────────────────────────────────────────────────
// 6. INSTALL CLAMAV
// ─────────────────────────────────────────────────────────────
section("6. Installing & Configuring ClamAV");

run("apt-get install -y clamav clamav-daemon clamav-freshclam");
run("systemctl stop clamav-freshclam", true);
run("freshclam", true);
run("systemctl enable clamav-freshclam");
run("systemctl start clamav-freshclam");
run("systemctl enable clamav-daemon");
run("systemctl start clamav-daemon");

log_success("ClamAV installed and virus definitions updated.");

// ─────────────────────────────────────────────────────────────
// 7. RUN SECURITY SCANS
// ─────────────────────────────────────────────────────────────
section("7. Running Security Scans");

log_warn("Running RKHunter scan (this may take a minute)...");
run("rkhunter --check --skip-keypress --report-warnings-only 2>&1 | tee /var/log/rkhunter_setup_scan.log", true);
log_success("RKHunter scan complete. Log: /var/log/rkhunter_setup_scan.log");

log_warn("Running ClamAV scan on /home (this may take a few minutes)...");
run("clamscan -r /home --log=/var/log/clamav_setup_scan.log --infected", true);
log_success("ClamAV scan complete. Log: /var/log/clamav_setup_scan.log");

// ─────────────────────────────────────────────────────────────
// 8. AUTOMATIC UPDATES
// ─────────────────────────────────────────────────────────────
section("8. Enabling Automatic Security Updates");

run("apt-get install -y unattended-upgrades");

$autoUpgradesConf = <<<EOL
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOL;

file_put_contents("/etc/apt/apt.conf.d/20auto-upgrades", $autoUpgradesConf);
log_success("Automatic security updates enabled.");

// ─────────────────────────────────────────────────────────────
// DONE
// ─────────────────────────────────────────────────────────────
section("✔ Setup Complete!");

echo GREEN . "Summary of what was done:" . NC . "\n";
$steps = [
    "System updated and upgraded",
    "APT sources switched to HTTPS",
    "UFW firewall configured (SSH, HTTP, HTTPS allowed)",
    "RKHunter installed and scanned",
    "ClamAV installed and scanned",
    "Automatic security updates enabled",
];
foreach ($steps as $step) {
    echo "  ✔ $step\n";
}

echo "\n" . YELLOW . "Scan logs:" . NC . "\n";
echo "  RKHunter : /var/log/rkhunter_setup_scan.log\n";
echo "  ClamAV   : /var/log/clamav_setup_scan.log\n";

echo "\n" . YELLOW . "To run scans manually:" . NC . "\n";
echo "  sudo rkhunter --check --skip-keypress\n";
echo "  sudo clamscan -r /home --infected\n";

echo "\n" . YELLOW . "To run this script again from GitHub:" . NC . "\n";
echo "  sudo php <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/ubuntu_setup.php)\n\n";
