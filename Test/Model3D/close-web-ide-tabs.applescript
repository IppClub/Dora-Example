repeat with appName in {"Google Chrome", "Microsoft Edge"}
	if application appName is running then
		using terms from application "Google Chrome"
			tell application appName
				repeat with windowIndex from (count windows) to 1 by -1
					repeat with tabIndex from (count tabs of window windowIndex) to 1 by -1
						set tabURL to URL of tab tabIndex of window windowIndex
						if tabURL contains ":8866" then close tab tabIndex of window windowIndex
					end repeat
				end repeat
			end tell
		end using terms from
	end if
end repeat

if application "Safari" is running then
	tell application "Safari"
		repeat with windowIndex from (count windows) to 1 by -1
			repeat with tabIndex from (count tabs of window windowIndex) to 1 by -1
				set tabURL to URL of tab tabIndex of window windowIndex
				if tabURL contains ":8866" then close tab tabIndex of window windowIndex
			end repeat
		end repeat
	end tell
end if
