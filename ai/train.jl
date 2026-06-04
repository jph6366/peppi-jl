
using Flux
# using Wandb
using Logging
using Dates
using JSON

include("nametags.jl")
include("onehot.jl")

const MAXNAMES = 16

# experimentlabel = "slippi-ai-$(now())"
# lg = WandbLogger(project = "slippi-ai-jl", name = experimentlabel,
#                  config = Dict("learning_rate" => 3e-4, "batchsize" => 256,
#                                "epochs" => 100, "dataset" => "PeppiDB", "use_cuda" => true))
# global_logger(lg)



function train(data, meta)
    # get replay info and replay meta
    # meta.stage,
    # meta.slpmd5,
    # meta.players for p1 and p2
    # # nametag and character
    metarows = open(metapath, "r") do f
        JSON.parse(f)
    end

    replays = map(metarows) do row
        p1 = row["players"][1] 
        # p1.name_tag p2.name_tag for local play
        p2 = row["players"][2]
        (
            path = joinpath(datadir, row["slp_md5"]),
            meta = (
                p1 = (character = p1["character"], nametag = p1["netplay"]["name"]),
                p2 = (character = p2["character"], nametag = p2["netplay"]["name"]),
                stage = row["stage"],
                slp_md5 = row["slp_md5"]
            )
        )
    end

    # @TODO: mirror replays for data augmentation

    
    trainset, testset = Flux.splitobs(replays, at=0.7, shuffle=true)

    meleecharacters = Dict{UInt8, Int}()

    foreach(trainset) do replay
        c = replay.meta.p1.character
        meleecharacters[c] = get(meleecharacters, c, 0) + 1
    end

    namecounts = Dict{AbstractString, Int}()

    foreach(trainset) do replay
        name = normalize_nametag(replay.meta.p1.nametag)
        namecounts[name] = get(namecounts, name, 0) + 1
    end

    sortednames = sort(collect(namecounts), by=last, rev=true)

    namemap = Dict{String, Int}()
    for (i, pair) in enumerate(sortednames[1:min(end, MAXNAMES)])
        name, _ = pair
        namemap[name] = i 
    end

    bake_namegroups!(namemap)

    open(joinpath(exptdir, "name_map.json"), "w") do file
        write(file, JSON.json(namemap))
    end

    # plus one for unknown namecodes
    nametagcodes = maximum(values(namemap))+1
    nametagencoding(name) = UInt8(get(namemap, normalize_nametag(name), nametagcodes))
    device = cpu

    # trainset = Flux.flatten(trainset)
    # testset = Flux.flatten(testset)

    println(col for col in first(onehotslp(trainset)))
    # ytrain, yval = onehotbatch(trainset, )

    
    # for epoch = 1:get_config(lg, "epochs")
    #     for (x, y) in train_loader
    #         x, y = device(x), device(y) # transfer data to device
    #         gs = gradient(ps) do
    #             result = model(x)
    #             l = logitcrossentropy(result, y) # compute gradient
    #         end
    #         Flux.Optimise.update!(opt, ps, gs) # update parameters
    #     end

    #     # Report on train and test
    #     train_loss, train_acc = loss_and_accuracy(train_loader, model, device)
    #     test_loss, test_acc = loss_and_accuracy(test_loader, model, device)

    #     println("Epoch=$epoch")
    #     println("  train_loss = $train_loss, train_accuracy = $train_acc")
    #     println("  test_loss = $test_loss, test_accuracy = $test_acc")
    # end

end


metapath = "/media/jphardee/82615e34-d3fd-42b4-a7a6-06a31aab319d/Sample3/meta.json"
datadir = "/media/jphardee/82615e34-d3fd-42b4-a7a6-06a31aab319d/Sample3/Parsed"
exptdir ="/media/jphardee/82615e34-d3fd-42b4-a7a6-06a31aab319d/Sample3/Experiments" 
train(datadir, metapath)

# @TODO: write tests for with players in NAME_GROUPS
# bake in name groups
# @TODO: setup WanDB connection, its not blocker and slows dev productivity for runs
# save to wandb




 
