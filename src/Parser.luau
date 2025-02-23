--!strict
--!optimize 2
--!nolint LocalShadow
--!nolint DuplicateLocal

local Lexer = require(script.Parent.Lexer)
type Token = Lexer.Token

local Colors = script.Parent.Colors
local ColorsCss = require(Colors.Css)
local ColorsTailwind = require(Colors.Tailwaind)
local ColorsBrick = require(Colors.Brick)

local Parser = {}
Parser.__index = Parser

local function ParseStringMultiEnd(parser: Parser, currTreeNode, token: Token, equalsAmount: number)
    -- We keep advancing tokens until we find a closing multiline string
    -- token with the same amount of equals signs as the start token.
    while true do
        local token = parser:Advance()
        if not token then return end

        if token.Kind == "StringMultiEnd" then
            local endTokenValue = token.Value
            local endEqualsAmount = #string.sub(endTokenValue, 2, #endTokenValue - 1)

            if equalsAmount == endEqualsAmount then
                return parser:Advance()
            end
        end
    end
end

local function ParseCommentMulti(parser: Parser, currTreeNode: TreeNode, token: Token)
    if token.Kind ~= "CommentMultiStart" then return end

    local tokenValue = token.Value
    local equalsAmount = #string.sub(tokenValue, 4, #tokenValue - 1)

    ParseStringMultiEnd(parser, currTreeNode, token, equalsAmount)
end

local function ParseCommentSingle(parser: Parser, currTreeNode: TreeNode, token: Token)
    if token.Kind ~= "CommentSingle" then return end

    return parser:Advance()
end

function Parser.Advance(self: Parser): Lexer.Token?
    local newPosition = self.Position + 1
    local tokens = self.Tokens

    while true do
        local token = tokens[newPosition]
        if not token or token.Kind ~= "Empty" then break end
        newPosition += 1
    end

    self.Position = newPosition

    local token = tokens[newPosition]
    if token then ParseCommentMulti(self, self.CurrentNode, token) end

    local token = tokens[self.Position]
    if token then ParseCommentSingle(self, self.CurrentNode, token) end

    return self.Tokens[self.Position]
end

function Parser.new(tokens: { Token }, rootTreeNode: TreeNode)
    local parser = setmetatable({
        Position = 0,
        Tokens = tokens,
        CurrentNode = rootTreeNode
    }, Parser)

    parser:Advance()

    return parser
end

type OperatorKind = "OpPow" | "OpDiv" | "OpMod" | "OpMult" | "OpAdd" | "OpSub"
type OperatorSymbol = { Kind: "Operator", OperatorKind: OperatorKind }

local OperatorPowSymbol: OperatorSymbol = { Kind = "Operator", OperatorKind = "OpPow" }
local OperatorDivSymbol: OperatorSymbol = { Kind = "Operator", OperatorKind = "OpDiv" }
local OperatorModSymbol: OperatorSymbol = { Kind = "Operator", OperatorKind = "OpMod" }
local OperatorMultSymbol: OperatorSymbol = { Kind = "Operator", OperatorKind = "OpMult" }
local OperatorAddSymbol: OperatorSymbol = { Kind = "Operator", OperatorKind = "OpAdd" }
local OperatorSubSymbol: OperatorSymbol = { Kind = "Operator", OperatorKind = "OpSub" }
local OperatorSymbols: { [string]: OperatorSymbol } = {
    ["OpPow"] = OperatorPowSymbol,
    ["OpDiv"] = OperatorDivSymbol,
    ["OpMod"] = OperatorModSymbol,
    ["OpMult"] = OperatorMultSymbol,
    ["OpAdd"] = OperatorAddSymbol,
    ["OpSub"] = OperatorSubSymbol
}

export type Datatype = string | boolean | Enum | Color3 | number | UDim | UDim2 | OperatorSymbol | Vector3 | Rect | Font

export type AttributesAndProperties = { [string]: Datatype }
export type Rules = { TreeNode }

export type TreeNode = {
    Attributes: AttributesAndProperties,
    Properties: AttributesAndProperties,
    Name: string?,
    Rules: { TreeNode },
    Derives: { string },
    Selector: string?,
    Priority: number?,
    Parent: TreeNode
}

export type Parser = typeof(setmetatable({} :: {
    Position: number,
    Tokens: { Lexer.Token },
    CurrentNode: TreeNode
}, {} :: typeof(Parser)))

local function NewTreeNode(parent: TreeNode): TreeNode
    return {
        Attributes = {},
        Properties = {},
        Derives = {},
        Rules = {},
        Parent = parent
    }
end

local function ParseScopeClose(parser: Parser, currTreeNode: TreeNode, token: Token)
    if token.Kind ~= "ScopeClose" then return end

    parser.CurrentNode = currTreeNode.Parent
end

local function StringifySelectorTokens(parser: Parser, startPosition: number, endPosition: number)
    local tokens = parser.Tokens

    local stringified = ""

    local shouldAddSpace = false
    for idx = startPosition, endPosition do
        local token = tokens[idx]

        local tokenKind = token.Kind
        if tokenKind == "Empty" then continue end

        stringified ..= `{if (shouldAddSpace and tokenKind ~= "Comma") then " " else ""}{token.Value}`

        shouldAddSpace =
            tokenKind == "ScopeToDescendants" or tokenKind == "ScopeToChildren" or
            tokenKind == "Text" or tokenKind == "Comma"
    end

    return stringified
end

local function ParseScopeOpen(
    parser: Parser, currTreeNode: TreeNode, token: Token, startPosition: number
)
    if token.Kind ~= "ScopeOpen" then return end

    local selector = StringifySelectorTokens(parser, startPosition, parser.Position - 1)

    local prevTreeNode = currTreeNode
    local currTreeNode = NewTreeNode(prevTreeNode)
    currTreeNode.Selector = selector

    table.insert(prevTreeNode.Rules, currTreeNode)
    parser.CurrentNode = currTreeNode

    return true
end

local function ParseScopeDelimiter(parser: Parser, currTreeNode: TreeNode, token: Token): Token?
    if token.Kind ~= "Comma" then return end

    return parser:Advance()
end

function ParseScopeName(
    parser: Parser, currTreeNode: TreeNode, token: Token, startPosition: number?
): true?
    local tokenKind: Lexer.TokenKind = token.Kind
    
    if (
        tokenKind == "NameIdentifier" or tokenKind == "PsuedoIdentifier" or 
        tokenKind == "StateOrEnumIdentifier" or tokenKind == "TagOrEnumIdentifier" or 
        tokenKind == "ScopeToDescendants" or tokenKind == "ScopeToChildren" or
        tokenKind == "Text"
    )  then
        startPosition = startPosition or parser.Position

        local token = parser:Advance()

        if token then
            local token = ParseScopeDelimiter(parser, currTreeNode, token) or token

            if token then
                if ParseScopeName(parser, currTreeNode, token, startPosition) then return end
            end
        end
    end

    if not startPosition or startPosition == parser.Position then return end

    return ParseScopeOpen(parser, currTreeNode, token, startPosition)
end


local function ParseText(parser: Parser, currTreeNode: TreeNode, token: Token): string?
    if token.Kind ~= "Text" then return end

    return token.Value
end

local function ParseEquals(parser: Parser, currTreeNode: TreeNode, token: Token): true?
    if token.Kind ~= "Equals" then return end

    return true
end

local function ParseEnumTokens(parser: Parser, startPosition: number, endPosition: number): EnumItem | true
    local ok, enum
    local tokens = parser.Tokens

    local firstStopIdx = 0
    for idx = startPosition, endPosition do
        local token = tokens[idx]

        if token.Kind ~= "Text" then continue end

        firstStopIdx = idx
        ok, enum = pcall(function() return Enum[token.Value] end)
        if not ok then return true end
        break
    end

    for idx = firstStopIdx + 1, endPosition do
        local token = tokens[idx]
        if token.Kind ~= "Text" then continue end

        ok, enum = pcall(function() return enum[token.Value] end)
        if not ok then return true end
        break
    end

    return enum :: EnumItem
end

local function ParseFullEnum(parser: Parser, currTreeNode: TreeNode, token: Token, startPosition: number?): (EnumItem | true)?
    local tokenKind: Lexer.TokenKind = token.Kind
    if tokenKind == "TagOrEnumIdentifier" or tokenKind == "StateOrEnumIdentifier" or tokenKind == "Text" then
        startPosition = startPosition or parser.Position

        local token = parser:Advance()

        if token then
            local fullEnum = ParseFullEnum(parser, currTreeNode, token, startPosition)
            if fullEnum then return fullEnum end
        end
    end

    if not startPosition or startPosition == parser.Position then return end
    
    return ParseEnumTokens(parser, startPosition, parser.Position - 1)
end

local function ParseEnumShorthand(parser: Parser, currTreeNode: TreeNode, token: Token, key: string?): (Enum | true)?
    if not key then return end
    if token.Kind ~= "StateOrEnumIdentifier" then return end

    local token = parser:Advance()
    if not token then return end

    local enumItem = ParseText(parser, currTreeNode, token)
    if not enumItem then return end

    local ok, enum = pcall(function() return Enum[key] end)
    if not ok then return true end

    local ok, enum = pcall(function() return enum[enumItem] end)
    if not ok then return true end

    return enum
end

local function ParseEnumKeyword(parser: Parser, currTreeNode: TreeNode, token: Token)
    if token.Kind ~= "EnumKeyword" then return end

    local token = parser:Advance()
    if not token then return end

    return ParseFullEnum(parser, currTreeNode, token)
end

local function ParseEnumDatatype(parser: Parser, currTreeNode: TreeNode, token: Token, key: string?)
    return ParseEnumKeyword(parser, currTreeNode, token) or ParseEnumShorthand(parser, currTreeNode, token, key)
end

local function ParseNumberScale(parser: Parser, currTreeNode: TreeNode, token: Token, num: number): UDim?
    if token.Kind ~= "ScaleOrOpMod" then return end

    parser:Advance()

    return UDim.new(num / 100, 0)
end

local function ParseNumberOffset(parser: Parser, currTreeNode: TreeNode, token: Token, num: number): UDim?
    if token.Kind ~= "Offset" then return end

    parser:Advance()

    return UDim.new(0, num)
end

local function ParseNumberDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): (number | UDim)?
    if token.Kind ~= "Number" then return end
    local num = tonumber(token.Value) :: number

    local token = parser:Advance()
    if not token then return num end

    local parsed = ParseNumberOffset(parser, currTreeNode, token, num)
    if parsed then return parsed end

    local parsed = ParseNumberScale(parser, currTreeNode, token, num)
    if parsed then return parsed end

    return num
end

local function ParseStringMultiDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): string?
    if token.Kind ~= "StringMultiStart" then return end

    local tokenValue = token.Value
    local equalsAmount = #string.sub(tokenValue, 4, #tokenValue - 1)

    local startPosition = parser.Position
    ParseStringMultiEnd(parser, currTreeNode, token, equalsAmount)
    local endPosition = parser.Position
    
    -- Joins the string tokens together ignoring the opening and closing tokens.
    local tokens = parser.Tokens
    local str = ""
    for idx = startPosition - 1, endPosition - 1 do
        str ..= tokens[idx].Value
    end

    -- Luau strips multiline strings up until the first occurances of multiline characters.
    str = string.gsub(str, "^[ \t\f]*\n+", "")

    return str
end

local function ParseStringSingleDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): string?
    local tokenKind: Lexer.TokenKind = token.Kind
    if tokenKind ~= "StringSingle" and tokenKind ~= "RobloxAsset" then return end

    parser:Advance()

    return token.Value
end

local function ParseStringDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): string?
    return ParseStringSingleDatatype(parser, currTreeNode, token) or ParseStringMultiDatatype(parser, currTreeNode, token)
end

local function ParseColorTailwindDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): Color3?
    if token.Kind ~= "ColorTailwind" then return end

    parser:Advance()

    local color: string? = ColorsTailwind[token.Value]
    return if color then Color3.fromHex(color) else nil
end

local function ParseColorCssDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): Color3?
    if token.Kind ~= "ColorCss" then return end

    parser:Advance()

    local color: string? = ColorsCss[token.Value]
    return if color then Color3.fromHex(color) else nil
end


local function ParseColorBrickDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): Color3?
    if token.Kind ~= "ColorBrick" then return end

    parser:Advance()

    local color: { number }? = ColorsBrick[token.Value]
    return if color then Color3.fromRGB(color[1], color[2], color[3]) else nil
end

local function ParseBoolean(parser: Parser, currTreeNode: TreeNode, token: Token): boolean?
    if token.Kind ~= "Boolean" then return end

    parser:Advance()

    return if token.Value == "true" then true else false
end

local function ParseAttributeName(parser: Parser, currTreeNode: TreeNode, token: Token): string?
    if token.Kind ~= "VariableIdentifier" then return end

    local token = parser:Advance()
    if not token then return end

    return ParseText(parser, currTreeNode, token)
end

type Tuple = {
    Name: string?,
    Parent: Tuple?,
    Data: { Datatype },
}

local function NewTuple(name: string?, parent: Tuple?)
    return {
        Name = name,
        Parent = parent or nil,
        Data = {}   
    }
end

local function DefaultIfNotType<T>(target: T, expectedType: string, default: T): T
    return if type(target) ~= expectedType then default else target
end

local function CoerceToUDim<T>(target: T, default: UDim): UDim
    local targetTypeof = typeof(target)
    if targetTypeof == "number" then return UDim.new((target :: any) :: number, 0) end
    if targetTypeof == "UDim" then return (target :: any) :: UDim end
    return default
end

type TupleAnnotationFunction<T = Datatype> = (data: { Datatype }) -> T

type TupleAnnotationFunctions = {
    udim: TupleAnnotationFunction<UDim>,
    udim2: TupleAnnotationFunction<UDim2>,
    vec2: TupleAnnotationFunction<Vector2>,
    vec3: TupleAnnotationFunction<Vector3>,
    rect: TupleAnnotationFunction<Rect>,
    color3: TupleAnnotationFunction<Color3>,
    rgb: TupleAnnotationFunction<Color3>,
    font: TupleAnnotationFunction<Font>,
}

local TupleAnnotations: TupleAnnotationFunctions = {
    udim = function(data)
        local scale = DefaultIfNotType(data[1], "number", 0) :: number
        local offset = DefaultIfNotType(data[2], "number", scale * 100) :: number

        return UDim.new(scale, offset)
    end,

    udim2 = function(data)
        if #data <= 2 then
            local xComponent = CoerceToUDim(data[1], UDim.new())
            local yComponent = CoerceToUDim(data[2], xComponent)
            return UDim2.new(xComponent, yComponent)

        else
            local xScale = DefaultIfNotType(data[1], "number", 0) :: number
            local xOffset = DefaultIfNotType(data[2], "number", 0) :: number
            local yScale = DefaultIfNotType(data[3], "number", 0) :: number
            local yOffset = DefaultIfNotType(data[4], "number", 0) :: number

            return UDim2.new(xScale, xOffset, yScale, yOffset)
        end
    end,

    vec2 = function(data)
        local xComponent = DefaultIfNotType(data[1], "number", 0) :: number
        local yComponent = DefaultIfNotType(data[2], "number", xComponent) :: number

        return Vector2.new(xComponent, yComponent)
    end,

    vec3 = function(data)
        local xComponent = DefaultIfNotType(data[1], "number", 0) :: number
        local yComponent = DefaultIfNotType(data[2], "number", xComponent) :: number
        local zComponent = DefaultIfNotType(data[3], "number", yComponent) :: number

        return (vector.create(xComponent, yComponent, zComponent) :: any) :: Vector3
    end,

    rect = function(data)
        local minX = DefaultIfNotType(data[1], "number", 0) :: number
        local minY = DefaultIfNotType(data[2], "number", minX) :: number
        local maxX = DefaultIfNotType(data[2], "number", minX) :: number
        local maxY = DefaultIfNotType(data[2], "number", maxX) :: number

        return Rect.new(minX, minY, maxX, maxY)
    end,

    color3 = function(data)
        local red = DefaultIfNotType(data[1], "number", 0) :: number
        local green = DefaultIfNotType(data[2], "number", red) :: number
        local blue = DefaultIfNotType(data[3], "number", green) :: number

        return Color3.new(red, green, blue)
    end,

    rgb = function(data)
        local red = DefaultIfNotType(data[1], "number", 0) :: number
        local green = DefaultIfNotType(data[2], "number", red)  :: number
        local blue = DefaultIfNotType(data[3], "number", green) :: number

        return Color3.fromRGB(red, green, blue)
    end,

    font = function(data)
        local fontFamily = data[1]
        local fontFamilyType = type(fontFamily)

        if fontFamilyType == "number" then
            fontFamily = `rbxassetid://{fontFamily}`

        elseif fontFamilyType == "string" then
            if not string.match(fontFamily :: string, "^rbxasset://") then
                fontFamily = `rbxasset://fonts/families/{fontFamily}.json`
            end
        else

            fontFamily = "rbxasset://fonts/families/SourceSansPro.json"
        end

        local fontWeight = data[2]
        local fontWeight =
            if fontWeight == "Regular" then Enum.FontWeight.Regular
            elseif fontWeight == "Thin" then Enum.FontWeight.Thin
            elseif fontWeight == "ExtraLight" then Enum.FontWeight.ExtraLight
            elseif fontWeight == "Light" then Enum.FontWeight.Light
            elseif fontWeight == "Medium" then Enum.FontWeight.Medium
            elseif fontWeight == "SemiBold" then Enum.FontWeight.SemiBold
            elseif fontWeight == "Bold" then Enum.FontWeight.Bold
            elseif fontWeight == "ExtraBold" then Enum.FontWeight.ExtraBold
            elseif fontWeight == "Heavy" then Enum.FontWeight.Heavy
            else Enum.FontWeight.Regular

        local fontStyle = data[3]
        local fontStyle =
            if fontStyle == "Italic" then Enum.FontStyle.Italic
            else Enum.FontStyle.Normal
        
        return Font.new(fontFamily :: string, fontWeight, fontStyle)
    end,
}

local function CoerceTupleToDatatype(tuple: Tuple): Datatype?
    local tupleName = tuple.Name

    if tupleName then
        local annotationFunction = TupleAnnotations[string.lower(tupleName)]
        if annotationFunction then return annotationFunction(tuple.Data) end
    end

    -- If the tuple's datatypes could not be coerced into
    -- one datatype then the first datatype is returned.
    return tuple.Data[1]
end

local function ParseTupleClose(
    parser: Parser, currTreeNode: TreeNode, token: Token, 
    rootTuple: Tuple, tuple: Tuple
): Tuple?
    if token.Kind ~= "ParensClose" then return end

    local parentTuple = tuple.Parent

    if parentTuple then
        local datatype = CoerceTupleToDatatype(tuple)
        if datatype then table.insert(parentTuple.Data, datatype) end
    end

    -- We are at the root of the tuple, no need to parse more tuple tokens.
    if rootTuple == tuple then return rootTuple end

    local token = parser:Advance()
    if not token then return parentTuple end

    if parentTuple then
        local parsed = ParseTupleDelimiter(parser, currTreeNode, token, rootTuple, parentTuple)
        if parsed then return parsed end

        local parsed = ParseTupleClose(parser, currTreeNode, token, rootTuple, parentTuple)
        if parsed then return parsed end

        local parsed = ParseTupleDatatype(parser, currTreeNode, token, rootTuple, parentTuple)
        if parsed then return parsed end

        local parsed = ParseTupleName(parser, currTreeNode, token, rootTuple, parentTuple)
        if parsed then return parsed end
    end

    return parentTuple
end

function ParseTupleDelimiter(
    parser: Parser, currTreeNode: TreeNode, token: Token, 
    rootTuple: Tuple, tuple: Tuple
): Tuple?
    local tokenKind = token.Kind
    if tokenKind ~= "SemiColon" and tokenKind ~= "Comma" then return end

    local token = parser:Advance()
    if not token then return end

    -- Handles cases where there are multiple delimiter tokens next to each other.
    local parsed = ParseTupleDelimiter(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    local parsed = ParseTupleDatatype(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    local parsed = ParseTupleClose(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    local parsed = ParseTupleName(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    return tuple
end

function ParseTupleDatatype(
    parser: Parser, currTreeNode: TreeNode, token: Token, 
    rootTuple: Tuple, tuple: Tuple
): Tuple?
    local datatype = ParseDatatypeGroup(parser, currTreeNode, token, nil)
    if not datatype then return end

    table.insert(tuple.Data, datatype)

    local token = parser:Advance()
	if not token then return end
	
	local parsed = ParseTupleDelimiter(parser, currTreeNode, token, rootTuple, tuple)
	if parsed then return parsed end

    local parsed = ParseTupleClose(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    local parsed = ParseTupleName(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    return tuple
end

local function ParseTupleOpen(
    parser: Parser, currTreeNode: TreeNode, token: Token, tupleName: string?, 
    rootTuple: Tuple?, parentTuple: Tuple?
): Tuple?
    if token.Kind ~= "ParensOpen" then return end

    local tuple = NewTuple(tupleName, parentTuple)

    local token = parser:Advance()
    if not token then return end

    local rootTuple = rootTuple or tuple

    local parsed = ParseTupleDelimiter(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    local parsed = ParseTupleClose(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    local parsed = ParseTupleName(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    local parsed = ParseTupleDatatype(parser, currTreeNode, token, rootTuple, tuple)
    if parsed then return parsed end

    return tuple
end

function ParseTupleName(
    parser: Parser, currTreeNode: TreeNode, token: Token,
    rootTuple: Tuple?, parentTuple: Tuple?
): Tuple?
    if token.Kind ~= "Text" then
        return ParseTupleOpen(parser, currTreeNode, token, nil, rootTuple, parentTuple)
    end

    local tupleName = token.Value

    local token = (parser :: Parser):Advance()
    if not token then return end

    return ParseTupleOpen(parser, currTreeNode, token, tupleName, rootTuple, parentTuple)
end

local function ParseOperatorDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): OperatorSymbol?
    local operator = OperatorSymbols[token.Kind]
    if operator then parser:Advance() end
    return operator
end

local function ParseDatatype(parser: Parser, currTreeNode: TreeNode, token: Token, key: string?): Datatype?
    local parsed = ParseTupleName(parser, currTreeNode, token)
    if parsed ~= nil then return CoerceTupleToDatatype(parsed) end

    local parsed = ParseStringDatatype(parser, currTreeNode, token)
    if parsed ~= nil then return parsed end

    local parsed = ParseNumberDatatype(parser, currTreeNode, token)
    if parsed ~= nil then return parsed end

    local parsed = ParseOperatorDatatype(parser, currTreeNode, token)
    if parsed ~= nil then return parsed end

    local parsed = ParseEnumDatatype(parser, currTreeNode, token, key)
    if parsed ~= nil then return parsed end

    local parsed = ParseColorTailwindDatatype(parser, currTreeNode, token)
    if parsed ~= nil then return parsed end

    local parsed = ParseColorCssDatatype(parser, currTreeNode, token)
    if parsed ~= nil then return parsed end
    
    local parsed = ParseColorBrickDatatype(parser, currTreeNode, token)
    if parsed ~= nil then return parsed end

    local parsed = ParseBoolean(parser, currTreeNode, token)
    if parsed ~= nil then return parsed end

    local parsed = ParseAttributeName(parser, currTreeNode, token)
    if parsed ~= nil then return `${parsed}` end

    return nil
end

local function DatatypeIsOperator(datatype: Datatype)
    return type(datatype) == "table" and datatype.Kind == "Operator"
end

local function AtomizeOperators(left: OperatorSymbol, right: OperatorSymbol)
    local leftOp, rightOp = left.OperatorKind, right.OperatorKind

    return
        if leftOp == "Sub" and rightOp == "Add" then OperatorSubSymbol
        elseif leftOp == "Sub" and rightOp == "Sub" then OperatorAddSymbol
        else right
end

local function FindOperatorInDatatypes(datatypes: { Datatype }, operatorKind: OperatorKind): { number }
    local indexes = {}

    for idx, datatype in datatypes do
        if DatatypeIsOperator(datatype) and (datatype :: OperatorSymbol).OperatorKind == operatorKind then
            table.insert(indexes, idx)
        end
    end

    return indexes
end

local OrderedOperators: { OperatorSymbol } = {
    OperatorPowSymbol, OperatorDivSymbol, OperatorModSymbol, OperatorMultSymbol,
    OperatorAddSymbol, OperatorSubSymbol
}

type OperationFn = (left: number, right: number) -> number

local OperationFns: { [OperatorSymbol]: OperationFn } = {
    [OperatorPowSymbol] = function(left: number, right: number) return left ^ right end,
    [OperatorDivSymbol] = function(left: number, right: number) return left / right end,
    [OperatorModSymbol] = function(left: number, right: number) return left % right end,
    [OperatorMultSymbol] = function(left: number, right: number) return left * right end,
    [OperatorAddSymbol] = function(left: number, right: number) return left + right end,
    [OperatorSubSymbol] = function(left: number, right: number) return left - right end,
}

type Operations = {
    [string]: {
        [string]: (left: any, right: any, operationFn: OperationFn) -> Datatype
    }
}

local DatatypeOperations: Operations = {
    ["number"] = {
        ["number"] = function(left: number, right: number, operationFn)
            return operationFn(left, right)
        end,

        ["UDim"] = function(left: number, right: UDim, operationFn): UDim
            return UDim.new(operationFn(left, right.Scale),  right.Offset)
        end,

        ["UDim2"] = function(left: number, right: UDim2, operationFn): UDim2
            local rightX, rightY = right.X, right.Y

            return UDim2.new(
                operationFn(left, rightX.Scale), rightX.Offset, 
                operationFn(left, rightY.Scale), rightY.Offset
            )
        end,

        ["Vector3"] = function(left: number, right: Vector3, operationFn): Vector3
            return Vector3.new(
                operationFn(left, right.X), 
                operationFn(left, right.Y),
                operationFn(left, right.Z)
            )
        end
    },

    ["UDim"] = {
        ["number"] = function(left: UDim, right: number, operationFn): UDim
            return UDim.new(operationFn(left.Scale, right), left.Offset)
        end,

        ["UDim"] = function(left: UDim, right: UDim, operationFn): UDim
            return UDim.new(operationFn(left.Scale, right.Scale), operationFn(left.Offset, right.Offset))
        end
    },

    ["UDim2"] = {
        ["number"] = function(left: UDim2, right: number, operationFn): UDim2
            local leftX, leftY = left.X, left.Y

            return UDim2.new(
                operationFn(leftX.Scale, right), leftX.Offset,
                operationFn(leftY.Scale, right), leftY.Offset
            )
        end,

        ["UDim2"] = function(left: UDim2, right: UDim2, operationFn): UDim2
            local leftX, leftY, rightX, rightY = left.X, left.Y, right.X, right.Y

            return UDim2.new(
                operationFn(leftX.Scale, rightX.Scale), operationFn(leftX.Offset, rightX.Offset),
                operationFn(leftY.Scale, rightY.Scale), operationFn(leftY.Offset, rightY.Offset)
            )
        end
    },

    ["Vector3"] = {
        ["number"] = function(left: Vector3, right: number, operationFn): Vector3
            return Vector3.new(
                operationFn(left.X, right), 
                operationFn(left.Y, right),
                operationFn(left.Z, right)
            )
        end,

        ["Vector3"] = function(left: Vector3, right: Vector3, operationFn): Vector3
            return Vector3.new(
                operationFn(left.X, right.X), 
                operationFn(left.Y, right.Y),
                operationFn(left.Z, right.Z)
            )
        end,
    }
}

local function SolveDatatypeGroup(datatypes: { Datatype }): Datatype
    for _, operator in OrderedOperators do
        local occurrences = FindOperatorInDatatypes(datatypes, operator.OperatorKind)
        local occurrenceIdxOffset = 0

        local operationFn = OperationFns[operator]

        for _, occurrenceIdx in occurrences do
            occurrenceIdx -= occurrenceIdxOffset

            local rightIdx = occurrenceIdx + 1
            if rightIdx > #datatypes then continue end

            local right = table.remove(datatypes, rightIdx) :: Datatype
            occurrenceIdxOffset += 1

            -- If `right` is the first item of the table then we assign `0` to the left side.
            local left: Datatype
            if occurrenceIdx == 1 then
                left = 0 

            else
                local leftIdx = occurrenceIdx - 1
                left = table.remove(datatypes, leftIdx) :: Datatype
                occurrenceIdxOffset += 1
            end

            local datatypeOperations = DatatypeOperations[typeof(left)]
            if not datatypeOperations then
                datatypes[occurrenceIdx - 1] = left
                continue
            end

            local datatypeOperationFn = datatypeOperations[typeof(right)]
            if not datatypeOperationFn then
                datatypes[occurrenceIdx - 1] = left
                continue
            end

            datatypes[occurrenceIdx - 1] = datatypeOperationFn(left, right, operationFn)
        end
    end

    return datatypes[1]
end

local function ResolveDatatypeGroup(
    parser: Parser, currTreeNode: TreeNode, datatypes: { Datatype }?
): Datatype?
    if not datatypes then return end
    if #datatypes == 1 then return datatypes[1] end

    parser:Advance()

    return SolveDatatypeGroup(datatypes)
end

local function DatatypesMightCreateThenInsert(datatypes: { Datatype }?, datatype: Datatype)
    if not datatypes then
        datatypes = { datatype } :: { Datatype }
    else
        table.insert(datatypes, datatype)
    end

    return datatypes
end

function ParseDatatypeGroup(
    parser: Parser, currTreeNode: TreeNode, token: Token, key: string?,
    datatypes: { Datatype }?, pendingOperator: OperatorSymbol?
): Datatype?
    local datatype = ParseDatatype(parser, currTreeNode, token, key)
    if not datatype then
        return ResolveDatatypeGroup(parser, currTreeNode, datatypes)
    end

    local datatypeIsOperator = DatatypeIsOperator(datatype)

    -- If the datatype is an operator then we need to postpone adding it
    -- to the datatypes group so we can atomise it with the next datatype
    -- if it is an operator.
    if not datatypeIsOperator then
        if pendingOperator then
            -- We can add our pending operator to the datatypes table
            -- since it has no other operator to atomise with.
            datatypes = DatatypesMightCreateThenInsert(datatypes, pendingOperator)
            pendingOperator = nil -- Operator is no longer pending anymore.

            table.insert(datatypes :: { Datatype }, datatype)

        else
            datatypes = DatatypesMightCreateThenInsert(datatypes, datatype)
        end
    end

    local token = parser.Tokens[parser.Position]
    if not token then
        return ResolveDatatypeGroup(parser, currTreeNode, datatypes)
    end
    local tokenKind: Lexer.TokenKind = token.Kind

    if tokenKind == "ParensClose" or tokenKind == "ScopeClose" or tokenKind == "Comma" or tokenKind == "SemiColon" then
        return ResolveDatatypeGroup(parser, currTreeNode, datatypes)
    else
        if datatypeIsOperator then
            -- Since our datatype was an operator we need to mark it as pending,
            -- atomising with the existing pending operator if it exists.
            pendingOperator =
                if pendingOperator then AtomizeOperators(pendingOperator, datatype :: OperatorSymbol)
                else datatype :: OperatorSymbol
        end

        return ParseDatatypeGroup(parser, currTreeNode, token, key, datatypes, pendingOperator)
    end
end

local function ParseAttribute(parser: Parser, currTreeNode: TreeNode, token: Token): true?
    local attributeName = ParseAttributeName(parser, currTreeNode, token)
    if not attributeName then return end

    local token = parser:Advance()
    if not token then return end

    if not ParseEquals(parser, currTreeNode, token) then return end

    local token = parser:Advance()
    if not token then return end

    local datatype = ParseDatatypeGroup(parser, currTreeNode, token, attributeName)
    if not datatype then return end

    currTreeNode.Attributes[attributeName] = datatype
    return true
end

local function ParseProperty(parser: Parser, currTreeNode: TreeNode, token: Token): true?
    local propertyName = ParseText(parser, currTreeNode, token)
    if not propertyName then return end

    local token = parser:Advance()
    if not token then return end

    if not ParseEquals(parser, currTreeNode, token) then
        return ParseScopeName(parser, currTreeNode, token, parser.Position - 2)
    end

    local token = parser:Advance()
    if not token then return end

    local datatype = ParseDatatypeGroup(parser, currTreeNode, token, propertyName)
    if datatype == nil then return end

    currTreeNode.Properties[propertyName] = datatype
    return true
end

local function ParsePriorityValue(parser: Parser, currTreeNode: TreeNode, token: Token): number?
    if token.Kind ~= "Number" then return end

    return math.floor(tonumber(token.Value) :: number)
end

local function ParsePriorityDeclaration(parser: Parser, currTreeNode: TreeNode, token: Token): true?
    if token.Kind ~= "PriorityDeclaration" then return end

    local token = parser:Advance()
    if not token then return end

    local priorityValue = ParsePriorityValue(parser, currTreeNode, token)
    if not priorityValue then return end

    currTreeNode.Priority = priorityValue

    return true
end

local function ParseNameDeclaration(parser: Parser, currTreeNode: TreeNode, token: Token): true?
    if token.Kind ~= "NameDeclaration" then return end

    local token = parser:Advance()
    if not token then return end

    local nameValue = ParseStringDatatype(parser, currTreeNode, token)
    if not nameValue then return end

    currTreeNode.Name = nameValue

    return true
end

local function ParseDefaultsDeclaration(parser: Parser, currTreeNode: TreeNode, token: Token): true?
    if token.Kind ~= "DefaultsDeclaration" then return end

    table.insert(currTreeNode.Derives, "@defaults")

    return true
end

local function ParseRsml(tokens: { Token })
    local rootTreeNode = NewTreeNode(nil :: any)
    rootTreeNode.Parent = rootTreeNode

    local parser = Parser.new(tokens, rootTreeNode)

    while true do
        local token = tokens[parser.Position]
        if token then ParseProperty(parser, parser.CurrentNode, token) end

        local token = tokens[parser.Position]
        if token then ParseAttribute(parser, parser.CurrentNode, token) end

        local token = tokens[parser.Position]
        if token then ParseScopeName(parser, parser.CurrentNode, token) end

        local token = tokens[parser.Position]
        if token then ParseScopeClose(parser, parser.CurrentNode, token) end

        local token = tokens[parser.Position]
        if token then ParsePriorityDeclaration(parser, parser.CurrentNode, token) end

        local token = tokens[parser.Position]
        if token then ParseNameDeclaration(parser, parser.CurrentNode, token) end

        local token = tokens[parser.Position]
        if token then ParseDefaultsDeclaration(parser, parser.CurrentNode, token) end

        if not parser:Advance() then break end
    end

    return rootTreeNode
end

return ParseRsml