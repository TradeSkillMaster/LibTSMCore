bit = {}

function bit.band(a, b)
	local result = 0
	local mask = 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then
			result = result + mask
		end
		mask = mask * 2
		a = math.floor(a / 2)
		b = math.floor(b / 2)
	end
	return result
end

function bit.lshift(value, places)
	return value * 2 ^ places
end

function bit.rshift(value, places)
	return math.floor(value / (2 ^ places))
end
