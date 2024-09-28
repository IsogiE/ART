local AceComm = LibStub("AceComm-3.0")
local AceTimer = LibStub("AceTimer-3.0")

local GlobalAddonName, EART = ...
local module = EART:New("AdvancedWA", "WeakAura Updater")
local ELib, L = EART.lib, EART.L

local weakAurasLoaded = false
local isPromptShown = false
local sendTimeoutFrame

-- data storage
AdvanceWeakAuraUpdaterDB = AdvanceWeakAuraUpdaterDB or {}

local function ShowWeakAuraImportScreen(data, senderName)
    if isPromptShown then return end
    isPromptShown = true

    local popupFrame = ELib:Popup(""):Size(300, 220):Point("CENTER", UIParent, "CENTER", 0, 300)
    -- frame:SetFrameStrata("DIALOG")

    popupFrame.title = popupFrame:CreateFontString(nil, "OVERLAY")
    popupFrame.title:SetFontObject("GameFontHighlight")
    popupFrame.title:SetPoint("TOP", popupFrame, "TOP", 0, -10)
    popupFrame.title:SetText("WeakAura Update")

    popupFrame.message = popupFrame:CreateFontString(nil, "OVERLAY")
    popupFrame.message:SetFontObject("GameFontNormal")
    popupFrame.message:SetPoint("TOP", popupFrame.title, "BOTTOM", 0, -10)
    popupFrame.message:SetWidth(280)
    popupFrame.message:SetJustifyH("LEFT")
    popupFrame.message:SetText("Sender: " .. senderName .. "\nAura: ")
	
	image = ELib:Texture(popupFrame,"Interface\\AddOns\\ART\\media\\lumldn"):Point("CENTER",popupFrame.message,"CENTER",0,-60):Size(347*0.7,98*0.7)

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

    -- Handle the OnHide event to reset the isPromptShown flag
    popupFrame:SetScript("OnHide", function()
        isPromptShown = false
    end)

    popupFrame:Show()
end

-- Sends the WA data thru acecomm
local function DistributeWeakAura(weakAuraData)
    local messagePrefix = "WEAKAURA_UPDATE:"
    local message = messagePrefix .. weakAuraData
    AceComm:SendCommMessage("ADVANCEWEAKAURA", message, "RAID")
    
    -- Create a timeout in case sending takes too long
    if sendTimeoutFrame then
        sendTimeoutFrame:Cancel()
    end
    sendTimeoutFrame = C_Timer.NewTimer(60, function()
        -- In case it bricks, inform whoever sent it 
        print("Sending WeakAura data timed out.")
    end)
end

-- Reassemble incoming WA data
local function HandleIncomingWeakAura(prefix, msg, distribution, sender)
    if prefix == "ADVANCEWEAKAURA" then
        -- Remove the prefix from the message to make sure WA knows whatever the fuck its importing 
        local messagePrefix = "WEAKAURA_UPDATE:"
        local data = msg:match("^" .. messagePrefix .. "(.*)")
        
        -- If the data is assmebled correctly 
        if data then
            if weakAurasLoaded then
                AdvanceWeakAuraUpdaterDB.pendingWeakAuraData = data
                ShowWeakAuraImportScreen(data, sender)
            end
        end
    end
end

-- Function to create the UI frame
function module.options:Load()
    self:CreateTilte()

    local editBox = ELib:MultiEdit(self):Size(540, 300):Point("TOP", 0, -40)
    self.editBox = editBox
	
	self.HandlingText = ELib:Text(self,"",11):Size(650,200):Point("CENTER",editBox, "BOTTOM", 55, -15):Color()

    local sendButton = ELib:Button(self, "Send"):Size(120, 40):Point("BOTTOMLEFT", self.editBox, "BOTTOMLEFT", 0, -55)
    sendButton:SetScript("OnClick", function()
        local weakAuraData = self.editBox:GetText()
        if weakAuraData and weakAuraData ~= "" then
            if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
                DistributeWeakAura(weakAuraData)
				self.editBox:SetText("")
				self.HandlingText:SetText("Weakaura pushed.")
            else
                self.editBox:SetText("")
				self.HandlingText:SetText("You must be the raid leader or have assist to use this feature.")
            end
        else
            self.editBox:SetText("")
			self.HandlingText:SetText("Please paste a valid WeakAura string.")
        end
    end)

    local clearButton = ELib:Button(self, "Clear"):Size(120, 40):Point("RIGHT", sendButton, "RIGHT", 140, 0)
    clearButton:SetScript("OnClick", function()
        AdvanceWeakAuraUpdaterDB.pendingWeakAuraData = nil
        self.editBox:SetText("")
		self.HandlingText:SetText("")
    end)
end

-- Register AceComm to use its shit
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

-- Double safety check for WA having loaded cause god this addon takes forever
local function CheckWeakAurasLoaded()
    if _G.WeakAuras then
        weakAurasLoaded = true
    end
end

C_Timer.After(5, CheckWeakAurasLoaded)
