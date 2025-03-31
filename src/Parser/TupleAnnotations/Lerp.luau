--!strict
--!optimize 2
--!native

local DATATYPE_NONE = require(script.Parent.Parent.DatatypeNone)

type LerpFunction<T> = (from: T, to: T, time: number) -> T

type LerpFunctions = {
    number: LerpFunction<number>,
    UDim: LerpFunction<UDim>,
    UDim2: LerpFunction<UDim2>,
    Rect: LerpFunction<Rect>,
    Vector2: LerpFunction<Vector2>,
    Vector2int16: LerpFunction<Vector2int16>,
    Vector3: LerpFunction<Vector3>,
    Vector3int16: LerpFunction<Vector3int16>,
    CFrame: LerpFunction<CFrame>,
    Color3: LerpFunction<Color3>,
}

local LerpFunctions: LerpFunctions = {
    number = math.lerp,

    UDim = function(from, to, time)
        return UDim.new(
            math.lerp(from.Scale, to.Scale, time),
            math.lerp(from.Offset, to.Offset, time)
        )
    end,

    UDim2 = function(from, to, time)
        local fromX, fromY = from.X, from.Y
        local toX, toY = to.X, to.Y

        return UDim2.new(
            math.lerp(fromX.Scale, toX.Scale, time),
            math.lerp(fromX.Offset, toX.Offset, time),
            math.lerp(fromY.Scale, toY.Scale, time),
            math.lerp(fromY.Offset, toY.Offset, time)
        )
    end,

    Rect = function(from, to, time)
        local fromMin, fromMax = from.Min, from.Max
        local toMin, toMax = to.Min, to.Max

        return Rect.new(
            math.lerp(fromMin.X, toMin.X, time),
            math.lerp(fromMin.Y, toMin.Y, time),
            math.lerp(fromMax.X, toMax.X, time),
            math.lerp(fromMax.Y, toMax.Y, time)
        )
    end,

    Vector2 = function(from, to, time)
        return Vector2.new(
            math.lerp(from.X, to.X, time),
            math.lerp(from.Y, to.Y, time)
        )
    end,

    Vector2int16 = function(from, to, time)
        return Vector2int16.new(
            math.lerp(from.X, to.X, time),
            math.lerp(from.Y, to.Y, time)
        )
    end,

    Vector3 = function(from, to, time)
        return Vector3.new(
            math.lerp(from.X, to.X, time),
            math.lerp(from.Y, to.Y, time),
            math.lerp(from.Z, to.Z, time)
        )
    end,

    Vector3int16 = function(from, to, time)
        return Vector3int16.new(
            math.lerp(from.X, to.X, time),
            math.lerp(from.Y, to.Y, time),
            math.lerp(from.Z, to.Z, time)
        )
    end,

    CFrame = function(from, to, time)
        local fromXVector, fromYVector, fromZVector = from.XVector, from.YVector, from.ZVector
        local toXVector, toYVector, toZVector = to.XVector, to.YVector, to.ZVector

        return CFrame.new(
            math.lerp(from.X, to.X, time),
            math.lerp(from.Y, to.Y, time),
            math.lerp(from.Z, to.Z, time),

            math.lerp(fromXVector.X, toXVector.X, time),
            math.lerp(fromXVector.Y, toXVector.Y, time),
            math.lerp(fromXVector.Z, toXVector.Z, time),

            math.lerp(fromYVector.X, toYVector.X, time),
            math.lerp(fromYVector.Y, toYVector.Y, time),
            math.lerp(fromYVector.Z, toYVector.Z, time),

            math.lerp(fromZVector.X, toZVector.X, time),
            math.lerp(fromZVector.Y, toZVector.Y, time),
            math.lerp(fromZVector.Z, toZVector.Z, time)
        )
    end,

    Color3 = function(from, to, time)
        return Color3.new(
            math.lerp(from.R, to.R, time),
            math.lerp(from.G, to.G, time),
            math.lerp(from.B, to.B, time)
        )
    end,
}

local function DefaultIfNotType<T>(target: T, expectedType: string, default: T): T
    return if type(target) ~= expectedType then default else target
end

local function Lerp(datatypes: { any })
    local datatypeA = datatypes[1]
    if not datatypeA then return DATATYPE_NONE end

    local datatypeB = datatypes[2]
    if not datatypeB then return datatypeA end

    local time = DefaultIfNotType(datatypes[3], "number", .5)

    local typeofDatatypeA, typeofDatatypeB = typeof(datatypeA), typeof(datatypeB)

    if typeofDatatypeA ~= typeofDatatypeB then return datatypeA end

    local func: LerpFunction<any>? = LerpFunctions[typeofDatatypeA]
    if not func then return datatypeA end

    return func(datatypeA, datatypeB, time)
end

return Lerp