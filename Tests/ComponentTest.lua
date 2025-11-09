---@diagnostic disable: invisible
local TSM, Locals = ... ---@type TSM, table<string,table<string,any>>
local LibTSMCore = TSM.LibTSMCore
local corePrivate = Locals["LibTSMCore.Core"].private



-- ============================================================================
-- Tests
-- ============================================================================

TestComponent = {}

function TestComponent:TearDown()
	wipe(corePrivate.components)
	wipe(corePrivate.componentByModule)
	wipe(corePrivate.componentByReference)
	wipe(corePrivate.allContexts)
	corePrivate.didLoad = false
end

function TestComponent:TestLoadUnload()
	local events = {}

	local Component1 = LibTSMCore.NewComponent("Component1")

	local Module1 = Component1:Init("Module1") ---@class Module1: LibTSMModule
	Module1:OnModuleLoad(function() tinsert(events, "LOAD1") end)
	Module1:OnModuleUnload(function() tinsert(events, "UNLOAD1") end)

	local Module2 = Component1:Init("Module2") ---@class Module2: LibTSMModule
	Module2:OnModuleLoad(function() tinsert(events, "LOAD2") end)
	Module2:OnModuleUnloadLate(function() tinsert(events, "UNLOAD_LATE2") end)
	assertEquals(events, {})

	local Module3 = Component1:Init("Module3") ---@class Module3: LibTSMModule
	Module3:OnModuleLoad(function() tinsert(events, "LOAD3") end)
	Module3:OnModuleUnload(function() tinsert(events, "UNLOAD3") end)

	-- Load everything in order
	assertEquals(events, {})
	LibTSMCore.LoadAll()
	assertEquals(events, {"LOAD1", "LOAD2", "LOAD3"})
	wipe(events)

	-- Unload everything - late unload should happen last
	LibTSMCore.UnloadAll(math.huge)
	assertEquals(events, {"UNLOAD1", "UNLOAD3", "UNLOAD_LATE2"})
end

function TestComponent:TestLoadOnInclude()
	local events = {}

	local Component1 = LibTSMCore.NewComponent("Component1")

	local Module1 = Component1:Init("Module1") ---@class Module1: LibTSMModule
	Module1:OnModuleLoad(function() tinsert(events, "LOAD1") end)

	local Module2 = Component1:Init("Module2") ---@class Module2: LibTSMModule
	Module2:OnModuleLoad(function() tinsert(events, "LOAD2") end)
	assertEquals(events, {})
	local _ = Component1:Include("Module1")
	assertEquals(events, {"LOAD1"})
end

function TestComponent:TestInternal()
	local Component1 = LibTSMCore.NewComponent("Component1")
	local Module1 = Component1:InitInternal("Module1") ---@class Module1: LibTSMModule

	-- Including within the component shouldn't error
	Component1:Include("Module1")

	local Component2 = LibTSMCore.NewComponent("Component2")
		:AddDependency("Component1")
	assertErrorMsgContains("Cannot include internal module", function() Component2:From("Component1"):Include("Module1") end)
end
