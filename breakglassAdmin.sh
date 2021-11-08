#!/bin/bash

: HEADER = <<'EOL'

██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗███╗   ███╗ █████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   ██╔████╔██║███████║██╔██╗ ██║
██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

        Name: Break Glass Admin
 Description: Creates/manages a hidden admin account with a random password
  Parameters: $1-$3 - Reserved by Jamf (Mount Point, Computer Name, Username)
              $4 - The name of the admin account
              $5 - Which method of creating a password to use (see below)
              $6 - Storage method:
                   "LOCAL" or Base64 encoded "user:password" string for API
              $7 - Name of extension attribute where password is stored
                   (e.g. "Backdoor Admin Password" for server-side or
                   "tech.rocketman.breakglass.plist" for local)
              $8 - Force (0 or 1) - If password is unknown,
                   do we delete the old account and recreate?

Available Password Methods:
            'nato' - Combines words from the NATO phonetic alphabet
                     (e.g. "WhiskeyTangoFoxtrot")
            'wopr' - Like the launch codes in the 80s movie, "Wargames"
                     [https://www.imdb.com/title/tt0086567]
                     (e.g. "CPE 1704 TKS")
            'xkcd' - Using the system from the XKCD webcomic
                     (https://xkcd.com/936)
           'names' - Same as above but only with the propernames database
    'pseudoRandom' - Based on University of Nebraska' LAPS system
                    (https://github.com/NU-ITS/LAPSforMac)
'custom' (default) - Customizable format with the following defaults
                     * 16 characters
                     * 1 Upper case character (min)
                     * 1 Lower case character (min)
                     * 1 Digit (min)
                     * 1 Special character (min)

Latest version and additional notes available at our GitHub
		https://github.com/Rocketman-Tech/BreakGlassAdmin

EOL

## Get the policy variables
ADMINUSER="$4" 	## What is the name of the admin user to change/create
PASSMODE="$5"   ## Which method to use to create the password (nato, xkcd, names, pseudoRandom)
STORAGE="$6"    ## "LOCAL" or Base64 encoded "user:password" string
EXTATTR="$7"    ## Name of the extension attribute where password is stored
                ##	(e.g. "Backdoor Admin Password" for cloud or "tech.rocketman.backdooradmin.plist" for local)
FORCE="$8"      ## 1 (true) or 0 (false) - If true and old password is unknown or can't be changed,
                ##	the script will delete the account and re-create it instead.
                ##	USE WITH EXTREME CAUTION!

## Set additional variables based on local or remote storage
if [[ ${STORAGE} == "LOCAL" ]]; then
	LOCALEA="/Library/Preferences/${EXTATTR}"
else
	STORAGE="REMOTE" ## Store in Jamf Pro as Extension Attribute
	APIHASH=$6
	APIURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
	SERIAL=$(system_profiler SPHardwareDataType | grep -i serial | grep system | awk '{print $NF}')
fi

##
## Functions
##

function debugLog () {
	message=$1
	timestamp=$(date +'%H%M%S')

	echo "${timestamp}: ${message}" >> /tmp/debug.log
}

function createRandomPassword() {
	system=$1

	case "$system" in

		nato) ## Using NATO Letters (e.g. WhiskeyTangoFoxtrot)
			NUM=4
			NATO=(Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel India Juliet Kilo Lima Mike November Oscar Papa Quebec Romeo Sierra Tango Uniform Victor Whiskey Yankee Zulu)
			MAX=${#NATO[@]}
			NEWPASS=$(for u in $(jot -r ${NUM} 0 $((${MAX}-1)) ); do  echo -n ${NATO[$u]} ; done)
			;;

		wopr) ## Like the launch codes in the 80s movie "Wargames" (e.g. "CPE 1704 TKS")
			## FWIW - The odds of getting the same code as in the movie is roughtly three trillion to one.
			PRE=$(jot -nrc -s '' 3 65 90)
			NUM=$(jot -nr -s '' 4 0 9)
			POST=$(jot -nrc -s '' 3 65 90)
			NEWPASS="${PRE} ${NUM} ${POST}"
			;;

		xkcd) ## Using the system from the XKCD webcomic (https://xkcd.com/936/)
			NUM=4
			## Get words that are betwen 4 and 6 characters in length, ignoring proper nouns
			MAX=$(awk '(length > 3 && length < 7 && /^[a-z]/)' /usr/share/dict/words | wc -l)
			CHOICES=$(for u in $(jot -r ${NUM} 0 $((${MAX}-1)) ); do awk '(length > 3 && length < 7 && /^[a-z]/)' /usr/share/dict/words 2>/dev/null | tail +${u} 2>/dev/null | head -1 ; done)
			NEWPASS=""
			for word in ${CHOICES}; do
				first=$(echo $word | cut -c1 | tr '[[:lower:]]' '[[:upper:]]')
				rest=$(echo $word | cut -c2-)
				NEWPASS=${NEWPASS}${first}${rest}
			done
			;;

		names) ## Uses the same scheme as above but only with the propernames database
			NUM=4
			MAX=$(wc -l /usr/share/dict/propernames | awk '{print $1}')
			CHOICES=$(for u in $(jot -r ${NUM} 0 $((${MAX}-1)) ); do tail +${u} /usr/share/dict/propernames 2>/dev/null | head -1 ; done)
			NEWPASS=$(echo "${CHOICES}" | tr -d "[:space:]" )
			;;

		pseudoRandom) ## Based on University of Nebraska' LAPS system (https://github.com/NU-ITS/LAPSforMac)
			NUM=16
			NEWPASS=$(openssl rand -base64 100 | tr -d OoIi1lLS | head -c${NUM};echo)
			;;

		custom* | *) ## Adjustable scheme
			## Example: "custom N=16;S=1;D=2;L=3;U=4"

			## Defaults
			N=16 # Password length
			S=1  # Minimum special characters
			U=1  # Minimum upper case
			L=1  # Minimum lower case
			D=1  # Minumum digits

			## If there are overrides passed in, use them
			INPUT=$(echo ${system} | awk '{print $2}')
			eval ${INPUT}

			## 33-126 - All the printable characters
			## 48-57 - Digits
			## 65-90 - Upper
			## 97-122 - Lower

			## Generate the minumums
			UC=($(jot -r ${U} 65 90))  ## Upper case
			LC=($(jot -r ${L} 97 122)) ## Lower Case
			NC=($(jot -r ${D} 48 57))  ## Digits
			## Special characters
			SCNA=({33..47} {58..64} {91..96} {122..126})
			SN=()
			for x in $(jot -r ${S} 0 ${#SCNA[@]}); do
				SN+=(${SCNA[$x]})
			done

			## Put the minimums together
			ALL=(${UC[@]} ${LC[@]} ${NC[@]} ${SN[@]})

			## How many more characters do we need
			LO=$(($N-$S-$U-$L-$D))
			## Pull any remaining characters from the whole set
			if [[ $LO -gt 0 ]]; then
				for x in $(jot -r $LO 33 126); do
					ALL+=(${x})
				done
			fi

			## Build the password by shuffling the bits
			passArray=()
			while [ ${#ALL[@]} -gt 0 ]; do
				i=$(jot -r 1 0 $(( ${#ALL[@]}-1 )))
				passArray+=(${ALL[$i]})
				ALL=( ${ALL[@]/${ALL[$i]}} )
			done
			NEWPASS="$(printf '%x' ${passArray[@]} | xxd -r -p)"
			;;

	esac

	echo ${NEWPASS}
}

function createHiddenAdmin() {

	## Using the built-in jamf tool which beats the old way which doesn't work
	## across all OS versions the same way.
  echo "Creating ${ADMINUSER}"
	jamf createAccount -username ${ADMINUSER} -realname "${ADMINUSER}" -password "${NEWPASS}" –home /private/var/${ADMINUSER} –shell “/bin/zsh” -hiddenUser -admin -suppressSetupAssistant
}

function changePassword() {

	## Delete keychain if present
	rm -f "~${ADMINUSER}/Library/Keychains/login.keychain"

	## Change password
	jamf changePassword -username ${ADMINUSER} -oldPassword "${OLDPASS}" -password "${NEWPASS}"

	## If we are forcing the issue
	if [[ $? -ne 0 ]]; then ## Error
		echo "ERROR: $?" >> /tmp/debug.log
		if [[ ${FORCE} ]]; then
			echo "Delete and recreate"
			jamf deleteAccount -username ${ADMINUSER} -deleteHomeDirectory
			createHiddenAdmin
		else
			## Log it
			NEWPASS="EXCEPTION - Password change failed: $?"
		fi
	fi
}

function getCurrentPassword() {
	if [[ ${STORAGE} == "LOCAL" ]]; then
		if [[ -f "${LOCALEA}" ]]; then
			CURRENTPASS=$(defaults read "${LOCALEA}" Password 2>/dev/null)
		else
			CURRENTPASS="EXCEPTION - Local attribute requested but not found"
		fi
	else
		## Get the password through the API
		CURRENTPASS=$(curl -ks -H "Authorization: Basic ${APIHASH}" -H "Accept: text/xml" ${APIURL}JSSResource/computers/serialnumber/${SERIAL}/subset/extension_attributes | xmllint --xpath "//*[name='${EXTATTR}']/value/text()" -)
	fi

	## Pass it back
	echo $CURRENTPASS
}

function storeCurrentPassword() {

	if [[ ${STORAGE} == "LOCAL" ]]; then
		## If the file doesn't exist, make it and secure it
		if [[ ! -f "${LOCALEA}" ]]; then
			touch "${LOCALEA}"
			chown root:wheel "${LOCALEA}"
			chmod 600 "${LOCALEA}"
		fi

		## Store the password locally for pickup by Recon
		/usr/bin/defaults write "${LOCALEA}" Password -string "${NEWPASS}"
	else
		# Store the password in Jamf
		XML="<computer><extension_attributes><extension_attribute><name>${EXTATTR}</name><value>${NEWPASS}</value></extension_attribute></extension_attributes></computer>"
		debugLog "XML: ${XML}"
		curl -k -H "Authorization: Basic ${APIHASH}" "${APIURL}JSSResource/computers/serialnumber/${SERIAL}" -H "Content-type: application/xml" -X PUT -d "${XML}"
	fi
}

##
## Main
##

## See if the user exists
EXISTS=$(id ${ADMINUSER} 2>/dev/null | wc -l | awk '{print $NF}')
debugLog "Exists: ${EXISTS}"

## Either way, we'll need a random password
NEWPASS=$(createRandomPassword ${PASSMODE})
debugLog "NewPass: ${NEWPASS}"

## Are we creating the user or changing their password
if [[ $EXISTS -gt 0 ]]; then
	debugLog "Exists: Changing"

	## Get the existing password
	OLDPASS=$(getCurrentPassword)
	debugLog "Old: ${OLDPASS}"

	## Exception Block
	## This was added to handle the computers that had an account prior to enrollment.
	## To change a password this, we need to know the old one. Now it also handles change failures and more.
	##
	## ADDITIONAL NOTE: If the record for any previous computer is updated with the correct password
	##		this script will run normally next time and update with a random password
	##
	case ${OLDPASS} in
		"")
			debugLog "Unknown - create exception"
			## The account was created before and is unknown
			NEWPASS="EXCEPTION - Unknown password"
			;;

		EXCEPTION*)
			debugLog "Previous exception - ${OLDPASS}"
			if [[ ${FORCE} ]]; then
				## Request a password change with known bad data to trigger refresh
				OLDPASS="NULL"
				changePassword
			else
				NEWPASS=${OLDPASS}
			fi
			;;

		*)
			debugLog "Changing from ${OLDPASS} to ${NEWPASS}"
			## Change the password
			changePassword
			;;
	esac
	## End exception block

else

	## Create the account
	debugLog "Creating new admin"
	## Create the user
	createHiddenAdmin

fi

## Store the new password
storeCurrentPassword

## Store and clear the debug log
if [[ -f /tmp/debug.log ]]; then
	echo $(cat /tmp/debug.log)
	rm /tmp/debug.log
fi

exit 0
