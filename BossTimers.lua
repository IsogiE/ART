BossTimers = {
    ["Ulgrax"] = {
        {time = {7, 32, 60}, ability = "Raid Aoe"},
        {time = {95, 96}, ability = "Knock"},
        {time = {107, 111, 118, 125, 132}, ability = "Charge"},
        {time = {147}, ability = "Intermission"},
        {time = {153, 162, 171, 180, 186, 195, 204}, ability = "Ramp Rot"},
    },
    ["Bloodbound"] = {
        {time = {11, 41, 71, 101, 139, 169, 199, 229, 267, 297, 327, 357, 395, 425, 455, 485}, ability = "Crimson Rain"},
        {time = {19, 72, 149, 200, 277, 328, 405, 456}, ability = "Gruesome Disgorge"},
        {time = {37, 58, 86, 106, 165, 186, 214, 234, 293, 314, 342, 362, 421, 442, 470, 490}, ability = "Spewing Hemorrhage"},
        {time = {121, 249, 377, 510}, ability = "Run Away"},
        {time = {128, 256, 384, 517}, ability = "Goresplatter"},
    },
    ["Sikran"] = {
        {time = {20, 65}, ability = "Phase Blades"},
        {time = {46, 86}, ability = "Decimate"},
        {time = {95}, ability = "Shattering Sweep"},
    },
    ["Rashanan"] = {
        {time = {3, 33, 77}, ability = "Erosive Spray"},
        {time = {14, 44, 64}, ability = "Spinneret's Strands"},
        {time = {65}, ability = "Infested Spawn"},
        {time = {89}, ability = "Run to new side"},
        {time = {108}, ability = "Web Reave"},
    },
    ["Ovinax"] = {
        {time = {12}, ability = "Volatile Concoction"},
        {time = {18}, ability = "Ingest Black Blood"}, duration = "1",
    },
    ["Kyveza"] = {
		{time = {10, 140, 270,}, ability = "Assassination", spellid = "436870", duration = "8"},
		{time = {35, 65, 165, 195, 295, 325}, ability = "Twilight Massacre", spellid = "438245", duration = "5"},
		{time = {17, 40, 70, 147, 170, 200, 277, 300, 330}, ability = "Queensbane", spellid = "437343", duration = "9"},
        {time = {26, 56, 86, 156, 186, 216, 286, 316, 346}, ability = "Nether Rift", spellid = "437620", duration = "1"},
        {time = {101, 231}, ability = "Starless Night", duration = "24", spellid = "435405", duration = "1"},
        {time = {361, 369, 377}, ability = "Eternal Night", spellid = "464923", duration = "8"},
    },
    ["Silken Court"] = {
        {time = {8, 45, 83, 119}, ability = "Venomous Rain"},
        {time = {15, 69}, ability = "Call of the Swarm"},
        {time = {18, 75}, ability = "Web Bomb"},
        {time = {34, 92}, ability = "Burrowed Eruption"},
        {time = {40, 99}, ability = "Skittering Leap"},
        {time = {41, 99}, ability = "Reckless Charge"},
        {time = {130}, ability = "Void Step"},
        {time = {132}, ability = "Burrow"},
        {time = {133, 143, 153, 163, 173}, ability = "Shatter Existence"},
    },
    ["Queen Ansurek"] = {
        {time = {10, 50, 101}, ability = "Liquefy"},
        {time = {12, 52, 103}, ability = "Feast"},
        {time = {19, 75, 131}, ability = "Reactive Toxin"},
        {time = {20, 67, 114, 139}, ability = "Web Blades"},
        {time = {35, 91, 147}, ability = "Venom Nova"},
        {time = {44, 100, 156}, ability = "Frothy Toxin"},
        {time = {62, 110, 126}, ability = "Silken Tomb"},
    },
}

return BossTimers