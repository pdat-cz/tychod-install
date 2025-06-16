#!/bin/bash
set -e

# Log a message with timestamp
log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  case "$level" in
    "INFO")
      echo -e "\033[0;32m[INFO]\033[0m $timestamp - $message"
      ;;
    "WARN")
      echo -e "\033[0;33m[WARN]\033[0m $timestamp - $message"
      ;;
    "ERROR")
      echo -e "\033[0;31m[ERROR]\033[0m $timestamp - $message"
      ;;
    *)
      echo "$timestamp - $message"
      ;;
  esac
}

# Exit with error message
exit_with_error() {
  log_message "ERROR" "$1"
  echo
  echo "For help, run: $0 --help"
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  exit_with_error "This script must be run as root (sudo). Please run: sudo $0"
fi


# -------------------- DEFAULTS --------------------
VERSION="v1.0.0"
INSTALL_DIR="/opt/tychod"
SERVICE_FILE="/etc/systemd/system/tychod.service"
# --------------------------------------------------

# -------------------- DETECT ARCH -----------------
uname_os=$(uname -s)
uname_arch=$(uname -m)

# Normalize to GOARCH-like format
case "$uname_os" in
  Linux*)   OS="linux" ;;
  Darwin*)  OS="darwin" ;;
  *)        log_message "ERROR" "Unsupported OS: $uname_os"; exit 1 ;;
esac

case "$uname_arch" in
  x86_64)   ARCH="amd64" ;;
  aarch64)  ARCH="arm64" ;;
  armv7l)   ARCH="arm" ;;
  *)        log_message "ERROR" "Unsupported arch: $uname_arch"; exit 1 ;;
esac

FULL_ARCH="${OS}-${ARCH}"
# --------------------------------------------------

# -------------------- PARSE ARGS ------------------
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift
            ;;
        -a|--arch)
            FULL_ARCH="$2"
            shift
            ;;
        *)
            log_message "INFO" "Unknown parameter: $1"
            log_message "WARN" "Usage: install-tychod.sh [--version vX.Y.Z] [--arch linux-arm64]"
            exit 1
            ;;
    esac
    shift
done
# --------------------------------------------------
# -------------------- CLEANUP FUNCTION & TRAP --------------------
cleanup_downloads() {
  if [ -f "$PACKAGE" ]; then
    rm -f "$PACKAGE"
  fi
  if [ -f "$CHECKSUM" ]; then
    rm -f "$CHECKSUM"
  fi
}
trap cleanup_downloads EXIT
# -----------------------------------------------------------------

# -------------------- DOWNLOAD --------------------
BASE_URL="https://github.com/pdat-cz/tychod-install/raw/main/versions/${VERSION}"
PACKAGE="tychod-${FULL_ARCH}-${VERSION}.tar.gz"
CHECKSUM="${PACKAGE}.sha256"

download() {
    url="$1"
    output="$2"
    if command -v curl > /dev/null 2>&1; then
      log_message "INFO" "curl $url"
        curl -fsSL "$url" -o "$output"
    elif command -v wget > /dev/null 2>&1; then
      log_message "INFO" "wget $url"
        if ! wget -qO "$output" "$url"; then
          log_message "ERROR" "$output not downloaded"
          exit 1
        fi
    else
        exit_with_error "Neither curl nor wget is installed." >&2
    fi
}

log_message "INFO" "Installing tychod version: $VERSION"
log_message "INFO" "Target architecture: $FULL_ARCH"
log_message "INFO" "Downloading package and checksum  ..."
download "${BASE_URL}/${PACKAGE}" "$PACKAGE"
download "${BASE_URL}/${CHECKSUM}" "$CHECKSUM"
log_message "INFO" "Downloading ${BASE_URL}/${PACKAGE}"
# Removed incorrect conditional that attempted to execute the package file
# --------------------------------------------------

log_message "INFO" "Verifying checksum..."
sha256sum -c "$CHECKSUM"

log_message "INFO" "Stopping service tychod"
systemctl stop tychod

log_message "INFO" "Extracting to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
log_message "INFO" "Creating NATS server directory..."
mkdir -p "$INSTALL_DIR/nats"
log_message "INFO" "Creating config directory..."
mkdir -p "/etc/tychod/config"
if ! tar -xzf "$PACKAGE" -C "$INSTALL_DIR"; then
  exit_with_error "Failed to extract $PACKAGE to $INSTALL_DIR"
fi
rm "$PACKAGE" "$CHECKSUM"


log_message "INFO" "Setting permissions..."
chmod +x "$INSTALL_DIR/bin/"*

# Verify tychod binary exists and is executable
if [ ! -f "$INSTALL_DIR/bin/tychod" ]; then
  exit_with_error "tychod binary not found at $INSTALL_DIR/bin/tychod"
fi

if [ ! -x "$INSTALL_DIR/bin/tychod" ]; then
  log_message "WARN" "tychod binary is not executable, fixing permissions..."
  chmod +x "$INSTALL_DIR/bin/tychod"
fi

log_message "INFO" "Linking tychod binary..."
ln -sf "$INSTALL_DIR/bin/tychod" /usr/local/bin/tychod

  log_message "INFO" "Installing systemd service..."
  tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Tychod Service
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/pdat-cz/tychod-install

[Service]
Type=simple
User=tychod
Group=tychod
WorkingDirectory=/opt/tychod
ExecStart=/opt/tychod/bin/tychod --config /etc/tychod/config
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable tychod

# Create tychod user and group if not exists
if ! id "tychod" &>/dev/null; then
  log_message "INFO" "Creating user and group: tychod"
  useradd --system --create-home --shell /usr/sbin/nologin tychod
  echo "tychod:tychod" | chpasswd
else
  log_message "INFO" "User 'tychod' already exists"
fi

# Ensure config directory has correct permissions
log_message "INFO" "Setting config directory permissions..."
chown -R tychod:tychod "/etc/tychod"
chmod -R 755 "/etc/tychod"

# Ensure /opt/tychod is owned by tychod
chown -R tychod:tychod "$INSTALL_DIR"

# Ensure permissions (directories: 755, files: 755 or 644 as appropriate)
find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
find "$INSTALL_DIR" -type f -exec chmod 755 {} \;

# Ensure NATS directory has proper permissions
log_message "INFO" "Setting NATS directory permissions to 777 for download access..."
chmod 777 "$INSTALL_DIR/nats"

log_message "INFO" "Starting tychod..."
systemctl start tychod

# Wait a moment for the service to start
sleep 2

# Check if the service is running
if systemctl is-active --quiet tychod; then
  log_message "INFO" "tychod ${VERSION} installed and running on ${FULL_ARCH}"
else
  log_message "WARN" "tychod service failed to start. Checking status..."
  systemctl status tychod
  log_message "WARN" "Attempting to restart tychod..."
  systemctl restart tychod
  sleep 3

  if systemctl is-active --quiet tychod; then
    log_message "INFO" "tychod ${VERSION} installed and running on ${FULL_ARCH} after restart"
  else
    log_message "ERROR" "tychod service failed to start after restart. Please check logs with 'journalctl -u tychod'"
    log_message "INFO" "Installation completed, but service is not running"
  fi
fi
