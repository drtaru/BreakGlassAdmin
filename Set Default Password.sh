#!/bin/bash

: HEADER = <<'EOL'

██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗███╗   ███╗ █████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   ██╔████╔██║███████║██╔██╗ ██║
██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

        Name: Set Default Password
 Description: For use with Breakglass Admin.

              The main script creates the account on the first run and then
              rotates the password on subsequent runs.

              For organizations that what to leverage and existing backdoor
              account instead, this script will store the current password
              in the client-side and/or server-side attributes for future runs.

  Parameters: $1-$3 - Reserved by Jamf (Mount Point, Computer Name, Username)
              $4 - Current password for existing user
              $5 - Name of extension attribute where password is stored
                   (e.g. "Breakglass Admin")
              $6 - Storage method: Provide BASE64 encoded "user:password" for
                                   storage via API. Otherwise locally stored.
              $11- Overrides (optional) - See GitHub for usage

Latest version and additional notes available at our GitHub
		https://github.com/Rocketman-Tech/BreakGlassAdmin

EOL

##
## Create settings from Policy Parameters
##

## Existing password for admin user
NEWPASS="$4" ## No default - will error if missing

## Name of the extension attribute to store password
EXTATTR=$([ "$5" ] && echo "$5" || echo "Breakglass Admin")

## API User "Hash" - Base64 encoded "user:password" string for API use
APIHASH=$([ "$6" ] && echo "$6" || echo "")

## Other Main Defaults
## These can either be harcoded here or overriden with $11 (see below)
STOREREMOTE="" ## Set to 'Yes' below -IF- APIHASH is provided
STORELOCAL=""  ## Set to 'Yes' below -IF- no APIHASH or overriden
LOCALPATH="/Library/Preferences"
LOCALPREFIX="tech.rocketman"

## Allow for overrides of everything so far...
## If the 11th policy parameter contains an equal sign, run eval on the
## whole thing.
## Example: If $11 is 'NUM=5;HIDDENFLAG=;FORCE=1;STORELOCAL="Yes"', then
##  the values of the variables with the same name of those above would change.
## WARNING! This would be HORRIBLE security in a script that remains local
##          as any bash-savvy user could inject whatever code they wanted to.
##          This danger is LESSENED by the fact that the parameters are
##          provided at run-time by Jamf and the script is not stored on
##          the computer outside the policy run.
[[ "$11" == *"="* ]] && eval ${11} ## Comment out to disable

## Finalize storage options
if [ ${APIHASH} ]; then
  STOREREMOTE="Yes"
  APIURL=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url)
  SERIAL=$(system_profiler SPHardwareDataType | grep -i serial | grep system | awk '{print $NF}')
else
  STORELOCAL="Yes"
fi
if [ $STORELOCAL ]; then
  ## The local file will use the same name but without anything but letters
  ## E.g. "Hidden Admin's Password" becomes "HiddenAdminsPassword"
  ATTRABBR=$(echo ${EXTATTR} | tr -dc '[:alpha:]')
  LOCALEA="${LOCALPATH}/${LOCALPREFIX}.${ATTRABBR}.plist"
fi


function storeCurrentPassword() {

	if [[ ${STORELOCAL} ]]; then
		## If the file doesn't exist, make it and secure it
		if [[ ! -f "${LOCALEA}" ]]; then
			touch "${LOCALEA}"
			chown root:wheel "${LOCALEA}"
			chmod 600 "${LOCALEA}"
		fi
		## Store the password locally for pickup by Recon
		/usr/bin/defaults write "${LOCALEA}" Password -string "${NEWPASS}"
  fi

  if [[ ${STOREREMOTE} ]]; then
		# Store the password in Jamf
		XML="<computer><extension_attributes><extension_attribute><name>${EXTATTR}</name><value>${NEWPASS}</value></extension_attribute></extension_attributes></computer>"
		debugLog "XML: ${XML}"
		curl -sk \
    -H "Authorization: Basic ${APIHASH}" \
    -H "Content-type: application/xml" \
    "${APIURL}JSSResource/computers/serialnumber/${SERIAL}" \
    -X PUT \
    -d "${XML}"
	fi
}

##
## Main Script
##

if [[ if ${NEWPASS} ]]; then
  storeCurrentPassword
  EXIT=0
else
  echo "ERROR: No password provided!"
  EXIT=1
fi

exit ${EXIT}
