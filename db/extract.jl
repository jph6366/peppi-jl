
function extractslpzipfiles(root, rawfiles, outdir, tmpdir, nthreads, compressionopts)
    if isone(nthreads)
        results_nested = map(ProgressBar(rawfiles)) do rawfile
            extractslpzip_(root, rawfile, outdir, tmpdir; compression=compressionopts[:compression], compressionlevel=compressionopts[:compression_level])
        end
        # Flatten results from nested arrays
        results = vcat(results_nested...)
    else
        results_nested = Vector{Any}(undef, length(rawfiles))
        @sync begin
            for (i, rawfile) in enumerate(rawfiles)
                Threads.@spawn begin
                    idx, res = extractslpzip(i, root, rawfile, outdir, tmpdir;  compression=compressionopts[:compression], compressionlevel=compressionopts[:compression_level])
                    results_nested[idx] = res
                end
            end
        end
        # Flatten results from nested arrays
        results = vcat(results_nested...)
    end
end

function extractslpgame(game)
    metadata = game.metadata
    result = Dict{String,Any}(key => metadata[key] for key in ["startAt", "playedOn"] if haskey(metadata, key))
    result["lastFrame"] = string(game.frames.id[end])
    result["slippi_version"] = string(game.start.slippi.version)
    result["match"] = string(game.start.match)

    playermetas = map(game.start.players) do player
        port = player.port
        leader = game.frames.ports[Int(port)+1].leader
        cs = leader.post.character
        character = Int(mode(cs))
        percent = leader.post.percent
        damage = sum(max.(percent[2:end] .- percent[1:end-1], 0.0))
        Dict((            
            "port" => Int(port),
            "character" => character,
            "type" => player.type == "Human" ? 0 : 1,
            "name_tag" => player.name_tag,
            "netplay" => player.netplay,
            "damage_taken" => damage,
            ))
    end

    merge!(result, Dict(
        "num_players" => string(length(playermetas)),
        "players" => playermetas,   
    ))

    result["stage"] = game.start.stage
    result["timer"] = game.start.timer
    result["is_teams"] = game.start.is_teams
    result["winner"] = getwinner(game)

    return result
end

function extractslpzip_(root, rawfile, outdir, tmpdir; compression, compressionlevel)
    """Extract a zip file and process the .slp files inside"""
    
    rawpat = joinpath(root, rawfile) 
    println("[extractslpzip_] Processing $rawpat")
    println("[extractslpzip_] Output directory: $outdir")
    
    # Create a temporary directory to extract the zip
    tmp = mktempdir(tmpdir)
    
    # Extract the zip file using 7z
    run(`$(p7zip()) x -o$tmp $rawpat -y`)
    
    # Find all .slp files in the extracted directory
    slpfiles = traverseslpfiles(tmp)
    println("Found $(length(slpfiles)) .slp files in $rawfile")
    
    # Process each .slp file and collect results
    results = []
    
    for slpfile in slpfiles
        result = Dict{String, Any}("name" => chop(rawpat), "raw" => rawfile)
        
        slpbytes = read(slpfile)
        result["slp_size"] = length(slpbytes)
        slpmd5 = bytes2hex(md5(slpbytes))
        result["slp_md5"] = slpmd5
        # Read the slp file
        println("[extractslpzip_] Reading slp file: $slpfile")
        game = read_slippi(slpfile)
        println("[extractslpzip_] Game read successfully")
        metadata = extractslpgame(game)
        println("[extractslpzip_] Metadata extracted")
        istraining, reason = validatereplays(metadata)
        println("[extractslpzip_] Validation result - is_training: $istraining, reason: '$reason'")
        println("[extractslpzip_] Metadata keys: $(keys(metadata))")

        merge!(result, metadata)
        result["valid"] = true
        result["is_training"] = istraining
        result["not_training_reason"] = reason

        if istraining
            println("[extractslpzip_] Game is valid training data")
            gamestruct = traversepeppi(game)
            println("[extractslpzip_] traversepeppi completed, gamearr type: $(typeof(gamestruct))")
            gamebytes = convertgame(gamestruct, compression, compressionlevel)
            println("[extractslpzip_] convertgame completed, gamebytes size: $(length(gamebytes)) bytes")
            result["pq_size"] = length(gamebytes)
            result["compression"] = string(compression)

            # @TODO from slippi-ai/slippi-db/parse_local.py
            # `consider writing to rawname/slpname`
            outfile = joinpath(outdir, slpmd5)
            println("[extractslpzip_] Writing parquet to: $outfile")
            open(outfile, "w") do f
                bytes_written = write(f, gamebytes)
                println("[extractslpzip_] Wrote $bytes_written bytes to file")
            end
            println("[extractslpzip_] File write complete")
        else
            println("[extractslpzip_] Game rejected: $reason")
        end
        
        push!(results, result)
    end
    
    # Clean up temporary directory
    println("[extractslpzip_] Cleaning up temporary directory: $tmp")
    rm(tmp, recursive=true, force=true)
    
    results
end

function extractslpzip(idx, root, file, outdir, tmpdir; kwargs...)
    idx, extractslpzip_(root, file, outdir, tmpdir; kwargs...)
end