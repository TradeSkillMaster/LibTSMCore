---@class TestLoader
local Loader = {}
local private = {
	addonTable = {},
	locals = {}, ---@type table<string,table<string,any>>
	testModules = {}, ---@type table<string,any>
}
local XML = require("LibTSMCore.Tests.Env.Lib.XML")

local function FixPath(path)
	if package.cpath:match("%.dll") then
		-- Use '\' on Windows
		return path:gsub("/", "\\")
	else
		-- Use '/' otherwise
		return path:gsub("\\", "/")
	end
end

local function GetFileExtension(path)
	return path:lower():match("%.([a-z]+)$")
end

local function ReadLuaFile(path)
	local file = assert(io.open(path))
	local code = file:read("*all")
	file:close()
	-- Get the module name
	local moduleName = path:gsub(".lua", ""):gsub("[/\\]", "."):gsub("Source%.", "")
	assert(moduleName)
	return code, moduleName
end

local function ExecuteCode(code, path, ...)
	return assert(loadstring(code, path))(...)
end

local function XMLFilePathIterator(path)
	local paths = {}
	for _, filePath in ipairs(XML.GetLuaFiles(path)) do
		table.insert(paths, filePath)
	end
	return ipairs(paths)
end

local function TOCFilePathIterator(path)
	local paths = {}
	for line in io.lines(path) do
		line = line:gsub("^%s*(.-)%s*$", "%1")
		if line ~= "" and not line:match("^#") then
			table.insert(paths, line)
		end
	end
	return ipairs(paths)
end

assert(not __CollectLocals)
function __CollectLocals(moduleName)
	local locals = {}
	local i = 0
	while true do
		i = i + 1
		local name, value = debug.getlocal(2, i)
		if name == nil then
			break
		end
		if name ~= "__GetLocals" and name:sub(1, 1) ~= "(" and name ~= "_" then
			locals[name] = value
		end
	end
	private.locals[moduleName] = locals
end

---Loads an addon file (also supports xml and toc files to recursively load).
---@param path string The file path
function Loader.LoadAddonFile(path, addonName)
	path = FixPath(path)
	local ext = GetFileExtension(path)
	if ext == "lua" then
		local code, moduleName = ReadLuaFile(path)
		-- Best-effort attempt to patch code to collect all the locals (may fail if the code returns early)
		assert(not private.locals[moduleName] and not code:match("__CollectLocals"))
		code = code:gsub("\nreturn .+\n*", "").."__CollectLocals(\""..moduleName.."\")"
		ExecuteCode(code, path, addonName, private.addonTable)
	elseif ext == "xml" then
		for _, filePath in XMLFilePathIterator(path) do
			Loader.LoadAddonFile(filePath, addonName)
		end
	elseif ext == "toc" then
		for _, filePath in TOCFilePathIterator(path) do
			Loader.LoadAddonFile(filePath, addonName)
		end
	else
		error("Invalid file: "..path)
	end
end

---Loads a test environment file (also supports xml files to recursively load).
---@param path string The file path
function Loader.LoadTestEnvFile(path)
	path = FixPath(path)
	local ext = GetFileExtension(path)
	if ext == "lua" then
		local code, moduleName = ReadLuaFile(path)
		assert(not private.testModules[moduleName])
		private.testModules[moduleName] = ExecuteCode(code, path)
	elseif ext == "xml" then
		for _, filePath in XMLFilePathIterator(path) do
			Loader.LoadTestEnvFile(filePath)
		end
	else
		error("Invalid file: "..path)
	end
end

---Loads a test case file.
---@param path string The file path
function Loader.LoadTestCaseFile(path)
	path = FixPath(path)
	loadfile(path)(private.addonTable, private.locals, private.testModules)
end
---Gets the addon table.
---@return table
function Loader.GetAddonTable()
	return private.addonTable
end

---Gets the locals table.
---@return table<string,table<string,any>>
function Loader.GetLocals()
	return private.locals
end

---Gets a loaded test module.
---@param name string The name of the module
---@return any
function Loader.GetTestModule(name)
	local module = private.testModules[name]
	assert(module)
	return module
end

return Loader
