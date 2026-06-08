#!/bin/bash
set -euo pipefail

if [ -z "${THEOS:-}" ]; then
    export THEOS="${HOME}/theos"
fi

if [ ! -d "$THEOS" ]; then
    echo "Cloning Theos into $THEOS"
    git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
fi

if [ ! -d "$THEOS/sdks/iPhoneOS16.5.sdk" ]; then
    echo "Downloading iOS SDK for Theos..."
    mkdir -p "$THEOS/sdks"
    curl -L "https://github.com/theos/sdks/archive/refs/heads/master.tar.gz" | tar -xz -C /tmp
    cp -R /tmp/sdks-master/iPhoneOS16.5.sdk "$THEOS/sdks/"
fi

if [ ! -d "$THEOS/lib/iphone/rootless/AltList.framework" ] && [ ! -d "vendor/AltList" ]; then
    echo "Building AltList framework..."
    git clone --depth 1 https://github.com/opa334/AltList.git vendor/AltList
    make -C vendor/AltList THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1
    mkdir -p "$THEOS/lib/iphone/rootless"
    cp -R vendor/AltList/.theos/obj/debug/AltList.framework "$THEOS/lib/iphone/rootless/" 2>/dev/null \
        || cp -R vendor/AltList/.theos/_/Library/Frameworks/AltList.framework "$THEOS/lib/iphone/rootless/" 2>/dev/null \
        || cp -R vendor/AltList/.theos/obj/AltList.framework "$THEOS/lib/iphone/rootless/"
fi

export FINALPACKAGE=1
make clean package

echo ""
echo "Built package:"
ls -1 packages/*.deb
