#!/bin/bash

## based on script found at: AT https://github.com/therealmacjeezy/Scripts/blob/master/LAPS%20for%20Mac/LAPSforMac.sh

## CLEANUP!

## IF THE PASSWORD FILE IS STILL THERE IT'LL UPDATE THE JAMF RECORD


########### Parameters (Required) ###############
# 4 - API Username String
# 5 - API Password String


passLocation="/Library/Application Support/COMPANYNAME/rescue"
#get the filepath
pathLocation=$(dirname "$passLocation")
#make sure the filepath exists
mkdir -p "$pathLocation"

if [[ -e $passLocation ]] ;then
	echo "temp file exists! Continue"
else
	echo "Temp file missing. Password should already be in Jamf"
	exit 0
fi

jssURL="https://domain.jamfcloud.com"
udid=$(/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/awk '/Hardware UUID:/ { print $3 }')
## extAttName also needs to be changed in the curl command in setEAStatus function.
extAttName="\"RescuePassword\""
getPass=$(cat "$passLocation")
echo "$getPass"

# Account Information
if [[ -z "$4" ]]; then 
    echo "Error: API USER MISSING"
    exit 1
else
	apiUser="$4"  
	echo "$apiUser"      
fi

if [[ -z "$5" ]]; then
	echo "Error: API PASS MISSING"
    exit 1        
else
	apiPass="$5"
	echo "$apiPass"
fi

# Request Auth Token
authToken=$( /usr/bin/curl \
--request POST \
--silent \
--url "$jssURL/api/v1/auth/token" \
--user "$apiUser:$apiPass" )

echo "$authToken"

# parse auth token
token=$( /usr/bin/plutil \
-extract token raw - <<< "$authToken" )

tokenExpiration=$( /usr/bin/plutil \
-extract expires raw - <<< "$authToken" )

localTokenExpirationEpoch=$( TZ=GMT /bin/date -j \
-f "%Y-%m-%dT%T" "$tokenExpiration" \
+"%s" 2> /dev/null )

echo Token: "$token"
echo Expiration: "$tokenExpiration"
echo Expiration epoch: "$localTokenExpirationEpoch"

setEAStatus() {

echo "setting EA status"

apiData="<computer><extension_attributes><extension_attribute><name>RescuePassword</name><type>String</type><input_type><type>Text Field</type></input_type><value>${getPass}</value></extension_attribute></extension_attributes></computer>"
echo ${apiData}

fullURL="$jssURL/JSSResource/computers/udid/$udid/subset/extension_attributes"
echo ${fullURL}

# apiPost=$(curl -s -f -u $apiUser:"$apiPass" -X "PUT" ${fullURL} -H "Content-Type: application/xml" -H "Accept: application/xml" -d "${apiData}" 2>&1 )

apiPost=$( /usr/bin/curl \
--header "Content-Type: text/xml" \
--request PUT \
--data "$apiData" \
--silent \
--url "$fullURL" \
--header "Authorization: Bearer $token" \
2>&1 \
)

/bin/echo ${apiPost}

#rm -f /tmp/pwlaps
}

uploadCheck() {
echo "Checking Password"
# checkPass=$(curl -s -f -u $apiUser:"$apiPass" -H "Accept: application/xml" $jssURL/JSSResource/computers/udid/$udid/subset/extension_attributes | xpath "//extension_attribute[name=$extAttName]" 2>&1 | awk -F'<value>|</value>' '{print $2}')
checkPass=$( /usr/bin/curl \
--header "Accept: text/xml" \
--request GET \
--silent \
--url "$jssURL/JSSResource/computers/udid/"$udid"/subset/extension_attributes" \
--header "Authorization: Bearer $token" | xpath "//extension_attribute[name=$extAttName]" 2>&1 | awk -F'<value>|</value>' '{print $2}' )
echo " "
# echo "full Check pass results"
# echo "$checkPass"
# echo " "
echo " "
checkPass=$(echo "$checkPass" | tr -d '\040\011\012\015')
echo "$checkPass"
echo "getPass"
echo "$getPass"

if [[ "$checkPass" == "$getPass" ]] ; then
	echo "password uploaded successfully"
	rm -f "$passLocation"
else
	echo "password failed to upload to jamf"
	echo "verifying failed"
	alternateUploadCheck
fi
}


alternateUploadCheck() {
echo "Checking Password"
# fullResult=$(curl -s -f -u $apiUser:"$apiPass" -H "Accept: application/xml" $jssURL/JSSResource/computers/udid/$udid/subset/extension_attributes)

fullResult=$( /usr/bin/curl \
--header "Accept: text/xml" \
--request GET \
--silent \
--url "$jssURL/JSSResource/computers/udid/$udid/subset/extension_attributes" \
--header "Authorization: Bearer $token" )

trimmedResult=$( echo $fullResult | grep '<name>$extAttName</name><type>String</type><multi_value>false</multi_value><value>' )
echo "$trimmedResult"

newline=$'\n'
trimmed2=$(echo "${trimmedResult//'$extAttName -Local'/$newline}")
echo " "
echo " "
echo "trimmed again"
echo "$trimmed2"
trimmed3=$(echo "${trimmed2//'$extAttName'/'${newline}$RescuePassword'}" | grep "$extAttName" | awk -F'<value>|</value>' '{print $2}' )
echo " "
echo " "
echo "trimmed again"
echo "$trimmed3"
echo " "
echo " "
checkPass=$(echo "$trimmed3" | tr -d '\040\011\012\015')
echo "$checkPass"
echo "getPass"
echo "$getPass"

if [[ "$checkPass" == "$getPass" ]] ; then
	echo "password uploaded successfully"
	rm -f "$passLocation"
else
	echo "password failed to upload to jamf"
	echo "trying again."
	setEAStatus
fi

}

uploadCheck

# expire auth token
/usr/bin/curl \
--header "Authorization: Bearer $token" \
--request POST \
--silent \
--url "$jssURL/api/v1/auth/invalidate-token"

# verify auth token is valid
checkToken=$( /usr/bin/curl \
--header "Authorization: Bearer $token" \
--silent \
--url "$jssURL/api/v1/auth" \
--write-out "%{http_code}" )

tokenStatus=${checkToken: -3}
# Token status should be 401
echo "Token status: $tokenStatus"

exit 0

