-- Turns the Apple logo light on or off. Two entry points:
--   - opening the app directly (Finder, Shortcuts): toggle;
--   - opening logolighttoggle://on or ://off (what the Control Center switch does): set that state.
-- The setting lives in root's defaults domain, so switching it needs root:
--   - with the passwordless rule (install-nopasswd.sh): run /usr/local/libexec/logo-light through sudo -n, no prompt;
--   - without it: run the bundled Contents/Resources/logo-light.sh behind the admin password prompt.

property helperPath : "/usr/local/libexec/logo-light"

on run
	switchLight("toggle")
end run

on open location theURL
	if theURL ends with "://on" then
		switchLight("on")
	else if theURL ends with "://off" then
		switchLight("off")
	else
		switchLight("toggle")
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
		display alert "Couldn't switch the Apple logo light" message errMsg as critical
		return
	end try
	display notification resultText with title "Apple Logo Light"
end switchLight
