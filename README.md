# peppi-jl

Julia bindings for the [peppi](https://github.com/hohav/peppi) Slippi replay parser, built using Apache Arrow and [jlrs](https://github.com/Taaitaaiger/jlrs).


@TODO: Use Serde.jl instead JSON.jl

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/your-repo/peppi-jl")
```

To build from source, first install [Rust](https://rustup.rs/). Then:

```bash
cd julia_app
cargo build --release
```

## Usage

peppi-jl exposes one function:

- `read_slippi(path; skip_frames=false)`

This parses a Slippi replay file (`.slp`) into a `Game` object.

Frame data is stored as a struct-of-arrays for performance, using Arrow. So to get the value of an attribute `foo.bar` for the nth frame of the game, you'd write `game.frames.foo.bar[n]` instead of `game.frames[n].foo.bar`. See the code example below.

You can do many other things with Arrow arrays, such as converting them to regular Julia arrays. See the [Arrow.jl docs](https://arrow.apache.org/julia/stable/) for more.

Also see the [Slippi replay spec](https://github.com/project-slippi/slippi-wiki/blob/master/SPEC.md) for detailed information about the available fields and their meanings.

## Example

```julia
using Peppi

game = read_slippi("path/to/game.slp")

# Metadata
game.metadata
# Dict{String, Any} with 4 entries:
#   "startAt"   => "2018-06-22T07:52:59Z"
#   "lastFrame" => 5085
#   "players"   => Dict{String, Any}("1"=>Dict{String, Any}("characters"=>Dict{String, Any}("1"=>5209)), "0"=>…)
#   "playedOn"  => "dolphin"

# Game start info
game.start
# GameStart(slippi=Slippi(version=(1, 0, 0)), ...)

game.start.slippi.version
# (1, 0, 0)

game.start.stage
# 8  (Yoshi's Story)

game.start.players[1].character
# 9  (Marth)

# Game end info
game._end
# GameEnd(method=RESOLVED, lras_initiator=nothing, players=nothing)

game._end.method
# RESOLVED::EndMethod = 3

# Frame data (struct-of-arrays via Arrow)
game.frames.ports[1].leader.pre.position.x[1]
# -42.0f0

game.frames.ports[1].leader.post.percent[1000]
# 45.0f0

# Access P2's position at frame 1001
game.frames.ports[2].leader.pre.position.x[1001]
# 42.195167541503906
```

## API Reference

### `read_slippi(path::String; skip_frames::Bool=false) -> Game`

Read a Slippi replay file and return a `Game` object.

**Arguments:**
- `path::String`: Path to the `.slp` file
- `skip_frames::Bool=false`: If `true`, skip parsing frame data (faster for metadata-only reads)

**Returns:**
- `Game`: Parsed game data including `start`, `_end`, `metadata`, and `frames`

### Types

#### `Game`
```julia
struct Game
    start::GameStart      # Game start information
    _end::GameEnd         # Game end information  
    metadata::Dict        # Replay metadata
    frames::Frame         # Frame data (Arrow arrays)
end
```

#### `GameStart`
Contains game configuration including:
- `slippi::Slippi` - Slippi version info
- `stage::Int` - Stage ID
- `players::Tuple{Vararg{Player}}` - Player information
- `timer::Int` - Game timer setting
- `random_seed::Int` - Random seed
- And more...

#### `GameEnd`
```julia
struct GameEnd
    method::EndMethod                           # How the game ended
    lras_initiator::Union{Port, Nothing}        # Who quit (if applicable)
    players::Union{Tuple{Vararg{PlayerEnd}}, Nothing}
end
```

#### `Player`
```julia
struct Player
    port::Port              # P1, P2, P3, or P4
    character::Int          # Character ID
    type::PlayerType        # HUMAN, CPU, or DEMO
    stocks::Int             # Starting stocks
    costume::Int            # Costume/color index
    # ... and more
end
```

### Enums

- `Port`: `P1`, `P2`, `P3`, `P4`
- `PlayerType`: `HUMAN`, `CPU`, `DEMO`
- `EndMethod`: `UNRESOLVED`, `TIME`, `GAME`, `RESOLVED`, `NO_CONTEST`
- `Language`: `JAPANESE`, `ENGLISH`
- `DashBack`: `DASHBACK_UCF`, `DASHBACK_ARDUINO`
- `ShieldDrop`: `SHIELDDROP_UCF`, `SHIELDDROP_ARDUINO`

## Frame Data Structure

Frame data uses Arrow arrays for efficient columnar access:

```
frames
├── id              # Frame index
├── start           # Frame start data
│   └── random_seed
├── end             # Frame end data
│   └── latest_finalized_frame
├── ports[]         # Per-port data (up to 4 players)
│   └── leader      # Main character data
│       ├── pre     # Pre-frame update
│       │   ├── position.x, position.y
│       │   ├── joystick.x, joystick.y
│       │   ├── state, direction
│       │   └── ...
│       └── post    # Post-frame update
│           ├── position.x, position.y
│           ├── percent, stocks
│           ├── state, character
│           └── ...
└── items[]         # Item data
```

## License

MIT
