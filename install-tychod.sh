#!/bin/bash
set -e

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
  *)        echo "Unsupported OS: $uname_os"; exit 1 ;;
esac

case "$uname_arch" in
  x86_64)   ARCH="amd64" ;;
  aarch64)  ARCH="arm64" ;;
  armv7l)   ARCH="arm" ;;
  *)        echo "Unsupported arch: $uname_arch"; exit 1 ;;
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
            echo "Unknown parameter: $1"
            echo "Usage: install-tychod.sh [--version vX.Y.Z] [--arch linux-arm64]"
            exit 1
            ;;
    esac
    shift
done
# --------------------------------------------------

# -------------------- DOWNLOAD --------------------
BASE_URL="https://pdat-cz.github.io/tychod-install/versions/${VERSION}"
PACKAGE="tychod-${FULL_ARCH}.tar.gz"
CHECKSUM="${PACKAGE}.sha256"

echo "[install] Installing tychod version: $VERSION"
echo "[install] Target architecture: $FULL_ARCH"
echo "[install] Downloading package and checksum..."
curl -fsSL "${BASE_URL}/${PACKAGE}" -o "$PACKAGE"
curl -fsSL "${BASE_URL}/${CHECKSUM}" -o "$CHECKSUM"
# --------------------------------------------------

echo "[install] Verifying checksum..."
sha256sum -c "$CHECKSUM"

echo "[install] Extracting to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf "$PACKAGE" -C "$INSTALL_DIR"
rm "$PACKAGE" "$CHECKSUM"

echo "[install] Setting permissions..."
sudo chmod +x "$INSTALL_DIR/bin/"*

echo "[install] Linking tychod binary..."
sudo ln -sf "$INSTALL_DIR/bin/tychod" /usr/local/bin/tychod

if [ ! -f "$SERVICE_FILE" ]; then
  echo "[install] Installing systemd service..."
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

echo "[install] Starting tychod..."
sudo systemctl restart tychod

echo "✅ tychod ${VERSION} installed and running on ${FULL_ARCH}"