--!strict
--!optimize 2
--!native
--!nolint LocalShadow
--!nolint DuplicateLocal

local Lexer = require(script.Parent.Lexer)
type Token = Lexer.Token
type TokenKind = Lexer.TokenKind
type Lexer = Lexer.Lexer

local Colors = script.Parent.Colors
local ColorsCss = require(Colors.Css)
local ColorsTailwind = require(Colors.Tailwind)
local ColorsBrick = require(Colors.Brick)

local TupleAnnotations = script.TupleAnnotations
local ColorSeqTupleAnnotation = require(TupleAnnotations.ColorSeq)
local NumSeqTupleAnnotation = require(TupleAnnotations.NumSeq)

local Parser = {}
Parser.__index = Parser

local function ParseCommentMultiEnd(parser: Parser, startEqualsAmount: number): Token?
    -- We keep advancing tokens until we find a closing multiline string
    -- token with the same amount of equals signs as the start token.
    while true do
        local token = parser.Lexer()
        if not token then return end

        if token.Kind == "StringMultiEnd" then
            local endTokenValue = token.Value
            local endEqualsAmount = #string.sub(endTokenValue, 2, #endTokenValue - 1)

            if startEqualsAmount == endEqualsAmount then
                return parser:CoreAdvance()
            end
        end
    end
end

local function ParseCommentMulti(parser: Parser, token: Token): Token?
    if token.Kind ~= "CommentMultiStart" then return end

    local tokenValue = token.Value
    local startEqualsAmount = #string.sub(tokenValue, 4, #tokenValue - 1)

    return ParseCommentMultiEnd(parser, startEqualsAmount)
end

local function ParseCommentSingle(parser: Parser, token: Token): Token?
    if token.Kind ~= "CommentSingle" then return end

    return parser:CoreAdvance()
end

function Parser.CoreAdvance(self: Parser): Token?
    self.DidAvance = true

    while true do
        local token = self.Lexer()
        if not token then return end
        if (token.Kind :: TokenKind) ~= "Error" then return token end
    end
end

function Parser.Advance(self: Parser): Token?
    local token = self:CoreAdvance()
    if not token then return nil end

    local token = ParseCommentMulti(self, token) or token

    return ParseCommentSingle(self, token) or token
end

function Parser.new(lexer: Lexer, rootTreeNode: TreeNode)
    local parser = setmetatable({
        Lexer = lexer,

        TreeNodes = { rootTreeNode },
        CurrentTreeNode = rootTreeNode,

        DidAvance = false
    }, Parser)

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

local EMPTY = { Kind = "Empty" }

export type Datatype = string | boolean | EnumItem | Color3 | number | UDim | UDim2 | OperatorSymbol | Vector3 | Rect | Font | Vector2 | ColorSequenceKeypoint | { Kind: "Empty" } | TupleData

export type AttributesAndProperties = { [string]: Datatype }
export type Rules = { TreeNode }

export type TreeNode = {
    Attributes: AttributesAndProperties,
    Properties: AttributesAndProperties,
    Name: string?,
    Rules: { TreeNode },
    Derives: { [string]: true },
    Selector: string?,
    Priority: number?,
    Parent: TreeNode
}

export type Parser = typeof(setmetatable({} :: {
    Lexer: Lexer,

    TreeNodes: { TreeNode },

    DidAvance: boolean
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

local function ParseScopeClose(parser: Parser, token: Token, currTreeNode: TreeNode): (Token?, TreeNode)
    if token.Kind ~= "ScopeClose" then return token, currTreeNode end

    return parser:Advance(), currTreeNode.Parent
end

local function ParseScopeOpen(
    parser: Parser, token: Token, currTreeNode: TreeNode, selector: string?
): (Token?, TreeNode)
    if token.Kind ~= "ScopeOpen" then return token, currTreeNode end

    local prevTreeNode = currTreeNode
    local currTreeNode = NewTreeNode(prevTreeNode)
    currTreeNode.Selector = selector

    table.insert(prevTreeNode.Rules, currTreeNode)

    return parser:Advance(), currTreeNode
end

local function ParseScopeDelimiter(parser: Parser, token: Token, delimToken: Token?): (Token?, Token?)
    if token.Kind == "Comma" then
        local nextToken = parser:Advance()
        if not nextToken then return nil, delimToken end
        
        return ParseScopeDelimiter(parser, nextToken, token)

    else
        return token, delimToken
    end
end

local Selector = {}
Selector.__index = Selector

function Selector.new(token: Token)
    return setmetatable({
        Content = token.Value,
        CurrentToken = token
    }, Selector)
end

function Selector.Append(self: Selector, token: Token)
    local tokenKind: TokenKind, currentTokenKind: TokenKind = token.Kind, self.CurrentToken.Kind

    local shouldAddSpace = tokenKind ~= "Comma" and (
        currentTokenKind == "ScopeToDescendants" or currentTokenKind == "ScopeToChildren" or 
        currentTokenKind == "Text" or currentTokenKind == "Comma"
    )

    self.CurrentToken = token

    self.Content ..= if shouldAddSpace then ` {token.Value}` else token.Value
end


type Selector = typeof(setmetatable({} :: {
    Content: string,
    CurrentToken: Token
}, {} :: typeof(Selector)))

local function ParseScopeSelectorStart(
    parser: Parser, token: Token, currTreeNode: TreeNode
): (Token?, TreeNode)
    -- The `Token::Text(_)` case is handled in `ParseProperty`.
    local tokenKind: TokenKind = token.Kind
    if not (
        tokenKind == "NameIdentifier" or tokenKind == "PsuedoIdentifier" or 
        tokenKind == "StateOrEnumIdentifier" or tokenKind == "TagOrEnumIdentifier" or 
        tokenKind == "ScopeToDescendants" or tokenKind == "ScopeToChildren"
    ) then
        return token, currTreeNode
    end

    local selector = Selector.new(token)
    
    local token = parser:Advance()
    if not token then return nil, currTreeNode end
    
    return ParseScopeSelector(parser, token, currTreeNode, selector)
end

function ParseScopeSelector(
    parser: Parser, token: Token, currTreeNode: TreeNode, selector: Selector
): (Token?, TreeNode)
    while true do
        -- Advances the parser until no delimiter token is found.
        local _token, delimToken = ParseScopeDelimiter(parser, token)
        if not _token then return nil, currTreeNode end
        token = _token
    

        local tokenKind: TokenKind = token.Kind

        if (
            tokenKind == "NameIdentifier" or tokenKind == "PsuedoIdentifier" or 
            tokenKind == "StateOrEnumIdentifier" or tokenKind == "TagOrEnumIdentifier" or 
            tokenKind == "ScopeToDescendants" or tokenKind == "ScopeToChildren" or
            tokenKind == "Text"
        )  then
            -- Appending the comma token here ensures selectors can't end with delimiters.
            if delimToken ~= nil then
                selector:Append(delimToken)
            end

            selector:Append(token)

            local _token = parser:Advance()
            if not _token then return nil, currTreeNode end
            token = _token

        else
            break
        end
    end

    return ParseScopeOpen(parser, token, currTreeNode, selector.Content)
end

local function ParseEnumTokens(tokenHistory: { Token }): EnumItem | true
    local tokenHistoryLength = #tokenHistory
    local ok, enum
    local firstStopIdx = 0

    for idx = 1, tokenHistoryLength do
        local token = tokenHistory[idx]
        if token.Kind ~= "Text" then continue end

        ok, enum = pcall(function() return Enum[token.Value] end)
        if not ok then return true end

        firstStopIdx = idx
        break
    end

    for idx = firstStopIdx + 1, #tokenHistory do
        local token = tokenHistory[idx]
        if token.Kind ~= "Text" then continue end

        ok, enum = pcall(function() return enum[token.Value] end)
        if not ok then return true end
        break
    end

    return enum :: EnumItem
end

local function ParseFullEnum(
    parser: Parser, token: Token, tokenHistory: { Token }
): (Token?, (EnumItem | true)?)
    local tokenKind: TokenKind = token.Kind
    if tokenKind == "TagOrEnumIdentifier" or tokenKind == "StateOrEnumIdentifier" or tokenKind == "Text" then
        local token = parser:Advance()

        if token then
            table.insert(tokenHistory, token)

            local token, datatype = ParseFullEnum(parser, token, tokenHistory)
            if datatype ~= nil then return token, (datatype :: any) :: (EnumItem | true)? end
        end
    end

    if #tokenHistory == 0 then return token, nil end
    
    return token, ParseEnumTokens(tokenHistory)
end

local function ParseEnumKeyword(parser: Parser, token: Token): (Token?, (EnumItem | true)?)
    if token.Kind ~= "EnumKeyword" then return token, nil end

    local token = parser:Advance()
    if not token then return end

    local tokenHistory = {}
    return ParseFullEnum(parser, token, tokenHistory)
end

local function ParseEnumShorthand(parser: Parser, token: Token, key: string?): (Token?, (EnumItem | true)?)
    if not key then return token, nil end
    if token.Kind ~= "StateOrEnumIdentifier" then return token, nil end

    local token = parser:Advance()
    if not token then return end

    if token.Kind ~= "Text" then return token, nil end
    local enumItem = token.Value

    local ok, enum = pcall(function() return Enum[key] end)
    if not ok then return token, true end

    local ok, enum = pcall(function() return enum[enumItem] end)
    if not ok then return token, true end

    return parser:Advance(), enum
end

local function ParseEnumDatatype(parser: Parser, token: Token, key: string?): (Token?, (EnumItem | true)?)
    local _token, datatype = ParseEnumKeyword(parser, token)
    if datatype ~= nil then return _token, (datatype :: any) :: (EnumItem | true)? end

    local _token, datatype = ParseEnumShorthand(parser, token, key)
    if datatype ~= nil then return _token, (datatype :: any) :: (EnumItem | true)? end

    return token, nil
end

local function ParseNumberScale(parser: Parser, token: Token, num: number): (Token?, UDim?)
    if token.Kind ~= "ScaleOrOpMod" then return token, nil end

    return parser:Advance(), UDim.new(num / 100, 0)
end

local function ParseNumberOffset(parser: Parser, token: Token, num: number): (Token?, UDim?)
    if token.Kind ~= "Offset" then return token, nil end

    return parser:Advance(), UDim.new(0, num)
end

local function ParseNumberDatatype(parser: Parser, token: Token): (Token?, (number | UDim)?)
    if token.Kind ~= "Number" then return token, nil end
    local num = tonumber(token.Value) :: number

    local token = parser:Advance()
    if not token then return nil, nil end

    local _token, datatype = ParseNumberOffset(parser, token, num)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParseNumberScale(parser, token, num)
    if datatype ~= nil then return _token, datatype end

    return token, num
end

local function ParseStringMultiEnd(parser: Parser, startEqualsAmount: number, tokenHistory: { Token }): Token?
    -- We keep advancing tokens until we find a closing multiline string
    -- token with the same amount of equals signs as the start token.
    while true do
        local token = parser.Lexer()
        if not token then return end

        if token.Kind == "StringMultiEnd" then
            local endTokenValue = token.Value
            local endEqualsAmount = #string.sub(endTokenValue, 2, #endTokenValue - 1)

            if startEqualsAmount == endEqualsAmount then
                return parser:CoreAdvance()
            end
        end

        table.insert(tokenHistory, token)
    end
end

local function ParseStringMultiDatatype(parser: Parser, token: Token): (Token?, string?)
    if token.Kind ~= "StringMultiStart" then return token, nil end

    local tokenValue = token.Value
    local startEqualsAmount = #string.sub(tokenValue, 4, #tokenValue - 1)

    local tokenHistory = {}
    local token = ParseStringMultiEnd(parser, startEqualsAmount, tokenHistory)
    
    -- Joins the string tokens together ignoring the opening and closing tokens.
    local str = ""
    for _, token in tokenHistory do
        str ..= token.Value
    end

    -- Luau strips multiline strings up until the first occurance of a newline character.
    -- So we will mimic this behaviour.
    str = string.gsub(str, "^[ \t\f]*\n+", "")

    return token, str
end

local function ParseStringSingleDatatype(parser: Parser, token: Token): (Token?, string?)
    local tokenKind: TokenKind = token.Kind
    if tokenKind ~= "StringSingle" and tokenKind ~= "RobloxAsset" then return token, nil end

    return parser:Advance(), token.Value
end

local function ParseStringDatatype(parser: Parser, token: Token): (Token?, string?)
    local _token, datatype = ParseStringSingleDatatype(parser, token)
    if datatype ~= nil then return _token, datatype end

    local token, datatype = ParseStringMultiDatatype(parser, token)
    if datatype ~= nil then return token, datatype end

    return token, nil
end

local function ParsePredefinedColor(
    parser: Parser, token: Token, 
    kind: TokenKind, colorsTable: { [string]: Color3 }
): (Token?, Color3?)
    if token.Kind ~= kind then return end
    return parser:Advance(), colorsTable[token.Value]
end

local function ParsePredefinedColorDatatype(parser: Parser, token: Token): (Token?, Color3?)
    local _token, datatype = ParsePredefinedColor(parser, token, "ColorTailwind", ColorsTailwind)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParsePredefinedColor(parser, token, "ColorCss", ColorsCss)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParsePredefinedColor(parser, token, "ColorBrick", ColorsBrick)
    if datatype ~= nil then return _token, datatype end

    return token, nil
end

local function ParseBooleanDatatype(parser: Parser, token: Token): (Token?, boolean?)
    local tokenKind = token.Kind
    if tokenKind ~= "BoolTrue" and tokenKind ~= "BoolFalse" then return token, nil end

    return parser:Advance(), if token.Value == "true" then true else false
end

local function ParseAttributeNameDatatype(parser: Parser, token: Token): (Token?, string?)
    if token.Kind ~= "AttributeIdentifier" then return token end

    local token = parser:Advance()
    if not token then return end

    if token.Kind ~= "Text" then return token, nil end

    return parser:Advance(), token.Value
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
    numseq: TupleAnnotationFunction<NumberSequence>,
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

    -- TODO: add support for 2 vector 2's.
    rect = function(data)
        local minX = DefaultIfNotType(data[1], "number", 0) :: number
        local minY = DefaultIfNotType(data[2], "number", minX) :: number
        local maxX = DefaultIfNotType(data[3], "number", minX) :: number
        local maxY = DefaultIfNotType(data[4], "number", maxX) :: number

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

    colorseq = ColorSeqTupleAnnotation :: TupleAnnotationFunction<ColorSequence>,
    numseq = NumSeqTupleAnnotation :: TupleAnnotationFunction<NumberSequence>,

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
    local tupleName, tupleData = tuple.Name, tuple.Data

    if tupleName then
        local annotationFunction = TupleAnnotations[string.lower(tupleName)]
        if annotationFunction then return annotationFunction(tupleData) end
    end

    local tupleDataLength = #tupleData

    return
        if tupleDataLength == 0 then EMPTY
        -- If the tuple only has one item then it can be simplified to just that item.
        elseif tupleDataLength == 1 then tupleData[1] 
        else tupleData
end

local function ParseTupleClose(
    parser: Parser, token: Token, 
    currTuple: Tuple, rootTuple: Tuple
): Token?
    if token.Kind ~= "ParensClose" then return end

    local parentTuple = currTuple.Parent

    local token = parser:Advance()

    if parentTuple then
        local datatype = CoerceTupleToDatatype(currTuple)
        if datatype then table.insert(parentTuple.Data, datatype) end

        if not token then return end

        local _token = ParseTupleDelimiter(parser, token, parentTuple, rootTuple)
        if _token then return _token end

        local _token = ParseTupleClose(parser, token, parentTuple, rootTuple)
        if _token then return _token end

        local _token, _tuple = ParseTupleName(parser, token, parentTuple, rootTuple)
        if _tuple then return _token end
    end

    return token
end

function ParseTupleDelimiter(
    parser: Parser, token: Token, 
    currTuple: Tuple, rootTuple: Tuple
): Token?
    local tokenKind = token.Kind
    if tokenKind ~= "SemiColon" and tokenKind ~= "Comma" then return end

    local token = parser:Advance()
    if not token then return end

    -- Handles cases of multiple delimiter tokens next to each other.
    local _token = ParseTupleDelimiter(parser, token, currTuple, rootTuple)
    if _token then return _token end

    local _token = ParseTupleClose(parser, token, currTuple, rootTuple)
    if _token then return _token end

    local _token, _tuple = ParseTupleName(parser, token, currTuple, rootTuple)
    if _tuple then return _token end

    local _token = ParseTupleDatatype(parser, token, currTuple, rootTuple)
    if _token then return _token end

    return token
end

function ParseTupleDatatype(
    parser: Parser, token: Token, 
    currTuple: Tuple, rootTuple: Tuple
): Token?
    local token, datatype = ParseDatatypeGroup(parser, token, nil)
    if not datatype then return end
    
    table.insert(currTuple.Data, datatype)

    if not token then return end
	
	local _token = ParseTupleDelimiter(parser, token, currTuple, rootTuple)
	if _token then return _token end

    local _token = ParseTupleClose(parser, token, currTuple, rootTuple)
    if _token then return _token end

    local _token, _tuple = ParseTupleName(parser, token, currTuple, rootTuple)
    if _tuple then return _token end

    return token
end

local function ParseTupleOpen(
    parser: Parser, token: Token, tupleName: string?, 
    parentTuple: Tuple?, rootTuple: Tuple?
): (Token?, Tuple?)
    if token.Kind ~= "ParensOpen" then return end
    
    local currTuple = NewTuple(tupleName, parentTuple) :: Tuple & boolean

    local token = parser:Advance()
    if not token then return currTuple end

    local rootTuple = rootTuple or currTuple

    local _token = ParseTupleDelimiter(parser, token, currTuple, rootTuple)
    if _token then return _token, currTuple end

    local _token = ParseTupleClose(parser, token, currTuple, rootTuple)
    if _token then return _token, currTuple end

    local _token, _tuple = ParseTupleName(parser, token, currTuple, rootTuple)
    if _tuple then return _token, currTuple end

    local _token = ParseTupleDatatype(parser, token, currTuple, rootTuple)
    if _token then return _token, currTuple end

    return token, currTuple
end

function ParseTupleName(
    parser: Parser, token: Token,
    parentTuple: Tuple?, rootTuple: Tuple?
): (Token?, Tuple?)
    if token.Kind ~= "Text" then
        return ParseTupleOpen(parser, token, nil, parentTuple, rootTuple)
    end

    local tupleName = token.Value

    local token = parser:Advance()
    if not token then return end

    return ParseTupleOpen(parser, token, tupleName, parentTuple, rootTuple)
end

local function ParseOperatorDatatype(parser: Parser, token: Token): (Token?, OperatorSymbol?)
    local operator = OperatorSymbols[token.Kind]
    if not operator then return token, nil end

    return parser:Advance(), operator
end

function ParseDatatype(
    parser: Parser, token: Token, key: string?
): (Token?, Datatype?)
    local _token, datatype = ParseTupleName(parser, token)
    if datatype ~= nil then return _token, CoerceTupleToDatatype(datatype) end

    local _token, datatype = ParseStringDatatype(parser, token)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParseNumberDatatype(parser, token)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParseOperatorDatatype(parser, token)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParseEnumDatatype(parser, token, key)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParsePredefinedColorDatatype(parser, token)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParseBooleanDatatype(parser, token)
    if datatype ~= nil then return _token, datatype end

    local _token, datatype = ParseAttributeNameDatatype(parser, token)
    if datatype ~= nil then return _token, `${datatype}` end

    return token, nil
end

local function DatatypeIsOperator(datatype: Datatype)
    return type(datatype) == "table" and (datatype :: any).Kind == "Operator"
end

local function CanMergeOperators(left: OperatorSymbol, right: OperatorSymbol)
    local leftOp: OperatorKind, rightOp: OperatorKind = left.OperatorKind, right.OperatorKind

    local leftOpIsAddOrSub = leftOp == "OpAdd" or leftOp == "OpSub"
    local rightOpIsAddOrSub = rightOp == "OpAdd" or rightOp == "OpSub"

    if (leftOpIsAddOrSub and not rightOpIsAddOrSub) or (rightOpIsAddOrSub and not leftOpIsAddOrSub) then
        return false
    end

    return true
end

local function MergeOperators(left: OperatorSymbol, right: OperatorSymbol)
    local leftOp: OperatorKind, rightOp: OperatorKind = left.OperatorKind, right.OperatorKind

    return
        if leftOp == "OpSub" and rightOp == "OpAdd" then OperatorSubSymbol
        elseif leftOp == "OpSub" and rightOp == "OpSub" then OperatorAddSymbol
        else right
end

local function FindOperatorsInDatatypes(
    datatypes: { Datatype },
    operatorGroup: {OperatorGroupItem}
): {{ number | OperatorGroupItem }}
    local indexes: {{ number | OperatorGroupItem }} = {}

    for idx, datatype in datatypes do
        if not DatatypeIsOperator(datatype) then continue end

        for _, operator in operatorGroup do
            if operator.Symbol ~= datatype then continue end

            table.insert(indexes, { idx, operator } :: { number | OperatorGroupItem })
            break
        end
    end

    return indexes
end

type OperatorGroupItem = {
    Symbol: OperatorSymbol,
    Fn: OperationFn
}
type OperationFn = (left: number, right: number) -> number

local ADD_SUB_OPERATORS = {
    {
        Symbol = OperatorAddSymbol,
        Fn = function(left: number, right: number) return left + right end
    },
    {
        Symbol = OperatorSubSymbol,
        Fn = function(left: number, right: number) return left - right end
    },
}

local ORDERED_OPERATORS: {{ OperatorGroupItem }} = {
    {
        {
            Symbol = OperatorPowSymbol,
            Fn = function(left: number, right: number) return left ^ right end
        }
    },

    {
        {
            Symbol = OperatorDivSymbol,
            Fn = function(left: number, right: number) return left / right end
        },
        {
            Symbol = OperatorModSymbol,
            Fn = function(left: number, right: number) return left % right end
        },
        {
            Symbol = OperatorMultSymbol,
            Fn = function(left: number, right: number) return left * right end
        },
    },

    ADD_SUB_OPERATORS
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

local function SolveDatatypeGroup(datatypes: { Datatype }): Datatype
    -- Merges Add and Sub operators with the datatype to the right if
    -- the datatype to  the left isn't an operator.
    local occurrences = FindOperatorsInDatatypes(datatypes, ADD_SUB_OPERATORS)
    local occurrenceIdxOffset = 0
    for _, occurrence in occurrences do
        local occurrenceIdx = occurrence[1] :: number - occurrenceIdxOffset

        local rightIdx = occurrenceIdx + 1
        if rightIdx > #datatypes then continue end

        local canMerge: boolean
        if occurrenceIdx == 1 then
            canMerge = true

        else
            local left = datatypes[occurrenceIdx - 1] :: Datatype
            canMerge = if DatatypeIsOperator(left) then true else false
        end

        if canMerge then
            local right = table.remove(datatypes, rightIdx) :: Datatype
            occurrenceIdxOffset += 1

            local datatypeOperations = DatatypeOperations["number"]
            if not datatypeOperations then
                datatypes[occurrenceIdx] = right
                continue
            end

            local datatypeOperationFn = datatypeOperations[typeof(right)]
            if not datatypeOperationFn then
                datatypes[occurrenceIdx] = right
                continue
            end

            local operationFn = (occurrence[2] :: OperatorGroupItem).Fn
            datatypes[occurrenceIdx] = datatypeOperationFn(0, right, operationFn)
        end
    end

    for _, operatorGroup in ORDERED_OPERATORS do
        local occurrences = FindOperatorsInDatatypes(datatypes, operatorGroup)
        local occurrenceIdxOffset = 0

        for _, occurrence in occurrences do
            local occurrenceIdx = occurrence[1] :: number - occurrenceIdxOffset

            local rightIdx = occurrenceIdx + 1
            if rightIdx > #datatypes then continue end

            local right = table.remove(datatypes, rightIdx) :: Datatype
            occurrenceIdxOffset += 1

            local left: Datatype, leftIdx: number
            if occurrenceIdx == 1 then
                left = 0
                leftIdx = 1

            else
                leftIdx = occurrenceIdx - 1
                left = table.remove(datatypes, leftIdx) :: Datatype
                if left == EMPTY then left = 0 end
                occurrenceIdxOffset += 1
            end

            local datatypeOperations = DatatypeOperations[typeof(left)]
            if not datatypeOperations then
                datatypes[leftIdx] = left
                continue
            end

            local datatypeOperationFn = datatypeOperations[typeof(right)]
            if not datatypeOperationFn then
                datatypes[leftIdx] = left
                continue
            end

            local operationFn = (occurrence[2] :: OperatorGroupItem).Fn
            datatypes[leftIdx] = datatypeOperationFn(left, right, operationFn)
        end
    end

    return datatypes[1]
end

local function ResolveDatatypeGroup(
    datatypes: { Datatype }?
): Datatype?
    if not datatypes then return end
    if #datatypes == 1 then return datatypes[1] end


    return SolveDatatypeGroup(datatypes)
end

local function DatatypesEnsureExistsThenInsert(datatypes: { Datatype }?, toInsert: Datatype)
    if not datatypes then
        datatypes = { toInsert } :: { Datatype }
    else
        table.insert(datatypes, toInsert)
    end

    return datatypes
end

function ParseDatatypeGroup(
    parser: Parser, token: Token, key: string?,
    datatypes: { Datatype }?, pendingOperator: OperatorSymbol?
): (Token?, Datatype?)
    local token, datatype = ParseDatatype(parser, token, key)
    if not datatype then
        return token, ResolveDatatypeGroup(datatypes)
    end

    local datatypeIsOperator = DatatypeIsOperator(datatype)

    -- If the datatype is an operator then we need to postpone adding it
    -- to the datatypes group so we can atomise it with the next datatype
    -- if it is an operator.
    if not datatypeIsOperator then
        if pendingOperator then
            -- We can add our pending operator to the datatypes table
            -- since it has no other operator to combine with.
            datatypes = DatatypesEnsureExistsThenInsert(datatypes, pendingOperator)
            pendingOperator = nil -- Operator is no longer pending anymore.

            table.insert(datatypes :: { Datatype }, datatype)

        else
            datatypes = DatatypesEnsureExistsThenInsert(datatypes, datatype)
        end
    end

    if not token then
        return token, ResolveDatatypeGroup(datatypes)
    end
    local tokenKind: TokenKind = token.Kind

    if tokenKind == "ParensClose" or tokenKind == "ScopeClose" or tokenKind == "Comma" or tokenKind == "SemiColon" then
        return token, ResolveDatatypeGroup(datatypes)
    else
        if datatypeIsOperator then
            -- Since our datatype was an operator we need to mark it as pending,
            -- atomising with the existing pending operator if it exists.

            if pendingOperator then
                if CanMergeOperators(pendingOperator, datatype :: OperatorSymbol) then
                    pendingOperator = MergeOperators(pendingOperator, datatype :: OperatorSymbol)
                else
                    datatypes = DatatypesEnsureExistsThenInsert(datatypes, pendingOperator)
                    pendingOperator = datatype :: OperatorSymbol
                end

            else
                pendingOperator = datatype :: OperatorSymbol
            end
        end

        return ParseDatatypeGroup(parser, token, key, datatypes, pendingOperator)
    end
end

local function ParseDelimiters(parser: Parser, token: Token): Token?
    local tokenKind: TokenKind = token.Kind
    if tokenKind ~= "SemiColon" and tokenKind ~= "Comma" then return token end

    local token = parser:Advance()
    if not token then return nil end

    return ParseDelimiters(parser, token)
end

local function ParseAttribute(parser: Parser, token: Token, currTreeNode: TreeNode): Token?
    if token.Kind ~= "AttributeIdentifier" then return token end

    local token = parser:Advance()
    if not token then return end

    if token.Kind ~= "Text" then return token end
    local attributeName = token.Value

    local token = parser:Advance()
    if not token then return end

    if token.Kind ~= "Equals" then return token end

    local token = parser:Advance()
    if not token then return end

    local token, datatype = ParseDatatypeGroup(parser, token, attributeName)
    if datatype ~= nil then
        currTreeNode.Attributes[attributeName] = if type(datatype) == "table" then datatype[1] else datatype
    end

    if not token then return nil end
    return ParseDelimiters(parser, token)
end

local function ParseProperty(parser: Parser, token: Token, currTreeNode: TreeNode): Token?
    if token.Kind ~= "Text" then return token end
    local initialToken = token

    local token = parser:Advance()
    if not token then return nil, currTreeNode end

    if token.Kind ~= "Equals" then
        return ParseScopeSelector(parser, token, currTreeNode, Selector.new(initialToken))
    end

    local token = parser:Advance()
    if not token then return nil end

    local propertyName = initialToken.Value

    local token, datatype = ParseDatatypeGroup(parser, token, propertyName)
    if datatype ~= nil then
        currTreeNode.Properties[propertyName] = if type(datatype) == "table" then datatype[1] else datatype
    end

    if not token then return nil end
    return ParseDelimiters(parser, token)
end

local function ParsePriorityDeclaration(parser: Parser, token: Token, currTreeNode: TreeNode): Token?
    if token.Kind ~= "PriorityDeclaration" then return token end

    local token = parser:Advance()
    if not token then return end

    local token, priorityValue = ParseDatatypeGroup(parser, token)
    if type(priorityValue) == "number" then
        currTreeNode.Priority = priorityValue
    end

    if not token then return end
    return ParseDelimiters(parser, token)
end

local function ParseNameDeclaration(parser: Parser, token: Token, currTreeNode: TreeNode): Token?
    if token.Kind ~= "NameDeclaration" then return token end

    local token = parser:Advance()
    if not token then return end

    local token, datatype = ParseDatatypeGroup(parser, token)
    if type(datatype) == "string" then
        currTreeNode.Name = datatype
    end

    if not token then return end
    return ParseDelimiters(parser, token)
end

local function ParseDeriveDeclaration(parser: Parser, token: Token, currTreeNode: TreeNode): Token?
    if token.Kind ~= "DeriveDeclaration" then return token end

    local token = parser:Advance()
    if not token then return end

    local token, datatype = ParseDatatypeGroup(parser, token)
    local datatypeType = type(datatype)

    if datatypeType == "string" then
        currTreeNode.Derives[datatype :: string] = true

    elseif datatypeType == "table" then
        local derives = currTreeNode.Derives

        for _, datatype in datatype :: TupleData do
            if type(datatype) ~= "string" then continue end
            derives[datatype] = true
        end
    end

    return token
end

local function ParseRsml(lexer: Lexer)
    local rootTreeNode = NewTreeNode(nil :: any)
    rootTreeNode.Parent = rootTreeNode

    local parser = Parser.new(lexer, rootTreeNode)

    local token: Token? = parser:Advance()
    if not token then return parser.CurrentTreeNode end

    local currTreeNode = parser.CurrentTreeNode

    while true do
        parser.DidAvance = false

        token = ParseAttribute(parser, token, currTreeNode)
        if not token then break end

        token = ParseProperty(parser, token, currTreeNode)
        if not token then break end

        token, currTreeNode = ParseScopeSelectorStart(parser, token, currTreeNode)
        if not token then break end

        token, currTreeNode = ParseScopeOpen(parser, token, currTreeNode)
        if not token then break end

        token, currTreeNode = ParseScopeClose(parser, token, currTreeNode)
        if not token then break end

        token = ParsePriorityDeclaration(parser, token, currTreeNode)
        if not token then break end

        token = ParseNameDeclaration(parser, token, currTreeNode)
        if not token then break end

        token = ParseDeriveDeclaration(parser, token, currTreeNode)
        if not token then break end

        -- Ensures the parser is advanced at least one time per iteration.
        -- This prevents infinite loops.
        if not parser.DidAvance then
            token = parser:Advance()
            if not token then break end
        end
    end

    return rootTreeNode
end

return ParseRsml