--	20.11.2024

local GlobalAddonName, ART = ...

ART.V = 5100
ART.T = "R"

ART.Slash = {}			--> функции вызова из коммандной строки
ART.OnAddonMessage = {}	--> внутренние сообщения аддона
ART.MiniMapMenu = {}		--> изменение меню кнопки на миникарте
ART.Modules = {}		--> список всех модулей
ART.ModulesLoaded = {}		--> список загруженных модулей [для Dev & Advanced]
ART.ModulesOptions = {}
ART.Classic = {}		--> функции для работы на классик клиенте
ART.Debug = {}
ART.RaidVersions = {}
ART.Temp = {}
ART.Profiling = {}

ART.A = {}			--> ссылки на все модули
ART.F = {}

ART.msg_prefix = {
	["EXRTADD"] = true,
	MRTADDA = true,	MRTADDB = true,	MRTADDC = true,
	MRTADDD = true,	MRTADDE = true,	MRTADDF = true,
	MRTADDG = true,	MRTADDH = true,	MRTADDI = true,
}

ART.L = {}			--> локализация
ART.locale = GetLocale()

local unitIDs = {
    player = true,
    target = true,
    focus = true,
    mouseover = true,
    npc = true,
    vehicle = true,
    pet = true,
}

---------------> Version <---------------
do
	local version, buildVersion, buildDate, uiVersion = GetBuildInfo()
	
	ART.clientBuildVersion = buildVersion
	ART.clientUIinterface = uiVersion
	local expansion,majorPatch,minorPatch = (version or "5.0.0"):match("^(%d+)%.(%d+)%.(%d+)")
	ART.clientVersion = (expansion or 0) * 10000 + (majorPatch or 0) * 100 + (minorPatch or 0)
end
if ART.clientVersion < 20000 then
	ART.isClassic = true
	ART.T = "Classic"	
elseif ART.clientVersion < 30000 then
	ART.isClassic = true
	ART.isBC = true
	ART.T = "BC"
elseif ART.clientVersion < 40000 then
	ART.isClassic = true
	ART.isBC = true
	ART.isLK = true
	ART.T = "WotLK"
elseif ART.clientVersion < 50000 then
	ART.isClassic = true
	ART.isBC = true
	ART.isLK = true
	ART.isCata = true
	ART.T = "Cataclysm"
elseif ART.clientVersion < 60000 then
	ART.isClassic = true
	ART.isBC = true
	ART.isLK = true
	ART.isCata = true
	ART.isMoP = true
	ART.T = "Pandaria"
elseif ART.clientVersion >= 110000 then
	ART.is11 = true
end
-------------> smart DB <-------------
ART.SDB = {}

do
	local realmKey = GetRealmName() or ""
	local charName = UnitName'player' or ""
	realmKey = realmKey:gsub(" ","")
	ART.SDB.realmKey = realmKey
	ART.SDB.charKey = charName .. "-" .. realmKey
	ART.SDB.charName = charName
	ART.SDB.charLevel = UnitLevel'player'
end
-------------> global DB <------------
ART.GDB = {}
-------------> upvalues <-------------
local pcall, unpack, pairs, coroutine, assert, next, type = pcall, unpack, pairs, coroutine, assert, next, type
local GetTime, IsEncounterInProgress, CombatLogGetCurrentEventInfo = GetTime, IsEncounterInProgress, CombatLogGetCurrentEventInfo
local SendAddonMessage, strsplit, tremove, Ambiguate = C_ChatInfo.SendAddonMessage, strsplit, tremove, Ambiguate
local C_Timer_NewTicker, debugprofilestop, InCombatLockdown = C_Timer.NewTicker, debugprofilestop, InCombatLockdown

if ART.T == "D" then
	ART.isDev = true
	pcall = function(func,...)
		func(...)
		return true
	end
end

ART.NULL = {}
ART.NULLfunc = function() end
---------------> Modules <---------------
ART.mod = {}

do
	local function mod_LoadOptions(this)
		this:SetScript("OnShow",nil)
		--local t,c = debugprofilestop(),collectgarbage("count")	
		if this.Load then
			this:Load()
		end
		--local newc,newt = collectgarbage("count"),debugprofilestop() print(this.moduleName,'options',newc - c,newt - t)
		this.Load = nil
		ART.F.dprint(this.moduleName.."'s options loaded")
		this.isLoaded = true

		ART.F:FireCallback("OPTIONS_LOADED", this, this.moduleName)
	end
	local function mod_Options_CreateTitle(self)
		self.title = ART.lib:Text(self,self.name,20):Point(15,6):Top()
	end
	local function mod_Options_OpenPage(self)
		ART.Options:Open(self)
	end
	local function mod_Options_ForceLoad(self)
		mod_LoadOptions(self)
	end
	function ART:New(moduleName,localizatedName,disableOptions)
		if ART.A[moduleName] then
			return false
		end
		local self = {}
		for k,v in pairs(ART.mod) do self[k] = v end
		
		if not disableOptions then
			self.options = ART.Options:Add(moduleName,localizatedName)

			self.options:Hide()
			self.options.moduleName = moduleName
			self.options.name = localizatedName or moduleName
			self.options:SetScript("OnShow",mod_LoadOptions)
			
			self.options.CreateTilte = mod_Options_CreateTitle
			self.options.OpenPage = mod_Options_OpenPage
			self.options.ForceLoad = mod_Options_ForceLoad
			
			ART.ModulesOptions[#ART.ModulesOptions + 1] = self.options
		end
		
		self.main = CreateFrame("Frame", nil)
		self.main.events = {}
		self.main:SetScript("OnEvent",ART.mod.Event)
		
		self.main.ADDON_LOADED = ART.NULLfunc	--Prevent error for modules without it, not really needed
		
		if ART.T == "D" or ART.T == "DU" then
			self.main.eventsCounter = {}
			self.main:HookScript("OnEvent",ART.mod.HookEvent)
			
			self.main.name = moduleName
		end
		
		self.db = {}
		
		self.name = moduleName
		self.main.moduleName = moduleName
		table.insert(ART.Modules,self)
		ART.A[moduleName] = self
		
		ART.F.dprint("New module: "..moduleName)
		
		return self
	end
end

function ART.mod:Event(event,...)
	return self[event](self,...)
end
function ART.mod:EventProfiling(event,...)
	local t = debugprofilestop()
	self[event](self,...)
	t = debugprofilestop() - t
	local eventKey = self.moduleName .. ":" .. event
	ART.Profiling.T[eventKey] = (ART.Profiling.T[eventKey] or 0) + t
	ART.Profiling.M[eventKey] = max(t, ART.Profiling.M[eventKey] or 0)
	ART.Profiling.C[eventKey] = (ART.Profiling.C[eventKey] or 0) + 1
end
if ART.T == "DU" then
	local MRTDebug = ART.Debug
	function ART.mod:Event(event,...)
		local dt = debugprofilestop()
		self[event](self,...)
		MRTDebug[#MRTDebug+1] = {debugprofilestop() - dt,self.name,event}
	end
end

function ART.mod:HookEvent(event)
	self.eventsCounter[event] = self.eventsCounter[event] and self.eventsCounter[event] + 1 or 1
end

local CLEUFrame = CreateFrame("Frame")
local CLEUList = {}
local CLEUModules = {}
local CLEUListLen = 0

CLEUFrame.CLEUList = CLEUList
CLEUFrame.CLEUModules = CLEUModules


local CLEU_realmKey = ART.SDB.realmKey:gsub("[ %-]","")

local function CLEU_OnEvent()
	local timestamp,event,hideCaster,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2,
		val1,val2,val3,val4,val5,val6,val7,val8,val9,val10,val11,val12,val13
				= CombatLogGetCurrentEventInfo()

	if type(sourceName)=="string" then
		local name,server,region = strsplit("-",sourceName)
		if server == CLEU_realmKey then 
			sourceName = name
		elseif region then 
			sourceName = name .. "-" .. server
		end
	end
	if type(destName)=="string" then
		local name,server,region = strsplit("-",destName)
		if server == CLEU_realmKey then 
			destName = name
		elseif region then 
			destName = name .. "-" .. server
		end
	end

	for i=1,CLEUListLen do
		CLEUList[i](timestamp,event,hideCaster,sourceGUID,sourceName,sourceFlags,sourceFlags2,destGUID,destName,destFlags,destFlags2,val1,val2,val3,val4,val5,val6,val7,val8,val9,val10,val11,val12,val13)
	end
end

local function CLEU_OnEvent_Recreate()
	for i=1,#CLEUList do CLEUList[i]=nil end
	CLEUListLen = 0
	for mod,func in pairs(CLEUModules) do
		CLEUListLen = CLEUListLen + 1
		CLEUList[CLEUListLen] = func
	end

	if CLEUListLen == 0 then
		CLEUFrame:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	end

	CLEUFrame:SetScript("OnEvent",CLEU_OnEvent)
	CLEU_OnEvent()
end
local function CLEU_OnEvent_RecreateProfiling()
	for i=1,#CLEUList do CLEUList[i]=nil end
	CLEUListLen = 0
	for mod,func in pairs(CLEUModules) do
		CLEUListLen = CLEUListLen + 1
		CLEUList[CLEUListLen] = function(...)
			local t = debugprofilestop()
			func(...)
			t = debugprofilestop() - t
			local eventKey = mod.name .. ":CLEU"
			ART.Profiling.T[eventKey] = (ART.Profiling.T[eventKey] or 0) + t
			ART.Profiling.M[eventKey] = max(t, ART.Profiling.M[eventKey] or 0)
			ART.Profiling.C[eventKey] = (ART.Profiling.C[eventKey] or 0) + 1
		end
	end

	if CLEUListLen == 0 then
		CLEUFrame:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	end

	CLEUFrame:SetScript("OnEvent",CLEU_OnEvent)
	CLEU_OnEvent()
end


CLEUFrame:SetScript("OnEvent",CLEU_OnEvent_Recreate)
ART.CLEUFrame = CLEUFrame

function ART.mod:RegisterEvents(...)
	for i=1,select("#", ...) do
		local event = select(i,...)
		if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
			if not ART.isClassic then
				self.main:RegisterEvent(event)
			else
				pcall(self.main.RegisterEvent,self.main,event)
			end
		elseif self.CLEUNotInList then
			if not self.CLEU then self.CLEU = CreateFrame("Frame") end
			self.CLEU:SetScript("OnEvent",self.main.COMBAT_LOG_EVENT_UNFILTERED)
			self.CLEU:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
		else
			local func = self.main.COMBAT_LOG_EVENT_UNFILTERED
			if type(func) == "function" then
				CLEUModules[self] = func
				CLEUFrame:SetScript("OnEvent",CLEU_OnEvent_Recreate)
				if ART.Profiling.Enabled then
					CLEUFrame:SetScript("OnEvent",CLEU_OnEvent_RecreateProfiling)
				end
				CLEUFrame:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
			else
				error("ART: "..self.name..": wrong CLEU function.")
			end
		end
		self.main.events[event] = true
		ART.F.dprint(self.name,'RegisterEvent',event)
	end
end

function ART.mod:UnregisterEvents(...)
	for i=1,select("#", ...) do
		local event = select(i,...)
		if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then
			if not ART.isClassic then
				self.main:UnregisterEvent(event)
			else
				pcall(self.main.UnregisterEvent,self.main,event)
			end
		elseif self.CLEUNotInList then
			if self.CLEU then
				self.CLEU:SetScript("OnEvent",nil)
				self.CLEU:UnregisterAllEvents()
			end
		else
			CLEUModules[self] = nil
			CLEUFrame:SetScript("OnEvent",CLEU_OnEvent_Recreate)
		end
		self.main.events[event] = nil
		ART.F.dprint(self.name,'UnregisterEvent',event)
	end
end

function ART.mod:RegisterUnitEvent(...)
	self.main:RegisterUnitEvent(...)
	local event = ...
	self.main.events[event] = true
	ART.F.dprint(self.name,'RegisterUnitEvent',event)
end

function ART.mod:RegisterSlash()
	ART.Slash[self.name] = self
end

function ART.mod:UnregisterSlash()
	ART.Slash[self.name] = nil
end

function ART.mod:RegisterAddonMessage()
	ART.OnAddonMessage[self.name] = self
end

function ART.mod:UnregisterAddonMessage()
	ART.OnAddonMessage[self.name] = nil
end

function ART.mod:RegisterMiniMapMenu()
	ART.MiniMapMenu[self.name] = self
end

function ART.mod:UnregisterMiniMapMenu()
	ART.MiniMapMenu[self.name] = nil
end

do
	local hideOnPetBattle = {}
	local petBattleTracker = CreateFrame("Frame")
	petBattleTracker:SetScript("OnEvent",function (self, event)
		if event == "PET_BATTLE_OPENING_START" then
			for _,frame in pairs(hideOnPetBattle) do
				if frame:IsShown() then
					frame.petBattleHide = true
					frame:Hide()
				else
					frame.petBattleHide = nil
				end
			end
		else
			for _,frame in pairs(hideOnPetBattle) do
				if frame.petBattleHide then
					frame.petBattleHide = nil
					frame:Show()
				end
			end
		end
	end)
	if not ART.isClassic then
		petBattleTracker:RegisterEvent("PET_BATTLE_OPENING_START")
		petBattleTracker:RegisterEvent("PET_BATTLE_CLOSE")
	end
	function ART.mod:RegisterHideOnPetBattle(frame)
		hideOnPetBattle[#hideOnPetBattle + 1] = frame
	end
end

---------------> Profiling <---------------

local profilingTicker
function ART.F:StartProfiling()
	ART.Profiling = {
		T = {},
		M = {},
		C = {},
		Enabled = true,
		Start = debugprofilestop(),
	}
	for _,mod in pairs(ART.Modules) do
		mod.main:SetScript("OnEvent",ART.mod.EventProfiling)
	end
	CLEUFrame:SetScript("OnEvent",CLEU_OnEvent_RecreateProfiling)
	ART.frame:OnUpdate_Recreate(0)
end
function ART.F:StopProfiling()
	ART.Profiling.End = debugprofilestop()
	ART.Profiling.Enabled = false
	for _,mod in pairs(ART.Modules) do
		mod.main:SetScript("OnEvent",ART.mod.Event)
	end
	CLEUFrame:SetScript("OnEvent",CLEU_OnEvent_Recreate)
	ART.frame:OnUpdate_Recreate(0)

	if profilingTicker then
		profilingTicker:Cancel()
		profilingTicker = nil
	end
end
function ART.F:StartStopProfiling()
	if ART.Profiling.Enabled then
		ART.F:StopProfiling()
		print('ART: profiling stopped')
	else
		ART.F:StartProfiling()
		print('ART: profiling started')
	end
end
function ART.F:StartProfilingBoss()
	if profilingTicker then
		profilingTicker:Cancel()
		profilingTicker = nil
	end
	ART.F:StartProfiling()
	profilingTicker = C_Timer.NewTicker(1,function(self)
		if not IsEncounterInProgress() and not ART.Profiling.BossStarted then
			ART.F:StartProfiling()
		elseif not IsEncounterInProgress() and ART.Profiling.BossStarted then
			ART.F:StopProfiling()
			self:Cancel()
			profilingTicker = nil
		elseif IsEncounterInProgress() and not ART.Profiling.BossStarted then
			ART.Profiling.BossStarted = true
		end
	end)
end
function ART.F:IsProfilingBoss()
	if profilingTicker then
		return true
	else
		return false
	end
end
function ART.F:GetProfiling()
	local now = (ART.Profiling.End or debugprofilestop()) - ART.Profiling.Start
	local str = ""..ART.V.." "..ART.T.." "..now.."\n"
	local r = {}
	for event in pairs(ART.Profiling.T) do
		local t = ART.Profiling.T[event]
		local c = ART.Profiling.C[event]
		local m = ART.Profiling.M[event]

		r[#r+1] = {event,t,c,m,(t/c),t/now*1000}
	end
	sort(r,function(a,b) return a[2]>b[2] end)
	for i=1,#r do
		str = str .. r[i][1] .. " "..r[i][2].." "..r[i][3].." "..r[i][4].." "..r[i][5] .." "..r[i][6] .. "\n"
	end
	ART.F:Export2(str)
end
function ART.F:LiveProfiling()
	debugStringFrame = CreateFrame("Frame",nil,UIParent)
	debugStringFrame:SetAllPoints()
	debugStringFrame:SetFrameStrata("DIALOG")
	debugString = debugStringFrame:CreateFontString(nil,"ARTWORK")
	debugString:SetPoint("TOPLEFT",5,-5)
	debugString:SetJustifyH("LEFT")
	debugString:SetJustifyV("TOP")
	debugString:SetFont("Interface\\AddOns\\ART\\media\\skurri.ttf", 12,"OUTLINE")

	C_Timer.NewTicker(0.5,function()
		local str = ""
		local r = {}
		local now = (ART.Profiling.End or debugprofilestop()) - ART.Profiling.Start
		for event in pairs(ART.Profiling.T) do
			local t = ART.Profiling.T[event]
			local c = ART.Profiling.C[event]
			local m = ART.Profiling.M[event]
	
			r[#r+1] = {event,t,c,m,(t/c),t/now*1000}
		end
		sort(r,function(a,b) return a[2]>b[2] end)
		for i=1,#r do
			str = str .. r[i][1] .. " "..format("%dms",r[i][2]).." c:"..r[i][3].." peak:"..format("%.1fms",r[i][4]).." per1:"..format("%.1fms",r[i][5]) .." persec:"..format("%.1fms",r[i][6]) .. "\n"
		end
		debugString:SetText(str)
	end)
	ART.F:StartProfiling()
end


---------------> Mods <---------------

do
	local function TimerFunc(self)
		self.func(unpack(self.args))
	end
	local function TimerFuncProfiling(self)
		local t = debugprofilestop()
		self.func(unpack(self.args))
		t = debugprofilestop() - t
		local eventKey = "delayed timers"..self.profilingevent
		ART.Profiling.T[eventKey] = (ART.Profiling.T[eventKey] or 0) + t
		ART.Profiling.M[eventKey] = max(t, ART.Profiling.M[eventKey] or 0)
		ART.Profiling.C[eventKey] = (ART.Profiling.C[eventKey] or 0) + 1
	end
	function ART.F.ScheduleTimer(func, delay, ...)
		local self = nil
		local isProfiling = ART.Profiling.Enabled
		local tf = isProfiling and TimerFuncProfiling or TimerFunc
		if delay > 0 then
			self = C_Timer_NewTicker(delay,tf,1)
			-- Avoid C_Timer.NewTimer here cuz it runs ticker with 1 iteration anyway
		else
			self = C_Timer_NewTicker(-delay,tf)
		end
		if isProfiling then
			local path = debugstack()
			local str
			for s in path:gmatch("[^/%[%]]+%]:%d+") do
				if not s:find("core.lua",1,true) then
					str = ":"..s:gsub('"%]',"")
					break
				end
			end
			
			self.profilingevent = str or ""
		end
		self.args = {...}
		self.func = func
		
		return self
	end
	function ART.F.CancelTimer(self)
		if self then
			self:Cancel()
		end
	end
	function ART.F.ScheduleETimer(self, func, delay, ...)
		ART.F.CancelTimer(self)
		return ART.F.ScheduleTimer(func, delay, ...)
	end
	
	ART.F.NewTimer = ART.F.ScheduleTimer
	ART.F.Timer = ART.F.ScheduleTimer

	local st = ART.F.ScheduleTimer
	ART.F.After = function(delay, func, ...)
		st(func, delay, ...)
	end
end

-----------> Coroutinies <------------

ART.Coroutinies = {}
local coroutineFrame

function ART.F:AddCoroutine(func, errorHandler, disableInCombat)
	if not coroutineFrame then
		coroutineFrame = CreateFrame("Frame")

		local sleep = {}
		local coroutineData = ART.Coroutinies
		
		coroutineFrame:Hide()
		coroutineFrame:SetScript("OnUpdate", function(self, elapsed)
			local start = debugprofilestop()
			if not next(coroutineData) then
				self:Hide()
				return
			end
			
			-- Resume as often as possible (Limit to 16ms per frame -> 60 FPS)
			local now = start
			local anyFunc
			while (now - start < 16) do
				anyFunc = false
				for func,opt in pairs(coroutineData) do
					if opt.cmt and InCombatLockdown() then
						--skip until combat ends
					elseif opt.w == start then
						--skip until next redraw
					elseif coroutine.status(func) ~= "dead" then
						if (not sleep[func]) or (now > sleep[func]) then
							sleep[func] = nil

							local ok, msg, resumeTime = coroutine.resume(func)
							if ok and msg == "sleep" then
								sleep[func] = now + (resumeTime or 1000)
							elseif ok and msg == "await" then
								opt.w = start
							elseif not ok then
								if opt.eh then
									opt.eh(msg, debugstack(func))
								else
									geterrorhandler()(msg .. '\n' .. debugstack(func))
								end
							end

							--prevent high load in combat, 200ms max for script in instances
							if InCombatLockdown() and ((debugprofilestop() - start) >= 100) then
								return
							end

							anyFunc = true
						end
					else
						coroutineData[func] = nil
						if not next(coroutineData) then
							self:Hide()
							return
						end
					end
				end

				--no function found in cycle, skip future cycling
				if not anyFunc then
					return
				end

				now = debugprofilestop()
			end
		end)
	end

	local c = coroutine.create(func)

	if type(errorHandler) ~= "function" then
		errorHandler = nil
	end

	ART.Coroutinies[c] = {
		eh = errorHandler,
		cmt = disableInCombat,
		f = func,
	}
	
	coroutineFrame:Show()

	return c
end

function ART.F:GetCoroutine(func)
	return ART.Coroutinies[func]
end

function ART.F:RemoveCoroutine(func)
	ART.Coroutinies[func] = nil
end

---------------> Data <---------------

ART.F.defFont = "Interface\\AddOns\\"..GlobalAddonName.."\\media\\skurri.ttf"
ART.F.barImg = "Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar17.tga"
ART.F.defBorder = "Interface\\AddOns\\"..GlobalAddonName.."\\media\\border.tga"
ART.F.textureList = {
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar1.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar2.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar3.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar4.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar5.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar6.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar7.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar8.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar9.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar10.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar11.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar12.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar13.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar14.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar15.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar16.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar17.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar18.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar19.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar20.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar21.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar22.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar23.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar24.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar24b.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar25.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar26.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar27.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar28.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar29.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar30.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar31.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar32.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar33.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\bar34.tga",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\White.tga",
	[[Interface\TargetingFrame\UI-StatusBar]],
	[[Interface\PaperDollInfoFrame\UI-Character-Skills-Bar]],
	[[Interface\RaidFrame\Raid-Bar-Hp-Fill]],
}
ART.F.fontList = {
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\skurri.ttf",
	"Fonts\\ARIALN.TTF",
	"Fonts\\FRIZQT__.TTF",
	"Fonts\\MORPHEUS.TTF",
	"Fonts\\NIM_____.ttf",
	"Fonts\\SKURRI.TTF",
	"Fonts\\FRIZQT___CYR.TTF",
	"Fonts\\ARHei.ttf",
	"Fonts\\ARKai_T.ttf",
	"Fonts\\2002.ttf",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\TaurusNormal.ttf",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\UbuntuMedium.ttf",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\TelluralAlt.ttf",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\Glametrix.otf",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\FiraSansMedium.ttf",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\alphapixels.ttf",
	"Interface\\AddOns\\"..GlobalAddonName.."\\media\\ariblk.ttf",
}

if ART.locale and ART.locale:find("^zh") then		--China & Taiwan fix
	ART.F.defFont = "Fonts\\ARHei.ttf"
elseif ART.locale == "koKR" then			--Korea fix
	ART.F.defFont = "Fonts\\2002.ttf"
end

----------> Version Checker <----------

local isVersionCheckCallback = nil
local function DisableVersionCheckCallback()
	isVersionCheckCallback = nil
end

-------------> Callbacks <-------------

local callbacks = {}
function ART.F:RegisterCallback(eventName, func)
	if not callbacks[eventName] then
		callbacks[eventName] = {}
	end
	tinsert(callbacks[eventName], func)

	ART.F:FireCallback("CallbackRegistered", eventName, func)
end
function ART.F:UnregisterCallback(eventName, func)
	if not callbacks[eventName] then
		return
	end
	local count = 0
	for i=#callbacks[eventName],1,-1 do
		if callbacks[eventName][i] == func then
			tremove(callbacks[eventName], i)
		else
			count = count + 1
		end
	end

	ART.F:FireCallback("CallbackUnregistered", eventName, func, count)
end

local function CallbackErrorHandler(err)
	print ("Callback Error", err)
end

function ART.F:FireCallback(eventName, ...)
	if not callbacks[eventName] then
		return
	end
	for _,func in pairs(callbacks[eventName]) do
		xpcall(func, CallbackErrorHandler, eventName, ...)
	end
end

---------------> Slash <---------------

SlashCmdList["mrtSlash"] = function (arg)
	local argL = strlower(arg)
	if argL == "icon" then
		VMRT.Addon.IconMiniMapHide = not VMRT.Addon.IconMiniMapHide
		if not VMRT.Addon.IconMiniMapHide then 
			ART.MiniMapIcon:Show()
		else
			ART.MiniMapIcon:Hide()
		end
	elseif argL == "getver" then
		ART.F.SendExMsg("needversion","")
		isVersionCheckCallback = ART.F.ScheduleETimer(isVersionCheckCallback, DisableVersionCheckCallback, 1.5)
	elseif argL == "getverg" then
		ART.F.SendExMsg("needversiong","","GUILD")
		isVersionCheckCallback = ART.F.ScheduleETimer(isVersionCheckCallback, DisableVersionCheckCallback, 1.5)
	elseif argL == "set" then
		ART.Options:Open()
	elseif argL == "quit" then
		for mod,data in pairs(ART.A) do
			data.main:UnregisterAllEvents()
			if data.CLEU then
				data.CLEU:UnregisterAllEvents()
			end
		end
		ART.frame:UnregisterAllEvents()
		ART.frame:SetScript("OnUpdate",nil)
		print("ART Disabled")
	elseif argL == "profiler" or argL == "profiling" then
		ART.F:ProfilingWindow()
	elseif string.len(argL) == 0 then
		ART.Options:Open()
		return
	end
	for _,mod in pairs(ART.Slash) do
		mod:slash(argL,arg)
	end
end
SLASH_mrtSlash1 = "/exrt"
SLASH_mrtSlash2 = "/rt"
SLASH_mrtSlash3 = "/raidtools"
SLASH_mrtSlash4 = "/methodraidtools"
SLASH_mrtSlash5 = "/ert"
SLASH_mrtSlash6 = "/mrt"
SLASH_mrtSlash6 = "/art"

---------------> Global addon frame <---------------

local reloadTimer = 0.1

ART.frame = CreateFrame("Frame")

local function loader(self,func)
	xpcall(func,geterrorhandler(),self)
end

local migrateReplace
do
	local tr
	function migrateReplace(t)
		if not t then
			if tr then
				for i=1,#tr,2 do
					local t,k = tr[i],tr[i+1]
					local str = t[k]
					if str:find("AddOns[\\/]ExRT") then
						t[k] = str:gsub("(AddOns[\\/])ExRT","%1MRT")
					end
				end
				tr = nil
			end
		else
			for k,v in pairs(t) do
				local vt = type(v)
				if vt == "table" then
					migrateReplace(v)
				elseif vt == "string" then
					if not tr then
						tr = {}
					end
					tr[#tr+1] = t
					tr[#tr+1] = k
				end
			end
		end
	end
end

ART.frame:SetScript("OnEvent",function (self, event, ...)
	if event == "CHAT_MSG_ADDON" then
		local prefix, message, channel, sender = ...
		if prefix and ART.msg_prefix[prefix] and (channel=="RAID" or channel=="GUILD" or channel=="INSTANCE_CHAT" or channel=="PARTY" or (channel=="WHISPER" and (ART.F.UnitInGuild(sender) or sender == ART.SDB.charName)) or (message and (message:find("^version") or message:find("^needversion")))) then
			ART.F.GetExMsg(sender, strsplit("\t", message))
		end
		if prefix and ART.msg_prefix[prefix] then
			ART.F.GetAnyExMsg(sender, prefix, message, channel, sender)
		end
	elseif event == "ADDON_LOADED" then
		local addonName = ...
		if addonName ~= GlobalAddonName then
			return
		end
		VMRT = VMRT or {}
		VMRT.Addon = VMRT.Addon or {}

		if not VMRT.Addon.migrateMRT and VExRT and VExRT.Addon then
			VMRT = VExRT

			migrateReplace(VMRT)
			migrateReplace()

			VMRT.Addon = VMRT.Addon or {}
			VMRT.Addon.migrateMRT = true
		end
		VExRT = nil
		VExRT = setmetatable({}, {
			__index = VMRT,
			__newindex = VMRT,
		})
		

		VMRT.Addon.Timer = VMRT.Addon.Timer or 0.1
		reloadTimer = VMRT.Addon.Timer

		if VMRT.Addon.IconMiniMapLeft and VMRT.Addon.IconMiniMapTop then
			ART.MiniMapIcon:ClearAllPoints()
			ART.MiniMapIcon:SetPoint("CENTER", VMRT.Addon.IconMiniMapLeft, VMRT.Addon.IconMiniMapTop)
		end
		
		if VMRT.Addon.IconMiniMapHide then 
			ART.MiniMapIcon:Hide() 
		end

		for prefix,_ in pairs(ART.msg_prefix) do
			C_ChatInfo.RegisterAddonMessagePrefix(prefix)
		end
		
		VMRT.Addon.Version = tonumber(VMRT.Addon.Version or "0")
		VMRT.Addon.PreVersion = VMRT.Addon.Version
		
		if ART.A.Profiles then
			ART.A.Profiles:ReselectProfileOnLoad()
		end
		
		ART.F.dprint("ADDON_LOADED event")
		ART.F.dprint("MODULES FIND",#ART.Modules)
		--local t,c = debugprofilestop(),collectgarbage("count") print('addon load event')		
		for i=1,#ART.Modules do
			loader(self,ART.Modules[i].main.ADDON_LOADED)
			--local newc,newt = collectgarbage("count"),debugprofilestop() print(ART.Modules[i].name,newc - c,newt - t) t,c = newt,newc

			ART.ModulesLoaded[i] = true
			
			ART.F.dprint("ADDON_LOADED",i,ART.Modules[i].name)
		end

		if not VMRT.Addon.DisableHideESC then
			tinsert(UISpecialFrames, "MRTOptionsFrame")
		end

		VMRT.Addon.Version = ART.V
		
		ART.F.ScheduleTimer(function()
			ART.frame:SetScript("OnUpdate", ART.frame.OnUpdate_Recreate)
		end,1)
		self:UnregisterEvent("ADDON_LOADED")

		ART.AddonLoaded = true

		if not ART.isClassic then
			if not VMRT.Addon.EJ_CHECK_VER or VMRT.Addon.EJ_CHECK_VER ~= ART.clientUIinterface or (((type(IsTestBuild)=="function" and IsTestBuild()) or (type(IsBetaBuild)=="function" and IsBetaBuild())) and VMRT.Addon.EJ_CHECK_VER_PTR ~= ART.clientBuildVersion) then
				C_Timer.After(10,function()
					ART.F.EJ_AutoScan()
				end)
			else
				ART.F.EJ_LoadData()
			end
		end

		return true	
	end
end)

do
	local encounterTime,isEncounter = 0,nil
	local OnUpdate_Funcs = {}
	local OnUpdate_Modules = {}

	local frameElapsed = 0
	local function OnUpdate(self,elapsed)
		frameElapsed = frameElapsed + elapsed
		if frameElapsed >= 0.1 then
			if not isEncounter and IsEncounterInProgress() then
				isEncounter = true
				encounterTime = GetTime()
			elseif isEncounter and not IsEncounterInProgress() then
				isEncounter = nil
			end
			
			for mod, func in next, OnUpdate_Funcs do
				func(mod, frameElapsed)
			end
			frameElapsed = 0
		end
	end
	local function OnUpdateProfiling(self,elapsed)
		frameElapsed = frameElapsed + elapsed
		if frameElapsed >= 0.1 then
			if not isEncounter and IsEncounterInProgress() then
				isEncounter = true
				encounterTime = GetTime()
			elseif isEncounter and not IsEncounterInProgress() then
				isEncounter = nil
			end
			
			for mod, func in next, OnUpdate_Funcs do
				local t = debugprofilestop()
				func(mod, frameElapsed)
				t = debugprofilestop() - t
				local eventKey = mod.name .. ":OnUpdate"
				ART.Profiling.T[eventKey] = (ART.Profiling.T[eventKey] or 0) + t
				ART.Profiling.M[eventKey] = max(t, ART.Profiling.M[eventKey] or 0)
				ART.Profiling.C[eventKey] = (ART.Profiling.C[eventKey] or 0) + 1
			end
			frameElapsed = 0
		end
	end

	local function OnUpdate_Recreate(self,elapsed)
		for k in pairs(OnUpdate_Funcs) do OnUpdate_Funcs[k]=nil end
		for mod,func in pairs(OnUpdate_Modules) do
			OnUpdate_Funcs[mod] = func
		end
		
		if ART.Profiling.Enabled then
			self:SetScript("OnUpdate", OnUpdateProfiling)
			OnUpdateProfiling(self,elapsed)
			return
		end
		self:SetScript("OnUpdate", OnUpdate)
		OnUpdate(self,elapsed)
	end

	ART.frame.OnUpdate = OnUpdate
	ART.frame.OnUpdate_Recreate = OnUpdate_Recreate
	ART.frame.OnUpdate_Funcs = OnUpdate_Funcs
	ART.frame.OnUpdate_Modules = OnUpdate_Modules

	function ART.mod:RegisterTimer()
		local func = self.timer
		if type(func) ~= "function" then
			error("ART: "..self.name..": wrong timer function.")
			return
		end
		OnUpdate_Modules[self] = func

		ART.frame:SetScript("OnUpdate", OnUpdate_Recreate)
	end
	
	function ART.mod:UnregisterTimer()
		OnUpdate_Modules[self] = nil

		ART.frame:SetScript("OnUpdate", OnUpdate_Recreate)
	end
	
	function ART.F.RaidInCombat()
		return isEncounter
	end
	
	function ART.F.GetEncounterTime()
		if isEncounter then
			return GetTime() - encounterTime
		end
	end
end

--temp fix
local prefix_sorted = {"EXRTADD","MRTADDA","MRTADDB","MRTADDC","MRTADDD","MRTADDE","MRTADDF","MRTADDG","MRTADDH","MRTADDI"}

local sendPending = {}
local sendPrev = {0}
local sendTmr
local _SendAddonMessage = SendAddonMessage
local SEND_LIMIT = 10
local sendLimit = {SEND_LIMIT}

local count5 = 0
local count5_t = 0

local function send(self)
	if self then
		sendTmr = nil
	end
	local t = debugprofilestop()
	if t - count5_t > 5000 then
		count5 = 0
		count5_t = t
	end
	for p=1,#prefix_sorted do
		local limitNow = (sendLimit[p] or SEND_LIMIT) + floor((t - (sendPrev[p] or 0))/1000)
		if limitNow > SEND_LIMIT then
			limitNow = SEND_LIMIT
		elseif limitNow < -30 and sendPrev[p] and t < sendPrev[p] then
			sendPrev[p] = t
			sendLimit[p] = 0
			limitNow = 0
		end
		if limitNow > 0 then
			local cp = 1
			for i=1,#sendPending do
				if limitNow <= 0 then
					break
				end
				local pendingNow = sendPending[cp]
				if pendingNow.maxPer5Sec and count5 > pendingNow.maxPer5Sec then
					--skip
					cp = cp + 1
				elseif (not pendingNow.prefixNum or pendingNow.prefixNum == p) and (not pendingNow.prefixMax or p <= pendingNow.prefixMax) then
					limitNow = limitNow - 1
					sendLimit[p] = limitNow
					pendingNow[1] = prefix_sorted[p] --override prefix
					_SendAddonMessage(unpack(pendingNow))
					sendPrev[p] = debugprofilestop()
					if pendingNow.ondone then
						pendingNow.ondone()
					end
					tremove(sendPending, cp)
					count5 = count5 + 1
					if not next(sendPending) then
						return
					end
				else
					--skip
					cp = cp + 1
				end
			end
		end
	end
	if not sendTmr and next(sendPending) then
		sendTmr = C_Timer.NewTimer(0.5, send)
		return
	end
end

local specialOpt = nil
SendAddonMessage = function (...)
	local entry = {...}
	if type(specialOpt)=="table" then
		if type(specialOpt.maxPer5Sec)=="number" then
			entry.maxPer5Sec = specialOpt.maxPer5Sec
		end
		if type(specialOpt.prefixNum)=="number" and specialOpt.prefixNum <= #prefix_sorted and specialOpt.prefixNum > 0 then
			entry.prefixNum = specialOpt.prefixNum
		end
		if type(specialOpt.prefixMax)=="number" and specialOpt.prefixMax <= #prefix_sorted and specialOpt.prefixMax > 0 then
			entry.prefixMax = specialOpt.prefixMax
		end
		if type(specialOpt.ondone)=="function" then
			entry.ondone = specialOpt.ondone
		end
	end
	sendPending[#sendPending+1] = entry
	send()
end

function ART.F.SendExMsg(prefix, msg, tochat, touser, addonPrefix)
	addonPrefix = addonPrefix or "EXRTADD"
	msg = msg or ""
	if tochat and not touser then
		SendAddonMessage(addonPrefix, prefix .. "\t" .. msg, tochat)
	elseif tochat and touser then
		SendAddonMessage(addonPrefix, prefix .. "\t" .. msg, tochat, touser)
	else
		local chat_type, playerName = ART.F.chatType()
		if chat_type == "WHISPER" and playerName == ART.SDB.charName then
			if type(specialOpt)=="table" and type(specialOpt.ondone)=="function" then
				specialOpt.ondone()
			end
			specialOpt = nil
			ART.F.GetExMsg(ART.SDB.charName, prefix, strsplit("\t", msg))
			return
		end
		SendAddonMessage(addonPrefix, prefix .. "\t" .. msg, chat_type, playerName)
	end
end


function ART.F.SendExMsgExt(opt, ...)
	specialOpt = opt
	--ART.F.SendExMsg(...)
	xpcall(ART.F.SendExMsg,geterrorhandler(),...)
	specialOpt = nil
end


function ART.F.GetExMsg(sender, prefix, ...)
	if prefix == "needversion" then
		ART.F.SendExMsg("version2", ART.V)
	elseif prefix == "needversiong" then
		ART.F.SendExMsg("version2", ART.V, "WHISPER", sender)
	elseif prefix == "version" then
		local msgver = ...
		print(sender..": "..msgver)
		ART.RaidVersions[sender] = msgver
	elseif prefix == "version2" then
		ART.RaidVersions[sender] = ...
		if isVersionCheckCallback then
			local msgver = ...
			print(sender..": "..msgver)
		end
	end
	if not ART.Profiling.Enabled then
		for _,mod in pairs(ART.OnAddonMessage) do
			mod:addonMessage(sender, prefix, ...)
		end
	else
		for _,mod in pairs(ART.OnAddonMessage) do
			local t = debugprofilestop()
			mod:addonMessage(sender, prefix, ...)
			t = debugprofilestop() - t
			local eventKey = mod.name .. ":CHAT_MSG_ADDON"
			ART.Profiling.T[eventKey] = (ART.Profiling.T[eventKey] or 0) + t
			ART.Profiling.M[eventKey] = max(t, ART.Profiling.M[eventKey] or 0)
			ART.Profiling.C[eventKey] = (ART.Profiling.C[eventKey] or 0) + 1
		end
	end
end

function ART.F.GetAnyExMsg(sender, prefix, ...)
	if Ambiguate(sender, "none") == ART.SDB.charName then
		return
	end

	local p
	for j=1,#prefix_sorted do
		if prefix_sorted[j] == prefix then
			p = j
			break
		end
	end

	if not p then
		return
	end

	sendLimit[p] = (sendLimit[p] or SEND_LIMIT) - 1
	sendPrev[p] = debugprofilestop()
end

local oldIsAddOnLoaded = C_AddOns.IsAddOnLoaded
function C_AddOns.IsAddOnLoaded(name)
    if name == "MRT" then
        return true
    end
    return oldIsAddOnLoaded(name)
end

local function GetNicknameByCharacter(characterName)
    if not VMRT or not VMRT.Nicknames then return nil end
    local nicknamesMap = type(VMRT.Nicknames) == "table" and #VMRT.Nicknames > 0 and type(VMRT.Nicknames[1]) == "table" and VMRT.Nicknames[1] or VMRT.Nicknames
    
    if not nicknamesMap then return nil end
    characterName = characterName:lower()
    
    for nickname, data in pairs(nicknamesMap) do
        if data and data.characters then
            for _, charData in ipairs(data.characters) do
                if type(charData) == "table" and charData.character and charData.character:lower() == characterName then
                    return nickname
                end
            end
        end
    end
    return nil
end

_G.LiquidAPI = {
    GetName = function(self, characterName, formatting, atlasSize)
        if not characterName then 
            error("LiquidAPI:GetName(characterName[, formatting, atlasSize]), characterName is nil") 
            return 
        end
        
        local nickname
        if unitIDs[characterName:lower()] then
            local n = UnitNameUnmodified(characterName)
            if n then
                n = strsplit("-", n)
                nickname = GetNicknameByCharacter(n)
            end
        else
            characterName = strsplit("-", characterName)
            nickname = GetNicknameByCharacter(characterName)
        end

        if not formatting then 
            return nickname or characterName
        end

        local guid = UnitGUID(characterName)
        if not guid then
            return nickname or characterName, "%s", ""
        end

        local classFileName = UnitClassBase(characterName)
        local colorStr = string.format("|c%s%%s|r", classFileName and RAID_CLASS_COLORS[classFileName] and RAID_CLASS_COLORS[classFileName].colorStr or "ffffff")

        local role = UnitGroupRolesAssigned(characterName)
        local roleAtlas = role == "TANK" and "Role-Tank-SM" or role == "HEALER" and "Role-Healer-SM" or role == "DAMAGER" and "Role-DPS-SM"
        local roleIcon = roleAtlas and CreateAtlasMarkup(roleAtlas, atlasSize, atlasSize) or ""

        return nickname or characterName, colorStr, roleIcon, RAID_CLASS_COLORS[classFileName] or {}
    end,

    GetCharacterInGroup = function(self, nickname)
        if not VMRT or not VMRT.Nicknames then return nil end
        local nicknamesMap = type(VMRT.Nicknames) == "table" and #VMRT.Nicknames > 0 and type(VMRT.Nicknames[1]) == "table" and VMRT.Nicknames[1] or VMRT.Nicknames
        
        if not nicknamesMap or not nickname then return nil end
        
        for nickKey, data in pairs(nicknamesMap) do
            if nickKey:lower() == nickname:lower() and data.characters then
                for _, charData in ipairs(data.characters) do
                    if UnitExists(charData.character) then
                        local guid = UnitGUID(charData.character)
                        local classFileName = UnitClassBase(charData.character)
                        return charData.character, string.format("|c%s%%s|r", RAID_CLASS_COLORS[classFileName].colorStr), guid
                    end
                end
            end
        end
    end,

    GetCharacters = function(self, nickname)
        if not nickname then 
            error("LiquidAPI:GetCharacters(nickname), nickname is nil") 
            return 
        end
        
        if not VMRT or not VMRT.Nicknames then return nil end
        local nicknamesMap = type(VMRT.Nicknames) == "table" and #VMRT.Nicknames > 0 and type(VMRT.Nicknames[1]) == "table" and VMRT.Nicknames[1] or VMRT.Nicknames
        
        if not nicknamesMap then return nil end
        
        nickname = nickname:gsub("^%l", string.upper)
        for nickKey, data in pairs(nicknamesMap) do
            if nickKey:lower() == nickname:lower() and data.characters then
                local chars = {}
                for _, charData in ipairs(data.characters) do
                    chars[charData.character] = true
                end
                return chars
            end
        end
        return nil
    end
}

_G.NSAPI = _G.LiquidAPI

if WeakAuras then
    if WeakAuras.GetName then 
        WeakAuras.GetName = function(n)
            if not n then return end
            return GetNicknameByCharacter(n) or n
        end
    end

    if WeakAuras.UnitName then
        WeakAuras.UnitName = function(unit)
            if not unit then return end
            local n, s = UnitName(unit)
            if not n then return end
            return GetNicknameByCharacter(n) or n, s
        end
    end

    if WeakAuras.GetUnitName then
        WeakAuras.GetUnitName = function(unit, showServer)
            if not unit then return end
            local unitName = GetUnitName(unit, showServer)
            if not unitName then return end
            if not UnitIsPlayer(unit) then return unitName end
            
            if showServer then
                local n, s = strsplit("-", unitName)
                if s then
                    return string.format("%s-%s", (GetNicknameByCharacter(n) or n), s)
                end
                return GetNicknameByCharacter(n) or n
            else
                local n = unitName:match("^(%S*)")
                if unitName:find("%*") then
                    return string.format("%s (*)", (GetNicknameByCharacter(n) or n))
                end
                return GetNicknameByCharacter(n) or n
            end
        end
    end

    if WeakAuras.UnitFullName then
        WeakAuras.UnitFullName = function(unit)
            if not unit then return end
            local n, s = UnitFullName(unit)
            if not n then return end
            if UnitIsPlayer(unit) then
                return GetNicknameByCharacter(n) or n, s
            end
            return n, s
        end
    end
end

_G["GExRT"] = ART
_G["GMRT"] = ART
ART.frame:RegisterEvent("CHAT_MSG_ADDON")
ART.frame:RegisterEvent("ADDON_LOADED") 