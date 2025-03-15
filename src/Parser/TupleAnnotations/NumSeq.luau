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

local function NumSeqGetNumberTimeAndEnvelope(item: any): (number, number?, number)
    local number, numberTime, envelope

    local typeofItem = type(item)

    if typeofItem == "table" then
        numberTime = DefaultIfNotType((item :: any)[1], "number", nil)
        number = DefaultIfNotTypeOf((item :: any)[2], "number", 0)
        envelope = DefaultIfNotType((item :: any)[3], "number", 0)

    elseif typeofItem == "number" then
        number = item

    else
        number = 0
    end

    return number, if numberTime then math.clamp(numberTime, 0, 1) else nil, envelope or 0
end

local function NumSeqGetStartValue(
    currIdx: number, numbers: { NumberSequenceKeypoint | { number } }
): (number, number)
    for idx = currIdx - 1, 1, -1 do
        local number = numbers[idx]
        if typeof(number) ~= "NumberSequenceKeypoint" then continue end

        return idx, number.Time :: number
    end

    return 1, 0
end

local function NumSeqGetEndValue(
    currIdx: number, numbers: { NumberSequenceKeypoint | { number } }, numbersLength: number
): (number, number)
    for idx = currIdx + 1, numbersLength do
        local number = numbers[idx]
        if typeof(number) ~= "NumberSequenceKeypoint" then continue end
        
        return idx, number.Time :: number
    end

    return numbersLength, 1
end

local function NumSeq(data)
    -- If the data only contains one number then we only
    -- need to return a number sequence with that number.
    if #data == 1 then
        local number = NumSeqGetNumberTimeAndEnvelope(data[1])
        return NumberSequence.new(number)
    end

    local timedNumbers: { NumberSequenceKeypoint }, untimedNumbers: {{ number }} = {}, {}

    -- Separates the numbers based on if their time is explicitly stated.
    for idx, item in data do
        local number, numberTime, envelope = NumSeqGetNumberTimeAndEnvelope(item)

        if numberTime then
            table.insert(timedNumbers, NumberSequenceKeypoint.new(numberTime, number, envelope))

        else
            untimedNumbers[idx] = { number, envelope }
        end
    end

    table.sort(timedNumbers, function(a, b) return a.Time < b.Time end)

    local numbers = timedNumbers :: { NumberSequenceKeypoint | { number } }

    -- We need to insert the numbers now to ensure number 
    -- times are calculated properly in the next step.
    for idx, number in untimedNumbers do
        table.insert(numbers, idx, number)
    end

    local numbersLength = #numbers
    for idx, number in untimedNumbers do
        local startIdx, startValue = NumSeqGetStartValue(idx, numbers)
        local endIdx, endValue = NumSeqGetEndValue(idx, numbers, numbersLength)

        local numberTime = math.lerp(startValue, endValue, (idx - startIdx) / (endIdx - startIdx))

        numbers[idx] = NumberSequenceKeypoint.new(numberTime, number[1], number[2])
    end

    local numbers = timedNumbers :: { NumberSequenceKeypoint }

    -- Ensures that the first keypoint's time is 0.
    local firstNumberKeypoint = numbers[1]
    if firstNumberKeypoint.Time ~= 0 then
        table.insert(numbers, NumberSequenceKeypoint.new(0, firstNumberKeypoint.Value))
        numbersLength += 1
    end
    
    -- Ensures that the last keypoint's time is 1.
    local lastNumberKeypoint = numbers[numbersLength]
    if lastNumberKeypoint.Time ~= 1 then
        table.insert(numbers, NumberSequenceKeypoint.new(1, lastNumberKeypoint.Value))
    end

    return NumberSequence.new(numbers :: { NumberSequenceKeypoint })
end

return NumSeq