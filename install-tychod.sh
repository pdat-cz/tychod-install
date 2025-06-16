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

# -------------------- DOWNLOAD --------------------
BASE_URL="https://github.com/pdat-cz/tychod-install/tree/main/versions/${VERSION}"
PACKAGE="tychod-${FULL_ARCH}.tar.gz"
CHECKSUM="${PACKAGE}.sha256"

download() {
    url="$1"
    output="$2"
    if command -v curl > /dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget > /dev/null 2>&1; then
        wget -qO "$output" "$url"
    else
        exit_with_error "Neither curl nor wget is installed." >&2
    fi
}

log_message "INFO" "[install] Installing tychod version: $VERSION"
log_message "INFO" "[install] Target architecture: $FULL_ARCH"
log_message "INFO" "[install] Downloading package and checksum..."
download "${BASE_URL}/${PACKAGE}" "$PACKAGE"
download "${BASE_URL}/${CHECKSUM}" "$CHECKSUM"

# --------------------------------------------------

log_message "INFO" "[install] Verifying checksum..."
sha256sum -c "$CHECKSUM"

log_message "INFO" "[install] Extracting to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf "$PACKAGE" -C "$INSTALL_DIR"
rm "$PACKAGE" "$CHECKSUM"

log_message "INFO" "[install] Setting permissions..."
sudo chmod +x "$INSTALL_DIR/bin/"*

log_message "INFO" "[install] Linking tychod binary..."
sudo ln -sf "$INSTALL_DIR/bin/tychod" /usr/local/bin/tychod

if [ ! -f "$SERVICE_FILE" ]; then
  log_message "INFO" "[install] Installing systemd service..."
  sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Tychod Edge Orchestrator
After=network.target

[Service]
ExecStart=$INSTALL_DIR/bin/tychod
WorkingDirectory=$INSTALL_DIR
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable tychod
fi

log_message "INFO" "[install] Starting tychod..."
sudo systemctl restart tychod

log_message "INFO" "tychod ${VERSION} installed and running on ${FULL_ARCH}"