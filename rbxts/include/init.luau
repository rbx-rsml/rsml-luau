--!strict
--!optimize 2

local LexRsml = require(script.Lexer)
local ParseRsml = require(script.Parser)
local ConvertRsml = require(script.Converter)

local DefaultStyles = require(script.DefaultStyles)

local function Rsml(content: string, derives: { StyleSheet }?)
    -- If the content is a `TemplateStringsArray`.
    if type(content) == "table" then content = content[1] :: string end
    
    return ConvertRsml(ParseRsml(LexRsml(content)), derives, DefaultStyles)
end

return {
    rsml = Rsml,
    parseRsml = ParseRsml,
    lexRsml = LexRsml
}
