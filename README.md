# v2server

A lightweight installer for Xray-core using VLESS + REALITY protocol.

This script automates the installation and configuration of Xray-core on a server, setting up three VLESS inbounds with REALITY on different ports.

## Features

- Installs the latest version of Xray-core.
- Generates X25519 keys for REALITY.
- Configures three inbounds on ports 443, 2020, and 8181 with different SNIs.
- Uses `xtls-rprx-vision` flow.
- Automatically detects the server's public IP for generating VLESS links.

## One-line Installation

```bash
bash <(curl -Ls https://raw.githubusercontent.com/akraad/v2server/main/install.sh)
```

## Post-installation

After running the script, three VLESS links will be displayed. You can use these links in your V2Ray/Xray client to connect.
