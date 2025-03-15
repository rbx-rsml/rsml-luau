--!strict
--!optimize 2

local LexRsml = require(script.Lexer)
local ParseRsml = require(script.Parser)
local ConvertRsml = require(script.Converter)

local DefaultStyles = require(script.DefaultStyles)

return function(content: string, derives: { StyleSheet }?)
    return ConvertRsml(ParseRsml(LexRsml(content)), derives, DefaultStyles)
end