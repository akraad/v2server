#!/bin/bash
#
# Main installer for v2server
# This script orchestrates the installation, configuration, and service setup.

set -e

# --- PRE-FLIGHT CHECKS ---
# Pre-flight check: Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi



# --- EXECUTE PACKAGES ---
# Create a temporary file to store variables between scripts
VAR_FILE=$(mktemp)

# Get the directory of the main script
SCRIPT_DIR=$(dirname "$0")

# Run Package A: Installer
bash "${SCRIPT_DIR}/installer/install_xray.sh"

# Run Package B: Configurator
bash "${SCRIPT_DIR}/configurator/create_config.sh" "$VAR_FILE"

# Run Package C: Servicer
bash "${SCRIPT_DIR}/servicer/setup_service.sh"


# --- FINAL OUTPUT ---
# Source the variables from the temp file
source "$VAR_FILE"
rm -f "$VAR_FILE"

# Get server IP
SERVER_IP=$(curl -s ipinfo.io/ip)
if [ -z "$SERVER_IP" ]; then
    echo "Warning: Could not automatically detect server IP."
    SERVER_IP="YOUR_SERVER_IP"
fi

echo "=================================================="
echo "Xray installation and configuration complete."
echo "Here are your VLESS links:"
echo ""
echo "1. Port 443 (SNI: www.cloudflare.com):"
echo "vless://$UUID@$SERVER_IP:443?security=reality&sni=www.cloudflare.com&flow=xtls-rprx-vision&publicKey=$PUBLIC_KEY&type=tcp#XRAY-443"
echo ""
echo "2. Port 2020 (SNI: www.microsoft.com):"
echo "vless://$UUID@$SERVER_IP:2020?security=reality&sni=www.microsoft.com&flow=xtls-rprx-vision&publicKey=$PUBLIC_KEY&type=tcp#XRAY-2020"
echo ""
echo "3. Port 8181 (SNI: www.bing.com):"
echo "vless://$UUID@$SERVER_IP:8181?security=reality&sni=www.bing.com&flow=xtls-rprx-vision&publicKey=$PUBLIC_KEY&type=tcp#XRAY-8181"
echo "=================================================="
