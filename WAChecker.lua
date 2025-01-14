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
    if isPromptShown then return end
    isPromptShown = true

    local popupFrame = ELib:Popup(""):Size(300, 220):Point("CENTER", UIParent, "CENTER", 0, 300)
    
    popupFrame.title = popupFrame:CreateFontString(nil, "OVERLAY")
    popupFrame.title:SetFontObject("GameFontHighlight")
    popupFrame.title:SetPoint("TOP", popupFrame, "TOP", 0, -10)
    popupFrame.title:SetText("WeakAura Update")

    popupFrame.message = popupFrame:CreateFontString(nil, "OVERLAY")
    popupFrame.message:SetFontObject("GameFontNormal")
    popupFrame.message:SetPoint("TOP", popupFrame.title, "BOTTOM", 0, -10)
    popupFrame.message:SetWidth(280)
    popupFrame.message:SetJustifyH("LEFT")
    popupFrame.message:SetText("Sender: " .. senderName .. "\nDescription: " .. description)

    -- Dynamically adjust the position of the image based on the description text's height
    local messageHeight = popupFrame.message:GetHeight()
    local imageOffsetY = -messageHeight - 50
    local image = ELib:Texture(popupFrame, "Interface\\AddOns\\ART\\media\\lumldn")
    image:Point("CENTER", popupFrame.message, "CENTER", 0, imageOffsetY):Size(347 * 0.7, 98 * 0.7)

    popupFrame.importButton = ELib:Button(popupFrame, "Import"):Size(120, 40):Point("BOTTOMLEFT", popupFrame, "BOTTOMLEFT", 10, 10)
    popupFrame.importButton:SetScript("OnClick", function()
        if weakAurasLoaded and WeakAuras and WeakAuras.Import then
            WeakAuras.Import(data)
            AdvanceWeakAuraUpdaterDB.pendingWeakAuraData = nil
            popupFrame:Hide()
            isPromptShown = false
        end
    end)

    popupFrame.cancelButton = ELib:Button(popupFrame, "Cancel"):Size(120, 40):Point("BOTTOMRIGHT", popupFrame, "BOTTOMRIGHT", -10, 10)
    popupFrame.cancelButton:SetScript("OnClick", function()
        popupFrame:Hide()
        isPromptShown = false
    end)

    popupFrame:SetScript("OnHide", function()
        isPromptShown = false
    end)

    popupFrame:Show()
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
	
    -- Description box added below the edit box
    local descriptionBox = ELib:Edit(self):Size(540, 30):Point("TOP", self.editBox, "BOTTOM", 0, -10):Text("Enter description here")
    self.DescriptionBox = descriptionBox  -- Ensure DescriptionBox is initialized

    -- Error text moved above the buttons
    self.HandlingText = ELib:Text(self, "", 11):Size(650, 200):Point("CENTER", descriptionBox, "BOTTOM", 55, -15):Color()

    -- Send button moved down to avoid overlap with the error text
    local sendButton = ELib:Button(self, "Send"):Size(120, 40):Point("BOTTOMLEFT", self.DescriptionBox, "BOTTOMLEFT", 0, -75)
    sendButton:SetScript("OnClick", function()
        local weakAuraData = self.editBox:GetText()
        local description = self.DescriptionBox:GetText()
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
    local clearButton = ELib:Button(self, "Clear"):Size(120, 40):Point("RIGHT", sendButton, "RIGHT", 140, 0)
    clearButton:SetScript("OnClick", function()
        AdvanceWeakAuraUpdaterDB.pendingWeakAuraData = nil
        self.editBox:SetText("")
        self.DescriptionBox:SetText("")
        self.HandlingText:SetText("")
    end)
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
