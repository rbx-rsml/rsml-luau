--!strict
--!optimize 2
--!native

local DATATYPE_NONE = require(script.Parent.Parent.DatatypeNone)

type CeilFunction<T> = (from: T) -> T

type CeilFunctions = {
    number: CeilFunction<number>,
    UDim: CeilFunction<UDim>,
    UDim2: CeilFunction<UDim2>,
    Rect: CeilFunction<Rect>,
    Vector2: CeilFunction<Vector2>,
    Vector2int16: CeilFunction<Vector2int16>,
    Vector3: CeilFunction<Vector3>,
    Vector3int16: CeilFunction<Vector3int16>,
    CFrame: CeilFunction<CFrame>,
    Color3: CeilFunction<Color3>,
}

local CeilFunctions: CeilFunctions = {
    number = math.ceil,

    UDim = function(from)
        return UDim.new(
            math.ceil(from.Scale),
            math.ceil(from.Offset)
        )
    end,

    UDim2 = function(from)
        local fromX, fromY = from.X, from.Y

        return UDim2.new(
            math.ceil(fromX.Scale),
            math.ceil(fromX.Offset),
            math.ceil(fromY.Scale),
            math.ceil(fromY.Offset)
        )
    end,

    Rect = function(from)
        local fromMin, fromMax = from.Min, from.Max

        return Rect.new(
            math.ceil(fromMin.X),
            math.ceil(fromMin.Y),
            math.ceil(fromMax.X),
            math.ceil(fromMax.Y)
        )
    end,

    Vector2 = function(from)
        return Vector2.new(
            math.ceil(from.X),
            math.ceil(from.Y)
        )
    end,

    Vector2int16 = function(from)
        return Vector2int16.new(
            math.ceil(from.X),
            math.ceil(from.Y)
        )
    end,

    Vector3 = function(from)
        return Vector3.new(
            math.ceil(from.X),
            math.ceil(from.Y),
            math.ceil(from.Z)
        )
    end,

    Vector3int16 = function(from)
        return Vector3int16.new(
            math.ceil(from.X),
            math.ceil(from.Y),
            math.ceil(from.Z)
        )
    end,

    CFrame = function(from)
        local fromXVector, fromYVector, fromZVector = from.XVector, from.YVector, from.ZVector

        return CFrame.new(
            math.ceil(from.X),
            math.ceil(from.Y),
            math.ceil(from.Z),

            math.ceil(fromXVector.X),
            math.ceil(fromXVector.Y),
            math.ceil(fromXVector.Z),

            math.ceil(fromYVector.X),
            math.ceil(fromYVector.Y),
            math.ceil(fromYVector.Z),

            math.ceil(fromZVector.X),
            math.ceil(fromZVector.Y),
            math.ceil(fromZVector.Z)
        )
    end,

    Color3 = function(from)
        return Color3.new(
            math.ceil(from.R),
            math.ceil(from.G),
            math.ceil(from.B)
        )
    end,
}

local function Ceil(datatypes: { any })
    local datatype = datatypes[1]
    if not datatype then return DATATYPE_NONE end

    local func: CeilFunction<any>? = CeilFunctions[typeof(datatype)]
    if not func then return datatype end

    return func(datatype)
end

return Ceil