#!/bin/bash

##########################################################################################/

# Script presented in Userproof Onboarding: Backup Plans for Zero Touch for IT JNUC 2022

# https://github.com/theadamcraig/jamf-scripts/tree/master/JNUC2022

##########################################################################################/

# This script users users browser data to the ~/Library/Application Support folder from their OneDrive folder.

# There is a corresponding script that will create the backup on a separate computer

# Supported browsers are:
# Brave Browser
# Google Chrome
# Mozilla Firefox

##########################################################################################/

# ITEMS THAT NEED UPDATED:

# onedrive_folder variable will need updated to your organizations default location

# jamf policy Custom Triggers
# These custom triggers should all correspond to a policy that will only install the designated browser

# uses of the DisplayDialog. You may want to change the error messages
##########################################################################################/

# SUPPORTING POLICIES THAT NEED CREATED

# jamf policy -event installBraveBrowser
# jamf policy -event installGoogleChrome
# jamf policy -event installFirefox

# Policies need created and/or these trigger variables need updated to install the required browser.

##########################################################################################/
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]] ; then
	loggedInUser="$3"
fi

if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] ; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi

loggedInUID=$(id -u "$loggedInUser")

# Define Variables for backup
home_root="/Users/$loggedInUser"
### This Variable Needs Changed
onedrive_folder="$home_root/OneDrive - CompanyName"
backup_root="$onedrive_folder/.userConfig"

# Jamf Policy Custom Triggers
brave_trigger="installBraveBrowser"
chrome_trigger="installGoogleChrome"
firefox_trigger="installFirefox"


#### SET UP DISPLAY DIALOG FUNCTION
DisplayDialog(){
	local dialogText="$1"
	echo "$dialogText"
	#Log "Display Dialog: $dialogText"
	cmd="display dialog \"$dialogText\" buttons {\"Continue\"} default button 1 giving up after 180"
	if [[ -z "$loggedInUID" ]] || [[ -z "$loggedInUser" ]] ; then 
		/usr/bin/osascript -e "$cmd"
	else
		/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" /usr/bin/osascript -e "$cmd"
	fi
}

CheckApp(){
	app_name="$1"
	jamf_trigger="$2"
	file_path="/Applications/$app_name"
	if [[ -d $file_path ]] ; then
		echo "$app_name installed."
	else
		echo "$app_name missing."
		echo "installing $app_name"
		jamf policy -event "$jamf_trigger" -forceNoRecon
	fi
}


## make sure the OneDrive folder exists
if [[ ! -e "${onedrive_folder}" ]] ; then
	echo "One Drive folder not found"
	DisplayDialog "OneDrive has not been set up, or something else has gone wrong. Sign into onedrive and try again."
	exit 1
fi

#### BROWSER RESTORE FUNCTIONS

RestoreBrave() {
	archive_name="brave-backup.zip"
	source_path="$backup_root/$archive_name"
	destination_path="$home_root/Library/Application Support/BraveSoftware/Brave-Browser"
	if [ ! -f "$source_path" ]
	then
		echo "No Brave Browser config to restore. Exiting."
		exit 1
	fi
	killall "Brave Browser"
	if [ ! -d "$destination_path" ]
	then
		mkdir -p "$destination_path"
	fi
	cp "$source_path" "$destination_path"
	cd "$destination_path" || exit 1
	unzip -o "$archive_name" >> /dev/null 2>&1 
	rm "$archive_name"
	chown "$loggedInUser" .
	chown -R "$loggedInUser" "${destination_path}"
	DisplayDialog "Brave Browser settings have been restored from OneDrive"
}

RestoreChrome() {
	archive_name="chrome-backup.zip"
	source_path="$backup_root/$archive_name"
	destination_path="$home_root/Library/Application Support/Google/Chrome"
	if [ ! -f "$source_path" ]
	then
		echo "No Google Chrome config to restore. Exiting."
		exit 1
	fi
	killall "Google Chrome"
	if [ ! -d "$destination_path" ]
	then
		mkdir -p "$destination_path"
	fi
	cp "$source_path" "$destination_path"
	cd "$destination_path" || exit 1
	unzip -o "$archive_name" >> /dev/null 2>&1 
	rm "$archive_name"
	chown "$loggedInUser" .
	chown -R "$loggedInUser" "${destination_path}"
	DisplayDialog "Google Chrome settings have been restored from OneDrive"
}

RestoreFirefox() {
	archive_name="firefox-backup.zip"
	source_path="$backup_root/$archive_name"
	destination_path="$home_root/Library/Application Support/Firefox"
	if [ ! -f "$source_path" ]
	then
		echo "No Firefox config to restore. Exiting."
		exit 1
	fi
	killall "Firefox"
	if [ ! -d "$destination_path" ]
	then
		mkdir -p "$destination_path"
	fi
	cp "$source_path" "$destination_path"
	cd "$destination_path" || exit 1
	unzip -o "$archive_name" >> /dev/null 2>&1 
	rm "$archive_name"
	chown "$loggedInUser" .
	chown -R "$loggedInUser" "${destination_path}"
	DisplayDialog "Firefox settings have been restored from OneDrive"
}

## Backup Files
brave_backup="${backup_root}/brave-backup.zip"
chrome_backup="${backup_root}/chrome-backup.zip"
firefox_backup="${backup_root}/firefox-backup.zip"

## define browsers we support
brave="Brave Browser.app"
chrome="Google Chrome.app"
firefox="Firefox.app"



## check if backups exist
if [[ ! -e "${brave_backup}" ]] && [[ ! -e "${chrome_backup}" ]] && [[ ! -e "${firefox_backup}" ]] ; then
	## no backup, force OneDrive to download the backup_root folder.
	/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" /Applications/OneDrive.App/Contents/MacOS/OneDrive /pin /r "$backup_root"
	sleep 30
fi

## Make sure Backups exist
if [[ ! -e "${brave_backup}" ]] && [[ ! -e "${chrome_backup}" ]] && [[ ! -e "${firefox_backup}" ]] ; then
	DisplayDialog "No browser backups found. Make sure OneDrive is open, signed in and syncing correctly on both computers."
	exit 1
fi

## Build Choice List

list="{ "
choice_number=0

if [[ -e "${brave_backup}" ]] ; then
	if [[ $choice_number -gt 0 ]] ; then
		list="${list},"
	fi
	browser_choice="Brave browser"
	list="${list} \"Brave Browser\""
	((choice_number++))
fi

if [[ -e "${chrome_backup}" ]] ; then
	if [[ $choice_number -gt 0 ]] ; then
		list="${list},"
	fi
	browser_choice="Google Chrome"
	list="${list} \"Google Chrome\""
	((choice_number++))
fi

if [[ -e "${firefox_backup}" ]] ; then
	if [[ $choice_number -gt 0 ]] ; then
		list="${list},"
	fi
	browser_choice="FireFox"
	list="${list} \"Firefox\" "
	((choice_number++))
fi

list="${list} }"

echo ""
echo "$list"
echo ""

if [[ $choice_number -gt 1 ]] ; then

	cmd="( choose from list ${list} with prompt \"Restore Data for which browser?\" default items \"None\" OK button name {\"Restore\"} cancel button name {\"Cancel\"})"

	browser_choice=$( /usr/bin/osascript -e "$cmd" )
elif [[ $choice_number = 1 ]] ; then
	## Only one browser found
	DisplayDialog "Restoring backup for: $browser_choice"	
else
	DisplayDialog "No eligible browser found."
fi


echo "User Chose:"
echo "$browser_choice"
echo ""

if [ "$browser_choice" = false ] ; then
	echo "User selected Cancel"
	exit 1
fi

if [[ "$browser_choice" == "Brave Browser" ]] ; then
	### ADD FUNCTION TO VERIFY APP EXITS AND INSTALL APP IF IT DOES NOT
	CheckApp "${brave}" "${brave_trigger}"
	echo "Restoring Brave."
	RestoreBrave
	sleep 1
	exit 0
fi

if [[ "$browser_choice" == "Google Chrome" ]] ; then
	### ADD FUNCTION TO VERIFY APP EXITS AND INSTALL APP IF IT DOES NOT
	CheckApp "${chrome}" "${chrome_trigger}"
	echo "Restoring Chrome."
	RestoreChrome
	sleep 1
	exit 0
fi

if [[ "$browser_choice" == "Firefox" ]] ; then
	CheckApp "${firefox}" "${firefox_trigger}"
	### ADD FUNCTION TO VERIFY APP EXITS AND INSTALL APP IF IT DOES NOT
	echo "Restoring Firefox."
	RestoreFirefox
	sleep 1
	exit 0
fi
