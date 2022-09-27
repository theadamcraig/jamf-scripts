#!/bin/bash
## preinstall

pathToScript=$0
pathToPackage=$1
targetLocation=$2
targetVolume=$3

arch=$(/usr/bin/arch)
if [[ "$arch" == "arm64" && ! -f "/Library/Apple/System/Library/LaunchDaemons/com.apple.oahd.plist" ]]; then
    /usr/sbin/softwareupdate --install-rosetta --agree-to-license
fi

exit 0 ## Success
