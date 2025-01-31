local GlobalAddonName, MRT = ...
local ELib, L = MRT.lib, MRT.L

local module = MRT:New("MACROS", "MACROS")

function module.options:Load()
    self:CreateTilte()

    local PAGE_HEIGHT, PAGE_WIDTH = 600, 680
    local LINE_HEIGHT, LINE_NAME_WIDTH = 16, 160
	
    mainFrame = ELib:ScrollFrame(self):Size(PAGE_WIDTH,PAGE_HEIGHT):Point("TOP", 0,-20)
    local scrollbar = mainFrame.ScrollBar
    ELib:Border(mainFrame,0)
    scrollbar:Hide()

    ELib:DecorationLine(self):Point("BOTTOM", mainFrame, "TOP", 0, 0):Point("LEFT", self):Point("RIGHT", self):Size(0, 1)
	
	-- Create ouput for Focus Macro
    FocusMacroOutput = ELib:MultiEdit(mainFrame):Size(300, 60):Point(0, -85)
	FocusMacroScroll = FocusMacroOutput.ScrollBar
	FocusMacroScroll:Hide()
	
	-- Create output for WA Macro
    WorldMarkMacroOutput = ELib:MultiEdit(mainFrame):Size(300, 60):Point(350, -85)
	WorldMarkMacroScroll = WorldMarkMacroOutput.ScrollBar
	WorldMarkMacroScroll:Hide()
	
	self.buttonicons = {}
	for i=1,8 do
		local button = CreateFrame("Button", nil, mainFrame)
		self.buttonicons[i] = button
		button:SetSize(32,32)
		button:SetPoint("TOPLEFT", 10+(i-1)*34,-40)
		button.back = button:CreateTexture(nil, "BACKGROUND")
		button.back:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..i)
		button.back:SetAllPoints()
		button:RegisterForClicks("LeftButtonDown")
		local macroText = "/focus [@target] \n/run if not GetRaidTargetIndex(\"focus\") then SetRaidTarget(\"focus\"," .. i .. ") end"
		button:SetScript("OnClick", function()
        FocusMacroOutput:SetText(macroText)
		end)
	end
	
	self.worldbuttonicons = {}
	for i=1,8 do
		local button = CreateFrame("Button", nil, mainFrame)
		self.worldbuttonicons[i] = button
		button:SetSize(32,32)
		button:SetPoint("TOPLEFT", 360+(i-1)*34,-40)
		button.back = button:CreateTexture(nil, "BACKGROUND")
		button.back:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..i)
		button.back:SetAllPoints()
		button:RegisterForClicks("LeftButtonDown")
		
		if i == 1 then -- Star
			j = 5
		elseif i == 2 then -- Circle
			j = 6
		elseif i == 3 then -- Diamond
			j = 3
		elseif i == 4 then -- Triangle
			j = 2
		elseif i == 5 then -- Moon
			j = 7
		elseif i == 6 then -- Sqaure
			j = 1
		elseif i == 7 then -- Cross
			j = 4
		elseif i == 8 then -- Skull
			j = 8
		end
		
		local macroText = "/cwm " .. j .. "\n/wm [@cursor] " .. j
		button:SetScript("OnClick", function()
        WorldMarkMacroOutput:SetText(macroText)
		end)
	end
	
	FocusMacroText = ELib:Text(FocusMacroOutput,"Set Focus + Target Marker Macro",12):Size(300,15):Point(40, 70)
	
	WorldMarkMacroText = ELib:Text(WorldMarkMacroOutput,"Place + Clear World Marker Macro @cursor",12):Size(300,15):Point(20, 70)
	
	-- Create ouput for WA Macro
    WAMacroOutput = ELib:MultiEdit(mainFrame):Size(300, 90):Point(0, -200)
	WAMacroScroll = WAMacroOutput.ScrollBar
	WAMacroScroll:Hide()
	
	-- Create WA Macro Text
	WAMacroText = ELib:Text(WAMacroOutput,"Liquid & NS WA Macro",12):Size(300,15):Point(75, 25)
	
	local WAmacroText = "/ping [@player] Warning\n/run WeakAuras.ScanEvents(\"\LIQUID_PRIVATE_AURA_MACRO\"\, true)\n/run WeakAuras.ScanEvents(\"\NS_PA_MACRO\"\, true)"
	
	WAMacroOutput:SetText(WAmacroText)
	
	-- Create ouput for Reloe Macro
    ReloeMacroOutput = ELib:MultiEdit(mainFrame):Size(300, 90):Point(350, -200)
	ReloeMacroScroll = ReloeMacroOutput.ScrollBar
	ReloeMacroScroll:Hide()
	
	-- Create Reloe Macro Text
	ReloeMacroText = ELib:Text(ReloeMacroOutput,"Reloe External Macro",12):Size(300,15):Point(75, 25)
	
	local ReloemacroText = "/ping [@player] Warning\n/run WeakAuras.ScanEvents(\"\NS_EXTERNAL\"\, true)"
	
	ReloeMacroOutput:SetText(ReloemacroText)
	
end