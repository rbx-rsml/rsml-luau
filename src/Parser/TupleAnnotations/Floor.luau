--!strict
--!optimize 2
--!native

local DATATYPE_NONE = require(script.Parent.Parent.DatatypeNone)

type FloorFunction<T> = (from: T) -> T

type FloorFunctions = {
    number: FloorFunction<number>,
    UDim: FloorFunction<UDim>,
    UDim2: FloorFunction<UDim2>,
    Rect: FloorFunction<Rect>,
    Vector2: FloorFunction<Vector2>,
    Vector2int16: FloorFunction<Vector2int16>,
    Vector3: FloorFunction<Vector3>,
    Vector3int16: FloorFunction<Vector3int16>,
    CFrame: FloorFunction<CFrame>,
    Color3: FloorFunction<Color3>,
}

local FloorFunctions: FloorFunctions = {
    number = math.floor,

    UDim = function(from)
        return UDim.new(
            math.floor(from.Scale),
            math.floor(from.Offset)
        )
    end,

    UDim2 = function(from)
        local fromX, fromY = from.X, from.Y

        return UDim2.new(
            math.floor(fromX.Scale),
            math.floor(fromX.Offset),
            math.floor(fromY.Scale),
            math.floor(fromY.Offset)
        )
    end,

    Rect = function(from)
        local fromMin, fromMax = from.Min, from.Max

        return Rect.new(
            math.floor(fromMin.X),
            math.floor(fromMin.Y),
            math.floor(fromMax.X),
            math.floor(fromMax.Y)
        )
    end,

    Vector2 = function(from)
        return Vector2.new(
            math.floor(from.X),
            math.floor(from.Y)
        )
    end,

    Vector2int16 = function(from)
        return Vector2int16.new(
            math.floor(from.X),
            math.floor(from.Y)
        )
    end,

    Vector3 = function(from)
        return Vector3.new(
            math.floor(from.X),
            math.floor(from.Y),
            math.floor(from.Z)
        )
    end,

    Vector3int16 = function(from)
        return Vector3int16.new(
            math.floor(from.X),
            math.floor(from.Y),
            math.floor(from.Z)
        )
    end,

    CFrame = function(from)
        local fromXVector, fromYVector, fromZVector = from.XVector, from.YVector, from.ZVector

        return CFrame.new(
            math.floor(from.X),
            math.floor(from.Y),
            math.floor(from.Z),

            math.floor(fromXVector.X),
            math.floor(fromXVector.Y),
            math.floor(fromXVector.Z),

            math.floor(fromYVector.X),
            math.floor(fromYVector.Y),
            math.floor(fromYVector.Z),

            math.floor(fromZVector.X),
            math.floor(fromZVector.Y),
            math.floor(fromZVector.Z)
        )
    end,

    Color3 = function(from)
        return Color3.new(
            math.floor(from.R),
            math.floor(from.G),
            math.floor(from.B)
        )
    end,
}

local function floor(datatypes: { any })
    local datatype = datatypes[1]
    if not datatype then return DATATYPE_NONE end

    local func: FloorFunction<any>? = FloorFunctions[typeof(datatype)]
    if not func then return datatype end

    return func(datatype)
end

return floor