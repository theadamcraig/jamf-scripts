#!/bin/bash

##########################################################################################/

# written by Adam Caudill

# Script presented in Userproof Onboarding: Backup Plans for Zero Touch for IT JNUC 2022

# https://github.com/theadamcraig/jamf-scripts/tree/master/JNUC2022

##########################################################################################/

# For use with Jamf Enrollment Kickstart by: Johan McGwire - Yohan @ Macadmins Slack - Johan@McGwire.tech
# github.com/Yohan460/JAMF-Enrollment-Kickstart

# https://www.youtube.com/watch?v=MhoHgC7AAUI

# This checks to make sure that InitalConfig has completed and then Completes InitialConfiguration so the launch agent will be removed

#  notify the users with IBM Notifier that the Initial Configuration has been completed.


##########################################################################################/

# ITEMS THAT NEED UPDATED IN THIS SCRIPT:

# name of your rescue user if you use one. If not you can delete the references to rescueUser
# https://github.com/theadamcraig/jamf-scripts/tree/master/rescue_account

## vpnPortal - also this is configured to useGLobalProtect for VPN

## apps in the coreapp array need to be the apps that your workflow is expecting to exist when configuration is complete.


## Dialog Images and Text needs updated.

# APP_SUPPORT
# RESOURCE_FOLDER
# ICON_PATH

##########################################################################################/

# SUPPORTING POLICIES THAT NEED CREATED

# jamf policy -event nota_install
#      Trigger to install IBM Notifier

# jamf policy -event InstallApplicationSupport
#       trigger to install reference files/images used in dialog boxes.

##########################################################################################/



## This variable will be added to with all of the errors that this script is able to find if any
text="Errors:"

## this has been configured for with two admin names for when we rotate local admin accounts
admin1Name="${4}"
admin2Name="${5}"

## no success message if silent
silent="${6}"

rescueUser="rescue"

vpnPortal="company.vpn.com"

## List of Core Applications to verify installed
declare -a coreAppArray=( "Google Chrome.app" \
	"OneDrive.app" \
	"Microsoft Outlook.app" \
	"Microsoft Teams.app" \
	"Citrix Workspace.app" \
	"BlueJeans.app" \
	"Slack.app" \
	"Jamf Connect.app" \
	)


if [[ -z "$admin1Name" ]] || [[ -z "$admin2Name" ]] ; then
	echo "adminName missing"
	exit 1
fi

## Get logged in user from Console.
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

## make sure there is a value and that it's not any of the accounts that can occasionally be a result of the console method and have an error.
if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]] ; then
	## if it's not a valid user let's' take the result from jamf
	loggedInUser="$3"
fi

## convert logged in user to lowercase
## sometimes we get an mixed case user and it can create inconsistent results
loggedInUser=$( echo "$loggedInUser" | tr [:upper:] [:lower:] )

## Make sure again that the user is valid. It's possible that $3 from Jamf is also an invalid user.
if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]] ; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi


if [[  "$loggedInUser" == "$admin1Name" ]] || [[ "$loggedInUser" == "$admin2Name" ]] || [[ "$loggedInUser" == "$rescueUser" ]] ; then
	echo "Should not be run in admin account."
	exit 1
fi

configDirectory="/Library/InitialConfiguration"
errorCountFile="${configDirectory}/.InitialConfigurationErrors"
configCompleteFile="${configDirectory}/.InitialConfigurationComplete"

## THIS SHOULD NEVER HAPPEN. BUT JUST IN CASE
if [[ ! -d "$configDirectory" ]] ; then
	mkdir "$configDirectory"
fi

# ERROR COUNT IS COUNTING THE NUMBER OF TIMES THIS SCRIPT HAS FOUND AN ERROR.
if [[ -e "$errorCountFile" ]] ; then
	errorCount=$(cat "$errorCountFile")
	echo "error count is $errorCount"
else
	echo "error count is 0"
	errorCount=0
fi

# RESULT IS DETERMINING IF THE SCRIPT WILL ERROR THIS TIME OR NOT
result=0

#############################################################################
### IBM Notifier things

# Policy triggers for downloading the icon/notification agent
NOT_AGENT="nota_install"
# Policy triggers for downloading the application support Reference folder
APPSUPPORTTRIGGER="InstallApplicationSupport"

# Application path and required version for this script
NA_PATH="/Applications/IBM Notifier.app/Contents/MacOS/IBM Notifier"
if [[ ! -e "${NA_PATH}" ]] ; then
	jamf policy -event "$NOT_AGENT" -forceNoRecon
fi

NA_VERS="2.4.1"

agent_check() {
    # will determine if the notification agent exists and is working. if not, download it
    tries=0
    echo "agent check"
    while [[ "$tries" < 2 ]]; do
        agent_help=$(sudo -u "${loggedInUser}" "${NA_PATH}" --help > /dev/null 2>&1; echo $?)
        if [[ "$agent_help" -eq 200 ]]; then
            # get the current installed version and compare to see if we need to upgrade
            inst_vers=$(sudo -u "${loggedInUser}" "${NA_PATH}" --version | awk -F": " '{print $2}')
            vers_list=$(printf '%s\n' "${NA_VERS}" "${inst_vers}" | sort -V | head -n1)
            
            if [[ "$vers_list" == "$inst_vers" ]] && [[ "$NA_VERS" != "$inst_vers" ]]; then
                tries="$tries"
            else
                echo "agent installed and working"
                tries=0
                break
            fi
        fi
        if [[ "$tries " -lt 1 ]]; then
        	echo "installing agent update via jamf"
            agent_install=$(jamf policy -event "$NOT_AGENT" -forceNoRecon)
        fi
        tries=$((++tries))
    done
}

agent_check
## Notifier Health Check - Complete


APP_SUPPORT="/Library/Application Support/COMPANY_NAME/"
RESOURCE_FOLDER="${APP_SUPPORT}InitialConfig_resources/"

ICON_PATH="${APP_SUPPORT}CompanyLogo.png"

WINDOW_TITLE="Computer Setup"
BUTTON_1="Done"
TIMEOUT=300


## ERROR REPORT USING IBM NOTIFIER
showErrorReport() {

	########### HALP IMAGE
	IMAGE="${RESOURCE_FOLDER}halp_logo.png"

	if [[ ! -e "${ICON_PATH}" ]] || [[ ! -e "${IMAGE}" ]] ; then
		echo "Icon or Image not found at:"
		echo "${ICON_PATH}"
		echo "${IMAGE}"
		jamf policy -event "${APPSUPPORTTRIGGER}" -forceNoRecon
	fi

	HEADING="There was an error in your Computer's automated setup."

	## newlines do not work.
	DESCRIPTION="${text} \nPlease reach out to #it-helpdesk for assistance."
	
	HELP_TYPE="link" # other option is link
	## This link will directly open the IT slack channel if you update it to the applicable link
	HELP_PAYLOAD="https://COMPANY.slack.com/archives/CHANNELCODE"
	
	"sudo" "-u" "${loggedInUser}" "${NA_PATH}" \
		"-type" "popup" \
		"-bar_title" "${WINDOW_TITLE}" \
		"-title" "${HEADING}" \
		"-subtitle" "${DESCRIPTION}" \
		"-icon_path" "${ICON_PATH}" \
		"-main_button_label" "${BUTTON_1}" \
		"-accessory_view_type" "image" \
		"-accessory_view_payload" "${IMAGE}" \
		"-help_button_cta_type" "${HELP_TYPE}" \
		"-help_button_cta_payload" "${HELP_PAYLOAD}" \
		"-position" "top_left" \
		"-timeout" "${TIMEOUT}"
	sleep 10
}

## COMPLETE MESSAGE USING IBM NOTIFIER
showCompleteMessage() {

	########## Success Image
	IMAGE="${RESOURCE_FOLDER}SuccessKid.jpeg"

	if [[ ! -e "${ICON_PATH}" ]] || [[ ! -e "${IMAGE}" ]] ; then
		echo "Icon or Image not found at:"
		echo "${ICON_PATH}"
		echo "${IMAGE}"
		jamf policy -event "${APPSUPPORT}" -forceNoRecon
	fi

	HEADING="Computer Setup Complete!"
	
	DESCRIPTION="This computer is now at our standard configuration. \n\nAdditional applications can be installed from Self Service. \n\nIf you need assistance check the confluence pages that have been loaded into your Chrome browser. \n\nYou can also reach out for help in #it-helpdesk."
	
	HELP_TYPE="infopopup" # other option is link
	HELP_PAYLOAD="At this point in time GlobalProtect should be connected to our standard VPN and all default applications and security settings have been applied."
	
	TIMEOUT=600

	BUTTON_2="Self Service"
	BUTTON_2_TYPE="link"
	BUTTON_2_PAYLOAD="jamfselfservice://content"


	"sudo" "-u" "${loggedInUser}" "${NA_PATH}" \
		"-type" "popup" \
		"-bar_title" "${WINDOW_TITLE}" \
		"-title" "${HEADING}" \
		"-subtitle" "${DESCRIPTION}" \
		"-icon_path" "${ICON_PATH}" \
		"-main_button_label" "${BUTTON_1}" \
		"-secondary_button_label" "${BUTTON_2}" \
		"-secondary_button_cta_type" "${BUTTON_2_TYPE}" \
		"-secondary_button_cta_payload" "${BUTTON_2_PAYLOAD}" \
		"-accessory_view_type" "image" \
		"-accessory_view_payload" "${IMAGE}" \
		"-help_button_cta_type" "${HELP_TYPE}" \
		"-help_button_cta_payload" "${HELP_PAYLOAD}" \
		"-position" "top_left" \
		"-timeout" "${TIMEOUT}"
	sleep 10

}


### ERROR CHECKING FUNCTIONS
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


## FUNCTION TO VERIFY IF APPLICATION IS INSTALLED. FAIL SCRIPT IF MISSING
verifyApplication(){
	app_name="$1"
	file_path="/Applications/$app_name"
	if [[ -d "$file_path" ]] ; then
		echo "$app_name installed."
	else
		## ADD TEXT TO THE ERROR REPORT THAT WILL BE SHOWN TO THE USER
		text="${text} ${app_name} not installed,"
		## ADDING SPACES HERE TO MAKE THE JAMF LOG MORE READABLE
		echo " "
		echo "ERROR: $app_name Missing. setting exit code to 1"
		echo " "
		result=1
	fi
}

fileVaultUserAccess() {
	# returns true if the user has filevault access. false if they do not
	local userToCheck="$1"
	if [[ $(fdesetup list | tr [:upper:] [:lower:] | grep "$userToCheck") == *"$userToCheck"* ]] ; then
		local fvAccess="true"
	else
		local fvAccess="false"
	fi
	echo "$fvAccess"
}


## Start checking the things
echo "checking for $admin1Name"
admin1Check=$(id -u "$admin1Name")
echo "checking for $admin2Name"
admin2Check=$(id -u "$admin2Name")

if [[ "$admin1Check" == "false" ]] && [[ "$admin2Check" == "false" ]] ; then
	echo "admin user not installed"
	jamf policy -trigger "install$admin2Name"
	sleep 5
fi

admin1FVCheck=$( fileVaultUserAccess "$admin1Name" )
admin2FVCheck=$( fileVaultUserAccess "$admin2Name" )

if [[ "$admin1FVCheck" == "false" ]] && [[ "$admin2FVCheck" == "false" ]] ; then
	text="${text} \nadmin account not Filevault enabled,"
	## ADDING SPACES HERE TO MAKE THE JAMF LOG MORE READABLE
	echo " "
	echo "ERROR: Admin account is not Filevault enabled"
	echo " "
	result=1
fi

userFVCheck=$( fileVaultUserAccess "$loggedInUser" )
if [[ "$userFVCheck" == "false" ]] ; then
	text="${text} \nUser account not Filevault enabled, "
	## ADDING SPACES HERE TO MAKE THE JAMF LOG MORE READABLE
	echo " "
	echo "ERROR: user account is not Filevault enabled"
	echo " "
	result=1
fi

## Check Core applications
for appName in "${coreAppArray[@]}"; do
	verifyApplication "${appName}"
done

## Check Filevault Status
fvStatus=$(fdesetup status)
if [[ "$fvStatus" == *"FileVault is On."* ]] ; then
	echo "Verified Filevault Enabled"
else
	## ADDING SPACES HERE TO MAKE THE JAMF LOG MORE READABLE
	echo " "
	echo "ERROR: Filevault not enabled. Exiting"
	echo " "
	text="${text}
	Encryption Disabled, "
	result=1
fi

### check S1 install
S1_BINARY="/Library/Sentinel/sentinel-agent.bundle/Contents/MacOS/sentinelctl"
if [[ -f ${S1_BINARY} ]]; then
	echo "Sentinel1  installed"
else
	## ADDING SPACES HERE TO MAKE THE JAMF LOG MORE READABLE
	echo " "
	echo "ERROR: Sentinel1 Missing."
	echo " "
	text="${text} Sentinel1 not installed,"
	result=1
fi

### CHECKS HERE TO MAKE SURE THAT VPN IS CONFIGURED PROPERLY AND CONNECTED

## This is the way to to check the status and Portal for our GlobalProtect. This will need changed if you are using a different VPN
### check VPN PORTAL
portal=$( /usr/libexec/PlistBuddy -c "Print Palo\ Alto\ Networks:GlobalProtect:PanSetup:Portal" /Library/Preferences/com.paloaltonetworks.GlobalProtect.settings.plist )
if [[ "$portal" == "${vpnPortal}" ]] ; then
	echo "vpn portal set correctly"
else
	echo " "
	echo "ERROR: vpn portal not set correctly"
	echo " "
	text="${text}
	vpn portal not set,"
	result=1
fi


# GlobalProtect check status.
## If you are not using global protect this needs updated. or removed
GPSlog="/Library/Logs/PaloAltoNetworks/GlobalProtect/PanGPS.log"

status=$( tail -r $GPSlog | grep -m 1 -o -e 'Set state to Disconnected' -e 'Set state to Connected' -e 'Set state to Discovery complete' )

if [[ "$status" == "Set state to Connected" ]] || [[ "$status" == "Set state to Discovery complete" ]] ; then
	echo "Status is: ${status}"
elif [[ "$status" == "Set state to Disconnected" ]] ; then
	## ADDING SPACES HERE TO MAKE THE JAMF LOG MORE READABLE
	echo " "
	echo "ERROR: GP Status is Disconnected"
	echo " "
	result=1
	text="${text}
	vpn not connected,"
else
	## ADDING SPACES HERE TO MAKE THE JAMF LOG MORE READABLE
	echo " "
	echo "ERROR: GP Status is: $status"
	echo " "
	result=1
	text="${text}
	vpn not connected,"
fi

if [[ "$errorCount" == 0 ]] ; then
	result=1
	## ADDING SPACES HERE TO MAKE THE JAMF LOG MORE READABLE
	echo " "
	echo "ERROR: no errors before. setting result to 1 so that initial config runs twice"
	echo " "
fi

## if any of those items failed then exit and report the number of errors
if [ $result != 0 ] ; then
	echo " "
	echo "RESULTS:"
	echo "at least one of the application checks failed"
	errorCount=$(( errorCount + 1 ))
	echo "$errorCount" > "$errorCountFile"
	echo "error count is $errorCount"
	## SHOW THE USER AN ERROR REPORT THE 11th time through and every 100 times after that
	if [[ $(( (errorCount-11) % 100 )) == 0 ]]; then
		echo "$errorCount is divisible by 100 after subtracting 11"
		showErrorReport & exit $result
	else
		echo "$errorCount not divisible by 100 after subtracting 11"
		echo "do not show error report."
	fi
	exit $result
fi

# Writing out a configuration receipt
touch "${configCompleteFile}"

## NOTE THAT FAILURES WILL ALWAYS SHOW MESSAGES, BUT SUCCESS WILL NOT.
if [[ -z "${silent}" ]] ; then
	showCompleteMessage
else
	echo "Script set to run silently. no success message."
fi

## redirecting the output to clean up the Jamf Logs
jamf recon >> /dev/null 2>&1 

# Exiting and returning the policy call code
exit $result