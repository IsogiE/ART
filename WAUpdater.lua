local AceComm = LibStub("AceComm-3.0")
local AceTimer = LibStub("AceTimer-3.0")

local GlobalAddonName, EART = ...
local module = EART:New("AdvancedWA", "WeakAura Updater")
local ELib, L = EART.lib, EART.L

local weakAurasLoaded = false
local isPromptShown = false
local sendTimeoutFrame

-- Data storage
AdvanceWeakAuraUpdaterDB = AdvanceWeakAuraUpdaterDB or {}

-- Function to show the import screen
local function ShowWeakAuraImportScreen(data, senderName, description)
        if weakAurasLoaded and WeakAuras and WeakAuras.Import then
            WeakAuras.Import(data)
            AdvanceWeakAuraUpdaterDB.pendingWeakAuraData = nil
        end
end

-- Sends the WeakAura data and description through AceComm
local function DistributeWeakAura(weakAuraData, description)
    local messagePrefix = "WEAKAURA_UPDATE:"
    local message = messagePrefix .. weakAuraData .. "|DESC:" .. description  -- Append description to the message
    AceComm:SendCommMessage("ADVANCEWEAKAURA", message, "RAID")
    
    -- Create a timeout in case sending takes too long
    if sendTimeoutFrame then
        sendTimeoutFrame:Cancel()
    end
    sendTimeoutFrame = C_Timer.NewTimer(60, function()
    end)
end

-- Handle incoming WeakAura data and description
local function HandleIncomingWeakAura(prefix, msg, distribution, sender)
    if prefix == "ADVANCEWEAKAURA" then
        -- Split the message into WeakAura data and description
        local messagePrefix = "WEAKAURA_UPDATE:"
        local descriptionPrefix = "|DESC:"
        local data, description = msg:match("^" .. messagePrefix .. "(.*)" .. descriptionPrefix .. "(.*)$")
        
        if data then
            if weakAurasLoaded then
                AdvanceWeakAuraUpdaterDB.pendingWeakAuraData = data
                -- Use the received description
                ShowWeakAuraImportScreen(data, sender, description or "No Description")
            end
        end
    end
end

-- Function to create the UI frame
function module.options:Load()
    self:CreateTilte()

    local editBox = ELib:MultiEdit(self):Size(540, 300):Point("TOP", 0, -40)
    self.editBox = editBox

    -- Error text moved above the buttons
    self.HandlingText = ELib:Text(self, "", 11):Size(650, 200):Point("CENTER", editBox, "BOTTOM", 55, -15):Color()

    -- Send button moved down to avoid overlap with the error text
    local sendButton = ELib:Button(self, "Send"):Size(260, 60):Point("BOTTOMLEFT", editBox, "BOTTOMLEFT", 0, -75)
    sendButton:SetScript("OnClick", function()
        local weakAuraData = self.editBox:GetText()
        local description = ""
        if weakAuraData and weakAuraData ~= "" then
            if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
                DistributeWeakAura(weakAuraData, description)  -- Include description in the transmission
                self.editBox:SetText("")
                self.HandlingText:SetText("WeakAura pushed.")
            else
                self.editBox:SetText("")
                self.HandlingText:SetText("You must be the raid leader or have assist to use this feature.")
            end
        else
            self.editBox:SetText("")
            self.HandlingText:SetText("Please paste a valid WeakAura string.")
        end
    end)

    -- Clear button moved down to match the new layout
    local clearButton = ELib:Button(self, "Clear"):Size(260, 60):Point("RIGHT", sendButton, "RIGHT", 280, 0)
    clearButton:SetScript("OnClick", function()
        AdvanceWeakAuraUpdaterDB.pendingWeakAuraData = nil
        self.editBox:SetText("")
        self.HandlingText:SetText("")
    end)

    lumlDN = ELib:Texture(self,"Interface\\AddOns\\"..GlobalAddonName.."\\media\\lumldn"):Point("BOTTOM",self,"BOTTOM",0,20):Size(520*0.8,200*0.8)


end

-- Register AceComm to handle incoming WeakAura data
AceComm:RegisterComm("ADVANCEWEAKAURA", HandleIncomingWeakAura)

-- Sanity check to see if WA has loaded yet 
local function OnAddonLoaded(event, addon)
    if addon == "WeakAuras" then
        weakAurasLoaded = true
    end
end

local addonLoadedFrame = CreateFrame("Frame")
addonLoadedFrame:RegisterEvent("ADDON_LOADED")
addonLoadedFrame:SetScript("OnEvent", OnAddonLoaded)

-- Double-check WeakAuras loading status
local function CheckWeakAurasLoaded()
    if _G.WeakAuras then
        weakAurasLoaded = true
    end
end

C_Timer.After(5, CheckWeakAurasLoaded)
