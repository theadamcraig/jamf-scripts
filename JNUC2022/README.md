# Userproof Onboarding:
## Backup Plans for Zero Touch for IT
Presented during JNUC 2022

These are the scripts referenced during my JNUC 2022 talks and additional supplemental scripts.

### Jamf Enrollment Kickstarter

I recommend using [https://github.com/Yohan460/JAMF-Enrollment-Kickstart](https://github.com/Yohan460/JAMF-Enrollment-Kickstart)
Johan McGuire's JNUC 2019 talk
[https://www.youtube.com/watch?v=MhoHgC7AAUI](https://www.youtube.com/watch?v=MhoHgC7AAUI)


### Install Rosetta During Prestage Enrollment

You can use the Custom Package Rosetta 2 Preinstall.sh script as a preinstall script on a signed package

if this is a part of your prestage enrollment then computers will install rosetta during prestage.

This is how I set this up in Composer
![ComposerPreinstall](https://github.com/theadamcraig/jamf-scripts/blob/master/JNUC2022/Screenshots/ReferenceFile_Rosetta_Preinstall.png)

This is how I set his up the packages in prestage enrollment
![PrestageEnrollment](https://github.com/theadamcraig/jamf-scripts/blob/master/JNUC2022/Screenshots/Prestage_Enrollment_Packages.png)

### Jamf Connect - Installed Check

This script checks to make sure Jamf Connect is installed and owns the login window process. It should resolve issues where the prestage .pkg with Jamf Connect did not install properly.

Have script automatically re-run on failure. Scope to a smart group of Last Enrollment is Less than 24 hours.

Make sure to have a policy available with the custom trigger `jamfconnect` to install Jamf Connect. Or update the custom trigger in the script.

### InitialConfig - Complete Check and Receipt write

There is a lot that will need updated with this script.

It is set to check if GlobalProtect has the correct portal and is connected. The VPN sections will need rewritten if not using GlobalProtect

update the coreAppArray to the list of applications you are installing during your setup.

There are a number of different dialogs and images that are possible.

This script is set to use IBM notifier for all dialog boxes.