#!/bin/bash

ATTRIBUTE="tech.rocketman.backdooradmin.plist"
FIELDNAME="Password"

EXTATTRPLIST="/Library/Preferences/${ATTRIBUTE}"
if [[ -f "${EXTATTRPLIST}" ]]; then
	RESULT=$(/usr/bin/defaults read "${EXTATTRPLIST}" ${FIELDNAME})
else
	RESULT="WARNING: Unable to read file. Will try again at next inventory."
fi

echo "<result>${RESULT}</result>"
