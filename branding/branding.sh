#!/bin/bash

# Replace images in the GSA web interface with Sysplore branded versions.
WEB_DIR="/usr/local/share/gvm/gsad/web"
mkdir -p "${WEB_DIR}/img"

# Copy branding assets
cp /branding/Sysplore.png "${WEB_DIR}/img/"
cp /branding/gsa.svg "${WEB_DIR}/img/"
cp /branding/login-label.svg "${WEB_DIR}/img/"
echo "Branding assets copied to ${WEB_DIR}/img/"
