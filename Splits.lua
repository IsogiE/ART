local GlobalAddonName, ART = ...

local module = ART:New("Splits", "Split Helper")
local ELib, L = ART.lib, ART.L

local LibDeflate = LibStub:GetLibrary("LibDeflate")

local VART = nil

function module.main:ADDON_LOADED()
    VART = _G.VART

    VART.Splits = VART.Splits or {}
    VART.Splits.profiles = VART.Splits.profiles or {}

    if not VART.Splits.upd4550 then
        VART.Splits.KeepPosInGroup = true
        VART.Splits.upd4550 = true
    end
end

function module.options:Load()
    self:CreateTilte()

    -- Create input for import string
    self.base64Input = ELib:Edit(self):Size(660, 20):Point("TOPLEFT", 10, -25)
	
    -- Create the frame to display the imported characters in  
    self.resultFrame = ELib:ScrollFrame(self):Size(660, 450):Point("TOPLEFT", 10, -120)
    self.resultFrame.content = CreateFrame("Frame", nil, self.resultFrame)
    self.resultFrame.content:SetSize(660, 450)
    self.resultFrame:SetScrollChild(self.resultFrame.content)
    self.resultFrame.text = ELib:Text(self.resultFrame.content, "", 12):Point("TOPLEFT", 5, -5):Point("TOPRIGHT", -5, -5)
    self.resultFrame.text:SetJustifyH("LEFT")
    self.resultFrame.text:SetJustifyV("TOP")
    self.resultFrame.text:SetWordWrap(true)

    -- Make a button to trigger the import 
    self.importButton = ELib:Button(self, "Import"):Size(100, 20):Point("BOTTOMLEFT", self.base64Input, "BOTTOMLEFT", 0, -25)
    self.importButton:OnClick(function()
		local check = self.base64Input:GetText()
		if check == "" then
		self.HandlingText:SetText("Error: Input box cannot be empty.")
		else 
			local base64String = self.base64Input:GetText()
			module:ProcessBase64String(base64String)
			self.base64Input:SetText("") -- Clear the text box
			module:DisplayImportedCharacters()
		end
    end)

    -- Create a dropdown for selecting the split
    self.splitDropdown = ELib:DropDown(self, 660, 10):Point("BOTTOMLEFT", self.importButton, "BOTTOMLEFT", 0, -40):Size(660)
    self.splitDropdown:SetText("Select Split")
    self.splitDropdown:Tooltip("Select a split profile to load")

    -- Some text to show users some errors and feedback
    self.HandlingText = ELib:Text(self, "", 11):Size(660, 20):Point("BOTTOMLEFT", self.resultFrame, "BOTTOMLEFT", 0, -30):Color()

    -- Make a button to delete an imported split 
    self.clearButton = ELib:Button(self, "Delete"):Size(100, 20):Point("RIGHT", self.importButton, "RIGHT", 110, 0)
    self.clearButton:OnClick(function()
        local selectedIndex = self.splitDropdown.selectedIndex
        if selectedIndex then
            module:ClearData(selectedIndex)
        end
    end)

    -- Make a button to rename an imported split 
    self.renameButton = ELib:Button(self, "Rename"):Size(100, 20):Point("RIGHT", self.clearButton, "RIGHT", 110, 0)
    self.renameButton:OnClick(function()
        local selectedIndex = self.splitDropdown.selectedIndex
        if selectedIndex then
            module:ShowRenamePopup(selectedIndex)
        end
    end)

    -- Make a button to check raid characters against the imported split 
    self.checkButton = ELib:Button(self, "Check"):Size(100, 20):Point("RIGHT", self.renameButton, "RIGHT", 110, 0)
    self.checkButton:OnClick(function()
        module:CheckCharacters()
    end)

    module:UpdateDropdown()
end

-- Base64 string handling happens here
function module:DecodeBase64(input)
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    input = string.gsub(input, '[^'..b..'=]', '')
    return (input:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function module:ParseCharacterString(characterString)
    local characters = {}
    for character in string.gmatch(characterString, '([^,]+)') do
        table.insert(characters, strtrim(character))
    end
    return characters
end

-- Getting the characters names 
function module:GetRaidCharacters()
    local raidCharacters = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(raidCharacters, strtrim(name))
        end
    end
    return raidCharacters
end

-- Stripping realm names cause that causes issues 
function module:StripRealmNames(characters)
    local strippedCharacters = {}
    for _, character in ipairs(characters) do
        local baseName = strsplit("-", character)
        table.insert(strippedCharacters, baseName)
    end
    return strippedCharacters
end

-- Check characters based on status versus the import 
function module:CompareAndColorCharacters(raidCharacters, sheetCharacters)
    local inBoth = {}
    local inSheetNotRaid = {}
    local inRaidNotSheet = {}

    local strippedRaidCharacters = self:StripRealmNames(raidCharacters)
    local strippedSheetCharacters = self:StripRealmNames(sheetCharacters)

    local raidSet = {}
    for _, character in ipairs(strippedRaidCharacters) do
        raidSet[strlower(character)] = true
    end

    for _, character in ipairs(strippedSheetCharacters) do
        local lowerCharacter = strlower(character)
        if raidSet[lowerCharacter] then
            table.insert(inBoth, character)
            raidSet[lowerCharacter] = nil
        else
            table.insert(inSheetNotRaid, character)
        end
    end

    for character, _ in pairs(raidSet) do
        table.insert(inRaidNotSheet, character)
    end

    return inBoth, inSheetNotRaid, inRaidNotSheet
end

-- Color code characters based on status versus the import 
function module:PrintColoredCharacters(inBoth, inSheetNotRaid, inRaidNotSheet)
    local result = ""

    for _, character in ipairs(inBoth) do
        result = result .. "|cff00ff00" .. character .. "|r\n" -- Green
    end
    for _, character in ipairs(inSheetNotRaid) do
        result = result .. "|cff808080" .. character .. "|r\n" -- Gray
    end
    for _, character in ipairs(inRaidNotSheet) do
        local capitalizedCharacter = character:sub(1, 1):upper() .. character:sub(2)
        result = result .. "|cffff0000" .. capitalizedCharacter .. "|r\n" -- Red
    end

    return result
end

-- Processing base64
function module:ProcessBase64String(base64String)
    local decodedString = self:DecodeBase64(base64String)
    local characters = self:ParseCharacterString(decodedString)
    table.insert(VART.Splits.profiles, {name = "Import " .. #VART.Splits.profiles + 1, characters = characters})
    self:UpdateDropdown()
end

-- Updates the dropdown
function module:UpdateDropdown()
    local dropdown = self.options.splitDropdown
    dropdown.List = {} 

    for i, profile in ipairs(VART.Splits.profiles) do
        dropdown.List[i] = {
            text = profile.name,
            func = function()
                module:LoadImport(i)
                dropdown.selectedIndex = i
                dropdown:SetText(profile.name) 
                ELib:DropDownClose() 
            end
        }
    end

    ELib:DropDownClose() -- Close any open dropdowns
end

-- Load the imported split from the selected dropdown
function module:LoadImport(index)
    self.sheetCharacters = VART.Splits.profiles[index].characters
    self:DisplayImportedCharacters()
    ELib:DropDownClose() -- Close the dropdown after loading the import
end

-- Display imported characters
function module:DisplayImportedCharacters()
    local result = table.concat(self.sheetCharacters, "\n")
    self.options.resultFrame.text:SetText(result)
    self:UpdateScrollFrame()
end

-- Check characters and display results after the checks are done
function module:CheckCharacters()
    local raidCharacters = self:GetRaidCharacters()

    local inBoth, inSheetNotRaid, inRaidNotSheet = self:CompareAndColorCharacters(raidCharacters, self.sheetCharacters)

    local result = self:PrintColoredCharacters(inBoth, inSheetNotRaid, inRaidNotSheet)

    self.options.resultFrame.text:SetText(result)
    self:UpdateScrollFrame()
end

-- Clearing the selected split after hitting the delete button 
function module:ClearData(index)
    if index and VART.Splits.profiles[index] then
		self.options.HandlingText:SetText("Import: '".. index .. "' deleted.")
        table.remove(VART.Splits.profiles, index)
        self.sheetCharacters = nil
        self.options.resultFrame.text:SetText("")
        self.options.splitDropdown.selectedIndex = nil 
        self.options.splitDropdown:SetText("Select Split") 
        self:UpdateDropdown()
    end
end

-- Renaming a split 
function module:ShowRenamePopup(index)
    local popupFrame = ELib:Popup("Rename Import"):Size(300, 100):Point("CENTER", UIParent, "CENTER", 0, 300)

    popupFrame.title = popupFrame:CreateFontString(nil, "OVERLAY")
    popupFrame.title:SetFontObject("GameFontHighlight")
    popupFrame.title:SetPoint("TOP", popupFrame, "TOP", 0, -10)

    local editBox = ELib:Edit(popupFrame):Size(280, 20):Point("TOP", 0, -30)
    local renameButton = ELib:Button(popupFrame, "Rename"):Size(100, 20):Point("BOTTOM", 0, 10)

    renameButton:OnClick(function()
        local newName = editBox:GetText()
        if newName and newName ~= "" then
            VART.Splits.profiles[index].name = newName
            self:UpdateDropdown()
            self.options.splitDropdown:SetText(newName) 
            popupFrame:Hide()
        end
    end)

    popupFrame:Show()
end

-- Trying to get the scrollbar to work but honestly who knows at this point 
function module:UpdateScrollFrame()
    local textHeight = self.options.resultFrame.text:GetStringHeight()
    self.options.resultFrame.content:SetHeight(textHeight)
    self.options.resultFrame:UpdateScrollChildRect()
end