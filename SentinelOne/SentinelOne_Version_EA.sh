#!/bin/bash

if [ -f "/usr/local/bin/sentinelctl" ] ; then 
    RESULT=$( /usr/local/bin/sentinelctl version | awk '{print $2 $3}' )
else
    RESULT="not installed"
fi

echo "<result>$RESULT</result>"