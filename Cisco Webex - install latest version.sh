#!/bin/bash
# Based on a script that installs the latest version of chrome.

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] ; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi
loggedInUID=$(id -u "$loggedInUser")


dmgfile="webexapp.dmg"
volname="Cisco Webex Meetings"
logfile="/Library/Logs/WebexInstallScript.log"
installerName="Cisco Webex Meetings.pkg"

url='https://akamaicdn.webex.com/client/webexapp.dmg'


/bin/echo "--" >> ${logfile}
/bin/echo "`date`: Downloading latest version." >> ${logfile}
/usr/bin/curl -s -o /tmp/${dmgfile} ${url}
/bin/echo "`date`: Mounting installer disk image." >> ${logfile}
/usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
/bin/echo "`date`: Installing..." >> ${logfile}

### run the installer as the user
/bin/launchctl asuser "$loggedInUID" /usr/sbin/installer -pkg "/Volumes/${volname}/${installerName}" -target /
/bin/sleep 10
/bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "${volname}" | awk '{print $1}') -quiet
/bin/sleep 10
/bin/echo "`date`: Deleting disk image." >> ${logfile}
/bin/rm /tmp/"${dmgfile}"

exit 0
