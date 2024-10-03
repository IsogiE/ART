BossTimers = {
  --  ["Ulgrax"] = {
      --  {time = {7, 32, 60}, ability = "Raid Aoe"},
      --  {time = {95, 96}, ability = "Knock"},
     --   {time = {107, 111, 118, 125, 132}, ability = "Charge"},
       -- {time = {147}, ability = "Intermission"},
      --  {time = {153, 162, 171, 180, 186, 195, 204}, ability = "Ramp Rot"},
   -- },
   -- ["Bloodbound"] = {
       -- {time = {11, 41, 71, 101, 139, 169, 199, 229, 267, 297, 327, 357, 395, 425, 455, 485}, ability = "Crimson Rain"},
       -- {time = {19, 72, 149, 200, 277, 328, 405, 456}, ability = "Gruesome Disgorge"},
      --  {time = {37, 58, 86, 106, 165, 186, 214, 234, 293, 314, 342, 362, 421, 442, 470, 490}, ability = "Spewing Hemorrhage"},
      --  {time = {121, 249, 377, 510}, ability = "Run Away"},
      --  {time = {128, 256, 384, 517}, ability = "Goresplatter"},
  --  },
 --   ["Sikran"] = {
      --  {time = {20, 65}, ability = "Phase Blades"},
      --  {time = {46, 86}, ability = "Decimate"},
      --  {time = {95}, ability = "Shattering Sweep"},
 --   },
 --   ["Rashanan"] = {
     --   {time = {3, 33, 77}, ability = "Erosive Spray"},
     --   {time = {14, 44, 64}, ability = "Spinneret's Strands"},
      --  {time = {65}, ability = "Infested Spawn"},
      --  {time = {89}, ability = "Run to new side"},
     --   {time = {108}, ability = "Web Reave"},
  --  },
  --  ["Ovinax"] = {
    --    {time = {12}, ability = "Volatile Concoction"},
     --   {time = {18}, ability = "Ingest Black Blood"}, duration = "1",
   -- },
    ["Kyveza"] = {
		{time = {26, 56, 86, 156, 186, 216, 286, 316, 346}, ability = "Nether Rift", spellid = "437620", duration = "6"},
		{time = {35, 65, 165, 195, 295, 325}, ability = "Twilight Massacre", spellid = "438245", duration = "5"},
		{time = {10, 140, 270,}, ability = "Assassination", spellid = "436870", duration = "8"},
		{time = {17, 40, 70, 147, 170, 200, 277, 300, 330}, ability = "Queensbane", spellid = "437343", duration = "9"},
		{time = {47, 77, 177, 207, 307, 337}, ability = "Nexus Daggers", spellid = "440197", duration = "6"},
		{time = {8, 42, 72, 138, 172, 202, 268, 301}, ability = "Void Shredders", spellid = "440377", duration = "3"},
        {time = {101, 231}, ability = "Starless Night", spellid = "435405", duration = "24"},
        {time = {361, 369, 377}, ability = "Eternal Night", spellid = "464923", duration = "8"},
    },
    ["Silken Court"] = {
        {time = {15, 35, 62, 82, 122, 195, 215, 240, 255, 275, 300, 381, 430, 450, 471, 491, 520}, ability = "Piercing Strike", spellid = "438218", duration = "1"},
        {time = {8, 28, 62, 82, 188, 218, 248, 278}, ability = "Impaling Eruption", spellid = "440504",  duration = "4"},
		{time = {42,102}, ability = "Skittering Leap", spellid = "450045", duration = "1"},
		{time = {127,216,251,274,303,411,449,478,508}, ability = "Void Step", spellid = "450483", duration =  "1"},
		{time = {26,79,208,269}, ability = "Call of the Swarm", spellid = "438801", duration = "3"},
    },
 --   ["Queen Ansurek"] = {
       -- {time = {10, 50, 101}, ability = "Liquefy"},
       -- {time = {12, 52, 103}, ability = "Feast"},
        --{time = {19, 75, 131}, ability = "Reactive Toxin"},
       -- {time = {20, 67, 114, 139}, ability = "Web Blades"},
        --{time = {35, 91, 147}, ability = "Venom Nova"},
        --{time = {44, 100, 156}, ability = "Frothy Toxin"},
        --{time = {62, 110, 126}, ability = "Silken Tomb"},
    --},
}

BossData = {
    ["Kyveza"] = {
        {enrage = {390}, phaser = "none", event = "none"},
	},
	["Silken Court"] = {
        {enrage = {544}, phaser = "none", event = "none"},
	},
}

return BossTimers, BossData