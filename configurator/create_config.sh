#!/bin/bash
#
# PACKAGE B: Xray-core Configurator
# This script generates the X25519 keys and creates the config.json.

set -e

echo "--- PACKAGE B: Configuring Xray-core ---"

# 1. Check if Xray is installed
if ! command -v "xray" &> /dev/null; then
    echo "Error: 'xray' command not found. Please run the installer package first."
    exit 1
fi

# 2. Create config directory
install -d /usr/local/etc/xray

# 3. Generate Keys and UUID
echo "Generating keys and UUID..."
XRAY_KEYS=$(/usr/local/bin/xray x25519)
PRIVATE_KEY=$(echo "$XRAY_KEYS" | awk '/Private key:/ {print $3}')
PUBLIC_KEY=$(echo "$XRAY_KEYS" | awk '/Public key:/ {print $3}')
UUID=$(uuidgen)

if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
    echo "Error: Failed to generate X25519 keys. The installed xray version may be incorrect."
    /usr/local/bin/xray version
    exit 1
fi

# 4. Create config.json
echo "Creating config.json..."
cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.cloudflare.com:443",
          "xver": 0,
          "serverNames": [
            "www.cloudflare.com"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortId": ""
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls" ]
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 2020,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": [
            "www.microsoft.com"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortId": ""
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls" ]
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 8181,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.bing.com:443",
          "xver": 0,
          "serverNames": [
            "www.bing.com"
          ],
          "privateKey": "$PRIVATE_KEY",
          "shortId": ""
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [ "http", "tls" ]
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

# 5. Export variables for the main script
# We'll write them to a temp file that the main script can source.
# The path to this file will be passed as an argument.
if [ -n "$1" ]; then
    echo "Exporting variables to $1"
    echo "UUID=$UUID" > "$1"
    echo "PUBLIC_KEY=$PUBLIC_KEY" >> "$1"
fi


echo "--- PACKAGE B: Xray-core configured successfully. ---"
echo "Generated UUID: $UUID"
echo "Public Key: $PUBLIC_KEY"
echo "---"

