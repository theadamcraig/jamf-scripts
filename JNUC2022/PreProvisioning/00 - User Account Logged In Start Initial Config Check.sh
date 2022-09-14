#!/bin/bash

##########################################################################################/

# written by Adam Caudill

# Script presented in Userproof Onboarding: Backup Plans for Zero Touch for IT JNUC 2022

# https://github.com/theadamcraig/jamf-scripts/tree/master/JNUC2022

##########################################################################################/

# This script is the 00 policy of InitialConfig which causes it to run first.

# it makes sure that the user account that is logged in is the correct user.

# this allows for computers to be pre-provisioned in the admin account and have the computer pre-provisioned

##########################################################################################/

# ITEMS THAT NEED UPDATED IN THIS SCRIPT:

# cacheinitialconfig policy that will Cache (not install) the jamf enrollment kickstart package

# we have 2 admin variables so we can have old and new account when we rotate admin accounts

# $6 is our rescue account
# https://github.com/theadamcraig/jamf-scripts/tree/master/rescue_account

# $7 should be your setup account name. this should match your pre-provision script.

##########################################################################################/

# SUPPORTING POLICIES THAT NEED CREATED

# sudo jamf policy -event cacheinitialconfig 

#      policy that will Cache (not install) the jamf enrollment kickstart package
#      https://github.com/Yohan460/JAMF-Enrollment-Kickstart

##########################################################################################/

cacheinitialconfig="JamfTriggerHere"

## multiple admin accounts to adjust for future admin password rotations
# $4 & 5 are mandatory and admin account names
admin1Name="${4}"
admin2Name="${5}"

if [[ -z "${4}" ]] || [[ -z "${5}" ]] ; then
	echo "admin1 or admin2 name is missing"
	exit 1
fi

## $6 is rescue Name. defaults to rescue
if [[ -z "${6}" ]] ; then 
	rescueName="rescue"
else
	rescueName="${6}"
fi

## $7 is setup name. defaults to setup
if [[ -z "${7}" ]] ; then 
	setupName="setup"
else
	setupName="${7}"
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
## Get the logged in UID which will be needed for some commands as well.
loggedInUID=$(id -u "$loggedInUser")

	## if logged in user is an admin or rescue then do the following
	# Remove Initial Config
	# cache Inital Config
	# kill jamf and let the user proceed as they would.

if [[ "$loggedInUser" = "$admin1Name" ]] || [[ "$loggedInUser" = "$admin2Name" ]] || [[ "$loggedInUser" = "$rescueName" ]] ; then
	echo "logged in user is $loggedInUser. cancelling 'initialconfig' process"
	launchctl unload /Library/LaunchDaemons/com.JAMF.InitialConfig.plist
	rm -f /Library/LaunchDaemons/com.JAMF.InitialConfig.plist
	sleep 1
	jamf policy -trigger "$cacheinitialconfig"
	sleep 1
	killall Jamf
	killall jamf

	exit 0

elif [[ "$loggedInUser" = "$setupName" ]] ; then
	## if logged in user is an setup then do the following
	# Remove Initial Config
	# cache Inital Config
	# log the user out
	# kill jamf and let the user proceed as they would.
	echo "logged in user is $loggedInUser. cancelling 'initialconfig' process"
	launchctl unload /Library/LaunchDaemons/com.JAMF.InitialConfig.plist
	rm -f /Library/LaunchDaemons/com.JAMF.InitialConfig.plist
	sleep 1
	jamf policy -trigger "${cacheinitialconfig}"
 
	/bin/launchctl asuser "${loggedInUID}" sudo -iu "${loggedInUser}" /usr/bin/osascript -e 'tell application "loginwindow" to  «event aevtrlgo»'

	sleep 1
	killall jamf
	killall Jamf

	exit 0
else
	## we don't need to do anything. Log this and continue!
	echo "Logged in user is $loggedInUser"
	echo "proceed with InitalConfig"
fi

exit 0