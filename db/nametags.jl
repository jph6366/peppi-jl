

const DEFAULT_NAME = "Master Player"
const NAME_UNKNOWN = ""

function getrankedplayer(raw)
    """The convention for personal dumps is Players/NAME/..."""
    if startswith(raw, "Players/")
        parts = split(raw, "/")
        return parts[2]
    end
    return nothing
end

# Some player dumps have a lot of local games with no name or code.
# For such players, we assume any game with that player's main is them.
const PLAYER_MAINS = Set([
    ("Solobattle", melee.Character.JIGGLYPUFF),
    ("Franz", melee.Character.DOC),
])

function playernametag(playermeta, raw=nothing)
    """Extract player name from metadata"""
    netplay = get(playermeta, "netplay", nothing)

    if netplay !== nothing
        # Player dumps will have netplay codes, while the ranked-anonymized dumps
        # have an empty code and the name set to "Platinum/Diamond/Master Player".
        code = get(netplay, "code", nothing)
        if code !== nothing && !isempty(code)
            # Internally, connect codes use the Shift-JIS hash sign.
            return replace(code, "＃" => "#")
        end

        name = get(netplay, "name", nothing)
        if name !== nothing && !isempty(name)
            return name
        end
    end

    if raw !== nothing
        playername = getrankedplayer(raw)
        if playername !== nothing
            char = melee.Character(playermeta["character"])
            if (playername, char) in PLAYER_MAINS
                return playername
            end
        end
    end

    # Offline games (e.g. tournaments)
    nametag = get(playermeta, "name_tag", nothing)
    if nametag !== nothing && !isempty(nametag)
        return nametag
    end

    return NAME_UNKNOWN
end

# TODO: we could scrape code -> ELO from the slippi website?

# TODO: put this in a json?
const NAME_GROUPS = [
    ("Zain", "zain", "DontTestMe", "ZAIN#0", "DTM#664"),  # 13K replays
    ("Cody", "iBDW", "cody", "IBDW#0", "IBDW#734", "JBDW#120"),  # 52K replays
    ("S2J", "Mr Plow", "John Redcorn", "SSJ#998"),  # 3.6K replays
    ("Amsa", "AMSA#0"),  # 26K replays
    ("Phillip AI", "PHAI#591"),
    ("Hax", "XX#02", "HAX#472"),  # 85K replays
    ("Aklo", "AKLO#381", "AKLO#239"),  # 18K replays
    ("Morsecode", "MORS#762"),  # 1.3K replays
    ("YCZ6", "YCZ#667", "YCZ#6", "WH#0"),  # 2.6K replays
    ("BBB", "BBB#960"),  # 3.6K replays
    ("Kodorin", "KOD#0", "8#9"),  # 21K replays
    ("SFAT", "SFAT#9", "OHMA#175", "SFAT#99", "SFAT#783"),  # 10K replays
    ("Solobattle", "666#666", "SOLO#735"),  # 19K replays
    ("Frenzy", "FRNZ#141"),  # 20K replays
    ("Gosu", "WIZZ#310"),  # 18K replays
    # Most Franz games are local with no name; for those we assume any Dr. Mario is Franz.
    ("Franz", "XELA#158", "PLATO#0"),  # 4K replays
    ("Isdsar", "ISDS#767"),  # 7.7K replays
    ("Ginger", "GING#345"),  # 20K replays
    ("DruggedFox", "SAMI#669"),  # 1.3K replays
    ("KJH", "KJH#23"),  # 9K replays
    ("BillyBoPeep", "BILLY#0"),  # 1.5K replays
    ("Spark", "ZAID#0"),
    ("Trif", "TRIF#0", "TRIF#268"),  # 9K replays
    ("Inky", "INKY#398"),  # Sheik Player from Nova Scotia, 3.5K replays
    ("JChu", "JCHU#536"),  # 3.5K replays
    ("Axe", "AXE#845"),  # 800 replays
    ("M2K", "KOTU#737", "CHU#352"),  # 9K replays, mostly Sheik
    ("Siddward", "SIDD#539"),  # Luigi main, 14K replays
    ("Kandayo", "KAND#898"),  # Marth main, 4K replays
    ("Krudo", "CHUG#596", "CODY#007"),  # 9K replays
    ("Uhhei", "SUTT#456"),  # Samus main, 7K replays
    ("FknSilver", "THA#837", "FUCKIN#1"),  # Samus main, 3K replays
    ("Salt", "SALT#747"),  # 3K replays
    ("Zamu", "A#9"),  # 2K replays

    # Don't have permission from these players yet.
    ("Ossify", "OSSIFY#0"),  # 1K replays
    ("Moky", "MOKY#475"),  # 3K replays

    # These players have asked not to be included in AI training.
    ("Mang0", "mang", "mang0", "MANG#0"),
    ("Wizzrobe", "WIZY#0"),
    ("Hungrybox", "HBOX#305", "hbox"),
]

# Build NAME_MAP from NAME_GROUPS
function buildnamemap()
    name_map = Dict{String, String}()
    for group in NAME_GROUPS
        first = group[1]
        for name in group[2:end]
            name_map[name] = first
        end
    end
    return name_map
end

const NAME_MAP = _buildnamemap()

function normalizename(name)
    """Normalize player name using NAME_MAP"""
    return get(NAME_MAP, name, name)
end

const KNOWN_PLAYERS = Set(group[1] for group in NAME_GROUPS)

function isknownplayer(name)
    """Check if player is in known players list"""
    return normalizename(name) in KNOWN_PLAYERS
end

function maxnamecode(name_map)
    """Get max code + 1 from name map"""
    return isempty(name_map) ? 0 : maximum(values(name_map)) + 1
end

function nameencoder(namemap)
    """Return a function that encodes names to integer codes"""
    missing_name_code = maxnamecode(namemap)
    return function encode_name(name)
        return get(namemap, normalizename(name), missing_name_code)
    end
end

const BANNED_NAMES = Set([
    # Have asked not to be included in AI training
    "Mang0", "Wizzrobe", "Hungrybox",

    # Haven't asked yet, so don't train on for now.
    "Ossify", "Moky",

    "Phillip AI",  # This is us!
])

# Verify all banned names are in known players
for name in BANNED_NAMES
    @assert name in KNOWN_PLAYERS "$name not in KNOWN_PLAYERS"
end

function isbannedname(name)
    """Check if player name is banned"""
    return normalizename(name) in BANNED_NAMES
end

# Verify all player mains are in known players
for (name, _) in PLAYER_MAINS
    @assert name in KNOWN_PLAYERS "$name not in KNOWN_PLAYERS"
end
