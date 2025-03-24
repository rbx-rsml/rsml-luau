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
    "PriorityDeclaration" | "DeriveDeclaration" | "NameDeclaration" |
    "OpAdd" | "OpSub" | "OpMult" | "OpDiv" | "OpFloorDiv" | "OpPow" | "OpMod" |
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
        Kind = "OpFloorDiv",
        Pattern = "//"
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
        Pattern = "[Tt][Ww]:[A-Za-z]+:%d+"
    },
    {
        Kind = "ColorTailwind",
        Pattern = "[Tt][Ww]:[A-Za-z]+"
    },
    {
        Kind = "ColorBrick",
        Pattern = "[Bb][Cc]:[A-Za-z]+"
    },
    {
        Kind = "ColorCss",
        Pattern = "[Cc][Ss][Ss]:[A-Za-z]+"
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

    {
        Kind = "StringSingle",
        Pattern = '"[^"\n\t]+"'
    },
    {
        Kind = "StringSingle",
        Pattern = '""'
    },
    {
        Kind = "StringSingle",
        Pattern = "'[^'\n\t]+'"
    },
    {
        Kind = "StringSingle",
        Pattern = "''"
    },

    {
        Kind = "RobloxAsset",
        Pattern = "rbxassetid://%d+"
    },
    {
        Kind = "RobloxAsset",
        Pattern = "rbxasset://[^) ]+"
    },
    {
        Kind = "RobloxAsset",
        Pattern = "rbxthumb://[^) ]+"
    },
    {
        Kind = "RobloxAsset",
        Pattern = "rbxgameasset://[^) ]+"
    },
    {
        Kind = "RobloxAsset",
        Pattern = "rbxhttp://[^) ]+"
    },
    {
        Kind = "RobloxAsset",
        Pattern = "rbxtemp://[^) ]+"
    },
    {
        Kind = "RobloxAsset",
        Pattern = "https?://[^) ]+"
    },

    {
        Kind = "Text",
        Pattern = "[_a-zA-Z][_A-Za-z0-9]*"
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
            local start, finish = string.find(content, token.Pattern, cursorIdx)
            if not start then continue end

            cursorIdx = (finish :: number) + 1

            return {
                Kind = token.Kind,
                Value = string.sub(content, start, finish)
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