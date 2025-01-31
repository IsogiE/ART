local GlobalAddonName, ExRT = ...

local module = ExRT:New("AddonChecker", ExRT.L.AddonChecker)
local ELib, L = ExRT.lib, ExRT.L
local AceComm = LibStub:GetLibrary("AceComm-3.0")

module.db.responces = {}
module.db.lastReq = {}
module.db.lastCheck = {}
module.db.lastCheckName = {}

module.db.addonsToCheck = {
	"AuraUpdater",
	"BigWigs",
	"ElvUI",
	"LibOpenRaid",
	"NorthernSkyMedia",
	"RCLootCouncil",
    "SharedMedia_Causese",
	"TimelineReminders",
	"WeakAuras"
}

function module:OnEnable()
    AceComm:RegisterComm("ART_AddonChecker", function(prefix, message, distribution, sender)
        if sender == UnitName("player") then return end
        
        if message == "CHECK_REQUEST" then
            local addonInfoTable = {}
    
            for _, addonName in ipairs(self.db.addonsToCheck) do
                local name, _, _, loadable = C_AddOns.GetAddOnInfo(addonName)
                if not name or not C_AddOns.IsAddOnLoaded(addonName) then
                else
                    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "-"
                    table.insert(addonInfoTable, addonName .. "=" .. version)
                end
            end
            
        local responseStr = #addonInfoTable > 0 and table.concat(addonInfoTable, ",") or "NONE"
            if responseStr == "" then responseStr = "NONE" end
            AceComm:SendCommMessage("ART_AddonChecker", "STATUS:"..responseStr, "WHISPER", sender)
            elseif message:find("^STATUS:") then
            local statusStr = message:sub(8)
            local response = {}
        
            if statusStr ~= "NONE" then
                for chunk in string.gmatch(statusStr, "[^,]+") do
                    local addonName, version = strsplit("=", chunk)
                    if addonName and version then
                        response[addonName] = {
                            loaded = true,
                            version = version,
                        }
                    end
                end
            end
        
            for _, addonName in ipairs(self.db.addonsToCheck) do
                if not response[addonName] then
                    response[addonName] = {
                        loaded = false,
                        version = nil,
                    }
                end
            end
        
            local shortName = Ambiguate(sender, "short")
            self.db.responces[shortName] = response
        
            if self.options:IsVisible() and self.options.UpdatePage then
                self.options.UpdatePage()
            end
        end
    end)
end

function module:SendReq()
    local myResponse = self.db.responces[UnitName("player")]
    wipe(self.db.responces)
    
    local missingAddons = {}
    for _, addonName in ipairs(self.db.addonsToCheck) do
        local name, title, notes, loadable = C_AddOns.GetAddOnInfo(addonName)
        if not name or not C_AddOns.IsAddOnLoaded(addonName) then
            missingAddons[addonName] = true
        end
    end

    local response = {}
    for _, addonName in ipairs(self.db.addonsToCheck) do
        local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
        if not version or version == "" then
            version = "-"
        end
        response[addonName] = {
            loaded  = not missingAddons[addonName],
            version = version,
        }
    end
    self.db.responces[UnitName("player")] = response

    if IsInRaid() or IsInGroup() then
        AceComm:SendCommMessage("ART_AddonChecker", "CHECK_REQUEST", "RAID")
    end

    if self.options:IsVisible() and self.options.UpdatePage then
        self.options.UpdatePage()
    end
end

function module:CheckResponse()
    local response = {}
    for _, addonName in ipairs(module.db.addonsToCheck) do
        local loadedOrLoading, loaded = C_AddOns.IsAddOnLoaded(addonName)
        local version = C_AddOns.GetAddOnMetadata(addonName, "Version") 
        response[addonName] = {
            loaded = (loadedOrLoading or loaded),
            version = version,  
        }
    end
    return response
end

function module.options:Load()
    self:CreateTilte()
    
    local UpdatePage, UpdatePageView

    local errorNoAddons = ELib:Text(self, "No addons found"):Point("TOP",0,-30)
    errorNoAddons:Hide()
    
    local PAGE_HEIGHT, PAGE_WIDTH = 520, 680
    local LINE_HEIGHT, LINE_NAME_WIDTH = 16, 160
    local VERTICALNAME_WIDTH = 20
    local VERTICALNAME_COUNT = 24
    
    local mainScroll = ELib:ScrollFrame(self):Size(PAGE_WIDTH,PAGE_HEIGHT):Point("TOP",0,-80):Height(700)
    ELib:Border(mainScroll,0)

    ELib:DecorationLine(self):Point("BOTTOM",mainScroll,"TOP",0,0):Point("LEFT",self):Point("RIGHT",self):Size(0,1)
    ELib:DecorationLine(self):Point("TOP",mainScroll,"BOTTOM",0,0):Point("LEFT",self):Point("RIGHT",self):Size(0,1)
    
    local prevTopLine = 0
    local prevPlayerCol = 0
    
    mainScroll.ScrollBar:ClickRange(LINE_HEIGHT)
    mainScroll.ScrollBar.slider:SetScript("OnValueChanged", function (self,value)
        local parent = self:GetParent():GetParent()
        parent:SetVerticalScroll(value % LINE_HEIGHT) 
        self:UpdateButtons()
        local currTopLine = floor(value / LINE_HEIGHT)
        if currTopLine ~= prevTopLine then
            prevTopLine = currTopLine
            UpdatePageView()
        end
    end)
    
    local raidSlider = ELib:Slider(self,""):Point("TOPLEFT",mainScroll,"BOTTOMLEFT",LINE_NAME_WIDTH + 15,-3):Range(0,25):Size(VERTICALNAME_WIDTH*VERTICALNAME_COUNT):SetTo(0):OnChange(function(self,value)
        local currPlayerCol = floor(value)
        if currPlayerCol ~= prevPlayerCol then
            prevPlayerCol = currPlayerCol
            UpdatePageView()
        end
    end)
    raidSlider.Low:Hide()
    raidSlider.High:Hide()
    raidSlider.text:Hide()
    raidSlider.Low.Show = raidSlider.Low.Hide
    raidSlider.High.Show = raidSlider.High.Hide
    
    local function SetIcon(self,type)
        if self.texturechanged then
            self:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
            self.texturechanged = nil
        end
        if not type or type == 0 then
            self:SetAlpha(0)
        elseif type == 1 then
            self:SetTexCoord(0.5,0.5625,0.5,0.625)
            self:SetVertexColor(.8,0,0,1) 
        elseif type == 2 then
            self:SetTexCoord(0.5625,0.625,0.5,0.625)
            self:SetVertexColor(0,.8,0,1)  
        end     
    end
    
    self.helpicons = {}
    for i=0,1 do
        local icon = self:CreateTexture(nil,"ARTWORK")
        icon:SetPoint("TOPLEFT",5,-10-i*12)
        icon:SetSize(14,14)
        icon:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
        SetIcon(icon,i+1)
        local t = ELib:Text(self,"",10):Point("LEFT",icon,"RIGHT",2,0):Size(0,16):Color(1,1,1)
        if i==0 then
            t:SetText("Missing Addon")
        elseif i==1 then
            t:SetText("Addon Present")
        end
        self.helpicons[i+1] = {icon,t}
    end

    local lines = {}
    self.lines = lines
    for i=1,floor(PAGE_HEIGHT / LINE_HEIGHT) + 2 do
        local line = CreateFrame("Frame",nil,mainScroll.C)
        lines[i] = line
        line:SetPoint("TOPLEFT",0,-(i-1)*LINE_HEIGHT)
        line:SetPoint("TOPRIGHT",0,-(i-1)*LINE_HEIGHT)
        line:SetSize(0,LINE_HEIGHT)
        
        line.name = ELib:Text(line,"",10):Point("LEFT",2,0):Size(LINE_NAME_WIDTH-LINE_HEIGHT/2,LINE_HEIGHT):Color(1,1,1):Tooltip("ANCHOR_LEFT",true)
        
        line.icons = {}
        local iconSize = min(VERTICALNAME_WIDTH,LINE_HEIGHT)
        for j=1,VERTICALNAME_COUNT do
            local icon = line:CreateTexture(nil,"ARTWORK")
            line.icons[j] = icon
            icon:SetPoint("CENTER",line,"LEFT",LINE_NAME_WIDTH + 15 + VERTICALNAME_WIDTH*(j-1) + VERTICALNAME_WIDTH / 2,0)
            icon:SetSize(iconSize,iconSize)
            icon:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
            SetIcon(icon,0)
        end
        
        line.t=line:CreateTexture(nil,"BACKGROUND")
        line.t:SetAllPoints()
        line.t:SetColorTexture(1,1,1,.05)
    end
    
    local function RaidNames_OnEnter(self)
        local t = self.t:GetText()
        if t ~= "" then
            ELib.Tooltip.Show(self,"ANCHOR_LEFT",t)
        end
    end
    
    local raidNames = CreateFrame("Frame",nil,self)
    for i=1,VERTICALNAME_COUNT do
        raidNames[i] = ELib:Text(raidNames,"RaidName"..i,10):Point("BOTTOMLEFT",mainScroll,"TOPLEFT",LINE_NAME_WIDTH + 15 + VERTICALNAME_WIDTH*(i-1),0):Color(1,1,1)

        local f = CreateFrame("Frame",nil,self)
        f:SetPoint("BOTTOMLEFT",mainScroll,"TOPLEFT",LINE_NAME_WIDTH + 15 + VERTICALNAME_WIDTH*(i-1),0)
        f:SetSize(VERTICALNAME_WIDTH,80)
        f:SetScript("OnEnter",RaidNames_OnEnter)
        f:SetScript("OnLeave",ELib.Tooltip.Hide)
        f.t = raidNames[i]
        
        local t=mainScroll:CreateTexture(nil,"BACKGROUND")
        raidNames[i].t = t
        t:SetPoint("TOPLEFT",LINE_NAME_WIDTH + 15 + VERTICALNAME_WIDTH*(i-1),0)
        t:SetSize(VERTICALNAME_WIDTH,PAGE_HEIGHT)
        if i%2==1 then
            t:SetColorTexture(.5,.5,1,.05)
            t.Vis = true
        end
    end

    local group = raidNames:CreateAnimationGroup()
    group:SetScript('OnFinished', function() group:Play() end)
    local rotation = group:CreateAnimation('Rotation')
    rotation:SetDuration(0.000001)
    rotation:SetEndDelay(2147483647)
    rotation:SetOrigin('BOTTOMRIGHT', 0, 0)
    rotation:SetDegrees(60)
    group:Play()
    
    local highlight_y = mainScroll.C:CreateTexture(nil,"BACKGROUND",nil,2)
    highlight_y:SetColorTexture(1,1,1,.2)
    local highlight_x = mainScroll:CreateTexture(nil,"BACKGROUND",nil,2)
    highlight_x:SetColorTexture(1,1,1,.2)
    
    local highlight_onupdate_maxY = (floor(PAGE_HEIGHT / LINE_HEIGHT) + 2) * LINE_HEIGHT
    local highlight_onupdate_minX = LINE_NAME_WIDTH + 15
    local highlight_onupdate_maxX = highlight_onupdate_minX + #raidNames * VERTICALNAME_WIDTH
    mainScroll.C:SetScript("OnUpdate",function(self)
        local x,y = ExRT.F.GetCursorPos(mainScroll)
        if y < 0 or y > PAGE_HEIGHT then
            highlight_x:Hide()
            highlight_y:Hide()
            return
        end 
        local x,y = ExRT.F.GetCursorPos(self)
        if y >= 0 and y <= highlight_onupdate_maxY then
            y = floor(y / LINE_HEIGHT)
            highlight_y:ClearAllPoints()
            highlight_y:SetAllPoints(lines[y+1])
            highlight_y:Show()
        else
            highlight_x:Hide()
            highlight_y:Hide()
            return
        end
        if x >= highlight_onupdate_minX and x <= highlight_onupdate_maxX then
            x = floor((x - highlight_onupdate_minX) / VERTICALNAME_WIDTH)
            highlight_x:ClearAllPoints()
            highlight_x:SetAllPoints(raidNames[x+1].t)
            highlight_x:Show()
        elseif x >= 0 and x <= (PAGE_WIDTH - 16) then
            highlight_x:Hide()
        else
            highlight_x:Hide()
            highlight_y:Hide()
        end
    end)
    
    local UpdateButton = ELib:Button(self,UPDATE):Point("TOPLEFT",mainScroll,"BOTTOMLEFT",-2,-5):Size(130,20):OnClick(function(self)
        module:SendReq()
    end)

    function UpdatePageView()
        local namesList = self.namesList or {}
        local namesList2 = {}
        local raidNamesUsed = 0
        for i=1+prevPlayerCol,#namesList do
            raidNamesUsed = raidNamesUsed + 1
            if not raidNames[raidNamesUsed] then
                break
            end
            local name = ExRT.F.delUnitNameServer(namesList[i].name)
            raidNames[raidNamesUsed]:SetText(name)
            raidNames[raidNamesUsed]:SetTextColor(ExRT.F.classColorNum(namesList[i].class))
            namesList2[raidNamesUsed] = name
            if raidNames[raidNamesUsed].Vis then
                raidNames[raidNamesUsed]:SetAlpha(.05)
            end
        end
        for i=raidNamesUsed+1,#raidNames do
            raidNames[i]:SetText("")
            raidNames[i].t:SetAlpha(0)
        end


        local function LineName_Icon_OnEnter(self)
            if self.HOVER_TEXT then
                ELib.Tooltip.Show(self, "ANCHOR_RIGHT", self.HOVER_TEXT) 
            end
        end
        
        local function LineName_Icon_OnLeave(self)
            if self.HOVER_TEXT then
                ELib.Tooltip.Hide()
            end
        end

        local lineNum = 1
        local backgroundLineStatus = (prevTopLine % 2) == 1

        for i=1,#module.db.addonsToCheck do
            local addonName = module.db.addonsToCheck[i]
            local line = lines[lineNum]
            if not line then
                break
            end
            line:Show()
            line.name:SetText(addonName)
            line.t:SetShown(backgroundLineStatus)

            for j=1,VERTICALNAME_COUNT do
                local pname = namesList2[j] or "-"
                if not line.icons[j].hoverFrame then
                    line.icons[j].hoverFrame = CreateFrame("Frame", nil, line)
                    line.icons[j].hoverFrame:Hide()
                    line.icons[j].hoverFrame:SetAllPoints(line.icons[j])
                    line.icons[j].hoverFrame:SetScript("OnEnter", LineName_Icon_OnEnter)
                    line.icons[j].hoverFrame:SetScript("OnLeave", LineName_Icon_OnLeave)
                end
                local db = module.db.responces[pname]

                if not db then
                    SetIcon(line.icons[j], 0)
                else
                    local addonData = db[addonName]
                    if addonData.loaded then
                        SetIcon(line.icons[j], 2)
                        line.icons[j].hoverFrame.HOVER_TEXT = addonData.version 
                        line.icons[j].hoverFrame:Show()
                    else
                        SetIcon(line.icons[j], 1)
                        line.icons[j].hoverFrame.HOVER_TEXT = nil
                        line.icons[j].hoverFrame:Hide()
                    end
                end
            end
            backgroundLineStatus = not backgroundLineStatus
            lineNum = lineNum + 1
        end
        for i=lineNum,#lines do
            lines[i]:Hide()
        end
    end
    
    function UpdatePage()
        local namesList = {}
        self.namesList = namesList
        for _,name,_,class in ExRT.F.IterateRoster do
            namesList[#namesList + 1] = {
                name = name,
                class = class,
            }
        end
        sort(namesList,function(a,b) return a.name < b.name end)
        
        if #namesList <= VERTICALNAME_COUNT then
            raidSlider:Hide()
            prevPlayerCol = 0
        else
            raidSlider:Show()
            raidSlider:Range(0,#namesList - VERTICALNAME_COUNT)
        end
        
        UpdatePageView()
    end
    self.UpdatePage = UpdatePage
    
    function self:OnShow()
        UpdatePage()
    end
end

function module.main:ADDON_LOADED()
    module:OnEnable()
end