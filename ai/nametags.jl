# @TODO write nametag macro
 
const NAME_GROUPS = [
    ("Zain", "zain", "DontTestMe", "ZAIN#0", "DTM#664"),
    ("Cody", "iBDW", "cody", "IBDW#0", "IBDW#734", "JBDW#120"),
    ("S2J", "Mr Plow", "John Redcorn", "SSJ#998"),
    ("Amsa", "AMSA#0"),
    ("Phillip AI", "PHAI#591"),
    ("Hax", "XX#02", "HAX#472"),
    ("Aklo", "AKLO#381", "AKLO#239"),
    ("Morsecode", "MORS#762"),
    ("YCZ6", "YCZ#667", "YCZ#6", "WH#0"),
    ("BBB", "BBB#960"),
    ("Kodorin", "KOD#0", "8#9"),
    ("SFAT", "SFAT#9", "OHMA#175", "SFAT#99", "SFAT#783"),
    ("Solobattle", "666#666", "SOLO#735"),
    ("Frenzy", "FRNZ#141"),
    ("Gosu", "WIZZ#310"),
    ("Franz", "XELA#158", "PLATO#0"),
    ("Isdsar", "ISDS#767"),
    ("Ginger", "GING#345"),
    ("DruggedFox", "SAMI#669"),
    ("KJH", "KJH#23"),
    ("BillyBoPeep", "BILLY#0"),
    ("Spark", "ZAID#0"),
    ("Trif", "TRIF#0", "TRIF#268"),
    ("Inky", "INKY#398"),
    ("JChu", "JCHU#536"),
    ("Axe", "AXE#845"),
    ("M2K", "KOTU#737", "CHU#352"),
    ("Kandayo", "KAND#898"),
    ("Krudo", "CHUG#596", "CODY#007"),
    ("Uhhei", "SUTT#456"),
    ("FknSilver", "THA#837", "FUCKIN#1"),
    ("Salt", "SALT#747"),
    ("Zamu", "A#9"),
    ("RedX", "REDX#668"),
    ("Daniel", "DAN#877"),
    ("Monotheon", "MON#0"),
    ("Magi", "MAGI#732"),
    ("Nez", "NEZ#125"),
    ("Moky", "MOKY#475"),
    ("CookBook", "COOK#671"),
    ("Friend", "FREN#129", "GOOM#5"),
    ("Grab2Win", "G2W#0"),
    ("MOF", "MOF#366"),
    ("Nicki", "NICKI#1"),
    ("Siddward", "SIDD#539"),
    ("JahRidin", "JAH#516"),
    ("RapM", "RAPM#151"),

    # Don't have permission from these players yet.
    ("Ossify", "OSSIFY#0"),
    ("Plup", "PLUB#754"),
    ("Medz", "MEDZ#841"),
    
    # These players have asked not to be included in AI training.
    ("Mang0", "mang", "mang0", "MANG#0"),
    ("Wizzrobe", "WIZY#0"),
    ("Hungrybox", "HBOX#305", "hbox")
]

const NAME_MAP = Dict{String, String}()

for group in NAME_GROUPS
    primary = group[1]
    # Iterate through all aliases (from index 2 to the end)
    for i in eachindex(group)[2:end]
        NAME_MAP[group[i]] = primary
    end
end

function bake_namegroups!(namemap)
    for group in NAME_GROUPS
        if first(group) ∈ keys(namemap)
            for i in eachindex(group)[2:end]
                namemap[group[i]] = first(group)
            end
        end
    end
end


function normalize_nametag(name)
    return get(NAME_MAP, name, name)
end


function maxnamecode(namemap)
    if isnothing(namemap)
        0
    end
    maximum(values(namemap)) + 1
end
