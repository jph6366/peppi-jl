
const MIN_DAMAGE = 100

function totaldamage(row)
    """Calculate total damage taken across all players in a replay"""
    total = 0
    for player in row["players"]
        damage = get(player, "damage_taken", nothing)
        if damage === nothing
            return nothing
        end
        total += damage
    end
    return total
end

function checkreplay(row; winneronly=true)
    """Check if replay should be included in training dataset.
    
    Returns reason string if replay should be excluded, nothing if valid.
    """
    if !row["valid"]
        return "invalid"
    end

    if !row["is_training"]
        return row["not_training_reason"]
    end

    if startswith(row["raw"], "Phillip/")
        model = split(row["name"], "/")[1]
        if startswith(model, "basic-") || contains(model, "imitation")
            return "vs weak phillip"
        end

        # Only train on replays vs good players.
        for player in row["players"]
            # One of the players is always `Phillip AI` who is "known".
            name = name_from_metadata(player)
            if !is_known_player(name)
                return "unknown player vs phillip"
            end
        end
    end

    damage = totaldamage(row)
    if damage !== nothing
        if damage < MIN_DAMAGE
            return "insufficient damage dealt"
        end
    elseif winneronly && get(row, "winner", nothing) === nothing
        return "no winner"
    end

    return nothing
end

"""Main dataset creation function.

Filters parsed replays, validates training data, and creates final dataset.
"""
function processdataset(root; winneronly=true, maketar=nothing)
    parsepath = joinpath(root, "parsed.json")
    
    # Load JSON rows
    if !isfile(parsepath)
        error("parsed.json not found at $parsepath. Run preprocessing first.")
    end
    
    rows = nothing
    try
        rows = JSON.parsefile(parsepath)
    catch e
        error("Failed to load JSON file $parsepath. Error: $(string(e))")
    end
    
    if !isa(rows, Vector)
        error("Expected rows to be a Vector, got $(typeof(rows))")
    end
    
    # Keep only training replays
    reasons = Dict{String, Int}()
    matchids = Set()
    valid = []
    
    for row in rows
        reason = checkreplay(row; winneronly=winneronly)
        if reason !== nothing
            reasons[reason] = get(reasons, reason, 0) + 1
            continue
        end
        
        match = get(row, "match", nothing)
        if match !== nothing && isa(match, Dict)
            matchid = (match["id"], match["game"], match["tiebreaker"])
            
            if matchid in matchids
                reasons["duplicate match ID"] = get(reasons, "duplicate match ID", 0) + 1
                continue
            end
            
            push!(matchids, matchid)
        end
        
        push!(valid, row)
    end
    
    # Print filtering statistics
    sortedrseasons = sort(collect(reasons), by=x -> -x[2])
    for (reason, count) in sortedreasons
        percentage = 100 * count / length(rows)
        println("Filtered $(round(percentage; digits=2))% due to \"$reason\"")
    end
    
    println("Found $(length(valid))/$(length(rows)) training replays.")
    
    # Fix numpy floats which json can't handle
    for row in valid
        for player in row["players"]
            damage = get(player, "damage_taken", nothing)
            if damage !== nothing
                player["damage_taken"] = float(damage)
            end
        end
    end
    
    # Create tar archive if requested
    tarhandle = nothing
    if maketar !== nothing
        tarpath = joinpath(root, "training.tar")
        tarhandle = open(tarpath, "w")
        mkpath(joinpath(root, "training", "games"))
    end
    
    missing = Dict{String, Int}()
    
    for row in valid
        md5 = row["slp_md5"]
        parsedfile = joinpath(root, "Parsed", md5)
        
        if !isfile(parsedfile)
            missing[row["raw"]] = get(missing, row["raw"], 0) + 1
            continue
        end
        
        if maketar !== nothing
            # Add file to tar archive
            # Note: This would require a tar library; using simple file copy for now
            cp(parsedfile, joinpath(root, "training", "games", md5); force=true)
        end
    end
    
    println("Missing: $missing")
    
    # Write metadata
    metapath = joinpath(root, "meta.json")
    open(metapath, "w") do f
        write(f, JSON.json(valid, 2))
    end
    
    if maketar !== nothing
        # Copy meta.json to tar
        cp(metapath, joinpath(root, "training", "meta.json"); force=true)
        close(tarhandle)
    end
    
    return valid
end

