module Peppi

include("Internal.jl")
include("parse.jl")
include("game.jl")

import .JuliaApp
import JSON

"""
    read_slippi(path::String; skip_frames::Bool=false) -> Game

Read a Slippi replay file and return a Game object.

# Arguments
- `path::String`: Path to the .slp file
- `skip_frames::Bool=false`: If true, skip parsing frame data

# Returns
- `Game`: Parsed game data including start, end, metadata, and frames
"""
function read_slippi(path::String; skip_frames::Bool=false)::Game
    g = JuliaApp.read_slippi(path, Int8(skip_frames))
    
    start_json = JSON.parse(JuliaApp.get_start(g))
    end_json = JSON.parse(JuliaApp.get_end(g))
    metadata = JSON.parse(JuliaApp.get_metadata(g))
    
    game_start = dc_from_json(GameStart, start_json)
    game_end = isempty(end_json) ? nothing : dc_from_json(GameEnd, end_json)
    
    # Load frames from Arrow file if not skipping
    local frames
    if skip_frames
        frames = nothing
    else
        arrow_path = JuliaApp.get_frames_arrow_path(g)
        if !isempty(arrow_path) && isfile(arrow_path)
            frames_table = Arrow.Table(arrow_path)
            frames = frames_from_sa(frames_table.frame)
        else
            frames = nothing
        end
    end
    
    return Game(
        start=game_start,
        _end=game_end,
        metadata=metadata,
        frames=frames
    )
end

export read_slippi, Game, GameStart, GameEnd, Frame, PortData, Data, Pre, Post
export Port, P1, P2, P3, P4
export PlayerType, HUMAN, CPU, DEMO
export Language, JAPANESE, ENGLISH
export DashBack, DASHBACK_UCF, DASHBACK_ARDUINO
export ShieldDrop, SHIELDDROP_UCF, SHIELDDROP_ARDUINO
export EndMethod, UNRESOLVED, TIME, GAME, RESOLVED, NO_CONTEST
export Player, Slippi, Scene, Match, Netplay, Team, Ucf, PlayerEnd

end
