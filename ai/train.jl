
using Flux
using Wandb
using Logging
using Dates

experimentlabel = "slippi-ai-$(now())"
lg = WandbLogger(project = "slippi-ai-jl", name = experimentlabel,
                 config = Dict("learning_rate" => 3e-4, "batchsize" => 256,
                               "epochs" => 100, "dataset" => "PeppiDB", "use_cuda" => true))
global_logger(lg)
