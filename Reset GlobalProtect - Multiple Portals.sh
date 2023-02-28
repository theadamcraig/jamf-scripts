#!/bin/bash

#This will be the default portal.
portalAddress1="${4}"

portalAddress2="${5}"

# For the gpUsername variable
emailDomain="COMPANYNAME.COM"


if [[ -z "$portalAddress1" ]] ; then
	echo "portal not set"
	exit 1
fi

if [[ -z "$portalAddress2" ]] ; then
	echo "portal not set"
	echo "this portal is optional, continuing"
fi

#########################################################################################
## Get logged in user from Console.
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

## make sure there is a value and that it's not any of the accounts that can occasionally be a result of the console method and have an error.
if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]] ; then
	## if it's not a valid user let's' take the result from jamf
	loggedInUser="$3"
fi
## convert logged in user to lowercase
## sometimes we get an mixed case user and it can create inconsistent results
if [ -n "$BASH_VERSION" ]; then
   # assume Bash
   loggedInUser=$( echo "$loggedInUser" | tr [:upper:] [:lower:] )
else
   # assume something else
   echo "script not written in bash, leaving as mixedcase."
fi
## Make sure again that the user is valid. It's possible that $3 from Jamf is also an invalid user.
if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]] ; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi
## Get the logged in UID which will be needed for some commands as well.
loggedInUID=$(id -u "$loggedInUser")

userHome="/Users/${loggedInUser}"
# if you look in the user plist you'll see how this should be formatted.
gpUsername="${loggedInUser}@${emailDomain}"

userKeychain="/Users/$loggedInUser/Library/Keychains/login.keychain-db"
systemKeychain="/Library/Keychains/System.keychain"

######################
## DISPLAY NOTIFICAITON lifted from installomator

runAsUser() {
    if [[ $loggedInUser != "loginwindow" ]]; then
        launchctl asuser $loggedInUID sudo -u $loggedInUser "$@"
    fi
}

## an update by acaudill to the displaynotification function to make it prefer swiftDialog if installed
displaynotification() { # $1: message $2: title
    message=${1:-"Message"}
    title=${2:-"Notification"}
    swiftDialog="/usr/local/bin/dialog"
    manageaction="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"
    hubcli="/usr/local/bin/hubcli"

    if [[ -x "$swiftDialog" ]]; then
         runAsUser "$swiftDialog" --notification --title "$title" --message "$message"
    elif [[ -x "$manageaction" ]]; then
         "$manageaction" -message "$message" -title "$title"
    elif [[ -x "$hubcli" ]]; then
         "$hubcli" notify -t "$title" -i "$message" -c "Dismiss"
    else
        runAsUser osascript -e "display notification \"$message\" with title \"$title\""
    fi
}


######################
## SET PORTAL FUNCTION
setPortal(){
	local portal="${1}"
	if [[ -z "$portal" ]] ; then
		echo "Portal not provided"
	else
		echo "setting portal to $portal1"
	fi
	local plistLocation="/Library/Preferences/com.paloaltonetworks.GlobalProtect.settings.plist"
	rm -f "${plistLocation}"

/bin/echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Palo Alto Networks</key>
	<dict>
		<key>GlobalProtect</key>
		<dict>
			<key>PanSetup</key>
			<dict>
				<key>Portal</key>
				<string>'${portal}'</string>
				<key>Prelogon</key>
				<string>0</string>
			</dict>
		</dict>
	</dict>
</dict>
</plist>' > "${plistLocation}"

chown root:wheel "${plistLocation}"
chmod 644 "${plistLocation}"
}
##  END SET PORTAL FUNCTION
######################


setUserPortals() {

	local portal1="${1}"
	if [[ -z "$portal1" ]] ; then
		echo "Portal not provided"
	fi
		local portal2="${2}"
	if [[ -z "$portal2" ]] ; then
		echo "Portal not provided"
	fi
	echo "setting user portals to $portal1 $portal2"
	local plistLocation="${userHome}/Library/Preferences/com.paloaltonetworks.GlobalProtect.client.plist"
	rm -f "${plistLocation}"
/bin/launchctl asuser "$loggedInUID" /usr/bin/sudo -iu "$loggedInUser" /bin/echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>PanPortalList</key>
        <array>
            <string>'${portal1}'</string>
            <string>'${portal2}'</string>
        </array>
        <key>User</key>
        <string>'${gpUsername}'</string>
        <key>user-credential-saved</key>
        <string>true</string>
    </dict>
</plist>' > "${plistLocation}"

chown "${loggedInUser}":staff "${plistLocation}"
chmod 644 "${plistLocation}"

}

removeGPState() {

	echo "removing GP launchAgents and State"

	/bin/launchctl asuser "$loggedInUID" /usr/bin/sudo -iu "$loggedInUser" /bin/launchctl unload /Library/LaunchAgents/com.paloaltonetworks.gp.pangps.plist
	/bin/launchctl asuser "$loggedInUID" /usr/bin/sudo -iu "$loggedInUser" /bin/launchctl unload /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist
	
## if this isn't bootout then it may be unload -w
/bin/launchctl bootout system "/Library/LaunchDaemons/com.paloaltonetworks.gp.pangpsd.plist"
# not running this command as user due to getting this error
# Warning: Expecting a LaunchAgents path since the command was ran as user. Got LaunchDaemons instead.
# `launchctl bootout` is a recommended alternative.
# Unload failed: 5: Input/output error

	#grabbed all of this from the official GP Uninstall script
	echo "remove State:/Network/Service/gpd.pan/IPv4" | scutil 
	echo "remove State:/Network/Service/gpd.pan/DNS"  | scutil 

	rm -rf "/Library/Application Support/PaloAltoNetworks/GlobalProtect"
	rm -rf "/Applications/GlobalProtect.app.bak"
	rm -rf "/System/Library/Extensions/gplock.kext"
	rm -rf "/Library/Extensions/gplock.kext"
	rm -rf "/Library/Security/SecurityAgentPlugins/gplogin.bundle"

	rm -rf "$userHome/Library/Application Support/PaloAltoNetworks/GlobalProtect"
	rm -rf "$userHome"/Library/Preferences/com.paloaltonetworks.GlobalProtect*
	rm -rf "$userHome"/Library/Preferences/PanGPS*
	
	security delete-generic-password -l GlobalProtect -s GlobalProtect "${userHome}/Library/Keychains/login.keychain-db"

	#10.9 addition to clear system preferences cache
	killall -SIGTERM cfprefsd

	killall GlobalProtect
	killall PanGPS
	
	echo " LaunchAgents Removed"
	echo " "
} 

reloadGPAgents() {

	echo "reloading GP launchAgents"
	/bin/launchctl asuser "$loggedInUID" /usr/bin/sudo -iu "$loggedInUser" /bin/launchctl load "/Library/LaunchAgents/com.paloaltonetworks.gp.pangps.plist"
/bin/launchctl asuser "$loggedInUID" /usr/bin/sudo -iu "$loggedInUser" /bin/launchctl load "/Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist"
/bin/launchctl load -w "/Library/LaunchDaemons/com.paloaltonetworks.gp.pangpsd.plist"
# not running this command as user due to getting an error with launchctl
# Unload failed: 5: Input/output error
	echo "launchAgents reloaded"
	echo " "

}

######################
# DO THE THINGS
#######################

removeGPState

setPortal "${portalAddress1}"

if [[ -z  "${portalAddress2}" ]] ; then
	echo "No second portal entered"
	plistLocation="${userHome}/Library/Preferences/com.paloaltonetworks.GlobalProtect.client.plist"
	rm -f "${plistLocation}"
else
	setUserPortals "${portalAddress1}" "${portalAddress2}"
fi

killall cfprefsd
killall GlobalProtect
killall PanGPS

echo "Load launch agents"
reloadGPAgents

# sleeping for 15 to allow GP time to connect
sleep 15

# GP check status.
GPSlog="/Library/Logs/PaloAltoNetworks/GlobalProtect/PanGPS.log"

loopCount=0
echo " "
echo "Looping GP Status check"
while [ $loopCount -lt 2 ] ; do
	echo " "
	echo "loopCount=${loopCount}"
	((loopCount++))
	## Sleep to give the user time to do things and GP a chance to connect
	sleep 15
	## Discovery complete is what happens with Internal when the user is on the Company network
	GPstatus=$( tail -r $GPSlog |grep -m 1 -o -e 'Set state to Disconnected' -e 'Set state to Connected' -e 'Set state to Discovery complete' )
	## determine if GP is already connected
	if [[ "$GPstatus" == "Set state to Connected" ]] || [[ "$GPstatus" == "Set state to Discovery complete" ]] ; then 
	echo "GP status is $GPstatus"
		break
	else
		echo "GP status is $GPstatus"
	fi
done

## check status again
if [[ "$GPstatus" == "Set state to Connected" ]] || [[ "$GPstatus" == "Set state to Discovery complete" ]] ; then 
	echo "GP status is $GPstatus"
	displaynotification "Reset GlobalProtect Complete!"
	exit 0
else
	echo "GP status is $GPstatus"
	if [[ -z "$silent" ]] ; then
		displaynotification "Reset GlobalProtect Complete! Sign into Okta if prompted. You may need to Refresh Connection or Restart your Computer."
	else
		echo "Script set to run silently"
	fi
	exit 0
fi