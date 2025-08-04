local opt = {}
opt.std = "lua51c"

-- Load globals
opt.globals = {}
opt.read_globals = {
	-- Addon Globals
	"LibStub",

	-- WoW Constants
	"WOW_PROJECT_ID",
	"WOW_PROJECT_CLASSIC",
	"WOW_PROJECT_MISTS_CLASSIC",
	"WOW_PROJECT_MAINLINE",

	-- Math Functions
	"abs",
	"acos",
	"asin",
	"atan",
	"atan2",
	"ceil",
	"cos",
	"deg",
	"exp",
	"floor",
	"fmod",
	"frexp",
	"ldexp",
	"log",
	"log10",
	"max",
	"min",
	"mod",
	"rad",
	"random",
	"sin",
	"sqrt",
	"tan",
	"fastrandom",

	-- String Functions
	"format",
	"gmatch",
	"gsub",
	"strbyte",
	"strchar",
	"strfind",
	"strlenutf8",
	"strlower",
	"strmatch",
	"strrep",
	"strrev",
	"strsub",
	"strupper",
	"tonumber",
	"tostring",
	"strtrim",
	"strsplit",
	"strjoin",
	"tostringall",

	-- Table Functions
	"CopyTable",
	"sort",
	"tContains",
	"tinsert",
	"tremove",
	"wipe",
	"table.removemulti",

	-- Bit Functions
	"bit.band",

	-- Misc. WoW Functions
	"date",
	"debugstack",

	-- Strictly Required WoW APIs
	"C_AddOns.GetAddOnMetadata",

	-- Optional WoW APIs
	"C_EncodingUtil",
}

-- No max line length
opt.max_line_length = false

-- Show warning codes in output
opt.codes = true

-- Ignore warnings
opt.ignore = {
	"311", -- pre-setting locals to nil
	"542", -- empty if blocks
	"212", -- unused function arguments
}

-- Only output files with warnings / errors
opt.quiet = 1

-- Exclude tests and plugins
opt.exclude_files = {
	"Tests/",
	"LuaLSPlugin/",
	".vscode/"
}

return opt
