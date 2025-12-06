
const BUTTON_MASKS = Dict(
    melee.Button.BUTTON_A => 0x0100,
    melee.Button.BUTTON_B => 0x0200,
    melee.Button.BUTTON_X => 0x0400,
    melee.Button.BUTTON_Y => 0x0800,
    melee.Button.BUTTON_START => 0x1000,
    melee.Button.BUTTON_Z => 0x0010,
    melee.Button.BUTTON_R => 0x0020,
    melee.Button.BUTTON_L => 0x0040,
    melee.Button.BUTTON_D_LEFT => 0x0001,
    melee.Button.BUTTON_D_RIGHT => 0x0002,
    melee.Button.BUTTON_D_DOWN => 0x0004,
    melee.Button.BUTTON_D_UP => 0x0008,
)

# Returns tuple: (A, B, X, Y, Z, L, R, D_UP)
function getbuttons(button_bits::AbstractArray)
    buttonmap = Dict()
    buttonvec = collect(button_bits)
    for (name, mask) in BUTTON_MASKS
        buttonmap[name] = (buttonvec .& mask) .!= 0
    end
    return (
        buttonmap[melee.Button.BUTTON_A],
        buttonmap[melee.Button.BUTTON_B],
        buttonmap[melee.Button.BUTTON_X],
        buttonmap[melee.Button.BUTTON_Y],
        buttonmap[melee.Button.BUTTON_Z],
        buttonmap[melee.Button.BUTTON_L],
        buttonmap[melee.Button.BUTTON_R],
        buttonmap[melee.Button.BUTTON_D_UP],
    )
end

function _stick2libmelee(stick::AbstractArray)
    return (stick ./ 2.0) .+ 0.5
end

# Returns tuple: (x, y)
function getstick(stick)
    xpos = Arrow.getfield(stick, :x)
    ypos = Arrow.getfield(stick, :y)
    
    return (
        _stick2libmelee(collect(xpos)),
        _stick2libmelee(collect(ypos)),
    )
end

# Returns tuple: (percent, facing, x, y, action, invulnerable, character, jumps_left, shield_strength, on_ground, controller)
# where controller is (main_stick, c_stick, shoulder, buttons)
function getplayer(player)
    leader = Arrow.getfield(player, :leader)
    
    post = Arrow.getfield(leader, :post)
    pre = Arrow.getfield(leader, :pre)
    position = Arrow.getfield(post, :position)
    
    post_get(key) = Arrow.getfield(post, Symbol(key))
    pre_get(key) = Arrow.getfield(pre, Symbol(key))
    
    percent = collect(post_get("percent")) .|> (x -> round(UInt16, x))
    direction = collect(post_get("direction"))
    facing = direction .> 0
    x = collect(Arrow.getfield(position, :x)) .|> Float32
    y = collect(Arrow.getfield(position, :y)) .|> Float32
    action = collect(post_get("state")) .|> UInt16
    hurtbox_state = collect(post_get("hurtbox_state")) .|> UInt8
    invulnerable = hurtbox_state .!= 0
    character = collect(post_get("character")) .|> UInt8
    jumps_left = collect(post_get("jumps")) .|> UInt8
    shield_strength = collect(post_get("shield")) .|> Float32
    
    joystick = Arrow.getfield(pre, :joystick)
    cstick = Arrow.getfield(pre, :cstick)
    buttons_physical = Arrow.getfield(pre, :buttons_physical)
    triggers = Arrow.getfield(pre, :triggers)
    
    airborne = collect(Arrow.getfield(post, :airborne)) .!= 0
    on_ground = .!airborne
    
    # controller tuple: (main_stick, c_stick, shoulder, buttons)
    controller = (
        getstick(joystick),
        getstick(cstick),
        triggers,
        getbuttons(buttons_physical),
    )
    
    return (
        percent,
        facing,
        x,
        y,
        action,
        invulnerable,
        character,
        jumps_left,
        shield_strength,
        on_ground,
        controller,
    )
end
