#!/bin/zsh

## written by theadamcraig https://github.com/theadamcraig/jamf-scripts/
## this script should be in the same directory as three text files
## adjectives.txt
## nouns.txt
## verbs.txt

## Optional arguments
# --min Minimum characters for words default is 1
# --max Maximum characters for words default is 9
# --debug show full logging
# --caps capitalize the first letter of every word. Default is no

# Goal is to re-write pass_phrase.py in a way that will allow it to be used without python.
#https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel

#hard code the default

debug=0
# do you want to capitalize the first letter of each word
capitals="no"
## So we could easily change the divider between space - or none.
div=""


debugEcho() {
	local text="${1}"
	if [[ $debug = 1 ]] ; then
		echo "${text}"
	fi
	}

## process flags
while test $# -gt 0 ; do
    case "${1}" in
        --min)
        	shift 
        	minLength="$1"
        	;;
        --max)
        	shift
        	maxLength="$1"
        	;;
        --debug) debug=1
        	;;
        --caps) capitals="yes"
        	;;
    esac
    shift
done

debugEcho "DEBUG=$debug"

workingDirectory=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
debugEcho "Working Directory Is: ${workingDirectory}"

adjList="${workingDirectory}/adjectives.txt"
nounList="${workingDirectory}/nouns.txt"
verbList="${workingDirectory}/verbs.txt"

if [[ ! -e "${adjList}" ]] ; then
	debugEcho "Adjective List not found"
	exit 1
fi

if [[ ! -e "${nounList}" ]] ; then
	debugEcho "Noun List not found"
	exit 1
fi

if [[ ! -e "${verbList}" ]] ; then
	debugEcho "Verb List not found"
	exit 1
fi

debugEcho "Raw min: $minLength";
debugEcho "Raw max: $maxLength";

##Make sure minLength is an int. set it to 1 if it is empty or not an int
case $minLength in
    ''|*[!0-9]*) debugEcho bad ; minLength=1 ;;
    *) debugEcho good ;;
esac

## makesure maxLength is an int. set it to 9 if it is empty or not an int.
case $maxLength in
    ''|*[!0-9]*) debugEcho bad ; maxLength=9 ;;
    *) debugEcho good ;;
esac


if [[ $minLength -gt $maxLength ]] ; then
	debugEcho "minLength greater than maxLength. swithgin varibales"
	tempVar=$minLength
	minLength=$maxLength
	maxLength=$tempVar
fi

debugEcho "min: $minLength";
debugEcho "max: $maxLength";

#Let's get our words into arrays
declare -a adjArray
adjArray=($(cat "$adjList"))
debugEcho "loaded ${#adjArray[@]} Adjectives"

declare -a nounArray
nounArray=($(cat "$nounList"))
debugEcho "loaded ${#nounArray[@]} Nouns"

declare -a verbArray
verbArray=($(cat "$verbList"))
debugEcho "loaded ${#verbArray[@]} Verbs"

## ELIMINATE ALL WORDS THAT DON"T FIT THE Min/max length requirements and spit the array back out
checkWordLength(){
	local array=("$@")
	for i in "${!array[@]}" ; do
		#debugEcho "checking ${array[i]}"
		## ${#string} prints the length
		if [[ ${#array[i]} -lt $minLength ]] || [[ ${#array[i]} -gt $maxLength ]] ; then 
			#debugEcho "removing ${array[i]}"
			##invalid length remove item
			unset 'array[i]'
		fi
	done
	#debugEcho "arrayCount= ${#array[@]}"
	echo "${array[@]}"
}

adjArray=($(checkWordLength "${adjArray[@]}"))
debugEcho "refined ${#adjArray[@]} Adjectives"
#declare -p adjArray

nounArray=($(checkWordLength "${nounArray[@]}"))
debugEcho "refined ${#nounArray[@]} Nouns"

verbArray=($(checkWordLength "${verbArray[@]}"))
debugEcho "refined ${#verbArray[@]} Verbs"

getRandomWord(){
	local array=("$@")
	# the random range excludes the top end of the range so we don't need to subtract 1.
	randMax=${#array[@]}
	#debugEcho "maximum index is $randMax"
	index=$(( $RANDOM % $randMax + 0 ))
	#debugEcho "random index is $index"
	local word="${array[$index]}"
	# Enfocre Lower case
	word=$(echo $word | tr '[:upper:]' '[:lower:]')
	#Capitalize first letter of each word
	if [[ "${capitals}" == "yes" ]] ; then
		word="$(tr '[:lower:]' '[:upper:]' <<< ${word:0:1})${word:1}"
	fi
	echo $word
}

### Example command to get a random word
# word=$(getRandomWord "${adjArray[@]}")

## Now let's make a password

## adjective noun verb digit adjective noun
adj1=$(getRandomWord "${adjArray[@]}")
debugEcho "$adj1"
noun1=$(getRandomWord "${nounArray[@]}")
debugEcho "$noun1"
verb=$(getRandomWord "${verbArray[@]}")
debugEcho "$verb"
digit=$(( $RANDOM % 10 + 0 ))
debugEcho "$digit"
adj2=$(getRandomWord "${adjArray[@]}")
debugEcho "$adj2"
noun2=$(getRandomWord "${nounArray[@]}")
debugEcho "$noun2"

password="${adj1}${div}${noun1}${div}${verb}${div}${digit}${div}${adj2}${div}${noun2}"
echo "$password"

exit 0
