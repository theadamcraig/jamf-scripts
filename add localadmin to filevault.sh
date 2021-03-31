#! /bin/bash

## Written by adamcraig https://github.com/theadamcraig/jamf-scripts
# updated 3/31/2021
# added Display Dialog function to streamline code
# added secure token functionality.
#
# referenced this article for some of the commands
#https://www.jamf.com/jamf-nation/discussions/26608/adding-user-to-filevault-using-fdesetup-and-recovery-key

## this script will prompt the user for their password and then re-add the Local Admin account to FV2

## this expects there to be a jamf policy with the trigger "install$adminName" that will be triggered if the admin account does not exist.
## also expects a trigger to enable filevault if it is not enabled.

adminName=$4
adminPass=$5
enableFV2JamfTrigger="catalina_fv"

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] ; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi
loggedInUID=$(id -u "$loggedInUser")


if [[ -z "$adminName" ]] || [[ -z "$adminPass" ]] ; then
	echo "adminName or adminPass variables are missing"
	exit 1
fi

adminCheck=$(id -u "$adminName")
if [[ "$adminCheck" == *"no such user"* ]] || [[ -z "$adminCheck" ]] ; then
	echo "admin user not installed"
	jamf policy -trigger "install${adminName}"
	sleep 5
fi

adminCheck=$(id -u "$adminName")

#### SET UP DISPLAY DIALOG FUNCTION
DisplayDialog(){
	local dialogText="$1"
	echo "$dialogText"
	cmd="display dialog \"$dialogText\""
	/usr/bin/osascript -e "$cmd"
}

if [[ "$adminCheck" == *"no such user"* ]] || [[ -z "$adminCheck" ]] ; then
	echo "admin user still not installed"
	DisplayDialog "$adminName not installed. Exiting"
	exit 1
fi

## Check Filevault Status
fvStatus=$(fdesetup status)
if [[ "$fvStatus" == *"FileVault is On."* ]] ; then
	echo "Verified Filevault Enabled"
else
	jamf policy -trigger $enableFV2JamfTrigger -forceNoRecon
	sleep 5
	DisplayDialog "Filevault Not Yet Enabled. Please Restart the computer to enable Filevault and Try again."
	exit 1
fi

secureTokenUserCheck() {
	local userToCheck="$1"
	if [[ $("/usr/sbin/sysadminctl" -secureTokenStatus "$userToCheck" 2>&1) =~ "ENABLED" ]]; then
		userToken="true"
	else
		userToken="false"
	fi
	echo "$userToken"
}

addSecureToken() {
	local tokenUser="$1"
	local tokenUserPass="$2"
	local addUser="$3"
	local addUserPass="$4"
	echo "adding token to $addUser with credentials from $tokenUser"
	sysadminctl -adminUser "$tokenUser" -adminPassword "$tokenUserPass" -secureTokenOn "$addUser" -password "$addUserPass"
	tokenAdded=$(secureTokenUserCheck "$tokenUser")
	echo "Token Added to $tokenUser : $tokenAdded"
	diskutil apfs listcryptousers /
}

fileVaultUserCheck() {
	userToCheck="$1"
	# this checks to see if the user exists
	userCheck=$(dscl . list /Users | grep "$userToCheck")
	if [[ -z "$userCheck" ]] ; then
		echo "$userToCheck does not exist"
	else
		fdeList=$(fdesetup list | grep "$userToCheck")
		echo "checking Filevault list $fdeList for $userToCheck"
		if [[ "$fdeList" == *"$userToCheck"* ]] ; then
			echo "FV2 Check for $userToCheck passed. Continuing"
		else
			DisplayDialog "$userToCheck not Filevault Enabled. Rectify this BEFORE you restart!"
		fi
	fi
}

### CHECK SECURE TOKEN STATUS:
if [[ $("/usr/sbin/diskutil" apfs listcryptousers / 2>&1) =~ "No cryptographic users" ]]; then
	tokenStatus="false"
else
	tokenStatus="true"	
fi
echo "Token Status $tokenStatus"

########### MANAGE SECURE TOKENS
echo " "
echo "checking secure tokens"
adminToken=$(secureTokenUserCheck "$adminName")
userToken=$(secureTokenUserCheck "$loggedInUser")

if [[ "$tokenStatus" == "false" ]] ; then
	echo "No Secure Tokens, adding admin and logged in user to secure token"
	addSecureToken "$adminName" "$adminPass" "$loggedInUser" "$userPass"
	adminToken=$(secureTokenUserCheck "$adminName")
	userToken=$(secureTokenUserCheck "$loggedInUser")
fi

echo "prompting user for Account Password"
userPass=$(/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" /usr/bin/osascript<<END
text returned of (display dialog "Enter $loggedInUser's Current Account Password:" default answer "" with hidden answer buttons {"Continue"} default button 1 giving up after 80 )
END
)
passCheck=$(/usr/bin/dscl /Local/Default -authonly "$loggedInUser" "$userPass")
if [[ -z "$passCheck" ]]; then
	echo "Continue"
else
	echo "Authorization failed"
	exit 1
fi


########### MANAGE SECURE TOKENS
echo " "
echo "checking secure tokens"

if [[ "$tokenStatus" == "false" ]] ; then
	echo "No Secure Tokens, adding admin and logged in user to secure token"
	addSecureToken "$adminName" "$adminPass" "$loggedInUser" "$userPass"
fi
adminToken=$(secureTokenUserCheck "$adminName")
userToken=$(secureTokenUserCheck "$loggedInUser")

### CHECK SECURE TOKEN STATUS:
if [[ $("/usr/sbin/diskutil" apfs listcryptousers / 2>&1) =~ "No cryptographic users" ]]; then
	tokenStatus="false"
	echo "Secure token still not enabled. This should never happen. Failing"
	exit 1
else
	tokenStatus="true"	
fi
## setting this variable to false so it exists later
demoteUser="false"
if [[ "$adminToken" = "true" ]] ; then
	tokenUser="$adminName"
	tokenPass="$adminPass"
	echo "admin user has a token, setting as $tokenUser"
elif [[ "$userToken" = "true" ]] ; then
	tokenUser="$loggedInUser"
	tokenPass="$userPass"
	echo "logged in user is only one with a token, this is bad. But will be attempted to be fixed automatically right now."
	### Make sure this user is an Admin
	if [[ $("/usr/sbin/dseditgroup" -o checkmember -m "$loggedInUser" admin / 2>&1) =~ "yes" ]]; then
		echo "$loggedInUser is an admin"
	else
		echo "$loggedInUser is not an admin"
		demoteUser="true"
		##Promoting user to admin
		echo "promoting user to admin"
		dscl . -append /groups/admin GroupMembership "$loggedInUser"
	fi
	addSecureToken "$loggedInUser" "$userPass" "$adminName" "$adminPass"
	## remove admin if it was added
	if [[ "$demoteUser" = "true" ]] ; then
		echo "demoting User from admin"
		dscl . -delete /groups/admin GroupMembership "$loggedInUser"
	fi
	adminToken=$(secureTokenUserCheck "$adminName")
	if [[ "$adminToken" = "false" ]] ; then
		echo "adding admin user failed"
		exit 1
	else
		tokenUser="$adminName"
		tokenPass="$adminPass"
	fi
fi

adminToken=$(secureTokenUserCheck "$adminName")
userToken=$(secureTokenUserCheck "$loggedInUser")

if [[ "$adminToken" = "false" ]] ; then
	addSecureToken "$tokenUser" "$tokenPass" "$adminName" "$adminPass"
fi
if [[ "$userToken" = "false" ]] ; then
	addSecureToken "$tokenUser" "$tokenPass" "$loggedInUser" "$userPass"
fi

fdesetup remove -user "$adminName"
# 
# expect -c "
# spawn fdesetup add -usertoadd $adminName
# expect \"Enter the primary user name:\"
# send ${loggedInUser}\r
# expect \"Enter the password for the user '$loggedInUser':\"
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
<string>'$loggedInUser'</string>
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

## assign secure tokens
adminToken=$(secureTokenUserCheck "$adminName")

if [[ "$adminToken" = "false" ]] ; then
	addSecureToken "$loggedInUser" "$userPass" "$adminName" "$adminPass"
fi

fileVaultUserCheck "$adminName"

# Make sure there is a secure token for the admin user.
# Give local admin user secure token using admin user credentials established as part of Setup Assistant 
/usr/sbin/sysadminctl -adminUser "$loggedInUser" -adminPassword "$userPass" -secureTokenOn "$adminName" -password "$adminPass"
exitresult=$(/bin/echo $?)

if [ "$exitresult" = 0 ]; then
    /bin/echo "Successfully added secure Token to ${adminName}!"    
else
    /bin/echo "Failed to add secure Token to ${adminName}."
fi

diskutil apfs updatePreboot / >> /dev/null 2>&1 

exit "$exitresult"