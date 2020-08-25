#! /bin/bash

## Written by adamcraig https://github.com/theadamcraig/jamf-scripts
#
# referenced this article for some of the commands
#https://www.jamf.com/jamf-nation/discussions/26608/adding-user-to-filevault-using-fdesetup-and-recovery-key

## this script will prompt the user for their password and then re-add the Local Admin account to FV2

adminName=$4
adminPass=$5
userName=$( scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )

##THIS RUNS A JAMF TRIGGER TO INSTALL YOUR LOCAL ADMIN ACCOUNT IF IT IS NOT THERE.
adminCheck=$(id -u "$adminName")
if [[ "$adminCheck" == *"no such user"* ]] || [[ -z "$adminCheck" ]] ; then
	echo "admin user not installed"
	jamf policy -trigger installadmin
	sleep 5
fi

adminCheck=$(id -u "$adminName")

if [[ "$adminCheck" == *"no such user"* ]] || [[ -z "$adminCheck" ]] ; then
	echo "admin user still not installed"
	dialog="$adminName not installed. Exiting"
	cmd="Tell app \"System Events\" to display dialog \"$dialog\""
	/usr/bin/osascript -e "$cmd"
	exit 1
fi

fileVaultUserCheck() {
	userToCheck="$1"
	fdeList=`fdesetup list | grep $userToCheck`
	echo "checking Filevault list $fdeLIst for $userToCheck"
	if [[ "$fdeList" == *"$userToCheck"* ]] ; then
		echo "FV2 Check for $userToCheck passed. Continuing"
	else
		dialog="$userToCheck not Filevault Enabled. Rectify this BEFORE you restart!"
		echo "$dialog"
		cmd="Tell app \"System Events\" to display dialog \"$dialog\""
		/usr/bin/osascript -e "$cmd"
	fi

}

echo "prompting user for Account Password"
userPass=$(/usr/bin/osascript<<END
tell application "System Events"
activate
set the answer to text returned of (display dialog "Enter $userName's Current Account Password:" default answer "" with hidden answer buttons {"Continue"} default button 1)
end tell
END
)
passCheck=$(/usr/bin/dscl /Local/Default -authonly "$userName" "$userPass")
if [[ -z "$passCheck" ]]; then
	echo "Continue"
else
	echo "Authorization failed"
	dialog="Password Check for $userName failed. Exiting."
	cmd="Tell app \"System Events\" to display dialog \"$dialog\""
	/usr/bin/osascript -e "$cmd"
	exit 1
fi

fdesetup remove -user "$adminName"
# 
# expect -c "
# spawn fdesetup add -usertoadd $adminName
# expect \"Enter the primary user name:\"
# send ${userName}\r
# expect \"Enter the password for the user '$userName':\"
# send ${userPass}\r
# expect \"Enter the password for the added user '$adminName':\"
# send ${adminPass}\r
# expect" 

## The above section errorred out due to special characters in a users password. 
## found the below solution at: 
## https://www.jamf.com/jamf-nation/discussions/20809/add-local-admin-to-filevault-via-script#responseChild125971

# create the plist file:
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Username</key>
<string>'$userName'</string>
<key>Password</key>
<string>'$userPass'</string>
<key>AdditionalUsers</key>
<array>
	<dict>
		<key>Username</key>
		<string>'$adminName'</string>
		<key>Password</key>
		<string>'$adminPass'</string>
	</dict>
</array>
</dict>
</plist>' > /tmp/fvenable.plist  ### you can place this file anywhere just adjust the fdesetup line below

# now enable FileVault
fdesetup add -i < /tmp/fvenable.plist

rm -r /tmp/fvenable.plist

fileVaultUserCheck "adminName"

# Make sure there is a secure token for the admin user.
# Give local admin user secure token using admin user credentials established as part of Setup Assistant 
/usr/sbin/sysadminctl -adminUser "$userName" -adminPassword "$userPass" -secureTokenOn "$adminName" -password "$adminPass"
exitresult=$(/bin/echo $?)

if [ "$exitresult" = 0 ]; then
    /bin/echo "Successfully added secure Token to ${adminName}!"    
else
    /bin/echo "Failed to add secure Token to ${adminName}."
fi

diskutil apfs updatePreboot /


exit 0
