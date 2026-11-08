-- Turns the Apple logo light on or off. Entry points:
--   - opening the app directly (Finder, Spotlight): toggle;
--   - opening macbooklogotoggle://on or ://off (what the Control Center switch does): set that state;
--   - opening any other URL, such as macbooklogotoggle://launch: nothing beyond the launch itself, so a
--     mistyped or stray link never switches the light. Being launched is enough for macOS to trust a new
--     build, which the Control Center switch needs (build.sh opens ://launch after installing, see there).
-- The setting lives in root's defaults domain, so switching it needs root:
--   - with the passwordless rule (install-nopasswd.sh): run /usr/local/libexec/logo-light through sudo -n, no prompt;
--   - without it: run the bundled Contents/Resources/logo-light.sh behind the admin password prompt.

property helperPath : "/usr/local/libexec/logo-light"

on run
	switchLight("toggle")
end run

-- Compared whole, not parsed: these are the only two URLs the switch sends ("is" ignores case).
on open location theURL
	if theURL is "macbooklogotoggle://on" then
		switchLight("on")
	else if theURL is "macbooklogotoggle://off" then
		switchLight("off")
	end if
end open location

-- action is always toggle / on / off, all of which the passwordless rule allows.
on switchLight(action)
	-- Probe passwordless sudo with the read-only status first, and only take that path if it works,
	-- so a failed run never falls through to the prompt and switches a second time.
	-- Not sudo -n -l: once the account has any NOPASSWD rule, -l reports every command an admin may run
	-- as allowed (listpw=any), which says nothing about whether this one needs a password.
	set canSkipPassword to true
	try
		do shell script "/usr/bin/sudo -n " & helperPath & " status"
	on error
		set canSkipPassword to false
	end try

	try
		if canSkipPassword then
			set resultText to do shell script "/usr/bin/sudo -n " & helperPath & " " & action
		else
			set scriptPath to quoted form of ((POSIX path of (path to me)) & "Contents/Resources/logo-light.sh")
			set resultText to do shell script scriptPath & " " & action with administrator privileges
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
