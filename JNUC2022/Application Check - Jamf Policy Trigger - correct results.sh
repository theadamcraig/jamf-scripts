#!/bin/bash

##########################################################################################/

# written by Adam Caudill

# Script presented in Userproof Onboarding: Backup Plans for Zero Touch for IT JNUC 2022

# https://github.com/theadamcraig/jamf-scripts/tree/master/JNUC2022

##########################################################################################/

# This script allows the "ReRun Policy of Failure" feature to be used to maximum effect

# if a policy runs another policy via unix command it will succeed regardless of the results of the targeted policy

# This policy gets accurate results and exits accordingly, so that the rerun on failure will trigger again if the policy does fail.

##########################################################################################/

# Variables in this script

# $4 is the application being installed, this will exit 0 if that file exists

# $5 is the trigger that installs the application listed in $4

##########################################################################################/

## needs to be full application name including .app extension
## if application is installed somewhere other than Applications folder this script will need modified
applicationName="${4}"

## the policy to install the above application
policyTrigger="${5}"

## Get logged in user from Console.
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

## make sure there is a value and that it's not any of the accounts that can occasionally be a result of the console method and have an error.
if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]] ; then
	## if it's not a valid user let's' take the result from jamf
	loggedInUser="$3"
fi

## convert logged in user to lowercase
## sometimes we get an mixed case user and it can create inconsistent results
if [ -n "$BASH_VERSION" ]; then
   # assume Bash
   loggedInUser=$( echo "$loggedInUser" | tr [:upper:] [:lower:] )
else
   # assume something else
   echo "script not written in bash, leaving as mixedcase."
fi

runAsUser() {
    if [[ $loggedInUser != "loginwindow" ]]; then
        uid=$(id -u "$loggedInUser")
        launchctl asuser $uid sudo -u $loggedInUser "$@"
    fi
}

# lifted from Installomator
displaynotification() { # $1: message $2: title
    message=${1:-"Message"}
    title=${2:-"Notification"}
    manageaction="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"

    if [[ -x "$manageaction" ]]; then
         "$manageaction" -message "$message" -title "$title"
    else
        runAsUser osascript -e "display notification \"$message\" with title \"$title\""
    fi
}

# Make sure we have the variables we need
if [[ -z "${applicationName}" ]] || [[ -z "${policyTrigger}" ]] ; then 
	echo "AppName:${applicationName} or trigger:${policyTrigger} is missing"
	exit 1
fi

## If it's there we don't need any action
if [[ -e "/Applications/${applicationName}" ]] ; then
	echo "${applicationName} already installed"
	result=0
else
	echo "Application missing. Installing via: ${policyTrigger}"
	jamf policy -trigger "${policyTrigger}" -forceNoRecon
	result="$?"
	echo "Result of jamf policy is: ${result}"
	## let's check to see if the app exits again
	if [[ -e "/Applications/${applicationName}" ]] ; then
		echo "${applicationName} is now installed"
	else
		echo "${applicationName} is still missing"
		result=1
	fi
fi

echo "Script result is $result"

if [[ "${result}" = 0 ]] ; then
	displaynotification "${applicationName} Installed" "Initial Configuration in progress" && exit "${result}"
else
	exit "${result}"
fi
