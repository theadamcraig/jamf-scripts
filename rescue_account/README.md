# Rescue Account

The goal of a rescue account is to have a local account on the computer that you can give the user the password to. If a remote user forgets their password or gets locked out of their account you can give them the randomly generated rescue account password. This will allow them to get past Filevault and access the internet. Policies will run, and the user can use Self Service.

Once you give a user the rescue password you can reset it just by deleting the password from jamf.
![RescueAccount_EA_ComputerRecord](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/RescueAccount_EA_ComputerRecord.png)


These are instructions on how to use the setup these rescue account policies with Jamf

### 1. Generate adjective.txt nount.txt & verb.txt files
I'm not providing these files, there are a lot of lists you can find online, I also recommend cleaning them of NSFW words to prevent having to awkwardly tell someone a very dirty sounding password.

pass_phrase.sh is expecting them to be formmatted like this:

![adjective.txt example](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/adjective.txt_example.png)

### 2. Install the pass_phrase.sh script and .txt files onto users computers.

We put them in:
>/Library/Application Support/COMPANYNAME/passphrase

This filepath will need updated in a number of locations

![passphrase folder setup](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/passphrase_folder_setup.png)

### 3. Setup the RescuePassword extension attribute

This is a text field EA that will be updated by the API.

The scripts as written are expecting this EA to be named RescuePassword without a space. if you name it something else you'll need to update the scripts accordingly.

![Rescue Password EA](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/Rescue_Password_EA.png)

### 4. Setup the RescuePassword - local extension attribute

Make sure to update the COMPANYNAME filepath

![Rescue Password - Local EA](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/Rescue_Password_Local_EA.png)

### 5 Upload the Rescue_Account_Password_Change.sh and rescue_account_cleanup.sh scripts to your jamf

Update the passLocation and jssURL variables in both scripts

the passLocation variable is written to live next to the passphrase folder that is installed in step 2

### 6 Create The following smart groups

If you choose to name your rescue account something other than rescue adjust for that here.

Rescue Account Installed
![RescueAccount_Installed_group](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/RescueAccount_Installed_group.png)

Rescue Account needs cleaned
![RescueAccount_NeedsCleaned_group](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/RescueAccount_NeedsCleaned_group.png)

Rescue Account Password Needs Reset ![RescueAccount_passwordNeedsReset_group](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/RescueAccount_passwordNeedsReset_group.png)

Rescue Account Installed and Not Encrypted
![RescueAccountInstalledNotEncrypted_group](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/RescueAccount_InstalledNotEncrypted_group.png)

### 7 Create Rescue Account Policy

*I have all the policies run on recurring check-in once a day*
*All Policies Should to Update Inventory*

Scope this to all the computers that need the Rescue Account, and have the Local Admin Account Filevault Enabled.

Exclude the *Rescue Account Installed* Smart Group.

$4 is your API Username
$5 is your API Users Password
$6 is the rescue account username (Make this match the smartgroups)
$7 is your local admin username
$8 is your local admin password

![CreateRescueAccount](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/CreateRescueAccount.png)

This Policy will Create Rescue accounts with randomly generated password on all scoped computers.
Those passwords will be uploaded to a text Extension Attribute in your jamfcloud.
If the API update fails it will be saved locally and read by a separate Extension Attribute

### 8 Change Rescue Account Password Policy

Clone the previous policy

Change the scope to be the *Rescue Account Password Needs Reset* & *Rescue Account Installed and Not Encrypted* smart groups. Remove the *Rescue Account Installed* group from the exclusions

![ChangeRescuePassword_scope](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/ChangeRescuePassword_scope.png)

This Policy will Create a new rescue account password for any computer with a blank variable.

This means that after you are done assisting a user with the Rescue account you can delete the text from the extension attribute variable and it will be reset.

### 9 Rescue Account Cleanup Policy

Create a new policy with the Rescue_Account_Cleanup.sh script

$4 is your API Username
$5 is your API Users Password

![RescueAccount_Cleanup](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/RescueAccount_Cleanup.png)

Scope this policy to the *Rescue Account needs cleaned* smart group.

This policy will get the local variable and upload it again if the password fails to upload when the account is created or the password is changed.

I chose to have this local password stored because often computers that need to use the rescue account are ones where things aren't working correctly, and I didn't want a bad API call to prevent a user from being helped.

### 10 If you use Jamf Connect

Make sure to account for the rescue accounted for in your jamf connect configuration

If you choose to name your rescue account something other than rescue adjust for that here.

add the account to Accounts Prohibited from Network Account Connection
![JamfConnect_prohibitedfromnetworkaccountconnection](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/JamfConnect_prohibitedfromnetworkaccountconnection.png)

and Users with Local Authentication Privileges
![JamfConnect_userswithlocalauth](https://github.com/theadamcraig/jamf-scripts/blob/master/rescue_account/screenshots/JamfConnect_userswithlocalauth.png)


