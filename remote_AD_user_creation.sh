#!bin/bash

## referenced commands on https://github.com/rtrouton/rtrouton_scripts/blob/master/rtrouton_scripts/migrate_local_user_to_AD_domain/MigrateLocalUserToADDomainAcct.command

## This script is written by theadamcraig sourced from https://github.com/theadamcraig/jamf-scripts/
## it expects the computer to be already bound to AD with filevault enabled
## if filevault is not enabled it will run jamf policy -trigger catalina_fv 
## if the computer is not bound it will run jamf policy -trigger rebind
## it will create a log file in /Users/Shared/Provisioning.log

adminUser="$4"
adminPass="$5"

enableFV2JamfTrigger="catalina_fv"
rebindJamfTrigger="rebind"

osvers=$(sw_vers -productVersion | awk -F. '{print $2}')
check4AD=`/usr/bin/dscl localhost -list . | grep "Active Directory"`

#########################
### SET UP LOGGING

log_file=/Users/Shared/Provisioning.log

touch $log_file

echo "Computer Provisioning Remote AD User Creation Begun" >> $log_file

Log(){
	local text=$1
	echo "$text" >> $log_file
}

today=`date`
Log "$today"

Log "---------------------------------"
Log "      Checking Requirements"
Log "---------------------------------"

#### SET UP DISPLAY DIALOG FUNCTION
DisplayDialog(){
	local dialogText="$1"
	echo "$dialogText"
	#echo "Display Dialog: $dialogText"
	cmd="display dialog \"$dialogText\" buttons {\"Continue\"} default button 1 giving up after 180"
	/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" /usr/bin/osascript -e "$cmd"
}

## verify that adminuser and pass variables are both passed to the user
if [[ -z "$adminUser" ]] || [[ -z "$adminPass" ]] ; then
	DisplayDialog "either Admin User or Password is missing. Please inform Helpdesk."
	exit 1
fi

## check the admin password
adminCheck=$(/usr/bin/dscl /Local/Default -authonly "$adminUser" "$adminPass")
if [[ -z "$adminCheck" ]] ; then
	Log "Admin password is verified"
else
	Log "Admin Password not working"
	exit 1
fi

# If the machine is not bound to AD, then there's no purpose going any further. 
if [ "${check4AD}" != "Active Directory" ]; then
	DisplayDialog "This machine is not bound to Active Directory.\nPlease bind to AD first. "
	exit 1
fi

## Check Filevault Status
fvStatus=$(fdesetup status)
if [[ "$fvStatus" == *"FileVault is On."* ]] ; then
	Log "Verified Filevault Enabled"
else
	jamf policy -trigger $enableFV2JamfTrigger -forceNoRecon
	sleep 5
	DisplayDialog "Filevault Not Yet Enabled. Please Restart the computer to enable Filevault and Try again."
	exit 1
fi


## Prompt for Username
userToAdd=$(/usr/bin/osascript<<END
tell application "System Events"
activate
set the answer to text returned of (display dialog "Enter your CoverMyMeds account Username:" default answer "" buttons {"Continue"} default button 1)
end tell
END
)

if [[ "$userToAdd" == "setup" ]] ; then
	DisplayDialog "Please enter your Username, not the setup user. \nExiting. Install Phase2 again"
	exit 1
fi

## Prompt for Password
userPass=$(/usr/bin/osascript<<END
tell application "System Events"
activate
set the answer to text returned of (display dialog "Enter your CoverMyMeds account Password:" default answer "" with hidden answer buttons {"Continue"} default button 1)
end tell
END
)

Log " "
Log "---------------------------------"
Log "       Adding Account to AD"
Log "---------------------------------"

userCheck=$(dscl . list /Users | grep "$userToAdd")

if [[ -n "$userCheck" ]] ; then
	Log "AD account $userToAdd is already on computer."
	Log " "
fi

loopCount=0
while [ $loopCount -lt 3 ]; do

if [[ -z "$userCheck" ]] ; then

	adCheck=`id $userToAdd`
	Log "AD Check is: $adCheck"
	Log "Blank means that the script may fail."

	sleep 2

	## hit AD create the user
	/System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount -a "$adminUser" -U "$adminPass" -n "$userToAdd" #-p "$userPass"

	sleep 2
else
	Log "$userToAdd is already on this computer."
	break
fi


## check to see if the user account was added
userCheck=$(dscl . list /Users | grep "$userToAdd")
if [[ -z "$userCheck" ]] ; then
	((loopCount++))
else
	break
fi
if [[ $loopCount == 2 ]] ; then
	jamf policy -trigger $rebindJamfTrigger -forceNoRecon
	sleep 5
fi
done

if [[ -z "$userCheck" ]] ; then
	DisplayDialog "AD User failed to add. \nVerify GlobalProtect is Connected. \nRecommend restarting the computer and trying this install again. \nIf issues continue run 'Rebind to Domain' from Self Service and then try install again."
	exit 1
fi

Log " "
Log "---------------------------------"
Log "       Syncing Password from AD"
Log "---------------------------------"
loopCount=0
while [ $loopCount -lt 3 ]; do
	Log " "
	Log "Using Cache Util"
	## this should query AD to cache the user including the password
	dscacheutil -q user -a name "$userToAdd"
	Log "Doing an AD Auth"
	## this will auth the user to AD and should also cache their password locally
	/usr/bin/dscl /Search -authonly "$userToAdd" "$userPass"
	
	passCheck=$(/usr/bin/dscl /Local/Default -authonly "$userToAdd" "$userPass")
	if [[ -z "$passCheck" ]]; then
		Log "Password Authenticated Successfully!"
		break
	else
		Log "Password Authorization failed"
		((loopCount++))
	fi
done

sleep 2
## this kills the menubar so that the fast user switching list refreshses
Log "Refreshing Menubar to update Fast User Switching"
killall -KILL SystemUIServer

## NOW that we've verified the user exists let's add the user to FileVault
Log "Removing User from Filevault"
fdesetup remove -user $userToAdd

# create the plist file:
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Username</key>
<string>'$adminUser'</string>
<key>Password</key>
<string>'$adminPass'</string>
<key>AdditionalUsers</key>
<array>
	<dict>
		<key>Username</key>
		<string>'$userToAdd'</string>
		<key>Password</key>
		<string>'$userPass'</string>
	</dict>
</array>
</dict>
</plist>' > /tmp/fvenable.plist  ### you can place this file anywhere just adjust the fdesetup line below

# now enable FileVault
Log "Re-adding User to Filevault"
fdesetup add -i < /tmp/fvenable.plist

rm -r /tmp/fvenable.plist

fdeList=`fdesetup list | grep $userToAdd`

if [[ "$fdeList" == *"$userToAdd"* ]] ; then
	DisplayDialog "$userToAdd account created.\nPhase 2 of Provisioning is complete.\nPlease select 'setup' in the menu bar by the clock and login as yourself."
	Log " "
	Log " ---------------------------------------"
	Log " "
	Log " "
	exit 0
## Checking password again!
elif [[ ! -z "$passCheck" ]] ; then
	Log "Password Check Authorization failed"
	DisplayDialog "Automated Password Check for $userToAdd failed. \nPlease select 'setup' in the menu bar by the clock and login as yourself. \nIf you are unable to login to your account run Phase 2 again."
	Log " "
	Log " ---------------------------------------"
	Log " "
	Log " "
	exit 0
else
	Log "Filevault add Failed"
	DisplayDialog "Automated $userToAdd account Encryption Failed. \nPlease select 'setup' in the menu bar by the clock and login as yourself."
	Log " "
	Log " ---------------------------------------"
	Log " "
	Log " "
	exit 0
fi
