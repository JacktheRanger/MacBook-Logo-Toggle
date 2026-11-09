-- Turns the Apple logo light on or off. Entry points:
--   - opening the app directly (Finder, Spotlight): a window that says how to add the Control Center
--     switch, shows the light's state when it can, and offers to switch the light and to turn
--     passwordless switching on or off. Nothing changes until a button is clicked: a downloaded copy
--     has to be opened once before macOS lets its Control Center switch work, and that first open
--     shouldn't ask for a password or switch the light. Opening it also ejects the installer disk
--     image if that is still mounted (eject-installer.sh);
--   - opening macbooklogotoggle://on or ://off (what the Control Center switch does): set that state;
--   - opening any other URL, such as macbooklogotoggle://launch: nothing beyond the launch itself, so a
--     mistyped or stray link never switches the light. Being launched is enough for macOS to trust a new
--     build, which the Control Center switch needs (build.sh opens ://launch after installing, see there).
-- The setting lives in root's defaults domain, so switching it needs root:
--   - with the passwordless rule: run /usr/local/libexec/logo-light through sudo -k -n, no prompt. The
--     window sets the rule up by running the bundled install-nopasswd.sh behind the admin prompt;
--   - without it: run the bundled Contents/Resources/logo-light.sh behind the admin password prompt.

property helperPath : "/usr/local/libexec/logo-light"

on run
	if runsFromDiskImage() then
		activate
		display alert "Move MacBook Logo Toggle to Applications first" message "Drag it onto the Applications folder, then open it from there. Its Control Center switch doesn't work while the app runs from the disk image." as warning
		return
	end if
	-- Installed and opened: eject the installer disk image if it's still mounted (see the script for
	-- how it is recognised). In the background, so the window doesn't wait for it.
	do shell script resourcePath("eject-installer.sh") & " >/dev/null 2>&1 &"
	showWindow()
end run

-- Compared whole, not parsed: these are the only two URLs the switch sends ("is" ignores case).
-- Deliberately no runsFromDiskImage() check here: that check keeps the first-run window off a copy on
-- the disk image, whereas a URL reaching any copy means someone tapped the switch, and switching from
-- that copy is right; refusing would turn the tap into nothing or an alert.
on open location theURL
	if theURL is "macbooklogotoggle://on" then
		switchLight("on")
	else if theURL is "macbooklogotoggle://off" then
		switchLight("off")
	end if
end open location

-- True when opened straight from the downloaded disk image: from its read-only volume, or from the
-- read-only copy macOS runs a downloaded app from until it has been moved (App Translocation).
on runsFromDiskImage()
	set appPath to POSIX path of (path to me)
	if appPath contains "/AppTranslocation/" then return true
	if appPath does not start with "/Volumes/" then return false
	set AppleScript's text item delimiters to "/"
	set volumeRoot to "/Volumes/" & text item 3 of appPath
	set AppleScript's text item delimiters to ""
	-- Ask whether the volume is mounted read-only, not whether this account may write to its root
	-- folder (test -w): a writable external disk can have a root folder owned by root.
	try
		set writable to do shell script "/usr/sbin/diskutil info -plist " & quoted form of volumeRoot & " | /usr/bin/plutil -extract WritableVolume raw -o - -"
	on error
		return false
	end try
	return writable is "false"
end runsFromDiskImage

-- Shown again after each change to passwordless switching, so it confirms the new state;
-- switching the light ends it (the notification confirms that).
on showWindow()
	set controlCenterText to "To add the switch to Control Center: click Control Center in the menu bar, click Edit Controls at the bottom, search for \"Apple Logo\" and drag Apple Logo Illumination in."
	repeat
		set statusText to passwordlessStatus()
		if statusText is missing value then
			-- Reading the state needs root too, so without the rule it stays unknown.
			-- "Missing" means the rule doesn't work for this account, not that there is none. Deliberately
			-- not told apart: a rule can only be left over for another admin account (one rule per Mac,
			-- for whoever enabled it last), or after install-nopasswd.sh found sudo ignoring
			-- sudoers.d, where the rule does nothing. Enable moves the rule to this account, after which
			-- Disable removes it; a leftover only lets that account switch the logo light. Accepted
			-- rather than probing for the rule file as a second state.
			set titleText to "Apple Logo Illumination"
			set lightButton to "Switch Light"
			set lightAction to "toggle"
			set passwordText to "Each switch asks for your administrator password. Enable passwordless switching to switch with a single tap."
			set passwordButton to "Enable Passwordless…"
			set passwordAction to "install"
			set promptText to "MacBook Logo Toggle wants to let you switch the Apple logo light without a password. Other apps running as you could then switch it too, but get no other administrator access."
		else
			-- The status line ends in ": Off", or reads ": On (follows display brightness)"; only the
			-- ending is compared, not the light's name before it.
			if statusText ends with ": Off" then
				set titleText to "Apple Logo Illumination: Off"
				set lightButton to "Turn On"
				set lightAction to "on"
			else
				set titleText to "Apple Logo Illumination: On"
				set lightButton to "Turn Off"
				set lightAction to "off"
			end if
			if helperMatchesBundled() then
				set passwordText to "Passwordless switching is on: switching needs no password."
				set passwordButton to "Disable Passwordless…"
				set passwordAction to "uninstall"
				set promptText to "MacBook Logo Toggle wants to turn off passwordless switching. Each switch will ask for your password again."
			else
				-- Deliberately Update only, no Disable: the alert has room for three buttons (Done, this
				-- one, the light). Once updated, the window offers Disable (the README's Uninstall says so).
				-- Accepted: if the update is refused (install-nopasswd.sh finds /usr/local or the helper
				-- writable by others, which the first install already ruled out), the window can't turn
				-- the rule off; running this app's Contents/Resources/install-nopasswd.sh uninstall with
				-- sudo still can, which the README's Uninstall gives as the fallback.
				set passwordText to "Passwordless switching is on, but its helper differs from the one in this version of the app. Update it to match."
				set passwordButton to "Update Passwordless…"
				set passwordAction to "install"
				set promptText to "MacBook Logo Toggle wants to update the helper behind passwordless switching."
			end if
		end if

		set messageText to controlCenterText & return & return & passwordText
		activate -- the app has no Dock icon (LSUIElement), so bring the alert to the front
		try
			set clicked to button returned of (display alert titleText message messageText buttons {"Done", passwordButton, lightButton} default button lightButton cancel button "Done")
		on error number -128
			return
		end try
		if clicked is lightButton then
			switchLight(lightAction)
			return
		end if
		changePasswordless(passwordAction, promptText)
	end repeat
end showWindow

-- The light's status line, read through the passwordless rule; missing value when the rule isn't
-- installed for this account. Read-only, so it doubles as the probe for whether the rule works.
-- Not sudo -n -l: once the account has any NOPASSWD rule, -l reports every command an admin may run
-- as allowed (listpw=any), which says nothing about whether this one needs a password.
-- -k ignores cached credentials (as install-nopasswd.sh's own check does): where sudo shares them
-- between processes (timestamp_type=global), a recent sudo would otherwise pass for the rule.
on passwordlessStatus()
	try
		return do shell script "/usr/bin/sudo -k -n " & helperPath & " status"
	on error
		return missing value
	end try
end passwordlessStatus

-- The installed helper is a copy of logo-light.sh, made when passwordless switching was turned on;
-- a newer app doesn't update it by itself. It is world-readable, so a plain comparison works.
on helperMatchesBundled()
	try
		do shell script "/usr/bin/cmp -s " & helperPath & " " & resourcePath("logo-light.sh")
		return true
	on error
		return false
	end try
end helperMatchesBundled

on resourcePath(fileName)
	return quoted form of ((POSIX path of (path to me)) & "Contents/Resources/" & fileName)
end resourcePath

-- action is install or uninstall. Run as root from the admin prompt rather than through sudo, so the
-- script can't tell who asked; --user names this account.
on changePasswordless(action, promptText)
	try
		do shell script resourcePath("install-nopasswd.sh") & " " & action & " --user " & quoted form of (short user name of (system info)) with prompt promptText with administrator privileges
	on error errMsg number errNum
		if errNum is -128 then return -- the user cancelled the admin prompt
		activate
		display alert "Couldn't change passwordless switching" message errMsg as critical
	end try
end changePasswordless

-- action is always toggle / on / off, all of which the passwordless rule allows.
on switchLight(action)
	-- Probe passwordless sudo with the read-only status first, and only take that path if it works,
	-- so a failed run never falls through to the prompt and switches a second time.
	set canSkipPassword to (passwordlessStatus() is not missing value)

	try
		if canSkipPassword then
			set resultText to do shell script "/usr/bin/sudo -k -n " & helperPath & " " & action
		else
			set resultText to do shell script resourcePath("logo-light.sh") & " " & action with administrator privileges
		end if
	on error errMsg number errNum
		if errNum is -128 then return -- the user cancelled the admin prompt
		display alert "Couldn't switch Apple Logo Illumination" message errMsg as critical
		return
	end try
	-- No title: macOS then uses the app's name, and resultText already names the control
	-- ("Apple Logo Illumination: On"), so the two lines don't repeat each other.
	display notification resultText
end switchLight
