
using Arrow
using DataFrames

function onehotslp(replays)
    map(replays) do replay
        Arrow.Table(replay.path)
    end
end
