local addonName, NS = ...
if not ACT then return end

local FeatherTracker = {}
ACT.FeatherTracker = FeatherTracker

ACT.RegisteredMechanics = ACT.RegisteredMechanics or {}
table.insert(ACT.RegisteredMechanics, {
    raid = "March on Quel'Danas",
    id = "feather_tracker",
    name = "Feather Tracker",
    module = FeatherTracker
})

local LEM = LibStub and LibStub("LibEditMode", true)

local ENCOUNTER_ID = 3182
local activeAuraInstance = nil

local iconFrame = CreateFrame("Frame", "ACT_FeatherTracker_Frame", UIParent)
iconFrame:SetSize(64, 64)
iconFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 400)
iconFrame:Hide()

local iconTexture = iconFrame:CreateTexture(nil, "BACKGROUND")
iconTexture:SetAllPoints()

local function GetConfig()
    local db = ACT.db.profile.feather_tracker or {}
    ACT.db.profile.feather_tracker = db
    
    if db.enabled == nil then db.enabled = false end
    if db.iconSize == nil then db.iconSize = 64 end
    if type(db.pos) ~= "table" then db.pos = {} end
    
    return db
end

local function CheckPlayerAuras()
    activeAuraInstance = nil
    iconFrame:Hide()
    
    local playerCastAuraInstanceIDsTest = {}
    local playerCastAuraInstanceIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
    
    if playerCastAuraInstanceIDs then
        for _, auraInstanceID in ipairs(playerCastAuraInstanceIDs) do
            playerCastAuraInstanceIDsTest[auraInstanceID] = true
        end
    end

    local auras = C_UnitAuras.GetUnitAuras("player", "HARMFUL", 10, Enum.UnitAuraSortRule.ExpirationOnly, Enum.UnitAuraSortDirection.Reverse)
    
    if auras then
        for _, aura in ipairs(auras) do
            if not playerCastAuraInstanceIDsTest[aura.auraInstanceID] then
                activeAuraInstance = aura.auraInstanceID
                iconTexture:SetTexture(aura.icon)
                iconFrame:Show()
                return
            end
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "PLAYER_REGEN_ENABLED" then
        FeatherTracker:UpdateState()
        
    elseif event == "ENCOUNTER_START" then
        if arg1 == ENCOUNTER_ID then
            self:RegisterEvent("UNIT_AURA")
            CheckPlayerAuras() 
        end
        
    elseif event == "ENCOUNTER_END" then
        if arg1 == ENCOUNTER_ID then
            self:UnregisterEvent("UNIT_AURA")
            activeAuraInstance = nil
            if not (LEM and LEM:IsInEditMode()) then iconFrame:Hide() end
        end

    elseif event == "UNIT_AURA" and arg1 == "player" then
        local updateInfo = arg2
        if updateInfo.isFullUpdate or updateInfo.addedAuras or updateInfo.removedAuraInstanceIDs then
            CheckPlayerAuras()
        end
    end
end)

function FeatherTracker:UpdateState()
    if InCombatLockdown() then
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local db = GetConfig()
    eventFrame:UnregisterAllEvents()

    if db.enabled then
        eventFrame:RegisterEvent("ENCOUNTER_START")
        eventFrame:RegisterEvent("ENCOUNTER_END")
        
        iconFrame:SetSize(db.iconSize, db.iconSize)

        if LEM and not iconFrame.editModeRegistered then
            LEM:AddFrame(iconFrame, function(f, layout, point, x, y)
                GetConfig().pos[layout] = { point = point, x = x, y = y }
            end, { point = "CENTER", x = 0, y = 400 }, "Feather Tracker")
            
            LEM:AddFrameSettings(iconFrame, {
                { kind = LEM.SettingType.Slider, name = "Icon Size", default = 64, minValue = 16, maxValue = 256, valueStep = 1, 
                  get = function() return GetConfig().iconSize end, 
                  set = function(_, v) GetConfig().iconSize = v; iconFrame:SetSize(v, v) end }
            })
            iconFrame.editModeRegistered = true
        end

        if LEM and LEM.GetActiveLayoutName then
            local pos = db.pos[LEM:GetActiveLayoutName()]
            if pos then
                iconFrame:ClearAllPoints()
                iconFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
            end
        end
    else
        iconFrame:Hide()
        activeAuraInstance = nil
    end
end

function FeatherTracker:Initialize()
    if LEM then
        LEM:RegisterCallback("enter", function()
            if not GetConfig().enabled then return end
            local tex = C_Spell and C_Spell.GetSpellTexture(1241162) or GetSpellTexture(1241162) or 132136
            iconTexture:SetTexture(tex)
            iconFrame:Show()
        end)

        LEM:RegisterCallback("exit", function()
            if not GetConfig().enabled then return end
            if activeAuraInstance then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID("player", activeAuraInstance)
                if aura then 
                    iconTexture:SetTexture(aura.icon) 
                else 
                    iconFrame:Hide() 
                    activeAuraInstance = nil 
                end
            else
                iconFrame:Hide()
            end
        end)
    end

    self:UpdateState()
end

if ACT.db and ACT.db.profile then 
    FeatherTracker:Initialize()
else
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self) 
        FeatherTracker:Initialize()
        self:UnregisterAllEvents() 
    end)
end