#!/bin/sh

## I stopped using this. Installomator does it way better

# https://github.com/Installomator/Installomator

#based on a script that installs the latest version of Chrome

dmgfile="Brave-Broswer.dmg"
volname="Brave Browser"
logfile="/Library/Logs/BraveInstallScript.log"

url='https://brave-browser-downloads.s3.brave.com/latest/Brave-Browser.dmg'


/bin/echo "--" >> ${logfile}
/bin/echo "`date`: Downloading latest version." >> ${logfile}
/usr/bin/curl -s -o /tmp/${dmgfile} ${url}
/bin/echo "`date`: Mounting installer disk image." >> ${logfile}
/usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
/bin/echo "`date`: Installing..." >> ${logfile}
ditto -rsrc "/Volumes/${volname}/Brave Browser.app" "/Applications/Brave Browser.app"
/bin/sleep 10
/bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "${volname}" | awk '{print $1}') -quiet
/bin/sleep 10
/bin/echo "`date`: Deleting disk image." >> ${logfile}
/bin/rm /tmp/"${dmgfile}"

exit 0