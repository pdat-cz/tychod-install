

# Tychod Install

Public OTA repository for distributing `tychod` edge orchestrator binaries.

This repository contains:
- `install-tychod.sh`: self-installing script for deploying `tychod` on edge devices
- `versions/`: OTA binary packages, organized by version and architecture
- `README.md`: this file

## 🚀 Install

To install the latest version of Tychod on a supported system:

```bash
curl -sL https://pdat-cz.github.io/tychod-install/install-tychod.sh | bash
```

The script will:
- auto-detect your architecture (e.g. `linux-arm64`, `linux-amd64`)
- download the appropriate `.tar.gz` package and `.sha256`
- verify the SHA256 checksum
- extract and install Tychod to `/opt/tychod`
- register and start a systemd service

## 📦 OTA Packages

Packages are stored in the `versions/` folder:

```
versions/
└── v1.0.0/
    ├── tychod-linux-arm64-v1.0.0.tar.gz
    ├── tychod-linux-arm64-v1.0.0.sha256
    ├── tychod-linux-amd64-v1.0.0.tar.gz
    └── tychod-linux-amd64-v1.0.0.sha256
```

Each version contains platform-specific builds and their corresponding SHA256 hashes.

## 🛡️ Security

The installer script always verifies the SHA256 checksum before installation. No code is executed until integrity is confirmed.

## 🌐 Hosting

This repository is designed to be published via GitHub Pages at:

```
https://pdat-cz.github.io/tychod-install/
```

The install script fetches from this location automatically.