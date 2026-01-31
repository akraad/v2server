#!/bin/bash
#
# PACKAGE C: Xray-core Servicer
# This script creates, enables, and starts the systemd service for Xray.

set -e

echo "--- PACKAGE C: Setting up systemd service ---"

# 1. Check if Xray is installed
if ! [ -f "/usr/local/bin/xray" ]; then
    echo "Error: '/usr/local/bin/xray' not found. Please run the installer package first."
    exit 1
fi

# 2. Check if config exists
if ! [ -f "/usr/local/etc/xray/config.json" ]; then
    echo "Error: '/usr/local/etc/xray/config.json' not found. Please run the configurator package first."
    exit 1
fi

# 3. Create systemd service file
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

# 4. Enable and start the service
echo "Reloading systemd, enabling and restarting Xray service..."
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# 5. Check service status
sleep 2 # Give the service a moment to start
if systemctl is-active --quiet xray; then
    echo "--- PACKAGE C: Xray service is active and running. ---"
else
    echo "--- WARNING: Xray service failed to start. ---"
    echo "Please check the logs with 'journalctl -u xray --no-pager' for more details."
    exit 1
fi
echo "---"

