# Features

## Terminology

There are a few terms used by LibTSMCore to refer to lua files / groups of files.

### Component

A component is a top-level grouping of related files which provide a common set of functionality.
Components are typically used for high-level separation of things like application logic from
business logic from ulility code. Components should have a very clear dependency hierarchy and
are generally contained within a single top-level directory in an addon.

### Module

A module is a single file within a component. Each module should contain a related set of APIs
and functionality, and may depend on any other module within the same component or any component
which the current component depends on. Modules which perform similar functions are generally
grouped together into folders within the component.

## Class Types

LibTSMCore makes it easy to create modules which define a class via
[LibTSMClass](https://github.com/TradeSkillMaster/LibTSMClass).

```lua
-- Utils/Range.lua
local Utils = select(2, ...).Utils
local Range = Utils:DefineClassType("Range")

function Range:__init(startValue, endValue)
    self._start = startValue
    self._end = endValue
end

function Range:IncludesValue(value)
    return value >= self._start and value <= self._end
end
```

```lua
-- Utils/DebugPrint.lua
local Utils = select(2, ...).Utils
local DebugPrint = Utils:Init("DebugPrint")
local Range = Utils:IncludeClassType("Range")

local VALID_LEVEL_RANGE = Range(1, 80)

function DebugPrint.PrintIsValidLevel(level)
    if VALID_LEVEL_RANGE:IncludesValues(level) then
        print(format("%d is a valid level!", level))
    else
        print(format("%d is not a valid level!", level))
    end
end
```

## Loading / Unloading

Each module provides a set of default methods which can be used to run code when the module is
loaded or unloaded. Note that these are not available for class types.

```lua
-- Utils/Table.lua
local Utils = select(2, ...).Utils
local Table = Utils:Init("Table")

Table:OnModuleLoad(function()
    -- This code runs once when the module is loaded.
end)

Table:OnModuleUnload(function()
    -- This code runs once when the module is unloaded.
end)
```

## Dependencies

Components can depend on other components, which then allows them to include modules from the
components they depend on.

```lua
-- Services/Core.lua
local ADDON_TABLE = select(2, ...)
ADDON_TABLE.Services = ADDON_TABLE.LibTSMCore.NewComponent("Services")
    :AddDependency("Utils")
```

```lua
-- Services/SlashCommands.lua
local Services = select(2, ...).Services
local SlashCommands = Services:Init("SlashCommands")
local DebugPrint = Services:From("Utils"):Include("DebugPrint")
local private = {
    greeting = "Hello World!",
}

SlashCommands:OnModuleLoad(function()
    SLASH_HELLOWORLD1 = "/helloworld"
    SLASH_HELLOWORLD2 = "/hw"
    SlashCmdList.HELLOWORLD = private.SlashCommandHandler
end)

---Sets the greeting.
---@param greeting string
function SlashCommands.SetGreeting(greeting)
    private.greeting = greeting
end

function private.SlashCommandHandler()
    print(private.greeting)
    local level = UnitLevel("player")
    print(format("You are level %d.", level))
    DebugPrint.PrintIsValidLevel(level)
end
```

## Component APIs

Components provide a set of APIs which may be called within the modules to provide some baseline
functionality.

### Game Version

A set of APIs is provided by every component for accessing the active game version.

```lua
-- Utils/DebugPrint.lua
local Utils = select(2, ...).Utils
local DebugPrint = Utils:Init("DebugPrint")

function DebugPrint.PrintGameVersion()
    if Utils.IsRetail() then
        print("Game version is retail!")
    elseif Utils.IsMistsClassic() then
        print("Game version is mists class!")
    elseif Utils.IsVanillaClassic() then
        print("Game version is vanilla classic!")
    else
        error("Game version is unknown")
    end
end
```

### Addon Version

A set of APIs is provided by every component for accessing the current addon version. LibTSMCore
assumes that, for development, the version string is defined in the .toc file as ending in
`"project-version@"`, which matches the conventions used by both the Curseforge and
[BigWigs](https://github.com/BigWigsMods/packager) packagers. For test environments, LibTSMCore
assumes that C_AddOns.GetAddOnMetadata(ADODN_NAME, "Version") is mocked to return `"v0.0.0"`.

```lua
-- Utils/DebugPrint.lua
local Utils = select(2, ...).Utils
local DebugPrint = Utils:Init("DebugPrint")

function DebugPrint.PrintAddonVersion()
    if Utils.IsTestVersion() then
        print("Running in a test environment")
    elseif Utils.IsDevVersion() then
        print("Running in a development environment")
    else
        print("Addon version is: "..Utils.GetVersionStr())
    end
end
```

### Time

Since having a source of time is a fairly common requirement, LibTSMCore provides a mechanism for
getting the current time based on a registered time function. This allows for the encompassing
addon to provides its own source-of-truth time based on its own requirements of precision and
accuracy. This is also a purely-optional dependency, with `GetTime()` simply returning `0` if no
time function is registered.

```lua
-- TimeInit.lua
local LibTSMCore = select(2, ...).LibTSMCore

LibTSMCore.SetTimeFunction(function()
    return time()
end)
```

```lua
-- Utils/DebugPrint.lua
local Utils = select(2, ...).Utils
local DebugPrint = Utils:Init("DebugPrint")

function DebugPrint.PrintTime()
    print("Current time is: "..Utils.GetTime())
end
```

## Misc. APIs

### `LibTSMCore.ModuleInfoIterator()`

This API is provided to get metadata about all registered modules for debugging purposes.

```lua
for _, componentName, modulePath, loadTime, unloadTime in LibTSMCore.ModuleInfoIterator() do
    if loadTime then
        print(format("%s->%s loaded in %d", componentName, modulePath, loadTime))
    end
    if unloadTime then
        print(format("%s->%s unloaded in %d", componentName, modulePath, unloadTime))
    end
end
```

### `:OnModuleUnloadLate()`

This method is provided on modules in addition to `:OnModuleUnload()` in order to defer unloading
of a module until later in the unloading process. This allows for a 2-stage unloading process if
other modules need to be unloaded first. Note that a single module **cannot use both**
`:OnModuleUnload()` and `:OnModuleUnloadLate()`.
