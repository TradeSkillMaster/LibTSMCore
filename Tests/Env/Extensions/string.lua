strjoin = function(sep, ...)
	local numArgs = select("#", ...)
	local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 = ...
	if numArgs == 0 then
		return ""
	elseif arg1 == nil then
		-- A weird quirk of WoW's implementation is that this results in an empty return, but we really don't want to rely on this
		error("Shouldn't pass nil to strjoin()")
	elseif numArgs == 1 then
		return arg1
	elseif numArgs == 2 then
		return arg1..sep..arg2
	elseif numArgs == 3 then
		return arg1..sep..arg2..sep..arg3
	elseif numArgs == 4 then
		return arg1..sep..arg2..sep..arg3..sep..arg4
	elseif numArgs == 5 then
		return arg1..sep..arg2..sep..arg3..sep..arg4..sep..arg5
	elseif numArgs == 6 then
		return arg1..sep..arg2..sep..arg3..sep..arg4..sep..arg5..sep..arg6
	elseif numArgs == 7 then
		return arg1..sep..arg2..sep..arg3..sep..arg4..sep..arg5..sep..arg6..sep..arg7
	else
		local first8 = arg1..sep..arg2..sep..arg3..sep..arg4..sep..arg5..sep..arg6..sep..arg7..sep..arg8
		if numArgs == 8 then
			return first8
		end
		return first8..sep..strjoin(sep, select(9, ...))
	end
end
strtrim = function(s)
	return s:gsub("^%s*(.-)%s*$", "%1")
end
strfind = string.find
strsub = string.sub
strmatch = string.match
format = string.format
strbyte = string.byte
function strchar(...)
	local args = {...}
	for i = 1, #args do
		args[i] = floor(args[i])
	end
	return string.char(unpack(args))
end
gsub = string.gsub
gmatch = string.gmatch
strlower = string.lower
function string.split(sep, str)
	local result = {}
	local s = 1
	local sepLength = #sep
	if sepLength == 0 then
		tinsert(result, str)
		return result
	end
	local resultLength = #result
	while true do
		local e = strfind(str, sep, s, true)
		if not e then
			result[resultLength+1] = strsub(str, s)
			resultLength = resultLength + 1
			break
		end
		result[resultLength+1] = strsub(str, s, e - 1)
		resultLength = resultLength + 1
		s = e + sepLength
	end
	assert(#result == resultLength)
	return unpack(result)
end
strsplit = string.split
function tostringall(...)
	local result = {}
	for i = 1, select("#", ...) do
		result[i] = tostring(select(i, ...))
	end
	return unpack(result)
end
strupper = string.upper
strrep = string.rep
strlenutf8 = string.len
