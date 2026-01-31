#!/bin/bash

# Function to check for required commands
check_dependencies() {
    for cmd in curl socat uuidgen; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is not installed. Please install it first."
            exit 1
        fi
    done
}

# Function to kill processes on specified ports
kill_processes_on_ports() {
    for port in 443 2020 8181; do
        echo "Checking for processes on port $port..."
        pid=$(lsof -t -i:$port)
        if [ -n "$pid" ]; then
            echo "Killing process with PID $pid on port $port."
            kill -9 "$pid"
        else
            echo "No process found on port $port."
        fi
    done
}


# Main script execution
echo "Starting Xray-core installation with VLESS+REALITY..."

# 1. Check for dependencies
check_dependencies

# 2. Kill existing processes on target ports
kill_processes_on_ports

# 3. Install Xray-core
echo "Installing Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --force

# 4. Generate X25519 keys
echo "Generating X25519 keys..."
keys=$(/usr/local/bin/xray x25519)
private_key=$(echo "$keys" | awk '/Private key:/ {print $3}')
public_key=$(echo "$keys" | awk '/Public key:/ {print $3}')

if [ -z "$private_key" ] || [ -z "$public_key" ]; then
    echo "Error: Failed to generate X25519 keys."
    exit 1
fi

echo "Keys generated successfully."

# 5. Generate UUID
uuid=$(uuidgen)
echo "Generated UUID: $uuid"

# 6. Get server public IP
server_ip=$(curl -s ipinfo.io/ip)
if [ -z "$server_ip" ]; then
    echo "Error: Failed to get server public IP."
    exit 1
fi
echo "Server IP: $server_ip"


# 7. Create config.json
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
        "destOverride": [
          "http",
          "tls"
        ]
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
        "destOverride": [
          "http",
          "tls"
        ]
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
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

# 8. Enable and restart Xray service
echo "Enabling and restarting Xray service..."
systemctl enable xray
systemctl restart xray

# 9. Display VLESS links
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
