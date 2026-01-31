#!/bin/bash
#
# PACKAGE A: Xray-core Installer
# This script downloads, verifies, and installs the latest Xray-core binary.

set -e

echo "--- PACKAGE A: Installing latest Xray-core ---"

# 1. Check for dependencies
for cmd in curl unzip sha256sum; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed."
        # Attempt to install unzip if missing
        if [ "$cmd" == "unzip" ]; then
            echo "Attempting to install 'unzip'..."
            if command -v "apt-get" &> /dev/null; then
                apt-get update && apt-get install -y unzip
            elif command -v "yum" &> /dev/null; then
                yum install -y unzip
            elif command -v "dnf" &> /dev/null; then
                dnf install -y unzip
            else
                echo "Error: Could not auto-install 'unzip'. Please install it manually."
                exit 1
            fi
        else
            exit 1
        fi
    fi
done

# 2. Find latest version and download
LATEST_TAG=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_TAG" ]; then
    echo "Error: Failed to fetch the latest Xray version tag."
    exit 1
fi
echo "Latest version found: $LATEST_TAG"
ZIP_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_TAG}/Xray-linux-64.zip"

TMP_DIR=$(mktemp -d)
echo "Downloading Xray-core from $ZIP_URL"
curl -L -o "${TMP_DIR}/xray.zip" "$ZIP_URL"
unzip -o "${TMP_DIR}/xray.zip" -d "${TMP_DIR}"

# 3. Verify file integrity
DOWNLOADED_CHECKSUM=$(sha256sum "${TMP_DIR}/xray" | awk '{print $1}')
echo "Checksum of downloaded xray binary: $DOWNLOADED_CHECKSUM"

# 4. Install files
echo "Installing binaries and data files..."
mv -f "${TMP_DIR}/xray" /usr/local/bin/xray
chmod 755 /usr/local/bin/xray

install -d /usr/local/share/xray/
mv -f "${TMP_DIR}/geosite.dat" /usr/local/share/xray/
mv -f "${TMP_DIR}/geoip.dat" /usr/local/share/xray/

# 5. Verify installed file
INSTALLED_CHECKSUM=$(sha256sum /usr/local/bin/xray | awk '{print $1}')
echo "Checksum of installed xray binary: $INSTALLED_CHECKSUM"

if [ "$DOWNLOADED_CHECKSUM" != "$INSTALLED_CHECKSUM" ]; then
    echo "---"
    echo "FATAL ERROR in PACKAGE A: CHECKSUM MISMATCH!"
    echo "The xray file was altered after being moved. This is likely due to an external process on your server."
    echo "Please contact your server administrator."
    echo "---"
    exit 1
fi

rm -rf "${TMP_DIR}"

echo "--- PACKAGE A: Xray-core installed successfully. ---"
echo -n "Installed version: "
/usr/local/bin/xray version
echo "---"
