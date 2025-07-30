local COLOR_REPLACEMENTS = {
	["|cfff72d20"] = "\27[31m",
	["|cff4ff720"] = "\27[32m",
	["|cffe1f720"] = "\27[33m",
	["|cff2076f7"] = "\27[34m",
	["|r"] = "\27[0m",
}

local origPrint = print
function print(...)
	local args = {...}
	for i = 1, #args do
		if type(args[i]) == "string" then
			for match, rep in pairs(COLOR_REPLACEMENTS) do
				args[i] = args[i]:gsub(match, rep)
			end
		end
	end
	origPrint(unpack(args))
end
