## Converters
"""
    julia_to_gap(input, recursive::Val{Recursive} = Val(false), recursion_dict = IdDict())

Converts a julia object `input` to an appropriate GAP object.
If `recursive` is set to `Val(true)`, recursive conversions on
arrays, tuples, and dictionaries is performed.

The input `recursive_data` should never be set by the user, it is meant to keep egality
of input data, by converting egal data to identical objects in GAP.
"""
julia_to_gap(x::GapObj) = x # Default for actual GAP objects is to do nothing
julia_to_gap(x::FFE) = x    # Default for actual GAP objects is to do nothing
julia_to_gap(x::Bool) = x   # Default for actual GAP objects is to do nothing

## Integers: general case first deal with things that fit into immediate
## integers, then falls back to converting to BigInt and calling into the GAP
## kernel API.
## TODO: we could provide more efficient conversion for UInt64, Int128, UInt128
## which avoids the conversion to BigInt, if we wanted to.
function julia_to_gap(x::Integer)
    # if it fits into a GAP immediate integer, convert x to Int64
    if x in -1<<60:(1<<60-1)
        return Int64(x)
    end
    # for the general case, fall back to BigInt
    return julia_to_gap(BigInt(x))
end

## Small integers types always fit into GAP immediate integers, and thus are
## represented by Int64 on the Julia side.
julia_to_gap(x::Int32)  = Int64(x)
julia_to_gap(x::Int16)  = Int64(x)
julia_to_gap(x::Int8)   = Int64(x)
julia_to_gap(x::UInt32) = Int64(x)
julia_to_gap(x::UInt16) = Int64(x)
julia_to_gap(x::UInt8)  = Int64(x)

## BigInts are converted via a ccall
function julia_to_gap(x::BigInt)
    o = ccall(:MakeObjInt, Ptr{Cvoid}, (Ptr{UInt64}, Cint), x.d, x.size)
    return RAW_GAP_TO_JULIA(o)
end

## Rationals
function julia_to_gap(x::Rational{T}) where T <: Integer
    denom_julia = denominator(x)
    numer_julia = numerator(x)
    if denom_julia == 0
        if numer_julia >= 0
            return Globals.infinity
        else
            return -Globals.infinity
        end
    end
    numer = julia_to_gap(numer_julia)
    denom = julia_to_gap(denom_julia)
    return Globals.QUO(numer, denom)
end

## Floats
julia_to_gap(x::Float64) = NEW_MACFLOAT(x)
julia_to_gap(x::Float32) = NEW_MACFLOAT(Float64(x))
julia_to_gap(x::Float16) = NEW_MACFLOAT(Float64(x))

## Chars
julia_to_gap(x::Char) = CharWithValue(Cuchar(x))

## Strings and symbols
julia_to_gap(x::AbstractString) = MakeString(x)
julia_to_gap(x::Symbol) = MakeString(string(x))

## Generic caller for optional arguments
julia_to_gap(obj::Any, recursive, recursion_dict ) = julia_to_gap(obj)

## Arrays (including BitArray{1})
function julia_to_gap(obj::Array{T,1}, recursive::Val{Recursive}=Val(false), recursion_dict = IdDict()) where Recursive where T
    len = length(obj)
    ret_val = NewPlist(len)
    if Recursive
        recursion_dict[obj] = ret_val
    end
    for i in 1:len
        x = obj[i]
        if x === nothing
            continue
        end
        if Recursive
            x = get!(recursion_dict, x) do
                julia_to_gap(x, recursive, recursion_dict)
            end
        end
        ret_val[i] = x
    end
    return ret_val
end

## Convert two dimensional arrays
function julia_to_gap(obj::Array{T,2}, recursive::Val{Recursive}=Val(false), recursion_dict = IdDict()) where Recursive where T
    (rows,cols) = size(obj)
    if haskey(recursion_dict, obj)
        return recursion_dict[obj]
    end
    ret_val = NewPlist(rows)
    if Recursive
        recursion_dict[obj] = ret_val
    end
    for i in 1:rows
        ret_val[i] = julia_to_gap(obj[i,:],recursive,recursion_dict)
    end
    return ret_val
end

## Tuples
function julia_to_gap(obj::Tuple, recursive::Val{Recursive}=Val(false), recursion_dict = IdDict()) where Recursive
    array = collect(Any, obj)
    return julia_to_gap(array, recursive, recursion_dict)
end

## Ranges
# FIXME: eventually check that the values are valid for GAP ranges
function julia_to_gap( range::UnitRange{T} ) where T <: Integer
    return EvalString( "[" * string( range.start ) *
                       ".." * string( range.stop ) * "]" )
end

function julia_to_gap( range::StepRange{T1,T2} ) where { T1 <: Integer,T2 <: Integer }
    return EvalString( "[" * string( range.start ) *
                       "," * string( range.start + range.step ) *
                       ".." * string( range.stop ) * "]" )
end

## Dictionaries
function julia_to_gap(obj::Dict{T,S}, recursive::Val{Recursive}=Val(false), recursion_dict = IdDict()) where Recursive where S where T <: Union{Symbol,AbstractString}

    # FIXME: add a dedicated method for creating an empty GAP record
    record = EvalString("rec()")
    if Recursive
        recursion_dict[obj] = record
    end
    for (x,y) in obj
        x = Globals.RNamObj(MakeString(string(x)))
        if Recursive
            y = get!(recursion_dict, y) do
                julia_to_gap(y, recursive, recursion_dict)
            end
        end
        Globals.ASS_REC(record, x, y)
    end

    return record
end

julia_to_gap(func::Function) = NewJuliaFunc(func)
