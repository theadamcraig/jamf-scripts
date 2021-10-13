#!/bin/bash
## Based on script found at https://macadmins.slack.com/archives/CAL8UHH1N/p1576618800010400?thread_ts=1576576382.005200&cid=CAL8UHH1N

## Update the Cert Subject on line 28 and the email address format on line 51

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] || [[ "$loggedInUser" == "_mbsetupuser" ]] ; then
	loggedInUser="$3"
fi

loggedInUser=$( echo "$loggedInUser" | tr [:upper:] [:lower:] )

if [[ -z "$loggedInUser" ]] || [[  "$loggedInUser" == 'root' ]] || [[ "$loggedInUser" == "loginwindow" ]] ; then
	echo "Failed to gather loggedInUser correctly"
	exit 1
else
	echo "loggedInUser is $loggedInUser"
fi
# 
loggedInUID=$(id -u "$loggedInUser")

userKeychain="/Users/$loggedInUser/Library/Keychains/login.keychain-db"

# This script will remove all instances of a system keychain cert where: 
# 1) The certificate subject matches the cert subject below. 
# 2) It does not have the latest expiration date.
certSubject="YOURDOMAINHERE"
#certList=$( /bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" security find-certificate -c "${certSubject}" -p -a "${userKeychain}")

## find all certs
certList=$( /bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" security find-certificate -p -a "${userKeychain}")

#echo "$certList"

# Get each cert into an array element
# Remove spaces
certList=$( echo "$certList" | sed 's/ //g' )
# Put a space after the end of each cert
certList=$( echo "$certList" | sed 's/-----ENDCERTIFICATE-----/-----ENDCERTIFICATE----- /g' )
# echo "$certList"
OIFS="$IFS"
IFS=' '
# read -a certArray <<< "${certList}"
declare -a certArray=($certList)
IFS="$OIFS"
i=-1
dateHashList=''

## get a list of all keychain identities
identityList=`/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" security find-identity -p smime -s @YOURDOMAINHHERE.com $userKeychain`
## remove all newlines
identityList=${identityList//[$'\t\r\n']}


declare -a deleteArray=()

## Go through the certs and add all the certs in the certArray to a deleteArray if the are in the identityList string

for rawCert in "${certArray[@]}"; do
	let "i++"
	echo '--------'

	# Fix the begin/end certificate
	cert=$( echo "$rawCert" | sed 's/-----BEGINCERTIFICATE-----/-----BEGIN CERTIFICATE-----/g' )
	cert=$( echo "$cert" | sed 's/-----ENDCERTIFICATE-----/-----END CERTIFICATE-----/g' )
	certMD5=$( echo "$cert" | openssl x509 -noout -fingerprint -sha1 -inform pem | cut -d "=" -f 2 | sed 's/://g' )

	echo ""
	echo "searching identity list"
	echo "${identityList}"
	echo ""

	if [[ "${identityList}" ==  *"${certMD5}"* ]] ; then
		echo "Item found in identity list"
		echo " "
	else
		deleteArray+=( "$rawCert" )
		echo "adding '${certMD5}' to deleteArray"
	fi
done

echo "There are ${#certArray[@]} items in certArray"
echo "There are  ${#deleteArray[@]} items in deleteArray"

for target in "${deleteArray[@]}"; do
	echo ""
	echo "parsing Delete Array Item"
	#echo "$target"
	for item in "${!certArray[@]}"; do
		if [[ ${certArray[item]} == $target ]]; then 
			echo "item being unset from certArray"
			unset 'certArray[item]'
		fi
	done
done

echo "There are now ${#certArray[@]} items in certArray"


#########################################################################################
## go through the remaining certs and 
i=-1
# Print what we got...
for cert in "${certArray[@]}"; do 
  let "i++"
  echo '---------'
  #   echo "$cert"
  #   echo '--'
  # Fix the begin/end certificate
  cert=$( echo "$cert" | sed 's/-----BEGINCERTIFICATE-----/-----BEGIN CERTIFICATE-----/g' )
  cert=$( echo "$cert" | sed 's/-----ENDCERTIFICATE-----/-----END CERTIFICATE-----/g' )
  #   echo "$cert"
  #   echo "$cert" | openssl x509 -text
  certMD5=$( echo "$cert" | openssl x509 -noout -fingerprint -sha1 -inform pem | cut -d "=" -f 2 | sed 's/://g' )
  certDate=$( echo "$cert" | openssl x509 -text | grep 'Not After' | sed -E 's|.*Not After : ||' )
  certDateFormatted=`date -jf "%b %d %T %Y %Z" "${certDate}" +%Y%m%d%H%M%S`
  echo "Cert ${i} : ${certDate} => $certDateFormatted"
  echo "Cert ${i} : ${certMD5}"
  NL=$'\n'
  dateHashList="${dateHashList}${NL}${certDateFormatted} ${certMD5}"
done
echo
dateHashList=$( echo "$dateHashList" | sort | uniq )
lines=$( echo "$dateHashList" | wc -l | tr -d ' ' )
let "lines--"
echo "[info] There are $lines lines in the certificate date-hash list."
echo
i=0
OIFS="$IFS"
IFS=$'\n'       # make newlines the only separator
for dateHash in $dateHashList; do
  let "i++"
  dateNum="${dateHash%% *}"
  hash="${dateHash##* }"
  echo "${i}| Hash : \"$hash\" | dateNum : \"$dateNum\""
  if [[ i -ne $lines ]]; then
    echo "=> This cert will be removed"
	/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" security delete-identity -Z $hash "${userKeychain}"
    echo
  else
    echo "=> This cert will not be touched because it has the latest expiration date."
  fi
done
IFS="$OIFS"
exit 0
