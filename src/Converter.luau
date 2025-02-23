--!strict
--!optimize 2

local Parser = require(script.Parent.Parser)

type StyleParent = StyleSheet | StyleRule

local function GetRoot()
    local idx = 1
    local root = debug.info(idx, "s")

    while true do
        idx += 1
        local newRoot = debug.info(idx, "s")
        if newRoot then
            root = newRoot
        else
            return root
        end
    end

    return root
end

local function InstanceFromString(instString: string): Instance
    local inst = game

    local segments = string.split(instString, ".")
    local segmentsLength = #segments

    local idx = 0
    while idx < segmentsLength do
        idx += 1
        local segment = segments[idx]

        repeat
            local ok, updatedInst = pcall(function()
                return (inst :: any)[segment]
            end)

            if not ok then
                idx += 1
                segment = `{segment}.{segments[idx]}`

            else
                inst = updatedInst
                continue
            end
        until updatedInst or idx == segmentsLength
    end

    return inst
end

local function ApplyDerive(styleSheet: StyleSheet, parent: StyleSheet)
    if typeof(styleSheet) ~= "Instance" and styleSheet.ClassName ~= "StyleSheet" then return end
    if styleSheet == parent then return end

    local derive = Instance.new("StyleDerive")
    derive.StyleSheet = styleSheet :: StyleSheet
    derive.Name = styleSheet.Name
    derive.Parent = parent
end

local function ApplyAttributes(attributes: Parser.AttributesAndProperties, parent: StyleParent)
    for attributeName, datatype in attributes do
        -- Attribute's can't start with RBX or be more than 100 characters.
        -- If this is the case then we return that parsing was successful -
        -- but we don't apply the attribute as that would cause an error.
        if string.match(attributeName, "^RBX") then continue end
        if #attributeName > 100 then continue end

        parent:SetAttribute(attributeName, datatype)
    end
end

local function ApplyRules(rules: Parser.Rules, parent: StyleParent)
    for _, node in rules do
        local selector = node.Selector :: string
        local priority = node.Priority
        local name = node.Name

        local styleRule = Instance.new("StyleRule")
        styleRule.Selector = selector
        styleRule.Name = name or selector

        styleRule:SetProperties(node.Properties)
        ApplyAttributes(node.Attributes, styleRule)

        ApplyRules(node.Rules, styleRule)

        styleRule.Parent = parent

        if priority then styleRule.Priority = priority end
    end
end

local function ConvertRsml(rootTreeNode: Parser.TreeNode, derivesTble: { StyleSheet }?, defaultStyles: StyleSheet?): StyleSheet
    local styleSheet = Instance.new("StyleSheet")

    local name = rootTreeNode.Name
    if name then styleSheet.Name = name end

    local attributes = rootTreeNode.Attributes
    if attributes then ApplyAttributes(attributes, styleSheet) end

    ApplyRules(rootTreeNode.Rules, styleSheet)

    if derivesTble then
        for _, sheetToDerive in derivesTble do
            ApplyDerive(sheetToDerive, styleSheet)
        end
    end

    local derivesFromNode = rootTreeNode.Derives
    if derivesFromNode then
        for _, sheetToDeriveStr in derivesFromNode do
            if defaultStyles and sheetToDeriveStr == "@defaults" then
                ApplyDerive(defaultStyles, styleSheet)
            end
        end
    end

    styleSheet.Parent = InstanceFromString(GetRoot())

    return styleSheet
end

return ConvertRsml