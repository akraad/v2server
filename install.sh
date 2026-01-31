#!/bin/bash
set -x # Enable shell debugging
#
# A lightweight installer for Xray-core with VLESS+REALITY.
# Final diagnostic version to verify file integrity after installation.

# Function to check for required commands
check_dependencies() {
    # Add sha256sum to dependencies
    for cmd in curl socat uuidgen sha256sum; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is not installed. Please install it first."
            exit 1
        fi
    done
}

# Function to kill processes on specified ports
kill_processes_on_ports() {
    echo "--- DEBUG: Entering kill_processes_on_ports function ---"
    for port in 443 2020 8181; do
        echo "Checking for processes on port $port..."
        # Use fuser, it's more common than lsof
        if command -v "fuser" &> /dev/null; then
            echo "Using fuser to check port $port."
            fuser -k -s -n tcp "$port"
            if [ $? -eq 0 ]; then
                echo "Process(es) killed on port $port using fuser."
            else
                echo "No process found on port $port using fuser."
            fi
        else # Fallback to lsof if fuser is not available
            echo "fuser not found. Using lsof to check port $port."
            pid=$(lsof -t -i:"$port")
            if [ -n "$pid" ]; then
                echo "Killing process with PID $pid on port $port using kill -9."
                kill -9 "$pid"
            else
                echo "No process found on port $port using lsof."
            fi
        fi
    done
    echo "--- DEBUG: Exiting kill_processes_on_ports function ---"
}


# --- Main script execution ---
echo "Starting Xray-core installation with VLESS+REALITY (Final Diagnostic Attempt)..."
set -e # Exit immediately if a command exits with a non-zero status.

# 1. Check for dependencies
check_dependencies

# 2. Kill existing processes on target ports
kill_processes_on_ports

# 3. Remove any old versions of Xray
echo "Removing any old versions of Xray to ensure a clean install..."
systemctl stop xray >/dev/null 2>&1 || echo "Xray service not found, skipping stop."
systemctl disable xray >/dev/null 2>&1 || echo "Xray service not found, skipping disable."
rm -f /usr/local/bin/xray
rm -rf /usr/local/etc/xray
rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/xray@.service
systemctl daemon-reload

# 4. Install Xray-core manually and verify integrity
echo "Installing latest Xray-core manually and verifying integrity..."
LATEST_TAG=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_TAG" ]; then
    echo "Error: Failed to fetch the latest Xray version tag."
    exit 1
fi
echo "Latest version found: $LATEST_TAG"
ZIP_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_TAG}/Xray-linux-64.zip"

# Check for unzip and install if not present
if ! command -v "unzip" &> /dev/null; then
    echo "'unzip' is not installed. Attempting to install..."
    if command -v "apt-get" &> /dev/null; then
        apt-get update && apt-get install -y unzip
    elif command -v "yum" &> /dev/null; then
        yum install -y unzip
    elif command -v "dnf" &> /dev/null; then
        dnf install -y unzip
    else
        echo "Error: Could not install 'unzip'. Please install it manually and re-run the script."
        exit 1
    fi
fi

# Download and install
TMP_DIR=$(mktemp -d)
echo "Downloading Xray-core from $ZIP_URL"
curl -L -o "${TMP_DIR}/xray.zip" "$ZIP_URL"
unzip -o "${TMP_DIR}/xray.zip" -d "${TMP_DIR}"

# --- Checksum Verification Step ---
DOWNLOADED_CHECKSUM=$(sha256sum "${TMP_DIR}/xray" | awk '{print $1}')
echo "---"
echo "--- INTEGRITY CHECK ---"
echo "Checksum of downloaded (correct) xray binary: $DOWNLOADED_CHECKSUM"

# Force move the binary
mv -f "${TMP_DIR}/xray" /usr/local/bin/xray
chmod 755 /usr/local/bin/xray

INSTALLED_CHECKSUM=$(sha256sum /usr/local/bin/xray | awk '{print $1}')
echo "Checksum of installed xray binary at /usr/local/bin/xray: $INSTALLED_CHECKSUM"

if [ "$DOWNLOADED_CHECKSUM" != "$INSTALLED_CHECKSUM" ]; then
    echo "---"
    echo "FATAL ERROR: CHECKSUM MISMATCH!"
    echo "The xray file was altered after being moved to /usr/local/bin/xray."
    echo "This proves that an external process on your server is interfering with the installation."
    echo "Please contact your server administrator and show them this log."
    echo "The issue is outside the control of this script."
    echo "---"
    exit 1
fi
echo "Checksums match. The correct binary is now installed."
echo "--- END INTEGRITY CHECK ---"
echo "---"
# --- End Verification Step ---

install -d /usr/local/share/xray/
install -m 644 "${TMP_DIR}/geosite.dat" /usr/local/share/xray/
install -m 644 "${TMP_DIR}/geoip.dat" /usr/local/share/xray/
rm -rf "${TMP_DIR}"

# Create config directory
install -d /usr/local/etc/xray

# Create systemd service file
echo "Creating systemd service file..."
cat > /etc/systemd/system/xray.service << EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "Latest Xray-core installed successfully."
echo -n "Installed version: "
/usr/local/bin/xray version

# 5. Generate X25519 keys
echo "Generating X25519 keys..."
keys=$(/usr/local/bin/xray x25519)
private_key=$(echo "$keys" | awk '/Private key:/ {print $3}')
public_key=$(echo "$keys" | awk '/Public key:/ {print $3}')

if [ -z "$private_key" ] || [ -z "$public_key" ]; then
    echo "Error: Failed to generate X25519 keys."
    exit 1
fi

echo "Keys generated successfully."

# 6. Generate UUID
uuid=$(uuidgen)

# 7. Get server public IP
server_ip=$(curl -s ipinfo.io/ip)
if [ -z "$server_ip" ]; then
    echo "Error: Could not automatically detect server IP. Please edit the config manually."
    exit 1
fi

# 8. Create config.json
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
            "id": "$uuid",
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
          "privateKey": "$private_key",
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
            "id": "$uuid",
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
          "privateKey": "$private_key",
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
            "id": "$uuid",
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
          "privateKey": "$private_key",
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

# 9. Enable and restart Xray service
echo "Enabling and restarting Xray service..."
systemctl enable xray
systemctl restart xray

# 10. Display VLESS links
echo "=================================================="
echo "Xray installation and configuration complete."
echo "Here are your VLESS links:"
echo ""
echo "1. Port 443 (SNI: www.cloudflare.com):"
echo "vless://$uuid@$server_ip:443?security=reality&sni=www.cloudflare.com&flow=xtls-rprx-vision&publicKey=$public_key&type=tcp#XRAY-443"
echo ""
echo "2. Port 2020 (SNI: www.microsoft.com):"
echo "vless://$uuid@$server_ip:2020?security=reality&sni=www.microsoft.com&flow=xtls-rprx-vision&publicKey=$public_key&type=tcp#XRAY-2020"
echo ""
echo "3. Port 8181 (SNI: www.bing.com):"
echo "vless://$uuid@$server_ip:8181?security=reality&sni=www.bing.com&flow=xtls-rprx-vision&publicKey=$public_key&type=tcp#XRAY-8181"
echo "=================================================="

set +e