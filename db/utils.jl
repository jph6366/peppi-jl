
# Constants that need to be defined before validatereplays can be called
# These should be defined in extract.jl but we import them here for reference

const melee_Character = melee.Character
const BANNED_CHARACTERS = Set([
    melee_Character.KIRBY,
    melee_Character.UNKNOWN_CHARACTER,
])
const ALLOWED_CHARACTERS = setdiff(Set(c for c in melee_Character), BANNED_CHARACTERS)
const ALLOWED_CHARACTER_VALUES = Set(Int(c.value) for c in ALLOWED_CHARACTERS)

const MIN_SLP_VERSION = [2, 1, 0]
const MIN_FRAMES = 60 * 60  # one minute
const GAME_TIME = 60 * 12    # 12 minutes

function getwinner(game)
    if length(game.start.players) > 2
        return nothing
    end

    # Get the last frame index from the Arrow arrays
    num_frames = length(game.frames.id)
    stocks = map(game.frames.ports) do port
        port.post[num_frames].stocks
    end

    losers = [p for (p, s) in enumerate(stocks) if s == 0]
    if !isempty(losers)
        winners = [p for (p, s) in enumerate(stocks) if s > 0]
        if length(winners) == 1
            return Int(winners[1])
        end
    end

    return nothing
end

function convertgame(game, compression, compressionlevel)
    println("[convertgame] Starting conversion")
    table = (root=game,)
    println("[convertgame] Table created: $(typeof(table))")
    pqfile = IOBuffer()
    println("[convertgame] IOBuffer created, position: $(position(pqfile))")
    try
        # Determine compression codec
        compress_codec = if compression == "zlib"
            :zstd  # Arrow uses :zstd for zlib-compatible compression
        elseif compression == "lz4"
            :lz4
        else
            nothing
        end
        
        # Write table to Arrow IPC format with compression
        if compress_codec !== nothing
            Arrow.write(pqfile, table; compress=compress_codec)
            println("[convertgame] Arrow.write completed with $compression compression")
        else
            Arrow.write(pqfile, table)
            println("[convertgame] Arrow.write completed without compression")
        end
        println("[convertgame] Buffer position: $(position(pqfile))")
    catch e
        println("[convertgame] ERROR in Arrow.write: $e")
        rethrow(e)
    end
    pqbytes = take!(pqfile)
    println("[convertgame] Bytes extracted, size: $(length(pqbytes)) bytes")
    
    pqbytes
end

function validatereplays(meta)
    # if meta["slippi_version"] < MIN_SLP_VERSION
    #     return false, "slippi version too low"
    # end
    if parse(Int, meta["num_players"]) != 2
        return false, "not 1v1"
    end
    if parse(Int, meta["lastFrame"]) < MIN_FRAMES
        return false, "game length too short"
    end
    # if meta["timer"] != GAME_TIME
    #     return false, "timer not set to 8 minutes"
    # end
    
    # Check stage validity (would need melee.enums integration)
    if melee.enums.to_internal_stage(meta["stage"]) == melee.enums.Stage.NO_STAGE
        return false, "invalid stage"
    end

    for player in meta["players"]
        player_type = player["type"]
        # if player_type != 0
        #     return false, "not human"
        # end
        character = player["character"]
        if character ∉ ALLOWED_CHARACTER_VALUES
            return false, "invalid character"
        end
    end

    return true, ""
end
