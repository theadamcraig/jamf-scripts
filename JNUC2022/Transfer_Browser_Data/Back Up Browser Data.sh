#!/bin/bash

##########################################################################################/

# Script presented in Userproof Onboarding: Backup Plans for Zero Touch for IT JNUC 2022

# https://github.com/theadamcraig/jamf-scripts/tree/master/JNUC2022

##########################################################################################/

# This script backs up a users browser data from the ~/Library/Application Support folder to their OneDrive folder.

# There is a corresponding script that will restore the backup on a separate computer

# Supported browsers are:
# Brave Browser
# Google Chrome
# Mozilla Firefox

##########################################################################################/

# ITEMS THAT NEED UPDATED IN THIS SCRIPT:

# onedrive_folder variable will need updated to your organizations default location

# uses of the DisplayDialog. You may want to change the error messages

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


# SET UP DISPLAY DIALOG FUNCTION
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

## make sure the OneDrive folder exists
if [[ ! -e "${onedrive_folder}" ]] ; then
	echo "One Drive folder not found"
	DisplayDialog "OneDrive has not been set up, or something else has gone wrong. Sign into onedrive and try again."
	exit 1
fi


### BROWSER BACKUP FUNCTIONS

BackupBrave() {
	archive_name="brave-backup.zip"
	source_path="$home_root/Library/Application Support/BraveSoftware/Brave-Browser"
	destination_path="$backup_root/$archive_name"
	#echo "checking $source_path"
	if [[ ! -d "${source_path}" ]]
	then
		echo "No Brave Browser config to save. Exiting."
		exit 1
	fi
	if [ ! -d "$backup_root" ]
	then
		mkdir -p "$backup_root"
	fi
	if [[ -e "$destination_path" ]] ; then
		echo "$destination_path already exists. Removing"
		rm -rf "$destination_path"
	fi
	cd "$source_path" || exit 1
	#https://isabelcastillo.com/bash-zip-exclude
	echo "beginning file zip"
	zip -r "$destination_path" * -x 'CacheStorage' '*Cache*' >> /dev/null 2>&1 
	chown -R "$loggedInUser" "$backup_root"
	chmod -R 755 "$backup_root"
	DisplayDialog "Brave settings have been backed up to OneDrive"
}

BackupChrome() {
	archive_name="chrome-backup.zip"
	source_path="$home_root/Library/Application Support/Google/Chrome"
	destination_path="$backup_root/$archive_name"
	#echo "checking $source_path"
	if [[ ! -d "${source_path}" ]]
	then
		echo "No Google Chrome config to save. Exiting."
		exit 1
	fi
	if [ ! -d "$backup_root" ]
	then
		mkdir -p "$backup_root"
	fi
	if [[ -e "$destination_path" ]] ; then
		echo "$destination_path already exists. Removing"
		rm -rf "$destination_path"
	fi
	cd "$source_path" || exit 1
	echo "beginning file zip"
	#https://isabelcastillo.com/bash-zip-exclude
	zip -r "$destination_path" * -x 'CacheStorage' '*Cache*' >> /dev/null 2>&1 
	chown -R "$loggedInUser" "$backup_root"
	chmod -R 755 "$backup_root"
	DisplayDialog "Chrome settings have been backed up to OneDrive"

}

BackupFirefox() {
	archive_name="firefox-backup.zip"
	source_path="$home_root/Library/Application Support/Firefox"
	destination_path="$backup_root/$archive_name"
	if [ ! -d "$source_path" ]
	then
		DisplayDialog "No Firefox config to save. Exiting."
		exit 1
	fi
	if [ ! -d "$backup_root" ]
	then
		mkdir -p "$backup_root"
	fi
	if [[ -e "$destination_path" ]] ; then
		echo "$destination_path already exists. Removing"
		rm -rf "$destination_path"
	fi
	cd "$source_path" || exit 1
	echo "beginning file zip"
	zip -r "$destination_path" * >> /dev/null 2>&1 
	chown -R "$loggedInUser" "$backup_root"
	chmod -R 755 "$backup_root"
	DisplayDialog "Firefox settings have been backed up to OneDrive"

}

## define browsers we support
brave="Brave Browser.app"
chrome="Google Chrome.app"
firefox="Firefox.app"

brave_path="/Applications/${brave}"
chrome_path="/Applications/${chrome}"
firefox_path="/Applications/${firefox}"

## Make sure there are browsers installed

if [[ ! -e "${brave_path}" ]] && [[ ! -e "${chrome_path}" ]] && [[ ! -e "${firefox_path}" ]] ; then
	DisplayDialog "No supported browsers found"
	exit 1
fi

# Build Choice List

list="{ "
choice_number=0

if [[ -e "${brave_path}" ]] ; then
	if [[ $choice_number -gt 0 ]] ; then
		list="${list},"
	fi
	list="${list} \"Brave Browser\""
	((choice_number++))
fi

if [[ -e "${chrome_path}" ]] ; then
	if [[ $choice_number -gt 0 ]] ; then
		list="${list},"
	fi
	list="${list} \"Google Chrome\""
	((choice_number++))
fi

if [[ -e "${firefox_path}" ]] ; then
	if [[ $choice_number -gt 0 ]] ; then
		list="${list},"
	fi
	list="${list} \"Firefox\" "
	((choice_number++))
fi

list="${list} }"

echo ""
echo "$list"
echo ""


if [[ $choice_number -gt 1 ]] ; then

	cmd="( choose from list ${list} with prompt \"Backup Data from which browser?\" default items \"None\" OK button name {\"Backup\"} cancel button name {\"Cancel\"})"
	browser_choice=$( /usr/bin/osascript -e "$cmd" )

elif [[ $choice_number = 1 ]] ; then
	## Only one browser found
	DisplayDialog "Backing up $browser_choice"	
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
	echo "Backing up Brave."
	BackupBrave
	sleep 1
	exit 0
fi

if [[ "$browser_choice" == "Google Chrome" ]] ; then
	echo "Backing up Chrome."
	BackupChrome
	sleep 1
	exit 0
fi

if [[ "$browser_choice" == "Firefox" ]] ; then
	echo "Backing up Firefox."
	BackupFirefox
	sleep 1
	exit 0
fi
