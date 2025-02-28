--!strict
--!optimize 2
--!nolint LocalShadow
--!nolint DuplicateLocal

local Lexer = require(script.Parent.Lexer)
type Token = Lexer.Token

local Colors = script.Parent.Colors
local ColorsCss = require(Colors.Css)
local ColorsTailwind = require(Colors.Tailwind)
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

export type Datatype = string | boolean | Enum | Color3 | number | UDim | UDim2 | OperatorSymbol | Vector3 | Rect | Font | Vector2 | ColorSequenceKeypoint

export type AttributesAndProperties = { [string]: Datatype | TupleData }
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

    return ColorsTailwind[token.Value]
end

local function ParseColorCssDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): Color3?
    if token.Kind ~= "ColorCss" then return end

    parser:Advance()

    return ColorsCss[token.Value]
end


local function ParseColorBrickDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): Color3?
    if token.Kind ~= "ColorBrick" then return end

    parser:Advance()

    return ColorsBrick[token.Value]
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

type TupleData = { Datatype | { TupleData } }

type Tuple = {
    Name: string?,
    Parent: Tuple?,
    Data: TupleData,
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

local function DefaultIfNotTypeOf<T>(target: T, expectedType: string, default: T): T
    return if typeof(target) ~= expectedType then default else target
end

local function CoerceToUDim<T>(target: T, default: UDim): UDim
    local targetTypeof = typeof(target)
    if targetTypeof == "number" then return UDim.new((target :: any) :: number, 0) end
    if targetTypeof == "UDim" then return (target :: any) :: UDim end
    return default
end

local function ColorSeqGetColorAndTime(item: Datatype): (Color3, number?)
    local color, colorTime

    local typeofItem = typeof(item)

    if typeofItem == "table" then
        colorTime = DefaultIfNotType((item :: any)[1], "number", nil)
        color = DefaultIfNotTypeOf((item :: any)[2], "Color3", Color3.new())

    elseif typeofItem == "Color3" then
        color = item
    end

    return color, if colorTime then math.clamp(colorTime, 0, 1) else nil
end

local function ColorSeqGetStartValue(
    currIdx: number, colors: { ColorSequenceKeypoint | Color3 }
): (number, number)
    for idx = currIdx - 1, 1, -1 do
        local color = colors[idx]
        if typeof(color) ~= "ColorSequenceKeypoint" then continue end

        return idx, color.Time :: number
    end

    return 1, 0
end

local function ColorSeqGetEndValue(
    currIdx: number, colors: { ColorSequenceKeypoint | Color3 }, colorsLength: number
): (number, number)
    for idx = currIdx + 1, colorsLength do
        local color = colors[idx]
        if typeof(color) ~= "ColorSequenceKeypoint" then continue end
        
        return idx, color.Time :: number
    end

    return colorsLength, 1
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
    colorseq: TupleAnnotationFunction<ColorSequence>,
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

    colorseq = function(data)
        -- If the data only contains one color then we only
        -- need to return a color sequence with that color.
        if #data == 1 then
            local color = ColorSeqGetColorAndTime(data[1])
            return ColorSequence.new(color)
        end

        local timedColors: { ColorSequenceKeypoint }, untimedColors: { Color3 } = {}, {}

        -- Separates the colors based on if their time is explicitly stated.
        for idx, item in data do
            local color, colorTime = ColorSeqGetColorAndTime(item)

            if colorTime then
                table.insert(timedColors, ColorSequenceKeypoint.new(colorTime, color))

            else
                untimedColors[idx] = color
            end
        end

        table.sort(timedColors, function(a, b) return a.Time < b.Time end)

        local colors = timedColors :: { ColorSequenceKeypoint | Color3 }

        -- We need to insert the colors now to ensure color 
        -- times are calculated properly in the next step.
        for idx, color in untimedColors do
            table.insert(colors, idx, color)
        end

        local colorsLength = #colors
        for idx, color in untimedColors do
            local startIdx, startValue = ColorSeqGetStartValue(idx, colors)
            local endIdx, endValue = ColorSeqGetEndValue(idx, colors, colorsLength)

            local colorTime = math.lerp(startValue, endValue, (idx - startIdx) / (endIdx - startIdx))

            colors[idx] = ColorSequenceKeypoint.new(colorTime, color)
        end

        local colors = timedColors :: { ColorSequenceKeypoint }

        -- Ensures that the first keypoint's time is 0.
        local firstColorKeypoint = colors[1]
        if firstColorKeypoint.Time ~= 0 then
            table.insert(colors, ColorSequenceKeypoint.new(0, firstColorKeypoint.Value))
        end
        
        -- Ensures that the last keypoint's time is 1.
        local lastColorKeypoint = colors[colorsLength]
        if lastColorKeypoint.Time ~= 1 then
            table.insert(colors, ColorSequenceKeypoint.new(1, lastColorKeypoint.Value))
        end

        return ColorSequence.new(colors :: { ColorSequenceKeypoint })
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

local function CoerceTupleToDatatype(tuple: Tuple): (Datatype | TupleData)?
    local tupleName, tupleData = tuple.Name, tuple.Data

    if tupleName then
        local annotationFunction = TupleAnnotations[string.lower(tupleName)]
        if annotationFunction then return annotationFunction(tupleData) end
    end

    local tupleDataLength = #tupleData

    return
        -- If the tuple has no items then there is no datatype.
        if tupleDataLength == 0 then nil
        -- If the tuple only has one item then it can be simplified to just that item.
        elseif tupleDataLength == 1 then tupleData[1] 
        else tupleData
end

local function ParseTupleClose(
    parser: Parser, currTreeNode: TreeNode, token: Token, 
    currTuple: Tuple, rootTuple: Tuple
): boolean
    if token.Kind ~= "ParensClose" then return false end

    local parentTuple = currTuple.Parent

    local token = parser:Advance()

    if parentTuple then
        local datatype = CoerceTupleToDatatype(currTuple)
        if datatype then table.insert(parentTuple.Data, datatype) end

        if not token then return true end

        local parsed = ParseTupleDelimiter(parser, currTreeNode, token, parentTuple, rootTuple)
        if parsed then return true end

        local parsed = ParseTupleClose(parser, currTreeNode, token, parentTuple, rootTuple)
        if parsed then return true end

        local parsed = ParseTupleName(parser, currTreeNode, token, currTuple, rootTuple)
        if parsed then return true end

        -- TODO: is this neccasary?
        local parsed = ParseTupleDatatype(parser, currTreeNode, token, parentTuple, rootTuple)
        if parsed then return true end
    end

    return true
end

function ParseTupleDelimiter(
    parser: Parser, currTreeNode: TreeNode, token: Token, 
    currTuple: Tuple, rootTuple: Tuple
): boolean
    local tokenKind = token.Kind
    if tokenKind ~= "SemiColon" and tokenKind ~= "Comma" then return false end

    local token = parser:Advance()
    if not token then return true end

    -- Handles cases where there are multiple delimiter tokens next to each other.
    local parsed = ParseTupleDelimiter(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return true end

    local parsed = ParseTupleClose(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return true end

    local parsed = ParseTupleName(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return true end

    ParseTupleDatatype(parser, currTreeNode, token, currTuple, rootTuple)

    return true
end

function ParseTupleDatatype(
    parser: Parser, currTreeNode: TreeNode, token: Token, 
    currTuple: Tuple, rootTuple: Tuple
): boolean
    local datatype = ParseDatatypeGroup(parser, currTreeNode, token, nil, ParseDatatype)
    if not datatype then return false end
    
    table.insert(currTuple.Data, datatype)

    -- We don't need to advance the token as parsing the datatype group already did this.
    local token = parser.Tokens[parser.Position]
    if not token then return true end
	
	local parsed = ParseTupleDelimiter(parser, currTreeNode, token, currTuple, rootTuple)
	if parsed then return true end

    local parsed = ParseTupleClose(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return true end

    local parsed = ParseTupleName(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return true end

    return true
end

local function ParseTupleOpen(
    parser: Parser, currTreeNode: TreeNode, token: Token, tupleName: string?, 
    rootTuple: Tuple?, parentTuple: Tuple?
): Tuple?
    if token.Kind ~= "ParensOpen" then return end
    
    local currTuple = NewTuple(tupleName, parentTuple) :: Tuple & boolean

    local token = parser:Advance()
    if not token then return currTuple end

    local rootTuple = rootTuple or currTuple

    local parsed = ParseTupleDelimiter(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return currTuple end

    local parsed = ParseTupleClose(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return currTuple end

    local parsed = ParseTupleName(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return currTuple end

    local parsed = ParseTupleDatatype(parser, currTreeNode, token, currTuple, rootTuple)
    if parsed then return currTuple end

    return currTuple
end

function ParseTupleName(
    parser: Parser, currTreeNode: TreeNode, token: Token,
    parentTuple: Tuple?, rootTuple: Tuple?
): Tuple?
    if token.Kind ~= "Text" then
        return ParseTupleOpen(parser, currTreeNode, token, nil, parentTuple, rootTuple)
    end

    local tupleName = token.Value

    local token = (parser :: Parser):Advance()
    if not token then return end

    return ParseTupleOpen(parser, currTreeNode, token, tupleName, parentTuple, rootTuple)
end

local function ParseOperatorDatatype(parser: Parser, currTreeNode: TreeNode, token: Token): OperatorSymbol?
    local operator = OperatorSymbols[token.Kind]
    if operator then parser:Advance() end
    return operator
end

function ParseDatatype(
    parser: Parser, currTreeNode: TreeNode, token: Token, key: string?
): (TupleData | Datatype)?
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

local function ParseDatatypeWithTuple(
    parser: Parser, currTreeNode: TreeNode, token: Token, key: string?
): (TupleData | Datatype)?
    local parsed = ParseTupleName(parser, currTreeNode, token)
    if parsed ~= nil then return CoerceTupleToDatatype(parsed) end

    return ParseDatatype(parser, currTreeNode, token, key)
end

local function DatatypeIsOperator(datatype: Datatype | TupleData)
    return type(datatype) == "table" and (datatype :: any).Kind == "Operator"
end

local function AtomizeOperators(left: OperatorSymbol, right: OperatorSymbol)
    local leftOp, rightOp = left.OperatorKind, right.OperatorKind

    return
        if leftOp == "Sub" and rightOp == "Add" then OperatorSubSymbol
        elseif leftOp == "Sub" and rightOp == "Sub" then OperatorAddSymbol
        else right
end

local function FindOperatorInDatatypes(datatypes: { Datatype | TupleData }, operatorKind: OperatorKind): { number }
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
        end,

        ["Vector2"] = function(left: number, right: Vector2, operationFn): Vector2
            return Vector2.new(
                operationFn(left, right.X), 
                operationFn(left, right.Y)
            )
        end,

        ["Rect"] = function(left: number, right: Rect, operationFn): Rect
            local rightMin, rightMax = right.Min, right.Max

            return Rect.new(
                operationFn(left, rightMin.X), operationFn(left, rightMin.Y),
                operationFn(left, rightMax.X), operationFn(left, rightMax.Y)
            )
        end,

        ["Color3"] = function(left: number, right: Color3, operationFn): Color3
            return Color3.new(
                operationFn(left, right.R),
                operationFn(left, right.G),
                operationFn(left, right.B)
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
    },

    ["Vector2"] = {
        ["number"] = function(left: Vector2, right: number, operationFn): Vector2
            return Vector2.new(
                operationFn(left.X, right), 
                operationFn(left.Y, right)
            )
        end,

        ["Vector2"] = function(left: Vector2, right: Vector2, operationFn): Vector2
            return Vector2.new(
                operationFn(left.X, right.X), 
                operationFn(left.Y, right.Y)
            )
        end,
    },

    ["Rect"] = {
        ["number"] = function(left: Rect, right: number, operationFn): Rect
            local leftMin, leftMax = left.Min, left.Max

            return Rect.new(
                operationFn(leftMin.X, right), operationFn(leftMin.Y, right),
                operationFn(leftMax.X, right), operationFn(leftMax.Y, right)
            )
        end,

        ["Rect"] = function(left: Rect, right: Rect, operationFn): Rect
            local leftMin, leftMax = right.Min, right.Max
            local rightMin, rightMax = right.Min, right.Max

            return Rect.new(
                operationFn(leftMin.X, rightMin.X), operationFn(leftMin.Y, rightMin.Y),
                operationFn(leftMax.X, rightMax.X), operationFn(leftMax.Y, rightMax.Y)
            )
        end
    },

    ["Color3"] = {
        ["number"] = function(left: Color3, right: number, operationFn): Color3
            return Color3.new(
                operationFn(left.R, right),
                operationFn(left.G, right),
                operationFn(left.B, right)
            )
        end,

        ["Color3"] = function(left: Color3, right: Color3, operationFn): Color3
            return Color3.new(
                operationFn(left.R, right.R),
                operationFn(left.G, right.G),
                operationFn(left.B, right.B)
            )
        end
    },
}

local function SolveDatatypeGroup(datatypes: { Datatype | TupleData }): Datatype | TupleData
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
    parser: Parser, currTreeNode: TreeNode, datatypes: { Datatype | TupleData }?
): (Datatype | TupleData)?
    if not datatypes then return end
    if #datatypes == 1 then return datatypes[1] end

    parser:Advance()

    return SolveDatatypeGroup(datatypes)
end

local function DatatypesMightCreateThenInsert(datatypes: { Datatype | TupleData }?, datatype: Datatype | TupleData)
    if not datatypes then
        datatypes = { datatype } :: { Datatype | TupleData }
    else
        table.insert(datatypes, datatype)
    end

    return datatypes
end

type ParseDatatype = (
    parser: Parser, currTreeNode: TreeNode, token: Token, key: string?
) -> (TupleData | Datatype)?

function ParseDatatypeGroup(
    parser: Parser, currTreeNode: TreeNode, token: Token, key: string?,
    parseDatatype: ParseDatatype,
    datatypes: { Datatype | TupleData }?, pendingOperator: OperatorSymbol?
): (Datatype | TupleData)?
    local datatype = parseDatatype(parser, currTreeNode, token, key)
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

            table.insert(datatypes :: { Datatype | TupleData }, datatype)

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

        return ParseDatatypeGroup(parser, currTreeNode, token, key, parseDatatype, datatypes, pendingOperator)
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

    local datatype = ParseDatatypeGroup(parser, currTreeNode, token, attributeName, ParseDatatypeWithTuple)
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

    local datatype = ParseDatatypeGroup(parser, currTreeNode, token, propertyName, ParseDatatypeWithTuple)
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