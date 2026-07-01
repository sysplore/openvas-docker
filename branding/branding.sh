#!/bin/bash

# Replace images and branding in the GSA web interface with Sysplore branded versions.
WEB_DIR="/usr/local/share/gvm/gsad/web"
mkdir -p "${WEB_DIR}/img"

# Copy all branding assets to the web image directory
cp /branding/Sysplore.png "${WEB_DIR}/img/"
cp /branding/gsa.svg "${WEB_DIR}/img/"
cp /branding/login-label.svg "${WEB_DIR}/img/"

# Copy custom SVG logos for the login page (replaces Greenbone logos)
cp /branding/openvasHorizontal.svg "${WEB_DIR}/img/"
cp /branding/openvasHorizontal-scan.svg "${WEB_DIR}/img/"

# Copy the branding override script that modifies footer text at runtime
cp /branding/branding-override.js "${WEB_DIR}/img/"
echo "Sysplore branding applied to ${WEB_DIR}"
