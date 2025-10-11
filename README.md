# LibTSMCore

LibTSMCore defines a framework for splitting large codebases into discrete components and modules
for explicit dependency management and clearly-defined interfaces between pieces of code.

## Documentation

See [the docs](https://tradeskillmaster.github.io/LibTSMCore) for complete documentation and usage.

## Dependencies

This library has as few dependencies as possible other than than WoW environment and
[LibTSMClass](https://github.com/TradeSkillMaster/LibTSMClass). Specifically, it depends on the
following WoW globals and functions:

* `WOW_PROJECT_ID` (and associated globals) to determine the game version
* `C_AddOns.GetAddOnMetadata` to determine the version of the including addon

## Installation

If you're using the [BigWigs packager](https://github.com/BigWigsMods/packager), you can reference
LibTSMCore as an external library:

```yaml
externals:
  Libs/LibTSMCore:
    url: https://github.com/TradeSkillMaster/LibTSMCore.git
```

Otherwise, you can download the
[latest release directly from GitHub](https://github.com/TradeSkillMaster/LibTSMCore/releases).

## Basic Usage

To use LibTSMCore, add LibTSMCore.xml to your .toc (or equivalent XML) and the `LibTSMCore`
namespace will be added to your local addon table. General convention is to define a compoent
within a discrete top-level file which is loaded first:

```lua
-- Utils/Core.lua
local ADDON_TABLE = select(2, ...)
ADDON_TABLE.Utils = ADDON_TABLE.LibTSMCore.NewComponent("Utils")
```

You can then define modules within their own files. General convention is to not locally reference
the addon namespace, but instead to only reference the component namespace. You can then initialize
a new module and add APIs to it which you'd like other modules to be able to use.

```lua
-- Utils/Table.lua
local Utils = select(2, ...).Utils
local Table = Utils:Init("Table")

---Gets the keys from a table in a new list (unordered).
---@param tbl table<string,any>
---@return string[]
function Table.GetKeys(tbl)
    local keys = {}
	for key in pairs(tbl) do
        tinsert(keys, key)
	end
    return keys
end
```

Modules can then include other modules:

```lua
-- Utils/DebugPrint.lua
local Utils = select(2, ...).Utils
local DebugPrint = Utils:Init("DebugPrint")
local Table = Utils:Include("Table")

---Prints out the table keys in sorted order.
---@param tbl table<string,any>
function DebugPrint.TableKeysOrdered(tbl)
    local keys = Table.GetKeys(tbl)
    sort(keys)
    for _, key in ipairs(keys) do
        print(key)
    end
end
```

## LuaLS Plugin

A [plugin](LuaLSPlugin/LibTSMCoreLuaLSPlugin.lua) for
[LuaLS](https://github.com/LuaLS/lua-language-server) is provided to allow for better language
server support. The plugin exposes `.GetContext(uri, text)` and `.ProcessContext(context)`
functions which can be called in the `OnSetText(uri, text)` function in your own plugin as well as
a few other useful functions for more custom integrations.

## License and Contributes

LibTSMCore is licensed under the MIT license. See LICENSE.txt for more information. If you would
like to contribute to LibTSMCore, opening an issue or submitting a pull request against the
[LibTSMCore GitHub project](https://github.com/TradeSkillMaster/LibTSMCore) is highly encouraged.
