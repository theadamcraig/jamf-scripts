#!/bin/bash

#################################################
# RESCUE ACCOUNT SETUP
#################################################

## https://github.com/theadamcraig/jamf-scripts/

## VARIABLES THAT NEED UPDATED
## Passphrase variables
## Pass location variable
## JSS URL

## updated 2/24/2021 by theadamcraig
## No longer uses python
## heavily reworked by theadamcraig 3/25/2021
## this creates the local account now so the account creation portion of the jamf policy is no longer necessary
## Initially based on script found at https://github.com/therealmacjeezy/Scripts/blob/master/LAPS%20for%20Mac/LAPSforMac.sh

########### Parameters (Required) ###############
# 4 - API Username String
# 5 - API Password String
# 6 - Rescue Admin Username
# 7 - Local Admin Username
# 8 - Local Admin Password

passLocation="/Library/Application Support/YOURCOMPANY/rescue"
#get the filepath
pathLocation=$(dirname "$passLocation")
#make sure the filepath exists
mkdir -p "$pathLocation"
# locate the password change script
passwordScript="$pathLocation/passphrase/pass_phrase.sh"
# This is the new shell script version of the pass_phrase.py script.

## if the pass_phrase.sh passwordScript doesn't exist then install it
if [[ ! -e "$passwordScript" ]] ; then
	jamf policy -trigger installpassphrase
fi
sleep 5

# HARDCODED VALUES
jssURL="https://yourdomain.jamfcloud.com"
udid=$(/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/awk '/Hardware UUID:/ { print $3 }')
## extAttName also needs to be changed in the curl command in setEAStatus function.
extAttName="\"RescuePassword\""

## If the passphrase script exists get the passphrase from there. Else do a random passphrase
if [[ -e "$passwordScript" ]] ; then
	cd "$pathLocation/passphrase" || exit
	echo "Password Script installed."
	newPass=$(sh "$passwordScript" --min 3 --max 6)
	echo "$newPass" > "$passLocation"
	rescuePass=$(cat "$passLocation")	
else
	echo "Password script missing."
	newPass=$(env LC_CTYPE=C tr -dc "A-HJ-KM-Za-hj-km-z0-9" < /dev/urandom | head -c 24 > "$passLocation")
	rescuePass=$(cat "$passLocation")
fi

if [[ -z "$rescuePass" ]] ; then
	echo "failed to get password"
	exit 1
fi

# Decrypt String
DecryptString() {
	# Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
	echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}

#####################################################
## VERIFY WE HAVE ALL THE VARIABLES THAT WE NEED
#####################################################

# Account Information
if [[ -z "$4" ]]; then 
    echo "Error: API USER MISSING"
    exit 1
else
	apiUser="$4"        
fi

if [[ -z "$5" ]]; then
	echo "Error: API PASS MISSING"
    exit 1        
else
	apiPass="$5"
fi

if [[ -z "$6" ]]; then
    echo "ERROR: RESCUE USERNAME NAME MISSING"
    exit 1
else
    rescueUser="$6"
fi

if [[ -z "$7" ]];then
	echo "ERROR: LOCAL ADMIN USERNAME MISSING"
	exit 1
else
	adminName="$7"
fi
if [[ -z "$8" ]];then
	echo "ERROR: LOCAL ADMIN PASSWORD MISSING"
	exit 1
else
	adminPass="$8"
fi

## Request Auth Token
authToken=$( /usr/bin/curl \
--request POST \
--silent \
--url "$jssURL/api/v1/auth/token" \
--user "$apiUser:$apiPass" )

echo "$authToken"

# parse auth token
token=$( /usr/bin/plutil \
-extract token raw - <<< "$authToken" )

tokenExpiration=$( /usr/bin/plutil \
-extract expires raw - <<< "$authToken" )

localTokenExpirationEpoch=$( TZ=GMT /bin/date -j \
-f "%Y-%m-%dT%T" "$tokenExpiration" \
+"%s" 2> /dev/null )

echo Token: "$token"
echo Expiration: "$tokenExpiration"
echo Expiration epoch: "$localTokenExpirationEpoch"


#####################################################
#####################################################
## Functions that the script will use
#####################################################
#####################################################

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

userIsAdmin(){
	local userToCheck="$1"
	if [[ $("/usr/sbin/dseditgroup" -o checkmember -m "$userToCheck" admin / 2>&1) =~ "yes" ]]; then
		local admin="true"
	else
		local admin="false"
	fi
	echo "$admin"
}

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
	tokenAdded=$(secureTokenUserCheck "$addUser")
	echo "Token Added to $addUser : $tokenAdded"
	diskutil apfs listcryptousers /
}

setEAStatus() {

	echo "setting EA status"

	apiData="<computer><extension_attributes><extension_attribute><name>RescuePassword</name><type>String</type><input_type><type>Text Field</type></input_type><value>${rescuePass}</value></extension_attribute></extension_attributes></computer>"
	echo "${apiData}"

	fullURL="$jssURL/JSSResource/computers/udid/$udid/subset/extension_attributes"
	echo "${fullURL}"

	# apiPost=$(curl -s -f -u "$apiUser":"$apiPass" -X "PUT" "${fullURL}" -H "Content-Type: application/xml" -H "Accept: application/xml" -d "${apiData}" 2>&1 )

    apiPost=$( /usr/bin/curl \
    --header "Content-Type: text/xml" \
    --request PUT \
    --data "$apiData" \
    --silent \
    --url "$fullURL" \
    --header "Authorization: Bearer $token" \
    2>&1 \
    )

	/bin/echo "${apiPost}"

}

uploadCheck() {
	echo "Checking Password"
	# checkPass=$(curl -s -f -u "$apiUser":"$apiPass" -H "Accept: application/xml" $jssURL/JSSResource/computers/udid/"$udid"/subset/extension_attributes | xpath "//extension_attribute[name=$extAttName]" 2>&1 | awk -F'<value>|</value>' '{print $2}')
    checkPass=$( /usr/bin/curl \
    --header "Accept: text/xml" \
    --request GET \
    --silent \
    --url "$jssURL/JSSResource/computers/udid/${udid}/subset/extension_attributes" \
    --header "Authorization: Bearer $token" | xpath "//extension_attribute[name=$extAttName]" 2>&1 | awk -F'<value>|</value>' '{print $2}' )
	checkPass=$(echo "$checkPass" | tr -d '\040\011\012\015')
	echo "$checkPass"
	echo "rescuePass"
	echo "$rescuePass"

	if [[ "$checkPass" == "$rescuePass" ]] ; then
		echo "password uploaded successfully"
		rm -f "$passLocation"
	else
		echo "password failed to upload to jamf"
		echo "trying again"
		setEAStatus
	fi
}

createUserAccount() {
	local userShortName="${1}"
	local userFullName="${2}"
	local userPassword="${3}"
	local adminUserName="${4}"
	local adminUserPass="${5}"
	echo " "
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
	echo "re-creating account using sysadminctl to make sure that filevault recovery mode access exists, and account has the same UID."
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

expireApiToken() {

	# expire auth token
	/usr/bin/curl \
	--header "Authorization: Bearer $token" \
	--request POST \
	--silent \
	--url "$jssURL/api/v1/auth/invalidate-token"

	# verify auth token is valid
	checkToken=$( /usr/bin/curl \
	--header "Authorization: Bearer $token" \
	--silent \
	--url "$jssURL/api/v1/auth" \
	--write-out "%{http_code}" )

	tokenStatus=${checkToken: -3}
	# Token status should be 401
	echo "Token status: $tokenStatus"
	}

#############################################
#############################################
##DO THE THINGS
#############################################
#############################################

rescueExists=$(userExists "$rescueUser" )
rescueIsAdmin=$(userIsAdmin "$rescueUser" )
rescuePassCorrect=$(passwordCorrect "$rescueUser" "$rescuePass")
rescueFV=$(fileVaultUserAccess "$rescueUser" )
rescueToken=$(secureTokenUserCheck "$rescueUser" )

echo " "
echo "Rescue account checks:"
echo "exists: $rescueExists"
echo "admin: $rescueIsAdmin (we want this to be false)"
echo "passCorrect: $rescuePassCorrect"
echo "filevault: $rescueFV"
echo "secureToken: $rescueToken"
echo " "
echo " "

## FIX rescue NOT EXIST
if [[ "$rescueExists" == "false" ]] ; then
	echo "$rescueUser does not exist. Creating account"
	
	createUserAccount "$rescueUser" "$rescueUser" "$rescuePass" "$adminName" "$adminPass"
# 	userShortName="${1}"
# 	userFullName="${2}"
# 	userPassword="${3}"
# 	adminUserName="${4}"
# 	adminUserPass="${5}"
	echo "adding $rescueUser icon"
	jamf recon
	sleep 1
	jamf policy -trigger "${rescueUser}icon"
	# update other checks
	rescueExists=$(userExists "$rescueUser" )
	rescueIsAdmin=$(userIsAdmin "$rescueUser" )
	rescuePassCorrect=$(passwordCorrect "$rescueUser" "$rescuePass")
	rescueFV=$(fileVaultUserAccess "$rescueUser" )
	rescueToken=$(secureTokenUserCheck "$rescueUser" )
	if [[ "$rescueExists" == "false" ]] ; then 
		echo "$rescueUser failed to create"
		exit 1
	fi
fi

## FIX rescue IS ADMIN
if [[ "$rescueIsAdmin" == "true" ]] ; then
	echo "$rescueUser is an admin. Demoting account"
	/usr/sbin/dseditgroup -o edit -n /Local/Default -d "$rescueUser" -t "user" "admin"
	sleep 1
	rescueIsAdmin=$(userIsAdmin "$rescueUser" )
	rescuePassCorrect=$(passwordCorrect "$rescueUser" "$rescuePass")
	rescueFV=$(fileVaultUserAccess "$rescueUser" )
	rescueToken=$(secureTokenUserCheck "$rescueUser" )
	if [[ "$rescueIsAdmin" == "true" ]] ; then 
		echo "$rescueUser failed to demote"
		expireApiToken
		exit 1
	fi
fi


## FIX rescue INCORRECT PASSWORD
if [[ "$rescuePassCorrect" == "false" ]] ; then
	echo "$rescueUser password is incorrect. changing password"
	/usr/sbin/sysadminctl -adminUser "$adminName" -adminPassword "$adminPass" -resetPasswordFor "$rescueUser" -newPassword "$rescuePass"
	sleep 1
	rescuePassCorrect=$(passwordCorrect "$rescueUser" "$rescuePass")
	rescueFV=$(fileVaultUserAccess "$rescueUser" )
	rescueToken=$(secureTokenUserCheck "$rescueUser" )
	if [[ "$rescuePassCorrect" == "false" ]] ; then 
		echo "$rescueUser failed to update password"
        expireApiToken
		exit 1
	fi
fi

if [[ "$rescueFV" == "false" ]] ; then
	echo "$rescueUser failed FV access"
	addUserToFilevault "$adminName" "$adminPass" "$rescueUser" "$rescuePass"
	sleep 1
	rescueFV=$(fileVaultUserAccess "$rescueUser" )
	rescueToken=$(secureTokenUserCheck "$rescueUser" )
	if [[ "$rescueFV" == "false" ]] ; then 
		echo "$rescueUser failed to update filevault"
        expireApiToken
		exit 1
	fi
fi

if [[ "$rescueToken" == false ]] ; then
	echo "$rescueUser missing secure token, adding"
	addSecureToken "$adminName" "$adminPass" "$rescueUser" "$rescuePass"
	sleep 1
	rescueToken=$(secureTokenUserCheck "$rescueUser" )
	if [[ "$rescueToken" == "false" ]] ; then 
		echo "$rescueUser failed to update secure token"
        expireApiToken
		exit 1
	fi
fi

echo " "
echo "Final Checks:"
echo "exists: $rescueExists"
echo "admin: $rescueIsAdmin (we want this to be false)"
echo "passCorrect: $rescuePassCorrect"
echo "filevault: $rescueFV"
echo "secureToken: $rescueToken"
echo " "
echo " "

setEAStatus
uploadCheck

echo " "
echo "Updating apfs preboot"
diskutil apfs updatePreboot / >> /dev/null 2>&1 

expireApiToken

exit 0
