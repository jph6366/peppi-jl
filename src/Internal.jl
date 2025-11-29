module JuliaApp
using JlrsCore.Wrap
# import peppi_jlrs_jll: libpeppi_jlrs_path

# @wrapmodule(libpeppi_jlrs_path, :peppi_jlrs_init)
@wrapmodule(joinpath(@__DIR__, "../target/debug/libjulia_app"), :julia_module_tutorial_init_fn)

function __init__()
    @initjlrs
end

end
