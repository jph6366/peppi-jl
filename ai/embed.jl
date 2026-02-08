using Flux, OneHotArrays, Distributions, NNlib, LogExpFunctions

abstract type AbstractEmbedding{In, Out} end

function encode(embedding::AbstractEmbedding{In, Out}, state::In)::Out where {In, Out}
    return convert(Out, state)
end

function (embedding::AbstractEmbedding{In, Out})(x::Out)::AbstractArray where {In, Out}
    error("asdf")
end

map(embedding, f, args...) = f(embedding, args...)
flatten(emb::AbstractEmbedding, s) = flatten(s)
unflatten(emb::AbstractEmbedding, seq) = first(seq)
decode(emb::AbstractEmbedding{In, Out}, out) where {In, Out} = out
dummy(emb::AbstractEmbedding{In, Out}, shape=()) where {In, Out} = zeros(Out, shape...)
dummy_embedding(emb::AbstractEmbedding, shape=()) = zeros(Float32, shape..., embedding_size(emb))
embedding_size(emb::AbstractEmbedding) = error("Not implemented: embedding_size(::$(typeof(emb)))")
sample(emb::AbstractEmbedding, embedded; kwargs...) = error("Not implemented: sample(::$(typeof(emb)), ::$(typeof(embedded)))")
distance(emb::AbstractEmbedding, embedded, target) = error("Not implemented: distance(::$(typeof(emb)), ::$(typeof(embedded)), ::$(typeof(target)))")
distribution(emb::AbstractEmbedding, embedded) = error("Not implemented: distribution(::$(typeof(emb)), ::$(typeof(embedded)))")



struct BoolEmbedding{On, Off} <: AbstractEmbedding{Bool, Bool}
    on::On
    off::Off
end

# Constructor
BoolEmbedding(; on=1.0f0, off=0.0f0) = BoolEmbedding(on, off)

# Embedding size
embedding_size(::BoolEmbedding) = 1

# Forward pass: embed a boolean as a tensor
function (emb::BoolEmbedding)(t::Bool)
    # Return a 1-element array (like tf.expand_dims)
    return [ifelse(t, emb.on, emb.off)]
end

function (emb::BoolEmbedding)(t::AbstractArray{Bool})
    # Broadcast over arrays of booleans
    return [ifelse(x, emb.on, emb.off) for x in t]
end

# Distance: sigmoid cross-entropy between embedded and target
function distance(emb::BoolEmbedding, embedded::AbstractArray, target::Bool)
    logits = dropdims(embedded; dims=ndims(embedded))  # Squeeze last dim
    labels = Float32(target)
    return Flux.logitbinarycrossentropy(logits, labels)
end

# Sample from the Bernoulli distribution
function sample(emb::BoolEmbedding, embedded::AbstractArray; temperature=nothing)
    logits = dropdims(embedded; dims=ndims(embedded))
    if temperature !== nothing
        logits = logits ./ temperature
    end
    dist = Bernoulli(logistic.(logits))  # logistic = sigmoid
    return rand(dist)
end

# Return the Bernoulli distribution
function distribution(emb::BoolEmbedding, embedded::AbstractArray)
    logits = dropdims(embedded; dims=ndims(embedded))
    return Bernoulli(logistic.(logits))
end


# Dummy embedding (for compatibility)
dummy(emb::BoolEmbedding, shape=()) = fill(emb.off, shape..., 1)
dummy_embedding(emb::BoolEmbedding, shape=()) = fill(emb.off, shape..., 1)
embed_bool = BoolEmbedding()
embedded = embed_bool(true)  # [1.0f0]
dist = distribution(embed_bool, embedded)
sampled = sample(embed_bool, embedded)
d = distance(embed_bool, embedded, false)


struct BitwiseEmbedding{N} <: AbstractEmbedding{Int, NTuple{N, Bool}}
    num_bits::Int
end

# Constructor
BitwiseEmbedding(num_bits::Int) = BitwiseEmbedding{num_bits}(num_bits)

# Embedding size
embedding_size(emb::BitwiseEmbedding) = emb.num_bits

# Convert an integer to a tuple of bits (Bool)
function from_state(emb::BitwiseEmbedding{N}, state)::NTuple{N, Bool} where {N}
    bitstr = last(bitstring(state), N)
    return ntuple(i -> bitstr[i] == '1', N)
end
# Forward pass: embed a bit tuple as a tensor (Float32)
function (emb::BitwiseEmbedding)(x::NTuple{N, Bool})::Vector{Float32} where {N}
    return Float32[ifelse(b, 1.0f0, 0.0f0) for b in x]
end

# Overload for arrays of bit tuples
function (emb::BitwiseEmbedding)(x::AbstractArray{<:NTuple{N, Bool}})::Matrix{Float32} where {N}
    return Float32[ifelse(b, 1.0f0, 0.0f0) for b in x, bit in 1:N]
end

# Dummy embedding
dummy(emb::BitwiseEmbedding{N}, shape=()) where {N} = ntuple(_ -> false, N)
dummy_embedding(emb::BitwiseEmbedding{N}, shape=()) where {N} = zeros(Float32, shape..., emb.num_bits)
embed_byte = BitwiseEmbedding(8)
state = 0xAB  # Example byte
bits = from_state(embed_byte, state)  # (true, false, true, false, true, false, true, true)
embedded = embed_byte(bits)  # [1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0]


struct FloatEmbedding <: AbstractEmbedding{Float32, Vector{Float32}}
    scale::Union{Nothing, Float32}
    bias::Union{Nothing, Float32}
    lower::Union{Nothing, Float32}
    upper::Union{Nothing, Float32}
end

# Constructor
function FloatEmbedding(;
    scale::Union{Nothing, Float32} = nothing,
    bias::Union{Nothing, Float32} = nothing,
    lower::Union{Nothing, Float32} = -10.0f0,
    upper::Union{Nothing, Float32} = 10.0f0
)
    return FloatEmbedding(scale, bias, lower, upper)
end

# Embedding size
embedding_size(::FloatEmbedding) = 1

# Encode: Apply scaling, bias, and bounds
function encode(emb::FloatEmbedding, t::Union{Float32, AbstractArray{Float32}})
    t = Float32(t)  # Ensure Float32 type
    if emb.bias !== nothing
        t += emb.bias
    end
    if emb.scale !== nothing
        t *= emb.scale
    end
    if emb.lower !== nothing
        t = max.(t, emb.lower)
    end
    if emb.upper !== nothing
        t = min.(t, emb.upper)
    end
    return t
end

# Forward pass: embed a float as a tensor
function (emb::FloatEmbedding)(t::Float32)
    encoded = encode(emb, t)
    return [encoded]  # Convert to array and return as column vector
end

function (emb::FloatEmbedding)(t::AbstractArray{Float32})
    encoded = encode(emb, t)
    return reshape(encoded, :, size(encoded, ndims(encoded)))
end

# Extract: Reverse scaling and bias
function extract(emb::FloatEmbedding, t::Union{Float32, AbstractArray{Float32}})
    t = Float32.(t)
    if emb.scale !== nothing
        t /= emb.scale
    end
    if emb.bias !== nothing
        t -= emb.bias
    end
    return dropdims(t; dims=ndims(t))  # Squeeze like tf.squeeze
end

# Identity function for to_input
to_input(emb::FloatEmbedding, t) = t

# Distance: Squared error
function distance(emb::FloatEmbedding, predicted, target)
    target = encode(emb, target)
    predicted = dropdims(predicted; dims=ndims(predicted))
    return sum((predicted .- target) .^ 2)  # Squared error
end

# Sample: Not implemented (as in Python)
function sample(emb::FloatEmbedding, t; kwargs...)
    error("Not implemented: Can't sample floats yet.")
end

# Dummy embedding
dummy(emb::FloatEmbedding, shape=()) = zeros(Float32, shape...)
dummy_embedding(emb::FloatEmbedding, shape=()) = zeros(Float32, shape..., 1)
# Example usage
embed_float = FloatEmbedding()
encoded = embed_float(3.14f0)  # [7.14] if bias=4.0, etc.
extracted = extract(embed_float, encoded)
dist = distance(embed_float, encoded, 3.14f0)


@enum OneHotPolicy CLAMP ERROR EXTRA EMPTY

struct OneHotEmbedding{T <: Integer} <: AbstractEmbedding{Int, OneHotVector{T}}
    name::String
    size::Int
    input_size::Int
    one_hot_policy::OneHotPolicy
    dtype::Type{T}

    function OneHotEmbedding(name::String; size::Int, dtype::Type{T} = Int32, one_hot_policy::OneHotPolicy = ERROR) where {T <: Integer}
        adjusted_size = one_hot_policy == EXTRA ? size + 1 : size
        new{T}(name, adjusted_size, size, one_hot_policy, dtype)
    end
end

# Embedding size
embedding_size(emb::OneHotEmbedding) = emb.size

# Convert state to valid indices
function from_state(emb::OneHotEmbedding{T}, state) where {T}
    # Convert state to a vector if it's not already
    state = Int[state]  # Wrap in a vector if it's a single integer

    if emb.one_hot_policy == CLAMP
        state = clamp.(state, 0, emb.input_size - 1)
    elseif emb.one_hot_policy == ERROR
        if any(s -> s < 0, state)
            throw(ArgumentError("Got negative input in OneHotEmbedding"))
        end
        if any(s -> s >= emb.input_size, state)
            x = maximum(state)
            throw(ArgumentError("Got invalid input $x >= $(emb.input_size) in OneHotEmbedding"))
        end
    elseif emb.one_hot_policy == EXTRA
        invalid = (state .< 0) .| (state .>= emb.input_size)
        if any(invalid)
            state = copy(state)
            state[invalid] .= emb.input_size
        end
    end

    return convert(Vector{T}, state)
end

# Forward pass: embed indices as one-hot vectors
function (emb::OneHotEmbedding{T})(t::Union{Int, AbstractArray{Int}}) where {T}
    indices = from_state(emb, t)
    return onehotbatch(indices, 0:emb.size-1)
end

# Residual mode: return logits
function (emb::OneHotEmbedding{T})(t::Union{Int, AbstractArray{Int}}, residual::Bool) where {T}
    one_hot = emb(t)
    if residual
        logits = log(emb.size * 10) .* one_hot
        return logits
    else
        return one_hot
    end
end

# Convert logits to probabilities
to_input(emb::OneHotEmbedding, logits) = softmax(logits; dims=ndims(logits))

# Extract indices from one-hot vectors
extract(emb::OneHotEmbedding, embedded) = argmax(embedded; dims=ndims(embedded))

# Distance: negative log probability
function distance(emb::OneHotEmbedding, embedded, target)
    logprobs = logsoftmax(embedded; dims=ndims(embedded))
    target_onehot = emb(target)
    return -sum(logprobs .* target_onehot; dims=ndims(logprobs))
end

# Sample from categorical distribution
function sample(emb::OneHotEmbedding, embedded; temperature=nothing)
    logits = embedded
    if temperature !== nothing
        logits = logits ./ temperature
    end
    probs = Flux.softmax(logits; dims=ndims(logits))
    return [rand(Categorical(probs[i, :])) for i in 1:size(logits, 1)]
end

# Return categorical distribution
function distribution(emb::OneHotEmbedding, embedded)
    probs = Flux.softmax(embedded; dims=ndims(embedded))
    return Categorical(probs)
end

# Dummy embedding
dummy(emb::OneHotEmbedding, shape=()) = onehot(0:emb.size-1, 0)
dummy_embedding(emb::OneHotEmbedding, shape=()) = zeros(Float32, shape..., emb.size)
# Example usage
embed_onehot = OneHotEmbedding("example"; size=5, one_hot_policy=CLAMP)
state = [0, 2, 4, 5]  # 5 will be clamped to 4
one_hot = embed_onehot(state)
logits = embed_onehot(state, true)
sampled = sample(embed_onehot, logits)
dist = distance(embed_onehot, logits, [0, 2, 4, 4])


abstract type AbstractStructEmbedding{NT} <: AbstractEmbedding{NT, NT} end

struct StructEmbedding{NT, Embeddings <: NamedTuple} <: AbstractStructEmbedding{NT}
    embedding::Embeddings
    builder::Function
    getter::Function
    size::Int

    function StructEmbedding(embedding::Embeddings, builder::Function, getter::Function) where {Embeddings <: NamedTuple}
        size = sum(embedding_size(e) for e in values(embedding))
        new{Any, Embeddings}(embedding, builder, getter, size)
    end
end

# Constructor
function StructEmbedding(;
    embedding::NamedTuple,
    builder::Function,
    getter::Function
)
    return StructEmbedding(embedding, builder, getter)
end

# Map function over sub-embeddings
function map(emb::StructEmbedding, f, args...)
    result = Dict(
        k => map(e, f, (emb.getter(x, k) for x in args)...)
        for (k, e) in pairs(emb.embedding)
    )
    return emb.builder(result)
end

# Flatten the structure
function flatten(emb::StructEmbedding, s)
    return Iterators.flatten(
        flatten(e, emb.getter(s, k))
        for (k, e) in pairs(emb.embedding)
    )
end

# Unflatten the sequence
function unflatten(emb::StructEmbedding, seq)
    return emb.builder(
        Dict(
            k => unflatten(e, seq)
            for (k, e) in pairs(emb.embedding)
        )
    )
end

# Convert state to embedded structure
function from_state(emb::StructEmbedding, state)
    s = Dict(
        k => from_state(e, emb.getter(state, k))
        for (k, e) in pairs(emb.embedding)
    )
    return emb.builder(s)
end
# Example usage
# Define a simple named tuple type for demonstration
@kwdef struct ExampleStruct
    field1::Int
    field2::Bool
end

# Example usage
# Define a simple named tuple type for demonstration
@kwdef struct ExampleStruct
    field1::Int
    field2::Bool
end


# Forward pass: embed the structure as a tensor
function (emb::StructEmbedding{Any, <:NamedTuple})(s::ExampleStruct, kwargs...)
    embeddings = [
        e(emb.getter(s, k); kwargs...)
        for (k, e) in pairs(emb.embedding) if e.size > 0
    ]
    isempty(embeddings) && error("Embedding must not be empty")
    return cat(embeddings...; dims=ndims(embeddings[1]))
end


# Dummy structure
function dummy(emb::StructEmbedding, shape=())
    return map(e -> dummy(e, shape), emb.embedding)
end

# Dummy embedding
function dummy_embedding(emb::StructEmbedding, shape=())
    return map(e -> dummy_embedding(e, shape), emb.embedding)
end

# Decode the structure
function decode(emb::StructEmbedding, s)
    return map((e, x) -> decode(e, x), emb.embedding, s)
end


# Define sub-embeddings
int_embedding = OneHotEmbedding("int_embedding", size=10, dtype=Int32)
bool_embedding = BoolEmbedding()  # Example embedding for booleans

# Define getter and builder functions
getter(ex::ExampleStruct, field::Symbol) = getfield(ex, field)
builder(dict::Dict) = ExampleStruct(; dict...)

# Create StructEmbedding
struct_embedding = StructEmbedding(
    embedding=(field1=int_embedding, field2=bool_embedding),
    builder=builder,
    getter=getter
)

# Example state
state = ExampleStruct(field1=3, field2=true)

# Embed the structure
embedded = struct_embedding(state)

# Decode the structure
decoded = decode(struct_embedding, state)

struct SplatKwargs{F, FixedKwargs}
    func::F
    fixed_kwargs::FixedKwargs
end

# Constructor
function SplatKwargs(func::F; fixed_kwargs...) where {F <: Function}
    return SplatKwargs(func, (; fixed_kwargs...))
end

# Callable method
function (sk::SplatKwargs)(; kwargs...)
    merged_kwargs = merge(sk.fixed_kwargs, (; kwargs...))
    return sk.func(; merged_kwargs...)
end

function struct_embedding_from_nt(nt::NamedTuple)
    embedding = [(string(k), v) for (k, v) in pairs(nt)]
    builder = SplatKwargs(nt_type -> nt_type; fixed_kwargs=())
    getter = getproperty

    return StructEmbedding(
        embedding=(; embedding...),
        builder=builder,
        getter=getter
    )
end


function ordered_struct_embedding(embedding::NamedTuple, nt_type::Type)
    existing_fields = Set(String.(keys(embedding)))
    all_fields = fieldnames(nt_type)
    missing_fields = setdiff(String.(all_fields), existing_fields)

    # Create a NamedTuple with default values for missing fields
    missing_kwargs = NamedTuple{Tuple(Symbol.(missing_fields))}(ntuple(_ -> (), length(missing_fields)))

    # Merge the existing and missing fields
    full_embedding = merge(embedding, missing_kwargs)

    builder = SplatKwargs(nt_type; fixed_kwargs=missing_kwargs)
    getter = getproperty

    return StructEmbedding(
        embedding=full_embedding,
        builder=builder,
        getter=getter
    )
end

# Example NamedTuple
nt = (field1 = Embed(10, 5), field2 = BoolEmbedding())

# Create StructEmbedding from NamedTuple
struct_embedding = struct_embedding_from_nt(nt)

# Example struct type
@kwdef struct ExampleStruct
    field1::Int
    field2::Bool
    field3::String
end

# Example embedding for some fields
embedding = (field1 = Embed(10, 5), field2 = BoolEmbedding())

# Create ordered StructEmbedding
ordered_embedding = ordered_struct_embedding(embedding, ExampleStruct)

# Example state
state = ExampleStruct(field1=3, field2=true, field3="example")

# Embed the structure
embedded = ordered_embedding(state)


struct MLPWrapper{In, Out, EmbedType <: AbstractEmbedding{In, Out}} <: AbstractEmbedding{In, Out}
    output_sizes::Vector{Int}
    embed::EmbedType
    mlp::Chain

    function MLPWrapper(output_sizes::Vector{Int}, embed::EmbedType) where {In, Out, EmbedType <: AbstractEmbedding{In, Out}}
        mlp = Chain(
            [Dense(output_sizes[i], output_sizes[i+1], relu) for i in 1:(length(output_sizes)-1)]...,
            Dense(output_sizes[end], output_sizes[end], relu)  # activate_final=True
        )
        new{In, Out, EmbedType}(output_sizes, embed, mlp)
    end
end

# Convert state to embedded type
from_state(mlp_wrapper::MLPWrapper, state) = from_state(mlp_wrapper.embed, state)

# Forward pass: embed and pass through MLP
function (mlp_wrapper::MLPWrapper)(inputs)
    embedded = mlp_wrapper.embed(inputs)
    return mlp_wrapper.mlp(embedded)
end

# Dummy method
dummy(mlp_wrapper::MLPWrapper, shape=()) = dummy(mlp_wrapper.embed, shape)

# One-hot embeddings
embed_action = OneHotEmbedding("Action", size=Int(0x18F), dtype=Int32, one_hot_policy=CLAMP)
embed_char = OneHotEmbedding("Character", size=Int(0x21), dtype=UInt8)
legacy_embed_jumps_left = OneHotEmbedding("jumps_left"; size=6, dtype=UInt8, one_hot_policy=EMPTY)
embed_jumps_left = OneHotEmbedding("jumps_left"; size=7, dtype=UInt8)
embed_bool = BoolEmbedding()

# Float embeddings
function make_float_embedding(name::String, scale::Float32)
    return FloatEmbedding(scale=scale)
end

# Base player embedding
function _base_player_embedding(;
    xy_scale::Float32=0.05f0,
    shield_scale::Float32=0.01f0,
    speed_scale::Float32=0.5f0,
    with_speeds::Bool=false,
    legacy_jumps_left::Bool=false
)
    embed_xy = make_float_embedding("xy", xy_scale)

    embedding = [
        ("percent", make_float_embedding("percent", 0.01f0)),
        ("facing", BoolEmbedding(off=-1.0f0)),
        ("x", embed_xy),
        ("y", embed_xy),
        ("action", embed_action),
        ("character", embed_char),
        ("invulnerable", embed_bool),
        ("shield_strength", make_float_embedding("shield_size", shield_scale)),
        ("on_ground", embed_bool),
        ("jumps_left", legacy_jumps_left ? legacy_embed_jumps_left : embed_jumps_left),
    ]

    if with_speeds
        embed_speed = make_float_embedding("speed", speed_scale)
        append!(embedding, [
            ("speed_air_x_self", embed_speed),
            ("speed_ground_x_self", embed_speed),
            ("speed_y_self", embed_speed),
            ("speed_x_attack", embed_speed),
            ("speed_y_attack", embed_speed),
        ])
    end

    return (; embedding...)
end

# Example structs (replace with your actual types)
struct Nana
    exists::Bool
    # Add other Nana-specific fields here
end

struct Player
    percent::Float32
    facing::Bool
    x::Float32
    y::Float32
    action::Int
    character::UInt8
    invulnerable::Bool
    shield_strength::Float32
    on_ground::Bool
    jumps_left::UInt8
    # Add other fields as needed
    nana::Nana
    controller::Any  # Placeholder for controller embedding
end

function make_player_embedding(;
    xy_scale::Float32=0.05f0,
    shield_scale::Float32=0.01f0,
    speed_scale::Float32=0.5f0,
    with_speeds::Bool=false,
    with_controller::Bool=false,
    with_nana::Bool=true,
    legacy_jumps_left::Bool=false
)
    embedding = _base_player_embedding(
        xy_scale=xy_scale,
        shield_scale=shield_scale,
        speed_scale=speed_scale,
        with_speeds=with_speeds,
        legacy_jumps_left=legacy_jumps_left
    )

    if with_nana
        nana_embedding = merge(embedding, (exists=embed_bool,))
        embed_nana = ordered_struct_embedding(nana_embedding, Nana)
        embedding = merge(embedding, (nana=embed_nana,))
    end

    if with_controller
        # Placeholder for controller embedding
        embed_controller_default = get_controller_embedding()
        embedding = merge(embedding, (controller=embed_controller_default,))
    end

    return ordered_struct_embedding(embedding, Player)
end

# Placeholder for controller embedding
function get_controller_embedding()
    # Implement or replace with your actual controller embedding
    return BoolEmbedding()
end


Base.@kwdef struct PlayerConfig
    xy_scale::Float32 = 0.05f0
    shield_scale::Float32 = 0.01f0
    speed_scale::Float32 = 0.5f0
    with_speeds::Bool = false
    with_controller::Bool = false
    with_nana::Bool = true
    legacy_jumps_left::Bool = false
end

const default_player_config = PlayerConfig()


# Stage embedding
embed_stage = OneHotEmbedding("Stage"; size=64, dtype=UInt8)

# Item embeddings
const MAX_ITEM_TYPE = 0xEC
embed_item_type = OneHotEmbedding("ItemType"; size=MAX_ITEM_TYPE + 1, dtype=Int32, one_hot_policy=EXTRA)

const MAX_ITEM_STATE = 11
embed_item_state = OneHotEmbedding("ItemState"; size=MAX_ITEM_STATE + 1, dtype=UInt8, one_hot_policy=EXTRA)

# Item embedding
function make_item_embedding(xy_scale::Float32)
    embed_xy = FloatEmbedding("xy", scale=xy_scale)
    item_embedding = (
        exists=embed_bool,
        type=embed_item_type,
        state=embed_item_state,
        x=embed_xy,
        y=embed_xy,
    )
    return struct_embedding_from_nt(item_embedding)
end


@enum ItemsType SKIP FLAT MLP

Base.@kwdef struct ItemsConfig
    type::ItemsType = MLP
    mlp_sizes::Tuple{Vararg{Int}} = (128, 32)
end

function make_items_embedding(items_config::ItemsConfig, xy_scale::Float32)
    if items_config.type == SKIP
        return ordered_struct_embedding("items", NamedTuple(), Items)
    end

    embed_item_flat = make_item_embedding(xy_scale)

    if items_config.type == FLAT
        embed_item = embed_item_flat
    elseif items_config.type == MLP
        embed_item = MLPWrapper(items_config.mlp_sizes, embed_item_flat)
    else
        throw(ArgumentError("Unsupported items config type: $(items_config.type)"))
    end

    # Assuming `Items` is a struct with fields like `item1`, `item2`, etc.
    return ordered_struct_embedding("items", [(:item$i, embed_item) for i in 1:fieldcount(Items)], Items)
end


function make_game_embedding(;
    with_randall::Bool=true,
    with_fod::Bool=true,
    items_config::ItemsConfig=ItemsConfig(),
    player_config::PlayerConfig=default_player_config
)
    embed_player = make_player_embedding(;
        xy_scale=player_config.xy_scale,
        shield_scale=player_config.shield_scale,
        speed_scale=player_config.speed_scale,
        with_speeds=player_config.with_speeds,
        with_controller=player_config.with_controller,
        with_nana=player_config.with_nana,
        legacy_jumps_left=player_config.legacy_jumps_left,
    )

    if with_randall
        embed_xy = FloatEmbedding("randall_xy", scale=player_config.xy_scale)
        embed_randall = struct_embedding_from_nt((x=embed_xy, y=embed_xy), Randall)
    else
        embed_randall = ordered_struct_embedding("randall", NamedTuple(), Randall)
        @assert embed_randall.size == 0
    end

    if with_fod
        embed_height = FloatEmbedding("fod_height", scale=player_config.xy_scale)
        embed_fod = struct_embedding_from_nt((left=embed_height, right=embed_height), FoDPlatforms)
    else
        embed_fod = ordered_struct_embedding("fod", NamedTuple(), FoDPlatforms)
        @assert embed_fod.size == 0
    end

    embed_items = make_items_embedding(items_config, player_config.xy_scale)

    game_embedding = (
        p0=embed_player,
        p1=embed_player,
        stage=embed_stage,
        randall=embed_randall,
        fod_platforms=embed_fod,
        items=embed_items,
    )

    return struct_embedding_from_nt(game_embedding, Game)
end


struct DiscreteEmbedding <: AbstractEmbedding{Float32, UInt8}
    n::Int
    size::Int

    function DiscreteEmbedding(n::Int=16)
        new(n, n + 1)
    end
end

from_state(emb::DiscreteEmbedding, a::Union{Float32, AbstractArray{Float32}}) = UInt8.(round.(Int, a * emb.n + 0.5f0))

decode(emb::DiscreteEmbedding, a::Union{UInt8, AbstractArray{UInt8}}) = Float32.(a / emb.n)

(emb::DiscreteEmbedding)(t) = OneHotEmbedding(emb.size)(from_state(emb, t))


const NATIVE_AXIS_SPACING = 160
const NATIVE_SHOULDER_SPACING = 140

Base.@kwdef struct ControllerConfig
    axis_spacing::Int = 16
    shoulder_spacing::Int = 4
end

function get_controller_embedding(;
    axis_spacing::Int=0,
    shoulder_spacing::Int=4
)
    if axis_spacing != 0
        if NATIVE_AXIS_SPACING % axis_spacing != 0
            throw(ArgumentError("Axis spacing must divide $NATIVE_AXIS_SPACING, got $axis_spacing"))
        end
        embed_axis = DiscreteEmbedding(axis_spacing)
    else
        embed_axis = FloatEmbedding("axis", scale=1.0f0)
    end

    embed_stick = struct_embedding_from_nt((x=embed_axis, y=embed_axis), Stick)

    if NATIVE_SHOULDER_SPACING % shoulder_spacing != 0
        throw(ArgumentError("Shoulder spacing must divide $NATIVE_SHOULDER_SPACING, got $shoulder_spacing"))
    end
    embed_shoulder = DiscreteEmbedding(shoulder_spacing)

    embed_buttons = ordered_struct_embedding(
        "buttons",
        [(string(b), BoolEmbedding(name=string(b))) for b in LEGAL_BUTTONS],
        Buttons,
    )

    controller_embedding = (
        buttons=embed_buttons,
        main_stick=embed_stick,
        c_stick=embed_stick,
        shoulder=embed_shoulder,
    )

    return ordered_struct_embedding(controller_embedding, Controller)
end


Base.@kwdef struct EmbedConfig
    player::PlayerConfig = PlayerConfig()
    controller::ControllerConfig = ControllerConfig()
    with_randall::Bool = true
    with_fod::Bool = true
    items::ItemsConfig = ItemsConfig()
end

function get_state_action_embedding(embed_game, embed_action, num_names::Int)
    name_embedding = OneHotEmbedding("name", num_names, Int32, one_hot_policy=EMPTY)
    state_action_embedding = (
        state=embed_game,
        action=embed_action,
        name=name_embedding,
    )
    return struct_embedding_from_nt(state_action_embedding, StateAction)
end



function _stick_to_str(stick)
    return "($(round(stick[1], digits=2)), $(round(stick[2], digits=2)))"
end

function controller_to_str(controller)
    buttons = [string(b) for b in LEGAL_BUTTONS if controller.buttons[b]]

    components = [
        "Main=$(_stick_to_str(controller.main_stick))",
        "C=$(_stick_to_str(controller.c_stick))",
        join(buttons, " "),
        "LS=$(round(controller.shoulder[1], digits=2))",
        "RS=$(round(controller.shoulder[2], digits=2))",
    ]

    return join(components, " ")
end
