# Rescue Account

The goal of a rescue account is to have a local account on the computer that you can give the user the password to. If a remote user forgets their password or gets locked out of their account you can give them the randomly generated rescue account password. This will allow them to get past Filevault and access the internet. Policies will run, and the user can use Self Service.

These are instructions on how to use the setup these rescue account policies with Jamf

### 1. Generate adjective.txt nount.txt & verb.txt files
I'm not providing these files, there are a lot of lists you can find online, I also recommend cleaning them of NSFW words to prevent having to awkwardly tell someone a very dirty sounding password.

pass_phrase.sh is expecting them to be formmatted like this:

![adjective.txt example](https://github.com/theadamcraig/jamf-scripts/blob/master)

### 2. Install the pass_phrase.sh script and .txt files onto users computers.

We put them in:
>/Library/Application Support/COMPANYNAME/passphrase

This filepath will need updated in a number of locations

![passphrase folder setup](https://github.com/theadamcraig/jamf-scripts/blob/master/SentinelOne/)

### 3. Setup the Rescue Password extension attribute

This is a text field EA that will be updated by the API

![Rescue Password EA](https://github.com/theadamcraig/jamf-scripts/blob/master/SentinelOne/)

### 4. Setup the Rescue Password - local extension attribute

Make sure to update the COMPANYNAME filepath

![Rescue Password - Local EA](https://github.com/theadamcraig/jamf-scripts/blob/master/SentinelOne/)
