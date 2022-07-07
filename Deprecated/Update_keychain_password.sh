#!/bin/bash

## This script isn't really useful anymore.
## Once computers stopped being bound to AD this stopped being a problem. There are a bunch of things I could do better now if I was to still use a process like this.
## I also found that even though it made perfect sense to me, helpdesk team members never got very comfortable with this process

##UPDATE KEYCHAIN PASSWORD
## Written by adamcraig https://github.com/theadamcraig/jamf-scripts
## Last updated 4/02/2020
## Fixed Filevault Bug
## added user authentication check
## Added ability to remove and re-add user from filevault as well.

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] ; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi

loggedInUID=$(id -u "$loggedInUser")

adminName=$4
adminPass=$5

## Find the renamed keychains
renamed=""

for n in {1..9} ; do
	long="Users/$loggedInUser/Library/Keychains/login_renamed_$n.keychain-db"
	short="login_renamed_$n.keychain-db"
	echo "$long"
	if [[ ! -f $long ]] ; then
		echo "Above Keychain not Found"
	else
		renamed="$long"
		short_renamed="$short"
		echo "renamed set to Above Keychain"
	fi
done

## If the rename keychain isn't found then exit

if [[ -z "$renamed" ]] ; then
	echo "Renamed keychain not found."
	dialog="Old keychain not found."
	cmd="Tell app \"System Events\" to display dialog \"$dialog\""
	/usr/bin/osascript -e "$cmd"
	exit 1
fi

#renamed=`echo ${renamed%???}`

echo "Prompting user for current password"

## Prompt use for current password
currentPass=$(/usr/bin/osascript<<END
tell application "System Events"
activate
set the answer to text returned of (display dialog "Please enter your Current account Password:" default answer "" with hidden answer buttons {"Continue"} default button 1)
end tell
END
)

passwordCheck() {
    passCheck=$(/usr/bin/dscl /Local/Default -authonly "$loggedInUser" "$currentPass")
    if [[ -z "$passCheck" ]]; then
        echo "Current Password checks Continue"
    else
        dialog="Current password was not entered correctly. Exiting."
        cmd="Tell app \"System Events\" to display dialog \"$dialog\""
		/usr/bin/osascript -e "$cmd"
		exit 1
    fi
}

passwordCheck

echo "Prompting user for password to $renamed"	
previousPass=$(/usr/bin/osascript<<END
tell application "System Events"
activate
set the answer to text returned of (display dialog "Please enter your Previous account Password:" default answer "" with hidden answer buttons {"Continue"} default button 1)
end tell
END
)


## Open the keychain to load it into keychain access
open "$renamed" &

sleep 2

## close keychain access
#killall Keychain\ Access

## unlock the previous keychain
unlock_result=`expect -c "
spawn /bin/launchctl asuser $loggedInUID sudo -iu $loggedInUser security unlock-keychain $short_renamed
expect \"password to unlock $renamed\"
send ${previousPass}\r
expect"`

# dialog="Testing access to old Keychain. If you are prompted for Keychain Password please press CANCEL!"
# cmd="Tell app \"System Events\" to display dialog \"$dialog\""
# /usr/bin/osascript -e "$cmd"
# 
# passwordTest=`/bin/launchctl asuser $loggedInUID sudo -iu "$loggedInUser" security show-keychain-info "$short_renamed"`
# echo "Password test = $passwordTest"

if [[ "$unlock_result" == *"The user name or passphrase you entered is not correct."* ]] ; then
	echo "Previous Password did not unlock keychain"
	dialog="Previous Account password did not unlock the old keychain."
	cmd="Tell app \"System Events\" to display dialog \"$dialog\""
	/usr/bin/osascript -e "$cmd"
	
	echo "reset the keychain list to just login.keychain-db"
	/bin/launchctl asuser $loggedInUID sudo -iu "$loggedInUser" security list-keychains -s login.keychain-db
	sleep 2
	
	killall Keychain\ Access
	
	exit 1
fi

### If it gets this far the Previous Password is correct


## Make a keychain archive on the users desktop
mkdir /Users/$loggedInUser/Desktop/Keychain\ Archive

## change the password to the previous keychain
expect -c "
spawn /bin/launchctl asuser $loggedInUID sudo -iu $loggedInUser security set-keychain-password $short_renamed
expect \"Old Password:\"
send ${previousPass}\r
expect \"New Password:\"
send ${currentPass}\r
expect \"Retype New Password:\"
send ${currentPass}\r
expect"


echo "move the login keychain to the archive"
mv /Users/$loggedInUser/Library/Keychains/login.keychain-db /Users/$loggedInUser/Desktop/Keychain\ Archive/login.keychain-db
echo "copy the renamed keychain to the archive"
cp /Users/$loggedInUser/Library/Keychains/$short_renamed /Users/$loggedInUser/Desktop/Keychain\ Archive/$short_renamed
echo "wipe current keychain list"
/bin/launchctl asuser $loggedInUID sudo -iu "$loggedInUser" security list-keychains -s none
echo "rename the renamed keychain to login"
mv $renamed /Users/$loggedInUser/Library/Keychains/login.keychain-db
echo "add the login keychain to the list."
/bin/launchctl asuser $loggedInUID sudo -iu "$loggedInUser" security list-keychains -s login.keychain-db

##unlock keychain
expect -c "
spawn /bin/launchctl asuser $loggedInUID sudo -iu $loggedInUser security unlock-keychain login.keychain-db
expect \"password to unlock $renamed\"
send ${currentPass}\r
expect"

## set that keychain to the default keychain
result=$(/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" security default-keychain -s "login.keychain-db")


## Removing and re-adding user to FileVault as a precautionary step.
fdesetup remove -user $loggedInUser

expect -c "
spawn fdesetup add -usertoadd $loggedInUser
expect \"Enter the primary user name:\"
send ${adminName}\r
expect \"Enter the password for the user '$adminName':\"
send ${adminPass}\r
expect \"Enter the password for the added user '$loggedInUser':\"
send ${currentPass}\r
expect" 

fdeList=`fdesetup list | grep $loggedInUser`

if [[ "$fdeList" == *"$loggedInUser"* ]] ; then
	echo "$loggedInUser Added to FileVault successfully"
	exit 0
else
	echo "Adding $loggedInUser to FV2 Failed"
	dialog="Adding $loggedInUser to FV2 Failed. Run 'Update Filevault Password' in Self Service"
	cmd="Tell app \"System Events\" to display dialog \"$dialog\""
	/usr/bin/osascript -e "$cmd"
	exit 1
fi


if [[ -z $result ]] ; then
	dialog="Updating Old Keychain is complete. If you did not recieve an error regarding Filevault then restart your computer"
else
	echo "$result"
	dialog="Error message: $result"
fi
cmd="Tell app \"System Events\" to display dialog \"$dialog\""
/usr/bin/osascript -e "$cmd"

killall Keychain\ Access

exit 0
