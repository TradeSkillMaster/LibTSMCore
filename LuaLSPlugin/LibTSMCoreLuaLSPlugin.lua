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

local function ContextVariableAssignmentIterator(context, index)
	index = index + 1
	if index > #context.variableAssignmentLines then
		return
	end
	local lineIndex = context.variableAssignmentLines[index]
	context.currentLine.index = lineIndex
	context.currentLine.startPos = context.lineStartPos[lineIndex]
	return index, context.variableAssignmentVarNames[index], context.variableAssignmentExpressions[index]
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
		variableAssignmentLines = {},
		variableAssignmentVarNames = {},
		variableAssignmentExpressions = {},
		componentNames = {},
		diffs = nil,
		currentLine = {
			index = nil,
			startPos = nil,
		},
		AddPrefixDiff = ContextAddPrefixDiff,
		LineIterator = function(self) return ContextLineIterator, self, 0 end,
		VariableAssignmentIterator = function(self) return ContextVariableAssignmentIterator, self, 0 end,
	}
	for startPos, line in text:gmatch("()(.-)\r?\n") do
		table.insert(context.lines, line)
		table.insert(context.lineStartPos, startPos)
		if line:sub(1, 5) == "local" then
			if line:find("select(2, ...)", nil, true) then
				local varName, tblKey = line:match("^local ([A-Za-z0-9_]+) = select%(2, %.%.%.%)%.(.-)$")
				if varName and varName == tblKey then
					table.insert(context.componentNames, varName)
				end
			end
			local varName, expression = line:match("^local ([A-Za-z0-9_]+) = (.-)$")
			if varName then
				table.insert(context.variableAssignmentLines, #context.lines)
				table.insert(context.variableAssignmentVarNames, varName)
				table.insert(context.variableAssignmentExpressions, expression)
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

local function ProcessComponentType(context, varName, expression)
	-- Define LibTSMCore component types
	if expression ~= "select(2, ...)."..varName then
		return
	end
	context:AddPrefixDiff("---@type "..varName.."\n")
end

local function ProcessModuleType(context, expression)
	-- Define class for <COMPONENT>:Init*("<MODULE_NAME>") calls
	for _, componentName in ipairs(context.componentNames) do
		local className = expression:match(componentName..":InitI?n?t?e?r?n?a?l?%(\"([^\"]+)\"%)")
		if className then
			context:AddPrefixDiff("---@class "..className..": LibTSMModule\n")
			break
		end
	end
end

local function ProcessClassType(context, expression)
	for _, componentName in ipairs(context.componentNames) do
		-- Define class for <COMPONENT>:Define*ClassType("<CLASS_NAME>", ...) calls
		local className, extraArgs = expression:match(componentName..":DefineI?n?t?e?r?n?a?l?ClassType%(\"([^\"]+)\"(.-)%)")
		if className then
			local parentClassName = extraArgs:match("^, (%a+)$") or extraArgs:match("^, (%a+), \"ABSTRACT\"$")
			if parentClassName == "nil" then
				parentClassName = nil
			end
			context:AddPrefixDiff(LibTSMClassPlugin.DefineClassHelper(className, parentClassName, context.text, context.lines))
		end
		-- Define class for <COMPONENT>:ExtendClass("<CLASS_NAME>") calls
		local extendClassName = expression:match(componentName..":ExtendClass%(\"([^\"]+)\"%)")
		if extendClassName then
			context:AddPrefixDiff("---@class "..extendClassName.."\n")
		end
		-- Define class for <COMPONENT>:From("<OTHER_COMPONENT>"):ExtendClass("<CLASS_NAME>") calls
		local extendClassName2 = expression:match(componentName..":From%(\"[^\"]+\"%):ExtendClass%(\"([^\"]+)\"%)")
		if extendClassName2 then
			context:AddPrefixDiff("---@class "..extendClassName2.."\n")
		end
	end
end

function Plugin.ProcessContext(context)
	context.diffs = LibTSMClassPlugin.ProcessFileLines(context.lines, context.lineStartPos)
	for _, varName, expression in context:VariableAssignmentIterator() do
		ProcessComponentType(context, varName, expression)
		ProcessModuleType(context, expression)
		ProcessClassType(context, expression)
	end
	for _, line in context:LineIterator() do
		context:AddPrefixDiff(DefineNewComponent(line))
	end
end

return Plugin
