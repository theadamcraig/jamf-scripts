#!/bin/bash

##########################################################################################/

# written by Adam Caudill

# Script presented in Userproof Onboarding: Backup Plans for Zero Touch for IT JNUC 2022

# https://github.com/theadamcraig/jamf-scripts/tree/master/JNUC2022

##########################################################################################/

# This script should be scoped to run once per computer, retry on failure, on all computers enrolled in the last 24 hours.

# if for some reason Jamf Connect fails to install during prestage, this will use the custom trigger specified to install it and then kill the login window allowing the user to login.

##########################################################################################/

# Requires an policy to install Jamf Connect that runs on custom trigger jamfconnect
customTrigger="jamfconnect" # "${4}" to use script parameter

# name of the profile with Jamf Connect settings installed
profileName="Jamf Connect Configuration" # "${5}" to use script parameter

#Function to check if profile is installed
function waitForProfileInstall () {
    index=0
    while [ "$(profiles -C -v | grep "$profileName" | awk -F": " '/attribute: name/{print $NF}')" != "$profileName" ] && [ $index -le 25 ]; do
        echo "Waiting for $profileName configuration profile to install..."
        sleep 5
        (( index++ ))
    done
    
    if [[ "$(profiles -C -v | grep "$profileName" | awk -F": " '/attribute: name/{print $NF}')" == "$profileName" ]]; then
        echo "$profileName configuration profile has been installed"
    else
        echo "Profile was still not installed. Please try again."
        exit 1
    fi
}

# If jamf connect is not installed install it and then kill loginwindow so jamf connect takes over.
if [[ ! -e "/Applications/Jamf Connect.app" ]] ; then
	echo "Jamf Connect is not installed. Starting initial Config"
	jamf policy -event "$customTrigger"
	waitForProfileInstall
	/usr/local/bin/authchanger -reset -JamfConnect
	killall loginwindow
	exit 1
else
# if jamf connect is installed make sure the authchanger was set. if not set it and kill login window
	if [[ $( /usr/local/bin/authchanger -print | grep JamfConnectLogin:LoginUI ) != "" ]] ; then
		echo "Jamf connect installed and auth changer is enabled"
	else
		echo "Jamf Connect is installed, auth changer is not set"
		/usr/local/bin/authchanger -reset -JamfConnect
		killall loginwindow
	fi
	exit 0
fi
