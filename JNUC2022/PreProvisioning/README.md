# Userproof Onboarding:
## Backup Plans for Zero Touch for IT
Presented during JNUC 2022

### CacheInitialConfig Policy

Create a policy that caches the JAMFInitialConfig-1.6.pkg 

![Cache_InitialConfig_Policy](https://github.com/theadamcraig/jamf-scripts/blob/master/JNUC2022/Screenshots/Cache_InitialConfig_Policy.png)

This policy should also update inventory.

That will put computers with into the InitialConfig - Cached Smart Group

![Cache_InitialConfig_SmartGroup](https://github.com/theadamcraig/jamf-scripts/blob/master/JNUC2022/Screenshots/Cache_InitialConfig_SmartGroup.png)

You want to target this SmartGroup with a policy that runs the InitialConfig - Install Cached LaunchDaemon.sh script

![Install_Cached_LaunchDaemon](https://github.com/theadamcraig/jamf-scripts/blob/master/JNUC2022/Screenshots/Install_Cached_LaunchDaemon.png)


### PreProvisioning

I've made a generic version of the PreProvisioning script we use that allows users to get the InitialConfig user experience.

I encourage you to look through this script and customize it for your environment.

Make sure to update the variables section appropriately

![PreProvision_Variables](https://github.com/theadamcraig/jamf-scripts/blob/master/JNUC2022/Screenshots/PreProvision_Variables.png)

You will also need to update the CoreInstalls section 

![PreProvision_CoreInstalls](https://github.com/theadamcraig/jamf-scripts/blob/master/JNUC2022/Screenshots/PreProvision_CoreInstalls.png)

Make sure to have corresponding policies for all of the applications you are directing the CoreInstalls section to install.

