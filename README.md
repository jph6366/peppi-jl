# Peppi.jl

WARNING: This is an early prototype. The API and features may change significantly in future releases.

TODO: Add tests for Slippi version 2.0.0/3.0.x

Julia bindings for the [peppi](https://github.com/hohav/peppi) Slippi replay parser, built using Apache Arrow and [jlrs](https://github.com/Taaitaaiger/jlrs)


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

# Game stop info
game.stop
# GameStop(method=RESOLVED, lras_initiator=nothing, players=nothing)

game.stop.method
# RESOLVED::EndMethod = 3

# Frame data (struct-of-arrays via Arrow)
# e.g. get first pre-frame update of port 1
game.frames.ports[1].leader.pre[1].position.x
# -42.0f0
# e.g. get 1000th post-frame update of port 1
game.frames.ports[1].leader.post[1000].percent
# 45.0f0

# Access port 2 position at frame 1001
game.frames.ports[2].leader.pre[1001].position.x
# 42.195167541503906
```

## API Reference

### `read_slippi(path::String; skip_frames::Bool=false) -> Game`

Read a Slippi replay file and return a UBJSON object.

- this version supports Slippi version 0.1.0

**Arguments:**
- `path::String`: Path to the `.slp` file
- `skip_frames::Bool=false`: If `true`, skip parsing frame data (faster for metadata-only reads)

**Returns:**
- `Game`: Parsed game data including `start`, `stop`, `metadata`, and `frames`

## Slippi replay file (.slp)
The overall structure of the file conforms to the Draft 12 version of the [UBJSON spec](http://ubjson.org/).

Read more here at the official [spec](https://github.com/project-slippi/slippi-wiki/blob/master/SPEC.md)

The .slp file has two core elements: raw and metadata. These elements will always show up in the same order in the file with the raw element first and the metadata element second.

# The `raw` Element
The value for this element is an array of bytes that describe discrete events that were sent by the game to be written. These specific events will be broken down later. The data for the raw element is the largest part of the file and is truly what defines what happened during the game.

The lead up to the data will look like the following: `[U][3][r][a][w][[][$][U][#][l][X][X][X][X]`

Each value in brackets is one byte. The first 5 bytes describe the length and name of the key - in this case "raw". The remaining bytes describe the form and length of the value. In this case the value is an array ([) of type uint8 ($U) of length XXXX (lXXXX). The l specifies that the length of the array is described by a long (32-bit number).

Every event is defined by a one byte code followed by a payload. The following table lists all of the existing event types.

| Event Type | Event Code | Description | Added |
| --- | :---: | --- | --- |
| [Event Payloads](#event-payloads) | 0x35 | This event will be the very first event in the byte stream. It enumerates all possible events and their respective payload sizes that may be encountered in the byte stream | 0.1.0
| [Game Start](#game-start) | 0x36 | Contains any information relevant to how the game is set up. Also includes the version of the extraction code | 0.1.0
| [Pre-Frame Update](#pre-frame-update) | 0x37 | One event per frame per character (Ice Climbers are 2 characters). Contains information required to **reconstruct a replay**. Information is collected right before controller inputs are used to figure out the character's next action | 0.1.0
| [Post-Frame Update](#post-frame-update) | 0x38 | One event per frame per character (Ice Climbers are 2 characters). Contains information for **making decisions about game states**, such as computing stats. Information is collected at the end of the Collision detection which is the last consideration of the game engine | 0.1.0
| [Game End](#game-end) | 0x39 | Indicates the end of the game | 0.1.0
| [Frame Start](#frame-start) | 0x3A | This event includes the RNG seed and frame number at the start of a frame's processing | 2.2.0
| [Item Update](#item-update) | 0x3B | One event per frame per item with a maximum of 15 updates per frame. This information can be used for stats, training AIs, or visualization engines to handle items. Items include projectiles like lasers or needles | 3.0.0
| [Frame Bookend](#frame-bookend) | 0x3C | An event that can be used to determine that the entire frame's worth of data has been transferred/processed | 3.0.0
| Gecko List | 0x3D | An event that lists gecko codes. As it can be very large, the list is broken up into multiple messages | 3.3.0
| [FOD Platforms](#fod-platforms) | 0x3F | This event records the height of Fountain of Dreams platforms | 3.18.0
| [Whispy Blow Direction](#whispy-blow-direction) | 0x40 | This event records the direction that Whispy is blowing | 3.18.0
| [Stadium Transformations](#stadium-transformations) | 0x41 | This event records the current Pokemon Stadium transformation | 3.18.0
| [Message Splitter](#message-splitter) | 0x10 | A single part of a large message that has been split out. Currently only applies to Gecko List. | 3.3.0


#### `GameStart`

| Offset | Name | Type | Description | Added |
| --- | --- | --- | --- | --- |
| 0x0 | Command Byte | uint8 | (0x36) The command byte for the game start event | 0.1.0
| 0x1 | Version | uint8[4] | 4 bytes describing the current extraction code version. `major.minor.build.unused` | 0.1.0
| 0x5 | Game Info Block | uint8[312] | Full game info block that Melee reads from to initialize a game. For a breakdown of the bytes, see the table [Game Info Block](#game-info-block) | 0.1.0
| 0x13D | Random Seed | uint32 | The random seed before the game start | 0.1.0
| 0x141 + 0x8*i* | Dashback Fix | uint32 | Controller fix dashback option (0 = off, 1 = UCF, 2 = Dween). *i* is 0-3 depending on the character port. | 1.0.0
| 0x145 + 0x8*i* | Shield Drop Fix | uint32 | Controller fix shield drop option (0 = off, 1 = UCF, 2 = Dween). *i* is 0-3 depending on the character port. | 1.0.0
| 0x161 + 0x10*i* | Nametag | Shift JIS char16[8] | Nametags used by the players. *i* is 0-3 depending on the character port. Nametags are [Shift JIS](https://en.wikipedia.org/wiki/Shift_JIS) encoded. The English characters are full width characters and [can be converted](https://github.com/project-slippi/slp-parser-js/blob/master/src/utils/fullwidth.ts) to normal ASCII/half width characters | 1.3.0
| 0x1A1 | PAL | bool | Value is 1 if PAL is enabled, 0 otherwise | 1.5.0
| 0x1A2 | Frozen PS | bool | Value is 1 if frozen Pokémon Stadium is enabled, 0 otherwise | 2.0.0
| 0x1A3 | Minor Scene | u8 | Minor scene number. Mostly useless atm, should always be 0x2 | 3.7.0
| 0x1A4 | Major Scene | u8 | Major scene number. 0x2 when the game is played from VS mode, 0x8 when online game (has rollbacks) | 3.7.0
| 0x1A5 + 0x1F*i* | Display Name | Shift JIS string | Display names used by the players if using Slippi Online. *i* is 0-3 depending on the character port. [Shift JIS](https://en.wikipedia.org/wiki/Shift_JIS) encoded, characters can be mixed half width (1 byte) and full width (2 bytes). Max 15 characters + null terminator | 3.9.0
| 0x221 + 0xA*i* | Connect Code | Shift JIS string | Connect codes used by the players in using Slippi Online. *i* is 0-3 depending on the character port. The `#` is full width (`0x8194`). All other characters are half width (1 byte). Max 7 1 byte characters + 2 byte `#` + null terminator | 3.9.0
| 0x249 + 0x1D*i* | Slippi UID | string | Firebase UIDs of players if using Slippi Online. *i* is 0-3 depending on the character port. Max 28 characters + null terminator | 3.11.0
| 0x2BD | Language Option | u8 | 0 = Japanese, 1 = English. Needed for HRC because stage is different between the languages | 3.12.0
| 0x2BE | Session ID | string | An ID consisting of the mode and time the session started (e.g. `mode.unranked-2022-12-20T06:52:39.18-0`). Max 50 characters + null terminator. Assigned by server and unique for every session. If you want a unique ID for an individual game, append the game number and tiebreak number to the end of this ID. | 3.14.0
| 0x2F1 | Game Number | u32 | For the given Session ID, starts at 1 | 3.14.0
| 0x2F5 | Tiebreaker Number | u32 | For the given Game Number, will be 0 if not a tiebreak game | 3.14.0

#### `GameStop`
| Offset | Name | Type | Description | Added |
| --- | --- | --- | --- | --- |
| 0x0 | Command Byte | uint8 | (0x39) The command byte for the game end event | 0.1.0
| 0x1 | Game End Method | uint8 | See table [Game End Method](#game-end-method) | 0.1.0
| 0x2 | LRAS Initiator | int8 | Index of player that LRAS'd. -1 if not applicable | 2.0.0
| 0x3 | Player Placements | int8[4] | 0-indexed placement positions. -1 if player not in game | 3.13.0


## Frame Data Structure

Frame data uses Arrow arrays for efficient columnar access:

```
frames
├── id              # Frame index
├── start           # Frame start data
│   └── random_seed
├── end             # Frame end data
│   └── latest_finalized_frame
├── ports[1]         # Per-port data (up to 4 players)
│   └── leader      # Main character data
│       ├── pre[1]     # Pre-frame update
│       │   ├── position.x, position.y
│       │   ├── joystick.x, joystick.y
│       │   ├── state, direction
│       │   └── ...
│       └── post[1]    # Post-frame update
│           ├── position.x, position.y
│           ├── percent, stocks
│           ├── state, character
│           └── ...
└── items[]         # Item data
```

## License

MIT
