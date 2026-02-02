module Peppi

include("Internal.jl")
include("parse.jl")
include("game.jl")

using .PeppiJlrs: read_slippi as _read_slippi, read_peppi as _read_peppi, get_start, get_end, get_metadata, get_frames_arrow_path
import JSON

"""
    read_slippi(path::String; skip_frames::Bool=false) -> Game

Read a Slippi replay file (.slp) and return a Game object.

# Arguments
- `path::String`: Path to the .slp file
- `skip_frames::Bool=false`: If true, skip parsing frame data

# Returns
- `Game`: Parsed game data including start, end, metadata, and frames
"""
function read_slippi(path::String; skip_frames::Bool=false)::Game
    g = _read_slippi(path, Int8(skip_frames))
    
    start_json = JSON.parse(get_start(g))
    stop_json = JSON.parse(get_end(g))
    metadata = JSON.parse(get_metadata(g))
    
    game_start = dc_from_json(GameStart, start_json)
    game_stop = isempty(stop_json) ? nothing : dc_from_json(GameStop, stop_json)
    
    # Load frames from Arrow file if not skipping
    local frames
    if skip_frames
        frames = nothing
    else
        arrow_path = get_frames_arrow_path(g)
        if !isempty(arrow_path) && isfile(arrow_path)
            frames_table = Arrow.Table(arrow_path)
            frames = frames_from_sa(frames_table.frame)
        else
            frames = nothing
        end
    end
    
    return Game(
        start=game_start,
        stop=game_stop,
        metadata=metadata,
        frames=frames
    )
end

"""
    read_peppi(path::String; skip_frames::Bool=false) -> Game

Read a Peppi replay file (.slpp) and return a Game object.

# Arguments
- `path::String`: Path to the .slpp file
- `skip_frames::Bool=false`: If true, skip parsing frame data

# Returns
- `Game`: Parsed game data including start, end, metadata, and frames
"""
function read_peppi(path::String; skip_frames::Bool=false)::Game
    g = _read_peppi(path, Int8(skip_frames))
    
    start_json = JSON.parse(get_start(g))
    end_json = JSON.parse(get_end(g))
    metadata = JSON.parse(get_metadata(g))
    
    game_start = dc_from_json(GameStart, start_json)
    game_end = isempty(end_json) ? nothing : dc_from_json(GameStop, end_json)
    
    # Load frames from Arrow file if not skipping
    local frames
    if skip_frames
        frames = nothing
    else
        arrow_path = get_frames_arrow_path(g)
        if !isempty(arrow_path) && isfile(arrow_path)
            frames_table = Arrow.Table(arrow_path)
            frames = frames_from_sa(frames_table.frame)
        else
            frames = nothing
        end
    end
    
    return Game(
        start=game_start,
        stop=game_end,
        metadata=metadata,
        frames=frames
    )
end

export read_slippi, read_peppi, Game, GameStart, GameStop, Frame, PortData, Data, Pre, Post
export Port, P1, P2, P3, P4
export PlayerType, HUMAN, CPU, DEMO
export Language, JAPANESE, ENGLISH
export DashBack, DASHBACK_UCF, DASHBACK_ARDUINO
export ShieldDrop, SHIELDDROP_UCF, SHIELDDROP_ARDUINO
export EndMethod, UNRESOLVED, TIME, GAME, RESOLVED, NO_CONTEST
export Player, Slippi, Scene, Match, Netplay, Team, Ucf, PlayerEnd

end
