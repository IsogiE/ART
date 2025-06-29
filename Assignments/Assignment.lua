local _, _, _, buildVersion = GetBuildInfo()

AssignmentData = {}

if buildVersion >= 110100 then
    table.insert(AssignmentData, {
        id = "liberationofundermine",
        name = "Liberation of Undermine",
        bosses = {
            { id = "cauldron",       name = "Cauldron of Carnage" },
            { id = "rikreverb",      name = "Rik Reverb" },
            { id = "sprocketmonger", name = "Sprocketmonger" },
            { id = "onearmedbandit", name = "One-Armed Bandit" },
            { id = "mugzee",         name = "Mug'Zee" },
            { id = "gallywix",       name = "Gallywix" },
        }
    })
end

if buildVersion >= 110200 then
    table.insert(AssignmentData, {
        id = "manaforgeomega",
        name = "Manaforge Omega",
        bosses = {
            { id = "plexus",        name = "Plexus Sentinel" },
            { id = "loomithar",     name = "Loom'ithar" },
            { id = "naazindhri",    name = "Naazindhri" },
            { id = "araz",          name = "Forgeweaver" },
            { id = "soulhunters",   name = "Soul Hunters" },
            { id = "fractillus",    name = "Fractillus" },
            { id = "salhadaar",     name = "Nexus-King" },
            { id = "dimensius",     name = "Dimensius" },
        }
    })
end