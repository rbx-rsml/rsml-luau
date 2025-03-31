--!strict
--!optimize 2
--!native

local DATATYPE_NONE = require(script.Parent.Parent.DatatypeNone)

type RoundFunction<T> = (from: T) -> T

type RoundFunctions = {
    number: RoundFunction<number>,
    UDim: RoundFunction<UDim>,
    UDim2: RoundFunction<UDim2>,
    Rect: RoundFunction<Rect>,
    Vector2: RoundFunction<Vector2>,
    Vector2int16: RoundFunction<Vector2int16>,
    Vector3: RoundFunction<Vector3>,
    Vector3int16: RoundFunction<Vector3int16>,
    CFrame: RoundFunction<CFrame>,
    Color3: RoundFunction<Color3>,
}

local RoundFunctions: RoundFunctions = {
    number = math.round,

    UDim = function(from)
        return UDim.new(
            math.round(from.Scale),
            math.round(from.Offset)
        )
    end,

    UDim2 = function(from)
        local fromX, fromY = from.X, from.Y

        return UDim2.new(
            math.round(fromX.Scale),
            math.round(fromX.Offset),
            math.round(fromY.Scale),
            math.round(fromY.Offset)
        )
    end,

    Rect = function(from)
        local fromMin, fromMax = from.Min, from.Max

        return Rect.new(
            math.round(fromMin.X),
            math.round(fromMin.Y),
            math.round(fromMax.X),
            math.round(fromMax.Y)
        )
    end,

    Vector2 = function(from)
        return Vector2.new(
            math.round(from.X),
            math.round(from.Y)
        )
    end,

    Vector2int16 = function(from)
        return Vector2int16.new(
            math.round(from.X),
            math.round(from.Y)
        )
    end,

    Vector3 = function(from)
        return Vector3.new(
            math.round(from.X),
            math.round(from.Y),
            math.round(from.Z)
        )
    end,

    Vector3int16 = function(from)
        return Vector3int16.new(
            math.round(from.X),
            math.round(from.Y),
            math.round(from.Z)
        )
    end,

    CFrame = function(from)
        local fromXVector, fromYVector, fromZVector = from.XVector, from.YVector, from.ZVector

        return CFrame.new(
            math.round(from.X),
            math.round(from.Y),
            math.round(from.Z),

            math.round(fromXVector.X),
            math.round(fromXVector.Y),
            math.round(fromXVector.Z),

            math.round(fromYVector.X),
            math.round(fromYVector.Y),
            math.round(fromYVector.Z),

            math.round(fromZVector.X),
            math.round(fromZVector.Y),
            math.round(fromZVector.Z)
        )
    end,

    Color3 = function(from)
        return Color3.new(
            math.round(from.R),
            math.round(from.G),
            math.round(from.B)
        )
    end,
}

local function round(datatypes: { any })
    local datatype = datatypes[1]
    if not datatype then return DATATYPE_NONE end

    local func: RoundFunction<any>? = RoundFunctions[typeof(datatype)]
    if not func then return datatype end

    return func(datatype)
end

return round