--!strict
--!optimize 2
--!native
--!nolint LocalShadow

export type TokenDefinition = {
    Kind: TokenKind,
    Pattern: string
}

export type Token = {
    Kind: TokenKind,
    Value: string
}

export type TokenKind = 
    "CommentMultiStart" | 
    "StringMultiStart" | "StringMultiEnd" |
    "CommentSingle" | 
    "ScopeOpen" | "ScopeClose" | 
    "ParensOpen" | "ParensClose" | 
    "Comma" | "SemiColon" |
    "Equals" |
    "AttributeIdentifier" | "NameIdentifier" | "PsuedoIdentifier" | "StateOrEnumIdentifier" |
    "ScopeToDescendants" | "ScopeToChildren" |
    "PriorityDeclaration" | "DeriveDeclaration" | "NameDeclaration" | "DefaultsDeclaration" |
    "OpAdd" | "OpSub" | "OpMult" | "OpDiv" | "OpPow" | "OpMod" |
    "BoolTrue" | "BoolFalse" |
    "EnumKeyword" |
    "ColorTailwind" | "ColorBrick" | "ColorCss" | "ColorHex" | 
    "Number" | "Offset" | "ScaleOrOpMod" |
    "TagOrEnumIdentifier" |
    "StringSingle" |
    "RobloxAsset" |
    "Text" | "Error"

export type Lexer = () -> Token?

local TokenDefinitions: { TokenDefinition } = {
    {
        Kind = "CommentMultiStart",
        Pattern = "%-%-%[=*%["
    },

    {
        Kind = "StringMultiStart",
        Pattern = "%[=*%["
    },
    {
        Kind = "StringMultiEnd",
        Pattern = "%]=*%]"
    },

    {
        Kind = "CommentSingle",
        Pattern = "%-%- *[^%[\n\f\r]*"
    },
    
    {
        Kind = "ScopeOpen",
        Pattern = "{"
    },
    {
        Kind = "ScopeClose",
        Pattern = "}"
    },

    {
        Kind = "ParensOpen",
        Pattern = "%("
    },
    {
        Kind = "ParensClose",
        Pattern = "%)"
    },

    {
        Kind = "Comma",
        Pattern = ","
    },
    {
        Kind = "SemiColon",
        Pattern = ";"
    },

    {
        Kind = "Equals",
        Pattern = "="
    },

    {
        Kind = "AttributeIdentifier",
        Pattern = "%$"
    },
    {
        Kind = "NameIdentifier",
        Pattern = "#"
    },
    {
        Kind = "PsuedoIdentifier",
        Pattern = "::"
    },
    {
        Kind = "StateOrEnumIdentifier",
        Pattern = ":"
    },

    {
        Kind = "ScopeToDescendants",
        Pattern = ">>"
    },
    {
        Kind = "ScopeToChildren",
        Pattern = ">"
    },

    {
        Kind = "PriorityDeclaration",
        Pattern = "@priority"
    },
    {
        Kind = "DeriveDeclaration",
        Pattern = "@derive"
    },
    {
        Kind = "NameDeclaration",
        Pattern = "@name"
    },
    {
        Kind = "DefaultsDeclaration",
        Pattern = "@defaults"
    },

    {
        Kind = "OpAdd",
        Pattern = "%+"
    },
    {
        Kind = "OpSub",
        Pattern = "%-"
    },
    {
        Kind = "OpMult",
        Pattern = "%*"
    },
    {
        Kind = "OpDiv",
        Pattern = "/"
    },
    {
        Kind = "OpPow",
        Pattern = "%^"
    },
    {
        Kind = "OpMod",
        Pattern = "[\n\f\t\r ]+(%%)"
    },

    {
        Kind = "BoolTrue",
        Pattern = "true"
    },
    {
        Kind = "BoolFalse",
        Pattern = "false"
    },

    {
        Kind = "EnumKeyword",
        Pattern = "Enum"
    },

    {
        Kind = "ColorTailwind",
        Pattern = "tw:[a-z]+:%d+"
    },
    {
        Kind = "ColorTailwind",
        Pattern = "tw:[a-z]+"
    },
    {
        Kind = "ColorBrick",
        Pattern = "bc:[a-z]+"
    },
    {
        Kind = "ColorCss",
        Pattern = "css:[a-z]+"
    },
    {
        Kind = "ColorHex",
        Pattern = "#[0-9a-fA-F]+"
    },

    {
        Kind = "Number",
        Pattern = "%d*%.?%d+"
    },
    {
        Kind = "Offset",
        Pattern = "px"
    },
    {
        Kind = "ScaleOrOpMod",
        Pattern = "%%"
    },

    {
        Kind = "TagOrEnumIdentifier",
        Pattern = "%."
    },

    -- Change the string tokens so that its not parsing in the lexer.
    -- ewwwwww. This should also fix issue with multi-line strings.
    -- yaayyyy.
    {
        Kind = "StringSingle",
        Pattern = '"([^"\n\t]+)"'
    },
    {
        Kind = "StringSingle",
        Pattern = '"()"'
    },
    {
        Kind = "StringSingle",
        Pattern = "'([^'\n\t]+)'"
    },
    {
        Kind = "StringSingle",
        Pattern = "'()'"
    },

    {
        Kind = "RobloxAsset",
        Pattern = "rbxassetid://[0-9]+"
    },

    {
        Kind = "Text",
        Pattern = "[a-zA-Z0-9_]+-?[a-zA-Z0-9_]*"
    },
}

for _, token in TokenDefinitions do
    local tokenPattern = token.Pattern
    if string.match(tokenPattern, "^%^") then continue end
    token.Pattern = `^{tokenPattern}`
end

local function LexRsml(content: string)
    local cursorIdx = 0

    return function(): Token?
        for _, token in TokenDefinitions do
            local start, finish, capture = string.find(content, token.Pattern, cursorIdx)
            if start == nil then continue end

            local value
            if capture then
                if type(capture) == "number" then
                    value = ""
                else
                    local capStart, capFinish = string.find(string.sub(content, start, finish), capture, 1, true)
                    local start = start + capStart :: number - 1
                    local finish = start + (capFinish :: number - capStart :: number) 
                    value = string.sub(content, start, finish)
                end
            else
                value = string.sub(content, start, finish)
            end

            cursorIdx = (finish :: number) + 1

            return {
                Kind = token.Kind,
                Value = value
            }
        end

        local start, finish = string.find(content, "[ \n\f\t\r]+", cursorIdx)
        if not start then return nil end
        cursorIdx = (finish :: number) + 1

        return {
            Kind = "Error",
            Value = string.sub(content, start, finish)
        }
    end
end

return LexRsml