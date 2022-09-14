#!/bin/bash

##########################################################################################/

# written by Adam Caudill

# Script presented in Userproof Onboarding: Backup Plans for Zero Touch for IT JNUC 2022

# https://github.com/theadamcraig/jamf-scripts/tree/master/JNUC2022

##########################################################################################/

# This script pre-provisions a computer to be used with the InitialConfig workflow
# it will do the following things

# Create a Provisioning.log file on the desktop of the logged in user to log progress
# Names the computer
# Cache InitialConfig Launch agent
# Enables Filevault if not enabled

# Makes sure it's running as the adminName, fails if it's not

# flushes Jamf Policy History

# makes the setup user account as an admin, with filevault access and a secure token and assigns the computer to the setup account in Jamf

# sets the icons for the admin and setup user accounts

# Installs Core Applications

# Runs tests to verify complete

# alerts user if there are errors.

##########################################################################################/

# ITEMS THAT NEED UPDATED IN THIS SCRIPT:

#enableFV2JamfTrigger variable with the correct policy
#proper_name variable for how you want the computer named
#ANTIVIRUS_BINARY is set for SentinelOne, update this (or remove this) accordingly.

# userToAdd = setup account name
# userPass = setup account password
# displayName = setup account DisplayName

# coreAppArray = these apps should be the ones for which you have custom triggers

##########################################################################################/

# SUPPORTING POLICIES THAT NEED CREATED

# jamf policy -event cacheinitialconfig
#     policy that caches the jamf enrollment kickstart package
#     found at https://github.com/Yohan460/JAMF-Enrollment-Kickstart/releases

# jamf policy -event enable_fv
#      policy that enables filevault, you can also change the 
#      enableFV2JamfTrigger to a current policy that enables filevault

# jamf policy -event starthere
# jamf policy -event "${adminName}icon"
#     Policies to set the icons for the setup account and the ${adminName} account
#     example script in github - Set User Icon.sh

## Look through the CORE INSTALLS section of the script and update this for your enviroment
## the triggers in the example are fairly generic

##########################################################################################/
# VARIABLES
##########################################################################################/

enableFV2JamfTrigger="enable_fv"
#Get the SN from the machine
serialNum=$(ioreg -l | awk '/IOPlatformSerialNumber/ { split($0, line, "\""); printf("%s\n", line[4]); }')
proper_name="CompanyName"$serialNum
ANTIVIRUS_BINARY="/Library/Sentinel/sentinel-agent.bundle/Contents/MacOS/sentinelctl"

computer_name="$2"
current_user="$3"
adminName="$4"
adminPass="$5"

userToAdd="setup"
userPass="setup"
displayName="Setup"

# List of Core Applications to verify installed
# Make sure you have an install set up for each of these in the Core Installs section
declare -a coreaAppArray=( "Google Chrome.app" \
	"OneDrive.app" \
	"Microsoft Outlook.app" \
	"Slack.app" \
	"GlobalProtect.app"\
	"Jamf Connect.app" \
	)


##########################################################################################/
## LOG FILE AND LOGGING
##########################################################################################/

# this errorCount variable will be updated by various processes and will trigger a dialog for the provisioner to double check the logs
errorCount=0

log_file=/Users/"$current_user"/Desktop/Provisioning.log

touch "$log_file"

echo "Computer Provisioning Begun" > "$log_file"

Log(){
	local text=$1
	echo "$text" >> "$log_file"
}

today=$(date)
Log "$today"

##########################################################################################/
##########################################################################################/
# ALL OF OUR FUNCTIONS
##########################################################################################/
##########################################################################################/

#### My Basic DISPLAY DIALOG FUNCTION
# I use IBM notifier for this in production, but is is my go to osascript function
DisplayDialog(){
	local dialogText="$1"
	echo "$dialogText"
	Log "Display Dialog: $dialogText"
	cmd="display dialog \"$dialogText\" buttons {\"Continue\"} default button 1 giving up after 180"
	if [[ -z "$loggedInUID" ]] || [[ -z "$loggedInUser" ]] ; then 
		/usr/bin/osascript -e "$cmd"
	else
		/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" /usr/bin/osascript -e "$cmd"
	fi
}

triggerJamfPolicy(){
	local trigger="$1"
	Log "Running Policy: $trigger"
	local output
	# we forceNoRecon on this to save time as there is no point in updating inventory 20 separate times during this script instead of just a few times at strategic moments
	output=$(jamf policy -event "$trigger" -forceNoRecon)
	if [[ "$?" != 0 ]] ; then
		Log " "
		Log "ERROR RUNNING POLICY: $trigger"
		((errorCount++))
	elif [[ "$output" == *"No policies were found" ]] ; then
		Log " "
		Log "ERROR POLICY $trigger NOT FOUND!"
		((errorCount++))
	fi
	Log " "
}

installApplication(){
	local app_name="$1"
	local trigger="$2"
	file_path="/Applications/$app_name"
	if [[ -d $file_path ]] ; then
		Log "$app_name installed."
	else
		Log "$app_name missing."
		triggerJamfPolicy "$trigger"
	fi
}

verifyApplication(){
	local app_name="$1"
	file_path="/Applications/$app_name"
	if [[ -d $file_path ]] ; then
		echo "$app_name installed."
	else
		Log " "
		Log "ERROR: $app_name missing."
		((errorCount++))
		Log " "
	fi
}

userExists(){
	local userToCheck="$1"
	# returns True if the user exists false if the user does not
	local userCheck
	userCheck=$(dscl . list /Users | grep "$userToCheck" | grep -v "_mbsetupuser" )
	if [[ "$userCheck" == "$userToCheck" ]] ; then
		local exists="true"
	else
		local exists="false"
	fi
	echo "$exists"
}

userIsAdmin(){
	local userToCheck="$1"
	if [[ $("/usr/sbin/dseditgroup" -o checkmember -m "$userToCheck" admin / 2>&1) =~ "yes" ]]; then
		local admin="true"
	else
		local admin="false"
	fi
	echo "$admin"
}

passwordCorrect() {
	#returns true if the user password is correct false if it is not
	local userName="${1}"
	local passWord="${2}"
	local passCheck
	passCheck=$(/usr/bin/dscl /Local/Default -authonly "$userName" "$passWord")
	if [[ -z "$passCheck" ]]; then
		local correct="true"
	else
		local correct="false"
	fi
	echo "$correct"
}

fileVaultUserAccess() {
	# returns true if the user has filevault access. false if they do not
	local userToCheck="$1"
	if [[ $(fdesetup list | grep "$userToCheck") == *"$userToCheck"* ]] ; then
		local fvAccess="true"
	else
		local fvAccess="false"
	fi
	echo "$fvAccess"
}

secureTokenUserCheck() {
	# returns true if the user has a secure token, false if they do not.
	local userToCheck="$1"
	if [[ $("/usr/sbin/sysadminctl" -secureTokenStatus "$userToCheck" 2>&1) =~ "ENABLED" ]] ; then
		local userToken="true"
	else
		local userToken="false"
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
	tokenAdded=$(secureTokenUserCheck "$addUser")
	echo "Token Added to $addUser : $tokenAdded"
	diskutil apfs listcryptousers /
}

createUserAccount() {
	local userShortName="${1}"
	local userFullName="${2}"
	local userPassword="${3}"
	local adminUserName="${4}"
	local adminUserPass="${5}"
	echo " "
	echo "Creating account using Jamf. to create home folder and suppress setup account."
	jamf createAccount -username "$userShortName" -realname "$userFullName" -password "$userPassword" -admin -suppressSetupAssistant
	sleep 1
	echo " "
	userUID=$(id -u "$userShortName")
	echo "getting accounts UID: $userUID"
	# the -keepHome option is not working
	# sysadminctl -deleteUser "$userToAdd" -keepHome -adminUser "$adminName" -adminPassword "$adminPass"
	echo " "
	echo "deleting account using dscl, which should leave home folder in place"
	dscl . delete "/Users/$userShortName"
	sleep 1	
	echo " "
	echo "re-creating account using sysadminctl to make sure that filevault recovery mode access exists."
	sysadminctl -addUser "$userShortName" -fullName "$userFullName" -password "$userPassword" -adminUser "$adminUserName" -adminPassword "$adminUserPass" -home "/Users/$userShortName" -UID "$userUID" -admin
	sleep 1
	echo " "
	echo "Correcting owner of homefolder"
	chown -R "$userShortName" "/Users/$userShortName"
	echo " "
}

addUserToFilevault() {
	local fvUser="${1}"
	local fvPass="${2}"
	local addUser="${3}"
	local addPass="${4}"
	local remove="${5:-false}"
	if [[ "$remove" == "true" ]] ; then
		fdesetup remove -user "$addUser"
	fi
#create the plist file:
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Username</key>
<string>'$fvUser'</string>
<key>Password</key>
<string>'$fvPass'</string>
<key>AdditionalUsers</key>
<array>
	<dict>
		<key>Username</key>
		<string>'$addUser'</string>
		<key>Password</key>
		<string>'$addPass'</string>
	</dict>
</array>
</dict>
</plist>' > /tmp/fvenable.plist  ### you can place this file anywhere just adjust the fdesetup line below

	# now enable FileVault
	fdesetup add -i < /tmp/fvenable.plist

	rm -r /tmp/fvenable.plist
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
			((errorCount++))
		fi
	fi
}

Log " "
Log " ---------------------------------------"
Log "		Naming the computer"
Log " ---------------------------------------"

Log "$serialNum"
Log "Computer name currently set to $computer_name"

if [[ "$computer_name" != "$proper_name" ]] ; then
	#Set the computer name
	jamf setcomputername -name "$proper_name"
	computer_name="$proper_name"
	Log "setting computer name from $computer_name to $proper_name"
else
	echo "computer name properly formatted"
fi
Log "Check that computer_name $computer_name and proper_name $proper_name match."
Log " "

Log " "
Log " ---------------------------------------"
Log "		Caching INITIAL CONFIG launch agent"
Log " ---------------------------------------"

Log "this will allow access to the needed policies"

Log "Caching JAMFInitialConfig Launch Agent."
triggerJamfPolicy cacheinitialconfig
Log " "

Log " "
Log " ---------------------------------------"
Log "	  Prepping for user account "
Log " ---------------------------------------"

## verify that adminName and pass variables are both passed to the user
if [[ -z "$adminName" ]] || [[ -z "$adminPass" ]] ; then
	DisplayDialog "either Admin User or Password is missing. Please inform Helpdesk."
	exit 1
fi

## check the admin password
adminCheck=$(passwordCorrect "$adminName" "$adminPass")
if [[ "$adminCheck" == "true" ]] ; then
	Log "Admin password is verified"
else
	Log "Admin Password not working"
	DisplayDialog "Admin Password not working"
	exit 1
fi

## Check Filevault Status
fvStatus=$(fdesetup status)
if [[ "$fvStatus" == *"FileVault is On."* ]] ; then
	Log "Verified Filevault Enabled"
else
	triggerJamfPolicy $enableFV2JamfTrigger
	sleep 5
	DisplayDialog "Filevault Not Yet Enabled. Please Restart the computer to enable Filevault and Try again."
	exit 1
fi

Log "Check that current_user is $adminName"
if [[ "${adminName}" == "${current_user}" ]] ; then
	Log "all good!"
	Log ""
else
	DisplayDialog "$current_user is not $adminName."
	exit 1
fi

Log "Flushing Jamf Policy History Logs."
jamf flushPolicyHistory

Log " "
Log " ---------------------------------------"
Log "		Creating User account with Filevault and Secure Token"
Log " ---------------------------------------"

userToAddExists=$(userExists "$userToAdd" )
userToAddIsAdmin=$(userIsAdmin "$userToAdd" )
userPassCorrect=$(passwordCorrect "$userToAdd" "$userPass")
userToAddFV=$(fileVaultUserAccess "$userToAdd" )
userToAddToken=$(secureTokenUserCheck "$userToAdd" )

Log " "
Log "$userToAdd account checks:"
Log "exists: $userToAddExists"
Log "admin: $userToAddIsAdmin"
Log "passCorrect: $userPassCorrect"
Log "filevault: $userToAddFV"
Log "secureToken: $userToAddToken"

## FIX userToAdd NOT EXIST
if [[ "$userToAddExists" == "false" ]] ; then
	Log "$userToAdd does not exist. Creating account"
	createUserAccount "$userToAdd" "$displayName" "$userPass" "$adminName" "$adminPass"
# 	userShortName="${1}"
# 	userFullName="${2}"
# 	userPassword="${3}"
# 	adminUserName="${4}"
# 	adminUserPass="${5}"
	# update other checks
	userToAddExists=$(userExists "$userToAdd" )
	userToAddIsAdmin=$(userIsAdmin "$userToAdd" )
	userPassCorrect=$(passwordCorrect "$userToAdd" "$userPass")
	userToAddFV=$(fileVaultUserAccess "$userToAdd" )
	userToAddToken=$(secureTokenUserCheck "$userToAdd" )
	if [[ "$userToAddExists" == "false" ]] ; then 
		DisplayDialog "$userToAdd failed to create"
		exit 1
	fi
	echo " "
	echo " "
fi

## FIX userToAdd IS ADMIN
if [[ "$userToAddIsAdmin" == "false" ]] ; then
	Log "$userToAdd is not an admin. promoting account"
	/usr/sbin/dseditgroup -o edit -n /Local/Default -a "$userToAdd" -t "user" "admin"
	sleep 1
	userToAddIsAdmin=$(userIsAdmin "$userToAdd" )
	userPassCorrect=$(passwordCorrect "$userToAdd" "$userPass")
	userToAddFV=$(fileVaultUserAccess "$userToAdd" )
	userToAddToken=$(secureTokenUserCheck "$userToAdd" )
	if [[ "$userToAddIsAdmin" == "false" ]] ; then 
		Log "$userToAdd failed to promote"
	fi
fi

## FIX userToAdd INCORRECT PASSWORD
if [[ "$userPassCorrect" == "false" ]] ; then
	Log "$userToAdd password is incorrect. changing password"
	/usr/sbin/sysadminctl -adminUser "$adminName" -adminPassword "$adminPass" -resetPasswordFor "$userToAdd" -newPassword "$userPass"
	sleep 1
	userPassCorrect=$(passwordCorrect "$userToAdd" "$userPass")
	userToAddFV=$(fileVaultUserAccess "$userToAdd" )
	userToAddToken=$(secureTokenUserCheck "$userToAdd" )
	if [[ "$userPassCorrect" == "false" ]] ; then 
		Log "$userToAdd failed to update password"
	fi
fi

if [[ "$userToAddFV" == "false" ]] ; then
	Log "$userToAdd failed FV access"
	addUserToFilevault "$adminName" "$adminPass" "$userToAdd" "$userPass"
	sleep 1
	userToAddFV=$(fileVaultUserAccess "$userToAdd" )
	userToAddToken=$(secureTokenUserCheck "$userToAdd" )
	if [[ "$userToAddFV" == "false" ]] ; then 
		Log "$userToAdd failed to update filevault"
	fi
fi

if [[ "$userToAddToken" == false ]] ; then
	Log "$userToAdd missing secure token, adding"
	addSecureToken "$adminName" "$adminPass" "$userToAdd" "$userPass"
	sleep 1
	userToAddToken=$(secureTokenUserCheck "$userToAdd" )
	if [[ "$userToAddToken" == "false" ]] ; then 
		Log "$userToAdd failed to update secure token"
	fi
fi

Log " "
Log "Final User Checks:"
Log "exists: $userToAddExists"
Log "admin: $userToAddIsAdmin"
Log "passCorrect: $userPassCorrect"
Log "filevault: $userToAddFV"
Log "secureToken: $userToAddToken"
Log " "
Log " "

if [[ "$userToAddExists" == "true" ]] && [[ "$userToAddIsAdmin" == "true" ]] && [[ "$userPassCorrect" == "true" ]] && [[ "$userToAddFV" == "true" ]] && [[ "$userToAddToken" == "true" ]] ; then 
	Log "$userToAdd access complete"
else
	DisplayDialog "$userToAdd access is incomplete. please review Log"
fi

Log "assigning computer to $userToAdd in jamf"
jamf recon -endUsername "$userToAdd"

Log "setting user icon to a Start Here"
jamf policy -event starthere

Log "Setting admin icon"
trigger="${adminName}icon"
jamf policy -event "${trigger}"

fileVaultUserCheck "$userToAdd"

Log " ---------------------------------------"
Log "		Beginning Core Installs"
Log " ---------------------------------------"

# The installApplication function will check in /Applications for a for an app_name if the app is not found it will run the triggerJamfPolicy to install it
# it should be run with the formatting

# installApplication "Application Name.app" "customtrigger"

# If you are running a policy that does not install an application then you should just use triggerJamfPolicy with the formatting
# triggerJamfPolicy "customtrigger"

Log " "
installApplication "Jamf Connect.app" "jamfconnect"

Log " "
installApplication "Google Chrome.app" "googlechrome"

# we use this process to set the default bookmarks https://support.google.com/chrome/a/answer/187948?hl=en
triggerJamfPolicy "chrome-default-bookmarks"

Log " "
installApplication "Microsoft Outlook.app" "microsoftoffice"
# we use Outlook as a check for if the whole office suite is installed.

Log " "
installApplication "Slack.app" "slack"

## for our VPN we check if the app is installed and then install the settings first and then the app
## the settings and app are on separate triggers, that's what's worked best for us on our GP setup.
installApplication "GlobalProtect.app" "vpnSettings"

installApplication "GlobalProtect.app" "globalprotect"

Log " "
# As an example of how you can do a check for things like anti-virus that may not be installed in the applications folder
if [[ -f ${ANTIVIRUS_BINARY} ]]; then
	Log "Sentinel 1 Already installed"
else
	triggerJamfPolicy sentinelone 
fi

Log "enabling location services - Will not be effective until after reboot"
triggerJamfPolicy "enable_location_services"

# we install a rescue account using the following process
# https://github.com/theadamcraig/jamf-scripts/tree/master/rescue_account
# Uncomment the lines below if you use a rescue account

# userCheck=$(id -u "rescue")
# if [[ "$userCheck" == *"no such user"* ]] || [[ -z "$userCheck" ]] ; then
# 	Log "rescue account not installed"
# 	Log "Creating Rescue account"
# 	triggerJamfPolicy rescueaccount
# else
# 	Log "rescue account already installed"
# fi

echo " "
Log "Running other Policies"
jamf recon
jamf manage
jamf policy
# this policy may change things in inventory that scope this computer into new policies
jamf policy -forceNoRecon

Log " "
Log " "
Log " ---------------------------------------"
Log "		SETUP TEST RESULTS"
Log " ---------------------------------------"
#### TESTS TO MAKE SURE ALL IS WELL
Log " "

## Check Core applications
for appName in "${coreaAppArray[@]}"; do
	verifyApplication "${appName}"
done


if [[ ! -f ${ANTIVIRUS_BINARY} ]]; then
	Log " "
	Log "ERROR: SentinelOne is Missing"
	((errorCount++))
	Log " "
fi

# let's make sure the JamfConnect auth changer is installed
if [[ -e "/Applications/Jamf Connect.app" ]] ; then 
	sudo authchanger -reset -JamfConnect
else
	DisplayDialog "Jamf connect did not load correctly. Please rectify"
	((errorCount++))
	Log "ERROR: Jamf Connect did not load correctly!"
fi

Log " "
Log "Filevault Check for user: $userToAdd"

userCheck=$(dscl . list /Users | grep "$userToAdd")
if [[ -z "$userCheck" ]] ; then
	Log "ERROR: $userToAdd does not exist"
	((errorCount++))
else
	fdeList=$(fdesetup list | grep "$userToAdd")
	echo "checking Filevault list $fdeList for $userToAdd"
	if [[ "$fdeList" == *"$userToAdd"* ]] ; then
		Log "FV2 Check for $userToAdd passed."
		diskutil apfs updatePreboot / >> /dev/null 2>&1 
	else
		Log "ERROR $userToAdd not Filevault Enabled. Rectify this BEFORE you restart!"
		((errorCount++))
		DisplayDialog "$userToAdd not Filevault Enabled. Rectify this BEFORE you restart!"
	fi
fi

## This still worked on the Ventura Beta i tested on, but this may break with future versions of Ventura
open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane

Log " "
Log " "

if [[ $errorCount == 0 ]] ; then
	DisplayDialog "Provisioning Complete. Please check the Provisioning.log on the desktop for details. Run Software updates. Then Restart and make sure the $userToAdd has filevault access."
else
	DisplayDialog "${errorCount} ERRORS! Check Provisioning.log on the desktop for details. Once errors are resolved run all Software Updates, and Restart to make sure $userToAdd has filevault access"
fi

Log " ---------------------------------------"
Log "		PROVISION SCRIPT COMPLETE"
Log " ---------------------------------------"

exit "$errorCount"