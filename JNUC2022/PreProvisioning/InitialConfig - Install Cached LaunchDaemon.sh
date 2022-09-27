#!/bin/bash

adminUser1="${4}"
adminUser2="${5}"
setupUser="${6}"

if [[ -z "adminUser1" ]] || [[ -z "adminUser2" ]] || [[ -z "setupUser" ]] ; then
	echo "admin username variables missing."
	exit 1
fi

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]]; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi


WAITING_ROOM="/Library/Application Support/JAMF/Waiting Room/"

installCachedPackage () {
	PKG_NAME="${1}"
	INSTALL_PKG="$WAITING_ROOM$PKG_NAME"
	if [[ -e "${INSTALL_PKG}" ]] ; then 
		cd "$WAITING_ROOM"
		/usr/sbin/installer -pkg "${INSTALL_PKG}" -target /
		rm -f "${INSTALL_PKG}"
		rm -f "${INSTALL_PKG}*"
	else
		echo "${INSTALL_PKG} not found. exiting"
		exit 1
	fi
}

if [[ "$loggedInUser" == "${adminUser1}" ]] || [[ "$loggedInUser" == "${adminUser1}" ]] || [[ "$loggedInUser" == "$setupUser" ]] ; then
	echo "$loggedInUser logged in, take no action"
	exit 1
else
	echo "$loggedInUser logged in. install cached JAMFInitialConfig.pkg"
	## Do the thing
	installCachedPackage "JAMFInitialConfig-1.6.pkg"
	jamf recon
	exit 0
fi

exit 1