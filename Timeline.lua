local GlobalAddonName, ART = ...

-- Ensure BossTimers is available
if not BossTimers then
    print("Error: BossTimers.lua was not loaded correctly.")
    return
end

-- Create a new module for Boss Timeline
local module = ART:New("BossTimeline", "Boss Timeline")
local ELib = ART.lib

-- Initialize variables for storing custom timelines
local VART = nil
local selectedBoss = nil  -- Local variable to store the selected boss

function module.main:ADDON_LOADED()
    VART = _G.VART
    VART.BossTimeline = VART.BossTimeline or {}
end

SlashCmdList["ARTSlash"] = function (arg)
	local argL = strlower(arg)
	if argL == "open" then
		module:CreateBossTimelineWindow()
	end
end

SLASH_ARTSlash2 = "/tl"

-- Load and customize the UI when the options panel is loaded
function module.options:Load()
    self:CreateTilte("Boss Timeline")

    -- Use ELib:DropDown to create the dropdown for selecting bosses
    self.bossDropdown = ELib:DropDown(self, 200, 10):Point(10, -25):Size(216)
    self.bossDropdown:SetText("Select Boss")
    
    -- Add options to the dropdown dynamically from BossTimers
    if not BossTimers or next(BossTimers) == nil then
        print("Error: No boss data available in BossTimers.")
        return
    end

    self.bossDropdown.List = {}
    for bossName, _ in pairs(BossTimers) do
        table.insert(self.bossDropdown.List, {
            text = bossName, 
            func = function() 
                selectedBoss = bossName
                self.bossDropdown:SetText(bossName) 
            end
        })
    end

    -- Create a button to show the boss timeline in a new window
    local showTimelineButton = ELib:Button(self, "Show Timeline"):Size(100, 30):Point("TOPLEFT", 10, -60)
    showTimelineButton:SetScript("OnClick", function()
        if selectedBoss then  -- Ensure a boss is selected
            module:CreateBossTimelineWindow(selectedBoss)
        else
            print("Please select a boss from the dropdown.")
        end
    end)
end

-- Create a separate window for the timeline
function module:CreateBossTimelineWindow(boss)
    if not BossTimers[boss] then
        print("Error: No timeline data available for boss: " .. boss)
        return
    end

    local timeline = BossTimers[boss]

    -- Find the maximum time from all the events
    local timeMax = 0
    for _, event in ipairs(timeline) do
        for _, time in ipairs(event.time) do
            if time > timeMax then
                timeMax = time
            end
        end
    end

    -- Dynamically scale the window based on the maximum time
    local baseGraphWidth = 850  -- Base width for the graph (excluding buffer for ability names)
    local bufferWidth = 120  -- Space reserved for ability names
    local rowHeight = 40     -- Height for each ability row
    local windowWidth = baseGraphWidth + bufferWidth + 50  -- Add buffer and padding
    local windowHeight = (#timeline * rowHeight) + 100  -- Dynamically scale height based on number of rows

    -- Create a new frame for the pop-out window
	local window = ELib:Popup(""):Size(windowWidth, windowHeight):Point("CENTER", UIParent, "CENTER", 0, 0)
	
	window.title = window:CreateFontString(nil, "OVERLAY")
    window.title:SetFontObject("GameFontHighlight")
    window.title:SetPoint("TOP", window, "TOP", 0, -10)
    window.title:SetText(boss)

    window.message = window:CreateFontString(nil, "OVERLAY")
    window.message:SetFontObject("GameFontNormal")
    window.message:SetPoint("TOP", window.title, "BOTTOM", 0, -10)
    window.message:SetWidth(windowWidth - 2)
    window.message:SetJustifyH("LEFT")
	
	window:Show()

    -- Calculate the dynamic content width based on the maximum time
    local graphWidth = max(baseGraphWidth, (timeMax * 10))  -- Scale graph width based on timeMax
    local contentWidth = graphWidth + bufferWidth  -- Total content width

    -- Create a scrollable content frame for long timelines (horizontal scrolling only)
    local scrollFrame = CreateFrame("ScrollFrame", nil, window)
    scrollFrame:SetPoint("TOPLEFT", 140, -40)
    scrollFrame:SetSize(baseGraphWidth, windowHeight - 100)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(contentWidth, (#timeline * rowHeight))  -- Adjust content width dynamically
    scrollFrame:SetScrollChild(content)

    -- Horizontal scrollbar setup
    horizontalScrollbar = CreateFrame("Slider", "CustomHorizontalScrollBar", window)
    horizontalScrollbar:SetOrientation('HORIZONTAL')  -- Make it horizontal
    horizontalScrollbar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMLEFT", 0, -30)
    horizontalScrollbar:SetSize(baseGraphWidth, 20)  -- Horizontal size

    -- Set range for horizontal scrolling and min/max values based on content width
    horizontalScrollbar:SetMinMaxValues(0, contentWidth - baseGraphWidth)
    horizontalScrollbar:SetValue(0)

    -- Manually create thumb (without vertical arrows)
    horizontalScrollbar.thumb = horizontalScrollbar:CreateTexture(nil, "BACKGROUND")
    horizontalScrollbar.thumb:SetColorTexture(1, 0.82, 0, 0.8)
    horizontalScrollbar:SetThumbTexture(horizontalScrollbar.thumb)
    local thumbSize = (baseGraphWidth / contentWidth) * baseGraphWidth  -- Calculate thumb size based on content
    horizontalScrollbar.thumb:SetSize(thumbSize, 20)  -- Dynamic thumb size

    horizontalScrollbar:SetScript("OnValueChanged", function(self, value)
        scrollFrame:SetHorizontalScroll(value)
    end)

    -- Disable vertical scrolling completely
    scrollFrame:EnableMouseWheel(false)

    -- Limit horizontal scrolling to valid bounds
    scrollFrame:HookScript("OnMouseWheel", function(self, delta)
        local currentScroll = self:GetHorizontalScroll()
        local newScroll = currentScroll - delta * 30  -- Scroll amount
        newScroll = max(0, min(newScroll, contentWidth - baseGraphWidth))  -- Bound the scroll position
        scrollFrame:SetHorizontalScroll(newScroll)
        horizontalScrollbar:SetValue(newScroll)
    end)

    -- **Dynamic scaling factor for time markers** (this is where we fix the issue)
    local effectiveGraphWidth = graphWidth - bufferWidth -- Only the actual timeline area (excluding buffer)
    local scaleFactor = effectiveGraphWidth / timeMax  -- Scale based only on the graph area
	
	local tcount = 1
	
    -- Add time interval lines at 30-second intervals
    for t = 60, timeMax, 60 do
        local intervalLine = content:CreateTexture(nil, "BACKGROUND")
        local intervalPosition = (t / timeMax) * effectiveGraphWidth + bufferWidth  -- Adjusted for buffer width
        intervalLine:SetSize(2, #timeline * rowHeight)
        intervalLine:SetPoint("TOPLEFT", intervalPosition, 0)
        intervalLine:SetColorTexture(0.6, 0.6, 0.6, 1)  -- Light gray for interval lines
    end
	
	--Create Export Button
	local showExportMRTButton = ELib:Button(scrollFrame, "Export"):Size(100, 20):Point("LEFT", horizontalScrollbar, "LEFT", -120, 0)
	
	--Start custom colors
	local count = 0
	local cR = 0
	local cG = 0
	local cB = 0
	
    for i, event in ipairs(timeline) do
	
		if count == 0 then
			cR = 0.8
			cG = 0.3
			cB = 0.3
		elseif count == 1 then
			cR = 0
			cG = 0.8
			cB = 1
		elseif count == 2 then
			cR = 0.2
			cG = 0.6
			cB = 0.4
		end
	
        -- Create a row label container (Frame) for each ability
		local rowLabelContainer = CreateFrame("Frame", nil, scrollFrame)
		rowLabelContainer:SetSize(bufferWidth, rowHeight)
		rowLabelContainer:SetPoint("TOPLEFT", -bufferWidth, -(i - 1) * rowHeight)  -- Ensure proper vertical alignment based on index
		
		 -- Create a row container (Frame) for each ability
        local rowContainer = CreateFrame("Frame", nil, content)
        rowContainer:SetSize(graphWidth, rowHeight)
        rowContainer:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)  -- Ensure proper vertical alignment based on index
		
		spell = C_Spell.GetSpellInfo(event.spellid)

        -- Add ability name label inside the row container
        local abilityText = rowLabelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        abilityText:SetPoint("LEFT", 10, 0)  -- Align ability name within the row
        abilityText:SetText(event.ability)
        abilityText:SetTextColor(1, 1, 0)  -- Yellow color for ability names

        -- Create a background for the ability row
        local abilityRowBackground = rowContainer:CreateTexture(nil, "BACKGROUND")
        abilityRowBackground:SetSize(graphWidth + bufferWidth, rowHeight)
        abilityRowBackground:SetPoint("LEFT", 0)
        abilityRowBackground:SetColorTexture(0.2, 0.2, 0.2, 0.8)

        -- Create a horizontal row divider inside the row container
        local rowDivider = rowContainer:CreateTexture(nil, "BACKGROUND")
        rowDivider:SetSize(graphWidth + bufferWidth, 2)
        rowDivider:SetPoint("BOTTOMLEFT", 0, 0)  -- Place divider at the bottom of the row
        rowDivider:SetColorTexture(0.5, 0.5, 0.5, 0.8)  -- Gray row divider

        -- Correctly position event markers in their respective rows (fix for markers falling out)
        for _, time in ipairs(event.time) do
			
			local duration = event.duration
			local minutes = floor(mod(time, 3600) / 60)
			local seconds = floor(mod(time, 60))
            local eventMarker = rowContainer:CreateTexture(nil, "OVERLAY")
			local eventMask = rowContainer:CreateTexture(nil, "OVERLAY")
            local eventPosition = (time / timeMax) * effectiveGraphWidth + bufferWidth  -- Adjusted for buffer width
            eventMarker:SetSize(10 * event.duration, rowHeight - 3)
            eventMarker:SetPoint("LEFT", eventPosition, 1, 0)  -- Now based on effectiveGraphWidth
            eventMarker:SetColorTexture(cR, cG, cB, 1)  -- Red color for event markers
			

            -- Optional: Add a tooltip to show exact time
            eventMarker:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(minutes .. ":" .. seconds .. "-" .. minutes .. ":" .. seconds + duration, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            eventMarker:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
		
		if count == 2 then
		count = 0 
		else 
			count = count + 1
		end
    end
end
