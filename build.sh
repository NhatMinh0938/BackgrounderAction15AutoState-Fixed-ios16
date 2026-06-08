#!/bin/bash
set -euo pipefail

if [ -z "${THEOS:-}" ]; then
    export THEOS="${HOME}/theos"
fi

if [ ! -d "$THEOS" ]; then
    echo "Cloning Theos into $THEOS"
    git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
fi

if [ ! -d "$THEOS/sdks/iPhoneOS16.5.sdk" ] && [ ! -d "$THEOS/sdks/iPhoneOS16.0.sdk" ]; then
  echo "Downloading iOS SDK for Theos..."
  curl -L "https://github.com/theos/sdks/archive/master.tar.gz" | tar -xz -C /tmp
  cp -R /tmp/sdks-master/*.sdk "$THEOS/sdks/" 2>/dev/null || true
fi

export FINALPACKAGE=1
make clean package

echo ""
echo "Built package:"
ls -1 packages/*.deb
