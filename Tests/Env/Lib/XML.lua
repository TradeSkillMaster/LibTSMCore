local XML = {}



-- ============================================================================
-- Module Functions / Code
-- ============================================================================

local function SplitPath(path)
	if not path:match("[\\/]") then
		return "", path
	end
	local dir, file = path:match("^(.*[/\\])([^/\\]*)$")
	assert(dir and file)
	return dir, file
end

local function ReadFile(path)
	if package.cpath:match("%.dll") then
		-- Use '\' on Windows
		path = path:gsub("/", "\\")
	else
		-- Use '/' otherwise
		path = path:gsub("\\", "/")
	end
	return assert(io.open(path, "r")):read("*all")
end

local function ParseFile(dirPath, fileName, readFileFunc, result)
	local contents = readFileFunc(dirPath..fileName)
	for extra, tag, filePath in gmatch(contents, "\n(.-)<(%w+) file=\"([^\"]+)\"[ ]*/>") do
		if not strmatch(extra, "<!%-%-") then
			if tag == "Script" then
				assert(filePath:match("%.lua$"))
				tinsert(result, dirPath..filePath)
			elseif tag == "Include" then
				assert(filePath:match("%.xml$"))
				local includeDirPath, includeFileName = SplitPath(filePath)
				ParseFile(dirPath..includeDirPath, includeFileName, readFileFunc, result)
			end
		end
	end
end

function XML.GetLuaFiles(path, readFileFunc)
	readFileFunc = readFileFunc or ReadFile
	local result = {}
	local dirPath, fileName = SplitPath(path)
	ParseFile(dirPath, fileName, readFileFunc, result)
	return result
end

do
	return XML
end
