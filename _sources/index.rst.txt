LibTSMCore
===========

The `LibTSMCore <https://github.com/TradeSkillMaster/LibTSMCore>`_ defines a framework for
splitting large codebases into discrete components and modules for explicit dependency
management and clearly-defined interfaces between pieces of code.

Example
-------

To use LibTSMCore, add LibTSMCore.xml to your .toc (or equivalent XML) and the `LibTSMCore`
namespace will be added to your local addon table. General convention is to define a compoent
within a discrete top-level file which is loaded first::

   -- Utils/Core.lua
   local ADDON_TABLE = select(2, ...)
   ADDON_TABLE.Utils = ADDON_TABLE.LibTSMCore.NewComponent("Utils")

You can then define modules within their own files. General convention is to not locally reference
the addon namespace, but instead to only reference the component namespace. You can then initialize
a new module and add APIs to it which you'd like other modules to be able to use.
::

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

Modules can then include other modules::

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


Contents
--------

.. toctree::
   :maxdepth: 1

   Home <self>
   features
   api
