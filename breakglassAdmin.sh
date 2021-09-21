#!/bin/bash

################################
##/////////////////////)######## Break Glass Admin
##|                      )######
##|                        )#### Creates and/or changes the password of a
##|                         )### backdoor admin account for emergency use
##|         #######)         )##
##|         ########)        )## TYPE: Jamf Policy Script
##|         #######)        )###
##|                         )### Parameters:
##|                       )##### $1-3 - Reserved by Jamf
##|                      )###### $4 - Username of admin account
##|      |  ####\         \##### $5 - Full name of admin account
##|      |  #####\         \#### $6 - Password generation method (see code)
##|    | |  ######\         \### $7 - Storage method (see code)
##|  | | |  #######\         \## $8 - Extension Attribute for password storage
################################ $9 - Force (y/n) (see code)
##
## Latest version and additional notes available at our GitHub
##      https://github.com/Rocketman-Tech/MakeMeAnAdmin
##
################################################################################

## Get the policy variables
ADMINUSER="$4" 	## What is the name of the admin user to change/create
ADMINFULL="$5" 	## Full name of admin user
PASSMODE="$6"	## Which method to use to create the password (nato, xkcd, names, pseudoRandom)
STORAGE="$7" 	## "LOCAL" or Base64 encoded "user:password" string
EXTATTR="$8" 	## Name of the extension attribute where password is stored
				##	(e.g. "Backdoor Admin Password" for cloud or "tech.rocketman.backdooradmin.plist" for local)
FORCE="$9"		## 1 (true) or 0 (false) - If true and old password is unknown or can't be changed,
				##	the script will delete the account and re-create it instead.
				##	USE WITH EXTREME CAUTION!

## Set additional variables based on local or remote storage
if [[ ${STORAGE} == "LOCAL" ]]; then
	LOCALEA="/Library/Preferences/${EXTATTR}"
else
	STORAGE="REMOTE" ## Store in Jamf Pro as Extension Attribute
	APIHASH=$7
	APIURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
	SERIAL=$(system_profiler SPHardwareDataType | grep -i serial | grep system | awk '{print $NF}')
fi

#################
### FUNCTIONS ###
#################

function debugLog () {
	message=$1
	timestamp=$(date +'%H%M%S')

	echo "${timestamp}: ${message}" >> /tmp/debug.log
}

function createRandomPassword() {
	system=$1

	case "$system" in

		nato) ## Using NATO Letters (e.g. WhiskeyTangoFoxtrot)
			NUM=3
			NATO=(Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel India Juliet Kilo Lima Mike November Oscar Papa Quebec Romeo Sierra Tango Uniform Victor Whiskey Yankee Zulu)
			MAX=${#NATO[@]}
			NEWPASS=$(for u in $(jot -r ${NUM} 0 $((${MAX}-1)) ); do  echo -n ${NATO[$u]} ; done)
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

		pseudoRandom | *) ## Based on University of Nebraska' LAPS system (https://github.com/NU-ITS/LAPSforMac)
			NUM=16
			NEWPASS=$(openssl rand -base64 100 | tr -d OoIi1lLS | head -c${NUM};echo)

	esac

	echo ${NEWPASS}
}

function createHiddenAdmin() {

	## Using the built-in jamf tool which beats the old way which doesn't work
	## across all OS versions the same way.
    echo "Creating ${ADMINUSER}"
	/usr/local/bin/jamf createAccount -username ${ADMINUSER} -realname "${ADMINFULL}" -password "${NEWPASS}" –home /private/var/${ADMINUSER} –shell “/bin/zsh” -hiddenUser -admin -suppressSetupAssistant
}

function changePassword() {

	## Delete keychain if present
	if [[  -f "~/${ADMINUSER}/Library/Keychains/login.keychain" ]]; then
		rm "~${ADMINUSER}/Library/Keychains/login.keychain"
	fi

	## Change password
	/usr/local/bin/jamf changePassword -username ${ADMINUSER} -oldPassword "${OLDPASS}" -password "${NEWPASS}"

	## If we are forcing the issue
	if [[ $? -ne 0 ]]; then ## Error
		if [[ ${FORCE} ]]; then
			echo "Time to fix"
			/usr/local/bin/jamf deleteAccount -username ${ADMINUSER} -deleteHomeDirectory
			createHiddenAdmin
		else
			## Log it
			NEWPASS="EXCEPTION - Password change failed"
		fi
	fi

}

function getCurrentPassword() {
	if [[ ${STORAGE} == "LOCAL" ]]; then
		if [[ -f "${LOCALEA}" ]]; then
			CURRENTPASS=$(/usr/bin/defaults read "${LOCALEA}" Password 2>/dev/null)
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
		## Store the password locally for pickup by Recon
		/usr/bin/defaults write "${LOCALEA}" Password -string "${NEWPASS}"
	else
		# Store the password in Jamf
		XML="<computer><extension_attributes><extension_attribute><name>${EXTATTR}</name><value>${NEWPASS}</value></extension_attribute></extension_attributes></computer>"
		debugLog "XML: ${XML}"
		/usr/bin/curl -k -H "Authorization: Basic ${APIHASH}" "${APIURL}JSSResource/computers/serialnumber/${SERIAL}" -H "Content-type: application/xml" -X PUT -d "${XML}"
	fi
}

############
### Main ###
############

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
