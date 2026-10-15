CopyTable = function(t)
	local copy = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			copy[k] = CopyTable(v)
		else
			copy[k] = v
		end
	end
	return copy
end
wipe = function(t)
	local toRemove = {}
	for k in pairs(t) do
		toRemove[k] = true
	end
	for k in pairs(toRemove) do
		t[k] = nil
	end
end
tContains = function(t, v)
	local i = 1
	while t[i] do
		if t[i] == v then
			return 1
		end
		i = i + 1
	end
	return nil
end
tinsert = table.insert
tremove = table.remove
sort = table.sort
unpack = unpack or table.unpack
table.removemulti = function(t, pos, count)
	for _ = 1, count do
		tremove(t, pos)
	end
end
table.getcountinfo = function(t)
	local numEntries, numPositiveIntegerKeys, maxPositiveIntegerKey = 0, 0, 0
	for k in pairs(t) do
		numEntries = numEntries + 1
		if type(k) == "number" and k > 0 and math.floor(k) == k then
			numPositiveIntegerKeys = numPositiveIntegerKeys + 1
			maxPositiveIntegerKey = math.max(maxPositiveIntegerKey, k)
		end
	end
	return numEntries, numPositiveIntegerKeys, maxPositiveIntegerKey
end
table.removevalue = function(t, value)
	local numRemoved = 0
	for i = #t, 1, -1 do
		if t[i] == value then
			tremove(t, i)
			numRemoved = numRemoved + 1
		end
	end
	return numRemoved
end
