
const VALID_SUFFIXES = [".slp", ".slpp"]

function traverseslpfiles(root)
    """Find all .slp/.slpp files in a directory"""
    files = String[]
    
    # Walk through the directory
    for (dirpath, _, filenames) in walkdir(root)
        for filename in filenames
            if any(endswith(filename, s) for s in VALID_SUFFIXES)
                push!(files, joinpath(dirpath, filename))
            end
        end
    end
    
    return files
end

function traversepeppi(game)
    frames = game.frames
    playerlist = game.start.players
    portnames = sort([p.port for p in playerlist])
    portsdata = Arrow.getfield(frames, :ports)
    players = Dict(map(enumerate(portnames)) do (i, portname)
        "p$(i-1)" => getplayer(Arrow.getfield(portsdata, Int(portname)+1))
    end)

    stage = melee.enums.to_internal_stage(game.start.stage).value
    stagearr = fill(UInt8(stage), length(frames.id))
    
    # Find consecutive frame sequence starting at -123
    index = collect(Arrow.getfield(frames, :id))
    println("[traversepeppi] Total frames: $(length(index)), Frame ID range: $(minimum(index)) to $(maximum(index))")
    nextidx = -123
    firstidxs = []
    for (i, idx) in enumerate(index)
        if idx == nextidx
            push!(firstidxs, i)
            nextidx += 1
        end
    end
    println("[traversepeppi] Found $(length(firstidxs)) consecutive frames starting at -123")
    
    # Filter all player data to only include frames in the sequence
    if !isempty(firstidxs)
        # Helper function to filter a tuple recursively
        function filter_tuple(t, indices)
            return tuple((isa(elem, Tuple) ? filter_tuple(elem, indices) : elem[indices] for elem in t)...)
        end
        
        p0_filtered = filter_tuple(players["p0"], firstidxs)
        p1_filtered = filter_tuple(players["p1"], firstidxs)
        stage_filtered = stagearr[firstidxs]
        
        println("[traversepeppi] Filtered data shapes - p0: $(length(p0_filtered)), p1: $(length(p1_filtered)), stage: $(length(stage_filtered))")
    else
        p0_filtered = players["p0"]
        p1_filtered = players["p1"]
        stage_filtered = stagearr
        println("[traversepeppi] No consecutive frame sequence found, using full data")
    end
    
    # Returns tuple: (p0, p1, stage)
    gamestruct = (
        p0_filtered,
        p1_filtered,
        stage_filtered,
    )

    return gamestruct
end