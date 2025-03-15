--!strict
--!optimize 2
--!native
--!nolint LocalShadow
--!nolint DuplicateLocal

local function DefaultIfNotType<T>(target: T, expectedType: string, default: T): T
    return if type(target) ~= expectedType then default else target
end

local function DefaultIfNotTypeOf<T>(target: T, expectedType: string, default: T): T
    return if typeof(target) ~= expectedType then default else target
end

local function ColorSeqGetColorAndTime(item: any): (Color3, number?)
    local color, colorTime

    local typeofItem = typeof(item)

    if typeofItem == "table" then
        colorTime = DefaultIfNotType((item :: any)[1], "number", nil)
        color = DefaultIfNotTypeOf((item :: any)[2], "Color3", Color3.new())

    elseif typeofItem == "Color3" then
        color = item

    else
        color = Color3.new()
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

local function ColorSeq(data)
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
        colorsLength += 1
    end
    
    -- Ensures that the last keypoint's time is 1.
    local lastColorKeypoint = colors[colorsLength]
    if lastColorKeypoint.Time ~= 1 then
        table.insert(colors, ColorSequenceKeypoint.new(1, lastColorKeypoint.Value))
    end

    return ColorSequence.new(colors :: { ColorSequenceKeypoint })
end

return ColorSeq