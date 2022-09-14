#! /bin/bash

##########################################################################################/

# written by Adam Caudill

# Script presented in Userproof Onboarding: Backup Plans for Zero Touch for IT JNUC 2022

# https://github.com/theadamcraig/jamf-scripts/tree/master/JNUC2022

##########################################################################################/

# This script sets the user targeted in $4 's user icon to be the file named in $5

##########################################################################################/

# ITEMS THAT NEED UPDATED IN THIS SCRIPT:

#resourceFolder variable needs updated to be the file path of the folder where the icon will live.

# this variable should end with a /

# installResourceFolder is the custom trigger to install the folder with the userIcons


##########################################################################################/

# SUPPORTING POLICIES THAT NEED CREATED

# jamf policy -event installResourceFolder

# create the policy with a custom trigger to install the resource folder when it's missing,


##########################################################################################/

targetUser="${4}"
imageFile="${5}"

resourceFolder="/Library/Application Support/CompanyName/userIcons/"
installResourceFolder="jamfTriggerHere"

targetUser=$( echo "$targetUser" | tr [:upper:] [:lower:] )

userCheck=$(id -u "$targetUser")
if [[ "$userCheck" == *"no such user"* ]] || [[ -z "$userCheck" ]] ; then
	echo "$targetUser user not installed"
	exit 1
fi

filePath="${resourceFolder}${imageFile}"
echo "$filePath"

#make sure the file has been installed
if [[ -e "$filePath" ]] ; then
	echo "File path found"
else
	echo "icon file is missing"
	jamf policy -trigger "${installResourceFolder}"
fi
	
# Set the target user icon
if [[ -e "$filePath" ]] ; then
	echo "Setting ${targetUser} photo as ${imageFile}"

dscl . delete /Users/"${targetUser}" jpegphoto
dscl . delete /Users/"${targetUser}" Picture
dscl . create /Users/"${targetUser}" Picture "${filePath}"

else
	echo "${filePath} is missing"
	exit 1
fi
	

exit 0