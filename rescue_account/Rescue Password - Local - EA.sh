#!/bin/bash

passLocation="/Library/Application Support/COMPANYNAME/rescue"

if [[ -e "$passLocation" ]] ;then
	echo "temp file exists! Continue"
	result=$(cat "$passLocation")
else
	echo "Temp file missing"
	result=""
fi

echo "<result>$result</result>"
exit 0