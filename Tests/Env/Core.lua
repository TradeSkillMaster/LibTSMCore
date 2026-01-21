local Loader = require("LibTSMCore.Tests.Env.Lib.Loader")
---@class TestEnv
local Env = {}
local private = {
	addonName = nil
}

---Initializes the environment for testing.
---@param addonName string The addon name (first argument passed to all addon files)
---@param gameVersion "VANILLA"|"MISTS"|"RETAIL" The game version to test for
function Env.Init(addonName, gameVersion)
	-- Load luaunit globally
	EXPORT_ASSERT_TO_GLOBALS = true
	require("LibTSMCore.Tests.Env.luaunit.luaunit")

	-- Initialize the lua debugger for VS Code
	if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
		require("lldebugger").start()
	end

	-- Load lua extensions
	require("LibTSMCore.Tests.Env.Extensions.bit")
	require("LibTSMCore.Tests.Env.Extensions.debug")
	require("LibTSMCore.Tests.Env.Extensions.math")
	require("LibTSMCore.Tests.Env.Extensions.print")
	require("LibTSMCore.Tests.Env.Extensions.string")
	require("LibTSMCore.Tests.Env.Extensions.system")
	require("LibTSMCore.Tests.Env.Extensions.table")

	-- Initialize game version globals
	WOW_PROJECT_CLASSIC = 3
	WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 4
	WOW_PROJECT_MISTS_CLASSIC = 5
	WOW_PROJECT_MAINLINE = 1
	if gameVersion == "VANILLA" then
		WOW_PROJECT_ID = WOW_PROJECT_CLASSIC
	elseif gameVersion == "BCC" then
		WOW_PROJECT_ID = WOW_PROJECT_BURNING_CRUSADE_CLASSIC
	elseif gameVersion == "MISTS" then
		WOW_PROJECT_ID = WOW_PROJECT_MISTS_CLASSIC
	elseif gameVersion == "RETAIL" then
		WOW_PROJECT_ID = WOW_PROJECT_MAINLINE
	else
		error("Invalid game version: "..tostring(gameVersion))
	end

	-- Mock functions required by LibTSMCore
	C_AddOns = {
		GetAddOnMetadata = function(name, key)
			key = key:lower()
			if name ~= addonName then
				return ""
			end
			if key == "version" then
				return "v0.0.0"
			end
		end
	}

	private.addonName = addonName
end

---Loads all addon files found at the specified paths.
---@param paths string[] The paths to the .toc/.xml/.lua files to load
function Env.LoadAddonFiles(paths)
	assert(private.addonName)
	for _, path in ipairs(paths) do
		Loader.LoadAddonFile(path, private.addonName)
	end
end

---Loads test environment files found at the specified paths.
---@param paths string[] The paths to the .xml/.lua files to load
function Env.LoadTestEnvFiles(paths)
	for _, path in ipairs(paths) do
		Loader.LoadTestEnvFile(path)
	end
end

---Loads test case files found at the specified paths.
---@param paths string[] The paths to the .lua files to load
function Env.LoadTestCaseFiles(paths)
	for _, path in ipairs(paths) do
		Loader.LoadTestCaseFile(path)
	end
end

---Gets the addon table.
---@return table
function Env.GetAddonTable()
	return Loader.GetAddonTable()
end

---Gets the locals table.
---@return table<string,table<string,any>>
function Env.GetLocals()
	return Loader.GetLocals()
end

---Gets a loaded test module.
---@param name string The name of the module
---@return any
function Env.GetTestModule(name)
	return Loader.GetTestModule(name)
end

---Runs the tests and exits.
function Env.Run()
	os.exit(LuaUnit.run())
end

do
	return Env
end
