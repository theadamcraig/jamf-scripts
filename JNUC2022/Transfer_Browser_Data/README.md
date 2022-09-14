# Userproof Onboarding:
## Backup Plans for Zero Touch for IT
Presented during JNUC 2022

These are the scripts referenced during my JNUC 2022 talks and additional supplemental scripts.

### Backup and Restore Browser Data

These scripts will Back up Browser data from a supported browser to a local folder that syncs to a cloud service. (specifically OneDrive, but it also should work with Google Drive, Dropbox or other services.)

it does this by Zipping ~/Library/Application Support/AppName and copying that to a hidden folder in the OneDrive folder.

The Restore Browser Data script looks for the backup and replaces the same folder on the new computer.

These policies are intended for use via SelfService and provide a convenient way for users to move bookmarks, history and tabs from an old computer to a new computer.

![selfservice_browser_data](https://github.com/theadamcraig/jamf-scripts/blob/master/JNUC2022/Screenshots/selfservice_browser_data.png)

Supported Browsers are Google Chrome, Firefox, and Brave Browser.

Make sure to update the onedrive_folder="$home_root/OneDrive - CompanyName" Variable in both locations with the destination that the backup will be stored in.

