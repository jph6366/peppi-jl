using Arrow

include("frame.jl")

# Helper to convert CamelCase to SCREAMING_SNAKE_CASE for enum lookup
function to_upper_snake_case(s::AbstractString)
    result = replace(s, r"([a-z])([A-Z])" => s"\1_\2")
    return uppercase(result)
end

# Unwrap Union{T, Nothing} to get T
function unwrap_union(::Type{Union{T, Nothing}}) where T
    return T
end

function unwrap_union(::Type{T}) where T
    return T
end

# Get field from Arrow.Struct by name using .data tuple
function arrow_getfield(arr::Arrow.Struct{T, D, S}, fieldname::Symbol) where {T, D, S}
    idx = findfirst(==(fieldname), S)
    if idx === nothing
        return nothing  # Return nothing for missing fields instead of error
    end
    return arr.data[idx]
end

# Get field from Arrow struct array, with default fallback
function arr_field(arr::Arrow.Struct, fieldname::Symbol, default=nothing)
    result = arrow_getfield(arr, fieldname)
    if result === nothing
        return default
    end
    return result
end

# Fallback for non-Arrow.Struct types
function arr_field(arr, fieldname::Symbol, default=nothing)
    try
        return getproperty(arr, fieldname)
    catch e
        if default === nothing
            rethrow(e)
        else
            return default
        end
    end
end

# Parse field from Arrow struct array based on type
function field_from_sa(::Type{T}, arr) where T
    if arr === nothing
        return nothing
    end
    
    unwrapped = unwrap_union(T)
    
    if unwrapped <: Tuple
        return tuple_from_sa(unwrapped, arr)
    elseif isstructtype(unwrapped) && !(unwrapped <: AbstractString) && !(unwrapped <: AbstractVector)
        return dc_from_sa(unwrapped, arr)
    else
        return arr
    end
end

# Parse dataclass-like struct from Arrow struct array
function dc_from_sa(::Type{T}, arr) where T
    field_names = fieldnames(T)
    field_types = fieldtypes(T)
    
    values = []
    for (fname, ftype) in zip(field_names, field_types)
        # Get default value if field has one
        default = nothing
        try
            default = getfield(T(), fname)
        catch
        end
        
        field_arr = arr_field(arr, fname, default)
        push!(values, field_from_sa(ftype, field_arr))
    end
    
    return T(values...)
end

# Parse tuple from Arrow struct array
function tuple_from_sa(::Type{T}, arr) where T <: Tuple
    type_params = T.parameters
    return Tuple(field_from_sa(type_params[i], arr_field(arr, Symbol(string(i - 1)))) for i in eachindex(type_params))
end

# Handle Vararg tuples
function tuple_from_sa(::Type{Tuple{Vararg{T}}}, arr) where T
    # For variable-length tuples, iterate over available fields
    results = T[]
    for i in 0:100  # reasonable upper bound
        try
            field_arr = arr_field(arr, Symbol(string(i)))
            push!(results, field_from_sa(T, field_arr))
        catch
            break
        end
    end
    return Tuple(results)
end

# Parse frames from Arrow struct array (column-oriented)
function frames_from_sa(arrow_frames)
    if arrow_frames === nothing
        return nothing
    end
    
    ports = PortData[]
    port_arrays = arrow_getfield(arrow_frames, :ports)
    
    for p in (:P1, :P2, :P3, :P4)
        port = arrow_getfield(port_arrays, p)
        if port === nothing
            continue
        end
        
        leader_data = arrow_getfield(port, :leader)
        if leader_data === nothing
            continue
        end
        leader = dc_from_sa(Data, leader_data)
        
        follower_data = arrow_getfield(port, :follower)
        follower = follower_data === nothing ? nothing : dc_from_sa(Data, follower_data)
        
        push!(ports, PortData(leader=leader, follower=follower))
    end
    
    return Frame(id=arrow_getfield(arrow_frames, :id), ports=Tuple(ports))
end
