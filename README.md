# v2server

A modular installer for Xray-core using the VLESS + REALITY protocol.

This repository is structured into multiple "packages" to provide a more robust and transparent installation process.

## Installation

Run the main installer which executes all the packages in order.

**Recommended Method (via curl):**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/akraad/v2server/main/install.sh)
```

**Alternative Method (Manual):**
If the above method fails due to network issues, you can download and run the script manually.
```bash
# 1. Download the repository zip and unzip it
curl -L -o v2server.zip https://github.com/akraad/v2server/archive/refs/heads/main.zip
unzip v2server.zip

# 2. Navigate into the directory and run the installer
cd v2server-main/
chmod +x install.sh
./install.sh
```

## Modular Structure

The installation is broken down into three main packages located in their respective directories:

- **`/installer`**: Contains `install_xray.sh`, which downloads, verifies, and installs the latest official Xray-core binary and its data files (`geoip.dat`, `geosite.dat`).
- **`/configurator`**: Contains `create_config.sh`, which generates the necessary X25519 keys for REALITY, creates a `config.json` file with three pre-configured inbounds, and generates a unique UUID.
- **`/servicer`**: Contains `setup_service.sh`, which creates a `systemd` service file for Xray, and enables and starts the service.

### Troubleshooting

This modular structure allows you to run each step individually for troubleshooting. For example, if you suspect an issue with the configuration, you can navigate to the repository directory and run only the configurator:

```bash
# Make sure all scripts are executable first
chmod +x installer/*.sh configurator/*.sh servicer/*.sh

# Example: Re-run only the configurator
./configurator/create_config.sh
```
This gives you fine-grained control over the installation process.