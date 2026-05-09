
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
    xpos = getproperty.(stick, :x)
    ypos = getproperty.(stick, :y)
    
    return (
        _stick2libmelee(collect(xpos)),
        _stick2libmelee(collect(ypos)),
    )
end

# Returns tuple: (percent, facing, x, y, action, invulnerable, character, jumps_left, shield_strength, on_ground, controller)
# where controller is (main_stick, c_stick, shoulder, buttons)
function getplayer(player)

    post = player.post
    pre  = player.pre
    percent      = getproperty.(post, :percent) .|> (x -> round(UInt16, x))
    direction    = getproperty.(post, :direction)
    facing       = direction .> 0
    pos = getproperty.(post, :position)
    x = getproperty.(pos, :x) .|> Float32
    y = getproperty.(pos, :y) .|> Float32
    
    action = getproperty.(post, :state) .|> UInt16
    invulnerable = getproperty.(post, :hurtbox_state) .!= 0
    character    = getproperty.(post, :character) .|> UInt8
    jumps_left   = getproperty.(post, :jumps) .|> UInt8
    shield_str   = getproperty.(post, :shield) .|> Float32
    on_ground    = getproperty.(post, :airborne) .== 0 
    joystick = getproperty.(pre, :joystick)
    cstick = getproperty.(pre, :cstick)
    buttons_phys = getproperty.(pre, :buttons_physical)
    triggers = getproperty.(pre, :triggers)
    
    controller = (
        getstick(joystick),
        getstick(cstick),
        triggers,
        getbuttons(buttons_phys),
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
        shield_str,
        on_ground,
        controller,
    )
end
