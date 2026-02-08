using Test

# Load the Peppi module
include(joinpath(@__DIR__, "..", "src", "Peppi.jl"))
using .Peppi: read_slippi, read_peppi, P1, P2, HUMAN, CPU, RESOLVED

function test_basic_game()
    game_path = joinpath(@__DIR__, "data", "game.slp")
    game = read_slippi(game_path)

    # Test metadata
    @test !isempty(game.metadata)
    @test game.metadata["startAt"] == "2018-06-22T07:52:59Z"
    @test game.metadata["lastFrame"] == 5085
    @test game.metadata["playedOn"] == "dolphin"
    @test haskey(game.metadata, "players")
    @test game.metadata["players"]["0"]["characters"]["18"] == 5209  # Marth
    @test game.metadata["players"]["1"]["characters"]["1"] == 5209   # Fox

    # Test start data
    start = game.start
    
    # Slippi version
    @test start.slippi.version == (1, 0, 0)
    
    # Bitfield
    @test start.bitfield == (50, 1, 134, 76)
    
    # Boolean flags
    @test start.is_raining_bombs == false
    @test start.is_teams == false
    
    # Game settings
    @test start.item_spawn_frequency == -1
    @test start.self_destruct_score == -1
    @test start.stage == 8  # Yoshi's Story
    @test start.timer == 480
    @test start.item_spawn_bitfield == (255, 255, 255, 255, 255)
    @test start.damage_ratio == 1.0
    
    # Random seed
    @test start.random_seed == 3803194226
    
    # Player 1 (Marth)
    p1 = start.players[1]
    @test p1.port == P1
    @test p1.character == 9  # Marth
    @test p1.type == HUMAN
    @test p1.stocks == 4
    @test p1.costume == 3
    @test p1.team === nothing
    @test p1.handicap == 9
    @test p1.bitfield == 192
    @test p1.cpu_level === nothing
    @test p1.ucf.dash_back === nothing
    @test p1.ucf.shield_drop === nothing
    
    # Player 2 (Fox)
    p2 = start.players[2]
    @test p2.port == P2
    @test p2.character == 2  # Fox
    @test p2.type == CPU
    @test p2.stocks == 4
    @test p2.costume == 0
    @test p2.team === nothing
    @test p2.handicap == 9
    @test p2.bitfield == 64
    @test p2.cpu_level == 1
    @test p2.ucf.dash_back === nothing
    @test p2.ucf.shield_drop === nothing

    # Test end data
    stop = game.stop
    @test stop !== nothing
    @test stop.method == RESOLVED
    @test stop.lras_initiator === nothing
    @test stop.players === nothing

    # Test frames
    frames = game.frames
    @test frames !== nothing
    
    # Test frame count via ports
    @test length(frames.ports) == 2
    
    # Access frame 1001 data (via Arrow arrays, 1-indexed)
    p1pre = frames.ports[1].leader.pre
    p2pre = frames.ports[2].leader.pre
    
    # Test position values at frame 1001
    @test isapprox(p1pre.position.x[1001], 56.818748474121094, atol=1e-6)
    @test isapprox(p1pre.position.y[1001], -18.6373291015625, atol=1e-6)
    @test isapprox(p2pre.position.x[1001], 42.195167541503906, atol=1e-6)
    @test isapprox(p2pre.position.y[1001], 9.287015914916992, atol=1e-6)
    
    println("✓ All tests passed for basic_game")
end

@testset "Peppi Julia Integration Tests" begin
    test_basic_game()
end
