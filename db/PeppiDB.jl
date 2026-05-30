using Distributed
using JSON
using Pickle
using Serialization
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
include("nametags.jl")
include("meta.jl")

using .Peppi: read_slippi, read_peppi

function scanreplays(root, shmlink=false)
    """Scan directory structure and identify files to process"""
    # GNU/Linux
    tmpdir = shmlink ? "/dev/shm"  : tempdir()
    # @TODO ADD SHARED MEMORY LINKS FOR OTHER SYSTEMS
    rawfilepath = joinpath(root, "raw.json")
    rawdb = if isfile(rawfilepath)
        JSON.parse(rawfilepath)
    else
        Dict()
    end

    foreach(walkdir(joinpath(root, "Raw"))) do (dirpath, _, filenames)
        relpat = relpath(dirpath, joinpath(root, "Raw"))
        for name in filenames
            path = lstrip(joinpath(relpat, name), ['.', '/'])
            if !haskey(rawdb, path)
                rawdb[path] = Dict("processed" => false, "name" => path)
            end
        end
    end

    toprocess = filter(k -> !rawdb[k]["processed"], keys(rawdb))
    outdir = joinpath(root, "Parsed")
    mkpath(outdir)

    return (tmpdir, joinpath(root, "Raw"), rawfilepath, outdir, toprocess, rawdb)
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
    rawfiles = map(collect(toprocess)) do raw
        if !isnothing(raw) && endswith(raw, ".zip")
            raw
        end
    end
    pqfiles = extractslpzipfiles(rawdir, rawfiles, outdir, tmpdir, nthreads, compressopts)

    for rawname in toprocess
        rawbyname[rawname]["processed"] = true
    end

    # serialize JSON to raw.json
    JSON.json(rawpath, collect(values(rawbyname)); pretty=true)

    # @TODO add Pickle support

    JSON.json(
        joinpath(root, "parsed.json"),
        collect(
            values(
                Dict(md5["slp_md5"] => md5 for md5 in pqfiles)
            )
        );
        pretty=true
    )
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

preprocessreplays("/media/jphardee/82615e34-d3fd-42b4-a7a6-06a31aab319d/Sample3/", 4, true)

processdataset("/media/jphardee/82615e34-d3fd-42b4-a7a6-06a31aab319d/Sample3/")
