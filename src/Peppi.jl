module Peppi

include("Internal.jl")
include("parse.jl")

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
function read_slippi(path::String; skip_frames::Bool=false)
    g = _read_slippi(path, Int8(skip_frames))
    
    start_json = JSON.parse(get_start(g))
    stop_json = JSON.parse(get_end(g))
    metadata = JSON.parse(get_metadata(g))
    

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
    
    (
        start=start_json,
        stop=stop_json,
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
function read_peppi(path::String; skip_frames::Bool=false)
    g = _read_peppi(path, Int8(skip_frames))
    
    start_json = JSON.parse(get_start(g))
    stop_json = JSON.parse(get_end(g))
    metadata = JSON.parse(get_metadata(g))

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
    (
        start=start_json,
        stop=stop_json,
        metadata=metadata,
        frames=frames
    )
end

export read_slippi, read_peppi, Frame, PortData, Data, Pre, Post
end
