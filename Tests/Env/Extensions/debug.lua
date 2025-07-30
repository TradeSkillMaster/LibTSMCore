function debugprofilestop()
	return 0
end

function debugstack(thread, start, countTop, countBottom)
	local lines = nil
	if type(thread) == "thread" then
		lines = { ("\n"):split(debug.traceback(thread)) }
	else
		start, countTop, countBottom = thread, start, countTop
		lines = { ("\n"):split(debug.traceback()) }
	end
	local includeLine = {}
	for i = 1, countTop do
		includeLine[start + i] = true
	end
	for i = 1, countBottom do
		local lineNum = #lines - (i - 1)
		if lineNum > 0 then
			includeLine[lineNum] = true
		end
	end
	local result = nil
	for i = 1, #lines do
		if includeLine[i] then
			result = (result and (result .. "\n") or "") .. lines[i]
		end
	end
	return result or ""
end

function geterrorhandler()
	return function (error) print("error: " .. error) end
end
