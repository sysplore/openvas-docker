#!/bin/bash
set -Eeuo pipefail
# Source this for the latest release versions
. build.rc
python3 -m pip install "redis==3.5.3" --break-system-packages
python3 -m pip install python-gvm==$python_gvm
