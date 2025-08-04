local LibTSMClassPlugin = require("LibTSMClassLuaLSPlugin")

local Plugin = {}

local function ContextAddPrefixDiff(context, text, startPos)
	if not text then
		return
	end
	startPos = startPos or context.currentLine.startPos
	context.diffs = context.diffs or {}
	table.insert(context.diffs, {
		start = startPos,
		finish = startPos - 1,
		text = text,
	})
end

local function ContextLineIterator(context, index)
	index = index + 1
	if index > #context.lines then
		return
	end
	context.currentLine.index = index
	context.currentLine.startPos = context.lineStartPos[index]
	return index, context.lines[index]
end

function Plugin.GetContext(uri, text)
	if uri:match(".vscode[/\\]") then
		-- Don't run for plugins / extensions
		return nil
	end
	local context = {
		uri = uri,
		text = text,
		lines = {},
		lineStartPos = {},
		componentNames = {},
		diffs = nil,
		currentLine = {
			index = nil,
			startPos = nil,
		},
		AddPrefixDiff = ContextAddPrefixDiff,
		LineIterator = function(self) return ContextLineIterator, self, 0 end,
	}
	for startPos, line in text:gmatch("()(.-)\r?\n") do
		table.insert(context.lines, line)
		table.insert(context.lineStartPos, startPos)
		if line:sub(1, 5) == "local" and line:find("select(2, ...)", nil, true) then
			local varName, tblKey = line:match("^local ([A-Za-z0-9_]+) = select%(2, %.%.%.%)%.(.-)$")
			if varName and varName == tblKey then
				table.insert(context.componentNames, varName)
			end
		end
	end
	return context
end

local function DefineNewComponent(line)
	-- Do a plain text search first as an optimization since the match is expensive
	if not line:find("LibTSMCore.NewComponent", nil, true) then
		return nil
	end
	local className = line:match("[A-Za-z _0-9]+ = [A-Za-z0-9_]+%.LibTSMCore%.NewComponent%(\"([^\"]+)\"%)$")
	if not className then
		return nil
	end
	return "---@class "..className..": LibTSMComponent\n"
end

local function DefineStateTypeHelper(fieldType, fieldName, extraArg, classTypeHelperFunc)
	fieldType = fieldType:lower():gsub("^optional(.+)", "%1?")
	extraArg = extraArg:gsub("^%s*", "")
	local isOptional = fieldType:sub(-1) == "?"
	local nonOptionalFieldType = isOptional and fieldType:sub(1, -2) or fieldType
	if nonOptionalFieldType == "enum" then
		fieldType = isOptional and "EnumValue?" or "EnumValue"
	elseif nonOptionalFieldType == "class" then
		extraArg = classTypeHelperFunc and classTypeHelperFunc(extraArg) or extraArg
		fieldType = extraArg..(isOptional and "?" or "")
	end
	return "---@field "..fieldName.." "..fieldType
end

function Plugin.DefineStateType(typeName, code, parentTypeName, classTypeHelperFunc)
	-- Define class for state types defined with ReactiveStateSchema
	parentTypeName = parentTypeName or "ReactiveState"
	local resultLines = {}
	table.insert(resultLines, "---@class "..typeName..": "..parentTypeName)
	if type(code) == "table" then
		for _, line in ipairs(code) do
			local fieldType, fieldName, extraArg = line:match(":Add([A-Za-z]+)Field%(\"([A-Za-z0-9_]+)\",?(.-)%)$")
			local resultLine = fieldType and DefineStateTypeHelper(fieldType, fieldName, extraArg, classTypeHelperFunc) or nil
			if resultLine then
				table.insert(resultLines, resultLine)
			end
		end
	else
		for fieldType, fieldName, extraArg in code:gmatch(":Add([A-Za-z]+)Field%(\"([A-Za-z0-9_]+)\",?(.-)%)\r?\n") do
			local resultLine = DefineStateTypeHelper(fieldType, fieldName, extraArg, classTypeHelperFunc)
			if resultLine then
				table.insert(resultLines, resultLine)
			end
		end
	end
	return table.concat(resultLines, "\n").."\n"
end

local function ProcessStateType(context, varName, expression, classTypeHelperFunc)
	-- Define reactive state types
	local typeName = expression:match("Reactive%.CreateStateSchema%(\"(.-)\"%)")
	if not typeName then
		return
	end
	typeName = typeName:lower():gsub("_ui_", "_UI_"):gsub("^([a-z])", string.upper):gsub("_(.)", string.upper)
	local codeLines = {}
	for i = context.currentLine.index + 1, #context.lines do
		local line = context.lines[i]
		if line:match("^%s*:Commit%(%)$") then
			break
		else
			table.insert(codeLines, line)
		end
	end
	local result = Plugin.DefineStateType(typeName, codeLines, nil, classTypeHelperFunc)
	-- Insert an extra empty line so this type isn't assigned to the schema
	context:AddPrefixDiff(result.."\n")
	for i = context.currentLine.index + 1, #context.lines do
		local line = context.lines[i]
		if line:match("= "..varName..":CreateState%(%)") then
			context:AddPrefixDiff("--[[@as "..typeName.."]]", context.lineStartPos[i] + #line)
		end
	end
end

local function ProcessComponentType(context, varName, expression)
	-- Define LibTSMCore component types
	if expression ~= "select(2, ...)."..varName then
		return
	end
	context:AddPrefixDiff("---@type "..varName.."\n")
end

local function ProcessModuleType(context, expression)
	-- Define class for <COMPONENT>:Init("<MODULE_NAME>") calls
	for _, componentName in ipairs(context.componentNames) do
		local className = expression:match(componentName..":Init%(\"([^\"]+)\"%)")
		if className then
			context:AddPrefixDiff("---@class "..className..": LibTSMModule\n")
			break
		end
	end
end

local function ProcessClassType(context, expression)
	-- Define class for <COMPONENT>:DefineClassType("<CLASS_NAME>", ...) calls
	for _, componentName in ipairs(context.componentNames) do
		local className, extraArgs = expression:match(componentName..":DefineClassType%(\"([^\"]+)\"(.-)%)")
		if className then
			local parentClassName = extraArgs:match("^, (%a+)$") or extraArgs:match("^, (%a+), \"ABSTRACT\"$")
			context:AddPrefixDiff(LibTSMClassPlugin.DefineClassHelper(className, parentClassName, context.text, context.lines))
		end
	end
end

local function ProcessVariableAssignment(context, line, stateClassTypeHelperFunc)
	if line:sub(1, 5) ~= "local" then
		return
	end
	local varName, expression = line:match("^local ([A-Za-z0-9_]+) = (.-)$")
	if not varName then
		return
	end
	ProcessComponentType(context, varName, expression)
	ProcessModuleType(context, expression)
	ProcessClassType(context, expression)
	ProcessStateType(context, varName, expression, stateClassTypeHelperFunc)
end

function Plugin.ProcessContext(context, stateClassTypeHelperFunc)
	context.diffs = LibTSMClassPlugin.ProcessFileLines(context.lines, context.lineStartPos)
	for _, line in context:LineIterator() do
		ProcessVariableAssignment(context, line, stateClassTypeHelperFunc)
		context:AddPrefixDiff(DefineNewComponent(line))
	end
end

return Plugin
