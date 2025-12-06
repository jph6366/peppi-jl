using Distributed
using JSON
using Pickle
using ProgressBars
using SHA
using MD5
using p7zip_jll: p7zip
using StatsBase
using PyCall
using Arrow

const melee = pyimport("melee")

include("../src/Peppi.jl")
include("state.jl")
include("traverse.jl")
include("utils.jl")
include("extract.jl")

using .Peppi: read_slippi, read_peppi, P1, P2, HUMAN, CPU, RESOLVED, Game

function scanreplays(root, shmlink=false)
    """Scan directory structure and identify files to process"""
    # GNU/Linux
    tmpdir = shmlink ? "/dev/shm"  : tempdir()
    # @TODO ADD SHARED MEMORY LINKS FOR OTHER SYSTEMS
    rawdir = joinpath(root, "Raw")
    rawpath = joinpath(root, "raw.json")
    if isfile(rawpath)
        rawdb = JSON.parsefile(rawpath)
    else
        rawdb = []
    end
    rawbyname = Dict(row["name"] => row for row in rawdb)
    toprocess = String[]
    for (dirpath, _, filenames) in walkdir(rawdir)
        relpat = relpath(dirpath, rawdir)
        for name in filenames
            path = joinpath(relpat, name)
            path = lstrip(path, '.')
            path = lstrip(path, '/')
            if !haskey(rawbyname, path)
                rawbyname[path] = Dict("processed" => false, "name" => path)
            end
            if !rawbyname[path]["processed"]
                push!(toprocess, path)
            end
        end
    end

    outdir = joinpath(root, "Parsed")
    mkpath(outdir)

    return (tmpdir, rawdir, rawpath, outdir, toprocess, rawbyname)
end

function processreplays(
    root,
    tmpdir,
    rawdir,
    rawpath,
    outdir,
    toprocess,
    rawbyname,
    nthreads=1,
    compressopts=Dict(
        :compression => "zlib",
        :compression_level => nothing
    )
)
    """Process identified replay files"""
    rawfiles = String[]
    rawnames = Vector{String}[]
    for raw in toprocess
        rawpat = joinpath(rawdir, raw)
        if !endswith(raw, ".zip")
            continue
        end
        slpfiles = traverseslpfiles(rawpat)
        push!(rawfiles, raw)
        push!(rawnames, fill(raw, length(slpfiles)))
    end

    results = extractslpzipfiles(rawdir, rawfiles, outdir, tmpdir, nthreads, compressopts)

    @assert length(results) == length(rawfiles)

    for (result, rawname) in zip(results, rawnames)
        result["raw"] = rawname
    end

    for rawname in toprocess
        rawbyname[rawname]["processed"] = true
    end

    open(rawpath, "w") do file
        write(file, JSON.json(collect(values(rawbyname)), 2))
    end

    slpdbpath = joinpath(root, "parsed.pkl")
    slpmeta = isfile(slpdbpath) ? Pickle.load(open(slpdbpath, "r")) : []
    bykey = Dict(getmd5key(row) => row for row in slpmeta)
    for result in results
        bykey[getmd5key(result)] = result
    end

    open(joinpath(root, "parsed.pkl"), "w") do file
        Pickle.dump(file, collect(values(bykey)))
    end
end

function preprocessreplays(        
    root, 
    nthreads=1,
    shmlink=false,
    compressopts=Dict(
        :compression => "zlib",
        :compression_level => nothing
    )
)
    """Main pipeline: scan and process replays"""
    tmpdir, rawdir, rawpath, outdir, toprocess, rawbyname = scanreplays(root, shmlink)
    processreplays(root, tmpdir, rawdir, rawpath, outdir, toprocess, rawbyname, nthreads, compressopts)
end

preprocessreplays("/media/jphardee/T9/Sample3/")