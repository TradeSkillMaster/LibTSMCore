-- ------------------------------------------------------------------------------ --
--                                   LibTSMCore                                   --
--                 https://github.com/TradeSkillMaster/LibTSMCore                 --
--         Licensed under the MIT license. See LICENSE.txt for more info.         --
-- ------------------------------------------------------------------------------ --

local ADDON_NAME = ...
local ADDON_TABLE = select(2, ...)
local LibTSMCore = {} ---@class LibTSMCore
ADDON_TABLE.LibTSMCore = LibTSMCore
local LibTSMClass = LibStub("LibTSMClass")
local private = {
	components = {}, ---@type LibTSMComponent[]
	componentByModule = {}, ---@type table<LibTSMModule,LibTSMComponent>
	componentByReference = {}, ---@type table<LibTSMComponentReference,LibTSMComponent>
	isExternalAccess = false,
	timeFunc = nil,
	versionStr = nil,
	versionIsDev = nil,
	versionIsTest = nil,
	didLoad = false,
	allContexts = {}, ---@type LibTSMModuleContext[]
}
local GAME_VERSION = nil
do
	assert(WOW_PROJECT_ID)
	if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
		GAME_VERSION = "VANILLA"
	elseif WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
		GAME_VERSION = "BCC"
	elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
		GAME_VERSION = "MISTS"
	elseif WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		GAME_VERSION = "RETAIL"
	end
	assert(GAME_VERSION, "Invalid game version: "..tostring(WOW_PROJECT_ID))

	local versionRaw = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
	local isDevVersion = strmatch(versionRaw, "project%-version@$") and true or false
	private.versionStr = isDevVersion and "Dev" or versionRaw
	private.versionIsDev = isDevVersion
	private.versionIsTest = versionRaw == "v0.0.0"
end



-- ============================================================================
-- LibTSMModule Metatable
-- ============================================================================

---@class LibTSMModule
local MODULE_METHODS = {}

---Registers the function be called when the module is loaded.
---@protected
---@param func fun() The function to call
function MODULE_METHODS:OnModuleLoad(func)
	private.componentByModule[self]:_SetModuleLoadFunc(self, func) ---@diagnostic disable-line: invisible
end

---Registers the function be called when the module is unloaded.
---@protected
---@param func fun() The function to call
function MODULE_METHODS:OnModuleUnload(func)
	private.componentByModule[self]:_SetModuleUnloadFunc(self, func, false) ---@diagnostic disable-line: invisible
end

---Registers the function be called when the module is unloaded as late as possible in the process.
---@protected
---@param func fun() The function to call
function MODULE_METHODS:OnModuleUnloadLate(func)
	private.componentByModule[self]:_SetModuleUnloadFunc(self, func, true) ---@diagnostic disable-line: invisible
end

local MODULE_MT = {
	__index = MODULE_METHODS,
	__newindex = function(self, key, value)
		assert(not private.componentByModule[self]:_DidModuleLoad(self) and not MODULE_METHODS[key]) ---@diagnostic disable-line: invisible
		rawset(self, key, value)
	end,
	__tostring = function(self)
		local component = private.componentByModule[self]
		return component:_GetName()..":"..component._moduleContext[self].path ---@diagnostic disable-line: invisible
	end,
	__metatable = false,
}



-- ============================================================================
-- LibTSMComponentReference Metatable
-- ============================================================================

---@class LibTSMComponentReference
local COMPOENT_REFERENCE_METHODS = {}

---Includes a module from the component.
---@generic T
---@param path `T` The path of the module
---@return T
function COMPOENT_REFERENCE_METHODS:Include(path)
	assert(not private.isExternalAccess)
	private.isExternalAccess = true
	local module = private.componentByReference[self]:Include(path)
	assert(private.isExternalAccess)
	private.isExternalAccess = false
	return module
end

---Includes a class type from the component.
---@generic T
---@param name `T` The name of the class
---@return T
function COMPOENT_REFERENCE_METHODS:IncludeClassType(name)
	assert(not private.isExternalAccess)
	private.isExternalAccess = true
	local class =  private.componentByReference[self]:IncludeClassType(name)
	assert(private.isExternalAccess)
	private.isExternalAccess = false
	return class
end

---Extends a previously-registered class (including an internal one).
---@generic T
---@param name `T` The name of the class
---@return T
function COMPOENT_REFERENCE_METHODS:ExtendClass(name)
	assert(not private.isExternalAccess)
	local class =  private.componentByReference[self]:IncludeClassType(name)
	return class:__extend()
end

local COMPONENT_REFERENCE_MT = {
	__index = COMPOENT_REFERENCE_METHODS,
	__newindex = function() error("Cannot write to LibTSMComponentReference", 2) end,
	__tostring = function(self) return tostring(private.componentByReference[self]) end,
	__metatable = false,
}



-- ============================================================================
-- LibTSMComponent Class - Meta Methods
-- ============================================================================

---@class LibTSMComponent
local LibTSMComponent = LibTSMClass.DefineClass("LibTSMComponent")

---@class LibTSMModuleContext
---@field path string
---@field module LibTSMModule
---@field isInternal boolean
---@field moduleLoadFunc fun()?
---@field moduleLoadTime number?
---@field moduleUnloadFunc fun()?
---@field moduleUnloadTime number?
---@field moduleUnloadIsLate boolean

---@private
function LibTSMComponent:__init(name)
	self._name = name
	self._moduleContext = {} ---@type table<LibTSMModule|string,LibTSMModuleContext>
	self._classTypes = {} ---@type table<string,Class>
	self._classIsInternal = {} ---@type table<string,boolean>
	self._initOrder = {} ---@type LibTSMModuleContext[]
	self._loadOrder = {} ---@type LibTSMModuleContext[]
	self._lateUnload = {} ---@type LibTSMModuleContext[]
	self._dependencies = {} ---@type table<string,LibTSMComponent>
	self._reference = setmetatable({}, COMPONENT_REFERENCE_MT) ---@type LibTSMComponentReference
	private.componentByReference[self._reference] = self
end



-- ============================================================================
-- LibTSMComponent Class - Static Functions
-- ============================================================================

---Returns whether or not we're running within the Vanilla Classic version of the game.
---@return boolean
function LibTSMComponent.__static.IsVanillaClassic()
	return GAME_VERSION == "VANILLA"
end

---Returns whether or not we're running within the Burning Crusade Classic version of the game.
---@return boolean
function LibTSMComponent.__static.IsBCClassic()
	return GAME_VERSION == "BCC"
end

---Returns whether or not we're running within the Mists Classic version of the game.
---@return boolean
function LibTSMComponent.__static.IsMistsClassic()
	return GAME_VERSION == "MISTS"
end

---Returns whether or not we're running within the retail version of the game.
---@return boolean
function LibTSMComponent.__static.IsRetail()
	return GAME_VERSION == "RETAIL"
end

---Gets the current time value (or 0 if no function is registered).
---@return number
function LibTSMComponent.__static.GetTime()
	return private.timeFunc and private.timeFunc() or 0
end

---Gets the version string.
---@return string
function LibTSMComponent.__static.GetVersionStr()
	return private.versionStr
end

---Gets whether or not this is a dev version.
---@return boolean
function LibTSMComponent.__static.IsDevVersion()
	return private.versionIsDev
end

---Gets whether or not this is a test version.
---@return boolean
function LibTSMComponent.__static.IsTestVersion()
	return private.versionIsTest
end




-- ============================================================================
-- LibTSMComponent Class - Public Methods
-- ============================================================================

---Creates a new module and makes it available to other components.
---@generic T: LibTSMModule
---@param path `T` The path of the module
---@return T
function LibTSMComponent:Init(path)
	return self:_InitHelper(path, false)
end

---Creates a new module which is only available internally within the component.
---@generic T: LibTSMModule
---@param path `T` The path of the module
---@return T
function LibTSMComponent:InitInternal(path)
	return self:_InitHelper(path, true)
end

---Creates a new class type and makes it available to other components.
---@generic T: Class
---@param name `T` The name of the class
---@param parentClass? Class The parent class
---@param ... ClassProperties Properties to define the class with
---@return T
function LibTSMComponent:DefineClassType(name, parentClass, ...)
	return self:_DefineClassTypeHelper(false, name, parentClass, ...)
end

---Creates a new class type which is only available internally within the component.
---@generic T: Class
---@param name `T` The name of the class
---@param parentClass? Class The parent class
---@param ... ClassProperties Properties to define the class with
---@return T
function LibTSMComponent:DefineInternalClassType(name, parentClass, ...)
	return self:_DefineClassTypeHelper(true, name, parentClass, ...)
end

---Returns an existing module.
---@generic T
---@param path `T` The path of the module
---@return T
function LibTSMComponent:Include(path)
	local context = self._moduleContext[path]
	if not context then
		error("Module doesn't exist for path: "..tostring(path), private.isExternalAccess and 5 or 3)
	elseif context.isInternal and private.isExternalAccess then
		error("Cannot include internal module: "..tostring(path), 5)
	end
	self:_ProcessModuleLoad(context)
	return context.module
end

---Returns a class type.
---@generic T
---@param name `T` The name of the class
---@return T
function LibTSMComponent:IncludeClassType(name)
	local class = self._classTypes[name]
	if not class then
		error("Class type doesn't exist: "..tostring(name), private.isExternalAccess and 5 or 3)
	elseif self._classIsInternal[name] and private.isExternalAccess then
		error("Cannot include internal class: "..tostring(name), 5)
	end
	return class
end

---Retrieves a component which the current component depends on.
---@param name string The name of the component
---@return LibTSMComponentReference
function LibTSMComponent:From(name)
	local component = self._dependencies[name]
	assert(component)
	return component._reference
end

---Adds a component as a dependency of the current component.
---@param name string The name of the component
---@return LibTSMComponent
function LibTSMComponent:AddDependency(name)
	assert(not next(self._moduleContext) and not next(self._classTypes))
	assert(type(name) == "string" and not self._dependencies[name])
	local component = private.components[name]
	assert(component)
	self._dependencies[name] = component
	return self
end



-- ============================================================================
-- LibTSMComponent Class - Private Methods
-- ============================================================================

function LibTSMComponent.__private:_InitHelper(path, isInternal)
	assert(type(path) == "string")
	if self._moduleContext[path] then
		error("Module already exists for path: "..tostring(path), 5)
	end
	local moduleObj = setmetatable({}, MODULE_MT)
	private.componentByModule[moduleObj] = self
	local context = { ---@type LibTSMModuleContext
		path = path,
		module = moduleObj,
		isInternal = isInternal,
		moduleLoadFunc = nil,
		moduleLoadTime = nil,
		moduleUnloadFunc = nil,
		moduleUnloadTime = nil,
		moduleUnloadIsLate = nil,
	}
	-- Store a reference to the context by both the module object and the path
	self._moduleContext[path] = context
	self._moduleContext[moduleObj] = context
	tinsert(self._initOrder, context)
	tinsert(private.allContexts, context)
	return moduleObj
end

---Creates a new class type.
---@generic T: Class
---@param name `T` The name of the class
---@param parentClass? Class The parent class
---@param ... ClassProperties Properties to define the class with
---@return T
function LibTSMComponent.__private:_DefineClassTypeHelper(isInternal, name, parentClass, ...)
	assert(type(name) == "string")
	if self._classTypes[name] then
		error("Class type already exists: "..tostring(name), 5)
	end
	local class = LibTSMClass.DefineClass(name, parentClass, ...)
	self._classTypes[name] = class
	self._classIsInternal[name] = isInternal
	return class
end

---@private
function LibTSMComponent:_SetModuleLoadFunc(module, func)
	assert(not private.didLoad)
	local context = self._moduleContext[module]
	assert(context and not context.moduleLoadFunc and not context.moduleLoadTime and type(func) == "function")
	context.moduleLoadFunc = func
end

---@private
function LibTSMComponent:_SetModuleUnloadFunc(module, func, isLate)
	local context = self._moduleContext[module]
	assert(context and not context.moduleUnloadFunc and not context.moduleUnloadTime and type(func) == "function")
	context.moduleUnloadFunc = func
	context.moduleUnloadIsLate = isLate
end

---@private
function LibTSMComponent:_DidModuleLoad(module)
	local context = self._moduleContext[module]
	assert(context)
	return context.moduleLoadTime and true or false
end

function LibTSMComponent.__private:_ProcessModuleLoad(context)
	if context.moduleLoadTime then
		return
	end
	tinsert(self._loadOrder, context)
	context.moduleLoadTime = 0
	if context.moduleLoadFunc then
		local startTime = self.GetTime()
		context.moduleLoadFunc()
		context.moduleLoadTime = self.GetTime() - startTime
	end
end

---@private
function LibTSMComponent:_LoadAll()
	-- Load any module which hasn't already
	for _, context in ipairs(self._initOrder) do
		self:_ProcessModuleLoad(context)
	end
end

---@private
function LibTSMComponent:_UnloadAll(maxTime)
	if maxTime == math.huge then
		-- Don't mutate our `_loadOrder` queue
		assert(#self._lateUnload == 0)
		for _, context in ipairs(self._loadOrder) do
			self:_UnloadModule(context)
		end
	else
		-- Unload in the opposite order we loaded
		while #self._loadOrder > 0 and self.GetTime() < maxTime do
			local context = tremove(self._loadOrder) ---@type LibTSMModuleContext
			context.moduleUnloadTime = self:_UnloadModule(context)
		end
	end
	-- Run the late unload functions
	while #self._lateUnload > 0 and self.GetTime() < maxTime do
		local context = tremove(self._lateUnload) ---@type LibTSMModuleContext
		local startTime = self.GetTime()
		context.moduleUnloadFunc()
		if maxTime ~= math.huge then
			context.moduleUnloadTime = self.GetTime() - startTime
		end
	end
	if maxTime == math.huge then
		assert(#self._lateUnload == 0)
		return true
	end
	return #self._loadOrder == 0 and #self._lateUnload == 0
end

---@param context LibTSMModuleContext
function LibTSMComponent.__private:_UnloadModule(context)
	if context.moduleUnloadTime then
		return context.moduleUnloadTime
	end
	if context.moduleUnloadIsLate then
		tinsert(self._lateUnload, context)
		return nil
	elseif context.moduleUnloadFunc then
		local startTime = self.GetTime()
		context.moduleUnloadFunc()
		return self.GetTime() - startTime
	else
		return 0
	end
end

---@private
function LibTSMComponent:_GetName()
	return self._name
end



-- ============================================================================
-- LibTSMCore Functions
-- ============================================================================

---Creats a new component.
---@param name string The name of the component
---@return LibTSMComponent
function LibTSMCore.NewComponent(name)
	assert(type(name) == "string" and not private.components[name])
	local component = LibTSMComponent(name)
	tinsert(private.components, component)
	private.components[name] = component
	return component
end

---Sets the time function.
---@param timeFunc fun(): number A function which returns the time with high precision
function LibTSMCore.SetTimeFunction(timeFunc)
	private.timeFunc = timeFunc
end

---Loads all modules.
function LibTSMCore.LoadAll()
	assert(not private.didLoad)
	private.didLoad = true
	for _, component in ipairs(private.components) do
		component:_LoadAll() ---@diagnostic disable-line: invisible
	end
end

---Unloads all modules.
---@param maxTime number The max time before aborting early
---@return boolean
function LibTSMCore.UnloadAll(maxTime)
	-- Unload in the opposite order
	for i = #private.components, 1, -1 do
		if not private.components[i]:_UnloadAll(maxTime) then ---@diagnostic disable-line: invisible
			return false
		end
	end
	return true
end

---Returns an iterator over all available modules.
---@return fun(): number, string, number, number @Iterator with fields: `index`, `componentName`, `modulePath`, `loadTime`, `unloadTime`
---@return nil
---@return number
function LibTSMCore.ModuleInfoIterator()
	return private.ModuleInfoIterator, nil, 0
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ModuleInfoIterator(_, index)
	index = index + 1
	local context = private.allContexts[index]
	if not context then
		return
	end
	local name = private.componentByModule[context.module]:_GetName() ---@diagnostic disable-line: invisible
	return index, name, context.path, context.moduleLoadTime, context.moduleUnloadTime
end
