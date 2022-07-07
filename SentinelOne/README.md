# SentinelOne

These are instructions on how to use the SentinelOne post install script with Jamf

the advantage of this workflow is that you can use one policy to install and update SentinelOne

### 1. Upload the SentinelAgent_macos_vXX_XX_X_XXXX_.pkg as downloaded from SentinelOne to Jamf

### 2. Add the script to Jamf. 
Change the line where it says "YOURREGISTRATIONTOKENHERE" to your sentinelone token.

![SentinelOne Token](https://github.com/theadamcraig/jamf-scripts/blob/master/SentinelOne/screenshots/SentinelOne_registration_token.png)

### 3. Create a new policy with whatever Scope and Trigger desired.

### 4. Add the package for SentinelOne to the policy. 

Make sure to set the Action to Cache

![SentinelOne Package Cache](https://github.com/theadamcraig/jamf-scripts/blob/master/SentinelOne/screenshots/SentinelOne_Policy_Packages.png)

### 5. Add the sentinelone_postinstall.sh script to the policy

set the Priority to After

As variable $4 add the full name of the .pkg that is being cached.

![SentinelOne Script](https://github.com/theadamcraig/jamf-scripts/blob/master/SentinelOne/screenshots/SentinelOne_Policy_Scripts.png)

### 6. Save the policy

Caching the package puts it into /Library/Application Support/JAMF/Waiting Room/

the postinstall script will look for it there and install/upgrade it with your token as needed.

I've also included an Extension attribute that can be used to create smartgroups for scoping sentinel one Updates.
