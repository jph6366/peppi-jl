using Arrow

# Parse frames from Arrow struct array (column-oriented)
function frames_from_sa(arrow_frames)
    
    port_arrays = getproperty.(arrow_frames, :ports)
    # TODO Is Follower	bool	Value is 1 for Nana and 0 otherwise... P3 ?
    portenums = length(first(port_arrays)) != 2 ? (:P1, :P2, :P3, :P4) : (:P1, :P2)
    ports = map(portenums) do p
        port = getproperty.(port_arrays, p)
        # TODO write logic for `is_follower`
        # Value is 1 for Nana and 0 otherwise
        # follower = nothing
        leader = getproperty.(port, :leader)
        (pre = getproperty.(leader, :pre), post = getproperty.(leader, :post))
    end
    
    (id = getproperty.(arrow_frames, :id), ports = ports)
end
