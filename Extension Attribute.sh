#!/bin/bash

: HEADER = <<'EOL'

██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗███╗   ███╗ █████╗ ███╗   ██╗
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝████╗ ████║██╔══██╗████╗  ██║
██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   ██╔████╔██║███████║██╔██╗ ██║
██╔══██╗██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   ██║╚██╔╝██║██╔══██║██║╚██╗██║
██║  ██║╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   ██║ ╚═╝ ██║██║  ██║██║ ╚████║
╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
EOL

## In the Breakglass Admin script, if local storage is used, the password
## is stored in a plist with the following ownership/permissions:
##	root:wheel - 600 (owner=rwx, all others=no access)
## The default location is "/Library/Preferences" with the default name:
## 	tech.rocketman.{{EXTATTR}}.plist
## where {{EXTATTR}} is the name provided in the policy.
## The name specified below must match the one used in your policies.
ATTRIBUTE="tech.rocketman.breakglassadmin.plist"
FIELDNAME="Password"

EXTATTRPLIST="/Library/Preferences/${ATTRIBUTE}"
if [[ -f "${EXTATTRPLIST}" ]]; then
	RESULT=$(/usr/bin/defaults read "${EXTATTRPLIST}" ${FIELDNAME})
else
	RESULT="WARNING: Unable to read file. Will try again at next inventory."
fi

echo "<result>${RESULT}</result>"
