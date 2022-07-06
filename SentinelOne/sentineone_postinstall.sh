#! /bin/bash

## script is written by the adamcraig and sourced from https://github.com/theadamcraig/jamf-scripts/tree/master/SentinelOne


# Unlike other sentinel installs this script will either Install on a new computer OR upgrade if sentinel is already installed. 
#I manage sentinel versions entirely from Jamf and only use one policy for both installs and upgrades.

## MAKE SURE TO ADD IN YOUR TOKEN TO REPLACE "YOURTOKENGOESHERE"

##Originally I was packaging up the SentinelAgent_macos installer and putting it in /tmp/
## then I changed to cache it so I didn't need to repackage it, so this script will check both /tmp and the waiting room.

PKG_NAME="$4"
## ex: SentinelAgent_macos_v3_0_4_2657.pkg
## ex: SentinelAgent_macos_v3_2_0_2671.pkg

if [ `id -u` != 0 ]; then
    /bin/echo "Error: You must run this command as root"
    exit 1
fi

if [[ "$PKG_NAME" == "" ]]; then 
    /bin/echo "Error: The parameter 'SentinelOne .pkg Name' is blank. Please specify a value." 
    exit 1 
fi

REGISTRATION_TOKEN="/tmp/com.sentinelone.registration-token"
S1_BINARY="/Library/Sentinel/sentinel-agent.bundle/Contents/MacOS/sentinelctl"
WAITING_ROOM="/Library/Application Support/JAMF/Waiting Room/"
INSTALL_DIRECTORY="/tmp/"


## check for the $PKG_NAME in the waiting room. if it exists then redefine INSTALL_PKG to that location
## this will allow the .pkg from sentinel one to be downloaded with out having to be repackaged
## this will also allow me to transition to doing this without needing to have 2 scripts.

if [[ -e "${WAITING_ROOM}${PKG_NAME}" ]] ; then
	echo "Installer found in Waiting room"
	INSTALL_DIRECTORY="$WAITING_ROOM"
fi

INSTALL_PKG="${INSTALL_DIRECTORY}${PKG_NAME}"
cd "${INSTALL_DIRECTORY}"

echo "Install Package"
echo "${INSTALL_PKG}"

if [ ! -f "${INSTALL_PKG}" ]; then
    /bin/echo "Error: ${INSTALL_PKG} does not exist, exiting"
    exit 1
fi

## if sentinelctl exists Upgrade sentinel one
if [[ -f ${S1_BINARY} ]]; then
    echo "sentinel on computer. Upgrading sentinel"
    /usr/local/bin/sentinelctl upgrade-pkg "${INSTALL_PKG}"
else
    #if not then install sentinel one
    ## create registration token
cat > "${INSTALL_DIRECTORY}com.sentinelone.registration-token" << END
YOURREGISTRATIONTOKENHERE
END
chmod -R 777 "${INSTALL_DIRECTORY}com.sentinelone.registration-token"
    /bin/echo "sentinel not on computer, beginning sentinel install"
    /usr/sbin/installer -pkg "${INSTALL_PKG}" -target /
    
    #clean up registration token
    sleep 10
    rm "${INSTALL_DIRECTORY}com.sentinelone.registration-token"
fi

#Clean up the installer and the jamf cache file
rm -f "${INSTALL_PKG}"
# also remove the cache.xml file
rm -f "${INSTALL_PKG}"*

exit 0
