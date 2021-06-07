# BreakGlassAdmin
<img src="images/breakglass.jpg" height="200" align=right>

A workflow to create/manage a backdoor admin account *(e.g. 'breakglass')* with a password that is unique to each computer, rotate the password regularly, and make the password available in Jamf for use. _(E.g. Another LAPS workflow.)_

<!-- TOC depthFrom:2 depthTo:6 withLinks:1 updateOnSave:0 orderedList:0 -->

- [Background](#background)
- [Usage](#usage)
	- [Admin Username and Password](#admin-username-and-password)
	- [Available Password Methods](#available-password-methods)
	- [Storage Method](#storage-method)
	- [Extension Attribute](#extension-attribute)
	- [Force / Destructive](#force-destructive)
- [Future Upgrades](#future-upgrades)
- [Warnings and Disclaimers](#warnings-and-disclaimers)

<!-- /TOC -->

## Background

Where there are several other implementations of LAPS for Macs out in the Jamf Nation and Mac Admins communities, this version was created to serve as a single solution for all our clients that can be configured through policy parameters.

## Usage

Towards the top of the script is the following header/parameter block:

```
ADMINUSER="$4"  ## What is the name of the admin user to change/create
ADMINFULL="$5"  ## Full name of admin user
PASSMODE="$6"   ## Which method to use to create the password (nato, xkcd, names, pseudoRandom)
STORAGE="$7"    ## "LOCAL" or Base64 encoded "user:password" string
EXTATTR="$8"    ## Name of the extension attribute where password is stored
                ##	(e.g. "Backdoor Admin Password" for cloud or "tech.rocketman.backdooradmin.plist" for local)
FORCE="$9"      ## 1 (true) or 0 (false) - If true and old password is unknown or can't be changed,
                ##	the script will delete the account and re-create it instead.
                ##	USE WITH EXTREME CAUTION!
```

#### Admin Username and Password
The first two options (*ADMINUSER* and *ADMINFULL*) are probably self-explanatory. This is for the name of the local admin account to be created or have its password rotated.

#### Available Password Methods
There are four options/schemes for generating passwords:

```
nato)                ## Using NATO Letters (e.g. WhiskeyTangoFoxtrot)
xkcd)                ## Using the system from the XKCD webcomic (https://xkcd.com/936/) (e.g. CorrectHorseBatteryStaple)
names)               ## Uses the same scheme as above but only with the propernames database (e.g. AliceBobEveMallory)
pseudoRandom | *)    ## Based on University of Nebraska' LAPS system (https://github.com/NU-ITS/LAPSforMac)
```
#### Storage Method

Either enter "LOCAL" or the Base64 encoded "user:password" string for a Jamf Pro user with READ and UPDATE access for the Computers object.

#### Extension Attribute

If the *Storage Method* above is an *Authentication: Basic* string, this field should be the name of an Extension Attribute of type 'string' to store the password.

If the *Storage Method* is "LOCAL," this field will be the name of the plist file at */Library/Preferences/* where the password is stored.

In this same repository is a sample of a script-based extension attribute to pull the password and store it in Jamf during an inventory update.

***WARNING:*** At this time, if you use the local storage option, the password is stored in clear text. Please make sure the owner, group, and permissions on the file match the security needs for your team. A later version of this script will encrypt the password for local storage.

***Note:*** In a future version, there will be an option for both local *and* remote storage.

#### Force / Destructive

If this is true ('1') and for some reason the script can't retrieve the old password (*e.g. API failure on previous run, local file deletion, etc.) then the script will attempt to delete the account and re-create it.

***WARNING:*** If the backdoor admin account has files/preferences and this option is selected, those files *will* be deleted! Use at your own risk!

## Future Upgrades

* Add option to store password locally *and* via API call at the same time
* Add capability to encrypt and decrypt the password during local storage

## Warnings and Disclaimers

This script is provided as-is. While we do our best to make sure it will work as described and without harmful side-effects, there are no guarantees. Use at your own risk.
