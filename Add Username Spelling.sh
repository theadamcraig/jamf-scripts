#!/bin/bash

## We are going to add a list of words to the users dictionary so that they are not autocorrected in an annoying way.
## this will hopefully prevent the thing where Okta login windows try to autocorrect usernames

# started off with script from
# https://macadmins.slack.com/archives/C07MGJ2SD/p1504615636000539

companyName="YourCompanyNameHere"

#########################################################################################
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
## Make sure again that the user is valid. It's possible that $3 from Jamf is also an invalid user.
if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]] ; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi

fullName=$( id -P $(stat -f%Su /dev/console) | awk -F '[:]' '{print $8}' )

LocalDictionary="/Users/${loggedInUser}/Library/Spelling/LocalDictionary"
words=("${companyName}" "$loggedInUser" "$fullName")

# Backup LocalDictionary
cp $LocalDictionary ${LocalDictionary}.backup

# Append each word from the list
for word in "${words[@]}"
do
    echo "$word" >> $LocalDictionary
done

# Sort case-insensitive out to the same file
sort -f $LocalDictionary -o $LocalDictionary

chown -R "$loggedInUser" "$LocalDictionary"
chmod -R 644 "$LocalDictionary"

exit 0