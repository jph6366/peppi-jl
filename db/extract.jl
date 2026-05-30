

function extractslpzipfiles(root, rawfiles, outdir, tmpdir, nthreads, compressionopts)
    kwargs = (
        compression = compressionopts[:compression], 
        compressionlevel = compressionopts[:compression_level]
    )
    if isone(nthreads)
        nestedresults = map(ProgressBar(rawfiles)) do rawfile
            extractslpzip_(root, rawfile, outdir, tmpdir; kwargs...)
        end
    else
        # Using @spawn and @sync to spawn tasks in threads
        # and synchronize them at the end of the block
        tasks = map(rawfiles) do rawfile
            @spawn begin
                _, res = extractslpzip_(root, rawfile, outdir, tmpdir; kwargs...)
                res
            end
        end
        nestedresults = @sync fetch.(tasks)
    end
    # Flatten results from nested arrays
    vcat(nestedresults...)
end

function extractslpgame(game)
    metadata = game.metadata
    result = Dict{String,Any}(key => metadata[key] for key in ["startAt", "playedOn"] if haskey(metadata, key))
    result["lastFrame"] = string(game.frames.id[end])
    result["slippi_version"] = string(game.start.slippi.version)
    result["match"] = string(game.start.match)
    println("players::",length(game.start.players))
    playermetas = map(game.start.players) do player
        port = Int(last(player.port))
        postframe = getproperty.(game.frames.ports, :post)[1]
        cs = getproperty.(postframe, :character) 
        character = mode(cs)
        percent = getproperty.(postframe, :percent)
        damage = sum(max.(percent[2:end] .- percent[1:end-1], 0.0))
        Dict((            
            "port" => port,
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

    result
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
    
    # Process each .slp file and collect results
    results = map(traverseslpfiles(tmp)) do slpfile
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
        
        result
    end
    
    # Clean up temporary directory
    println("[extractslpzip_] Cleaning up temporary directory: $tmp")
    rm(tmp, recursive=true, force=true)
    
    results
end

function extractslpzip(idx, root, file, outdir, tmpdir; kwargs...)
    idx, extractslpzip_(root, file, outdir, tmpdir; kwargs...)
end
