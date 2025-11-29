using Arrow

include("util.jl")

# Type aliases for Arrow arrays
const Int8Arr = Union{Arrow.Primitive{Int8}, Nothing}
const Int16Arr = Union{Arrow.Primitive{Int16}, Nothing}
const Int32Arr = Union{Arrow.Primitive{Int32}, Nothing}
const Int64Arr = Union{Arrow.Primitive{Int64}, Nothing}
const UInt8Arr = Union{Arrow.Primitive{UInt8}, Nothing}
const UInt16Arr = Union{Arrow.Primitive{UInt16}, Nothing}
const UInt32Arr = Union{Arrow.Primitive{UInt32}, Nothing}
const UInt64Arr = Union{Arrow.Primitive{UInt64}, Nothing}
const Float32Arr = Union{Arrow.Primitive{Float32}, Nothing}
const Float64Arr = Union{Arrow.Primitive{Float64}, Nothing}

Base.@kwdef mutable struct End
    latest_finalized_frame::Int32Arr = nothing
end
Base.repr(x::End) = _repr(x)

Base.@kwdef struct Position
    x::Float32Arr
    y::Float32Arr
end
Base.repr(x::Position) = _repr(x)

Base.@kwdef struct Start
    random_seed::UInt32Arr
    scene_frame_counter::UInt32Arr = nothing
end
Base.repr(x::Start) = _repr(x)

Base.@kwdef struct TriggersPhysical
    l::Float32Arr
    r::Float32Arr
end
Base.repr(x::TriggersPhysical) = _repr(x)

Base.@kwdef struct Velocities
    self_x_air::Float32Arr
    self_y::Float32Arr
    knockback_x::Float32Arr
    knockback_y::Float32Arr
    self_x_ground::Float32Arr
end
Base.repr(x::Velocities) = _repr(x)

Base.@kwdef struct Velocity
    x::Float32Arr
    y::Float32Arr
end
Base.repr(x::Velocity) = _repr(x)

Base.@kwdef mutable struct Item
    type::UInt16Arr
    state::UInt8Arr
    direction::Float32Arr
    velocity::Velocity
    position::Position
    damage::UInt16Arr
    timer::Float32Arr
    id::UInt32Arr
    misc::Union{Tuple{UInt8Arr, UInt8Arr, UInt8Arr, UInt8Arr}, Nothing} = nothing
    owner::Int8Arr = nothing
end
Base.repr(x::Item) = _repr(x)

Base.@kwdef mutable struct Post
    character::UInt8Arr
    state::UInt16Arr
    position::Position
    direction::Float32Arr
    percent::Float32Arr
    shield::Float32Arr
    last_attack_landed::UInt8Arr
    combo_count::UInt8Arr
    last_hit_by::UInt8Arr
    stocks::UInt8Arr
    state_age::Float32Arr = nothing
    state_flags::Union{Tuple{UInt8Arr, UInt8Arr, UInt8Arr, UInt8Arr, UInt8Arr}, Nothing} = nothing
    misc_as::Float32Arr = nothing
    airborne::UInt8Arr = nothing
    ground::UInt16Arr = nothing
    jumps::UInt8Arr = nothing
    l_cancel::UInt8Arr = nothing
    hurtbox_state::UInt8Arr = nothing
    velocities::Union{Velocities, Nothing} = nothing
    hitlag::Float32Arr = nothing
    animation_index::UInt32Arr = nothing
end
Base.repr(x::Post) = _repr(x)

Base.@kwdef mutable struct Pre
    random_seed::UInt32Arr
    state::UInt16Arr
    position::Position
    direction::Float32Arr
    joystick::Position
    cstick::Position
    triggers::Float32Arr
    buttons::UInt32Arr
    buttons_physical::UInt16Arr
    triggers_physical::TriggersPhysical
    raw_analog_x::Int8Arr = nothing
    percent::Float32Arr = nothing
    raw_analog_y::Int8Arr = nothing
end
Base.repr(x::Pre) = _repr(x)

Base.@kwdef struct Data
    pre::Pre
    post::Post
end
Base.repr(x::Data) = _repr(x)

Base.@kwdef mutable struct PortData
    leader::Data
    follower::Union{Data, Nothing} = nothing
end
Base.repr(x::PortData) = _repr(x)

Base.@kwdef struct Frame
    id::Any
    ports::Tuple{Vararg{PortData}}
end
Base.repr(x::Frame) = _repr(x)