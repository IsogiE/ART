--	13.09.2024

local GlobalAddonName, ART = ...

ART.V = 4920
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

ART.A = {}			--> ссылки на все модули

ART.msg_prefix = {
	["EARTADD"] = true,
	ARTADDA = true,	ARTADDB = true,	ARTADDC = true,
	ARTADDD = true,	ARTADDE = true,	ARTADDF = true,
	ARTADDG = true,	ARTADDH = true,	ARTADDI = true,
}

ART.L = {}			--> локализация
ART.locale = GetLocale()

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
		if this.Load then
			this:Load()
		end
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
		table.insert(ART.Modules,self)
		ART.A[moduleName] = self
		
		ART.F.dprint("New module: "..moduleName)
		
		return self
	end
end

function ART.mod:Event(event,...)
	return self[event](self,...)
end
if ART.T == "DU" then
	local ARTDebug = ART.Debug
	function ART.mod:Event(event,...)
		local dt = debugprofilestop()
		self[event](self,...)
		ARTDebug[#ARTDebug+1] = {debugprofilestop() - dt,self.name,event}
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

---------------> Mods <---------------

ART.F = {}
ART.mds = ART.F

-- Moved to Functions.lua

do
	local function TimerFunc(self)
		self.func(unpack(self.args))
	end
	function ART.F.ScheduleTimer(func, delay, ...)
		local self = nil
		if delay > 0 then
			self = C_Timer_NewTicker(delay,TimerFunc,1)
			-- Avoid C_Timer.NewTimer here cuz it runs ticker with 1 iteration anyway
		else
			self = C_Timer_NewTicker(-delay,TimerFunc)
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

SlashCmdList["ARTSlash"] = function (arg)
	local argL = strlower(arg)
	if argL == "icon" then
		VART.Addon.IconMiniMapHide = not VART.Addon.IconMiniMapHide
		if not VART.Addon.IconMiniMapHide then 
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
	elseif string.len(argL) == 0 then
		ART.Options:Open()
		return
	end
	for _,mod in pairs(ART.Slash) do
		mod:slash(argL,arg)
	end
end
SLASH_ARTSlash1 = "/ART"

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
					if str:find("AddOns[\\/]EART") then
						t[k] = str:gsub("(AddOns[\\/])EART","%1ART")
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
		VART = VART or {}
		VART.Addon = VART.Addon or {}

		if not VART.Addon.migrateART and VEART and VEART.Addon then
			VART = VEART

			migrateReplace(VART)
			migrateReplace()

			VART.Addon = VART.Addon or {}
			VART.Addon.migrateART = true
		end
		VEART = nil
		VEART = setmetatable({}, {
			__index = VART,
			__newindex = VART,
		})
		

		VART.Addon.Timer = VART.Addon.Timer or 0.1
		reloadTimer = VART.Addon.Timer

		if VART.Addon.IconMiniMapLeft and VART.Addon.IconMiniMapTop then
			ART.MiniMapIcon:ClearAllPoints()
			ART.MiniMapIcon:SetPoint("CENTER", VART.Addon.IconMiniMapLeft, VART.Addon.IconMiniMapTop)
		end
		
		if VART.Addon.IconMiniMapHide then 
			ART.MiniMapIcon:Hide() 
		end

		for prefix,_ in pairs(ART.msg_prefix) do
			C_ChatInfo.RegisterAddonMessagePrefix(prefix)
		end
		
		VART.Addon.Version = tonumber(VART.Addon.Version or "0")
		VART.Addon.PreVersion = VART.Addon.Version
		
		if ART.A.Profiles then
			ART.A.Profiles:ReselectProfileOnLoad()
		end
		
		ART.F.dprint("ADDON_LOADED event")
		ART.F.dprint("MODULES FIND",#ART.Modules)
		for i=1,#ART.Modules do
			loader(self,ART.Modules[i].main.ADDON_LOADED)

			ART.ModulesLoaded[i] = true
			
			ART.F.dprint("ADDON_LOADED",i,ART.Modules[i].name)
		end

		if not VART.Addon.DisableHideESC then
			tinsert(UISpecialFrames, "ARTOptionsFrame")
		end

		VART.Addon.Version = ART.V
		
		ART.F.ScheduleTimer(function()
			ART.frame:SetScript("OnUpdate", ART.frame.OnUpdate_Recreate)
		end,1)
		self:UnregisterEvent("ADDON_LOADED")

		ART.AddonLoaded = true

		if not ART.isClassic then
			if not VART.Addon.EJ_CHECK_VER or VART.Addon.EJ_CHECK_VER ~= ART.clientUIinterface or (((type(IsTestBuild)=="function" and IsTestBuild()) or (type(IsBetaBuild)=="function" and IsBetaBuild())) and VART.Addon.EJ_CHECK_VER_PTR ~= ART.clientBuildVersion) then
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

	local function OnUpdate_Recreate(self,elapsed)
		for k in pairs(OnUpdate_Funcs) do OnUpdate_Funcs[k]=nil end
		for mod,func in pairs(OnUpdate_Modules) do
			OnUpdate_Funcs[mod] = func
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
local prefix_sorted = {"EARTADD","ARTADDA","ARTADDB","ARTADDC","ARTADDD","ARTADDE","ARTADDF","ARTADDG","ARTADDH","ARTADDI"}

local sendPending = {}
local sendPrev = {0}
local sendTmr
local _SendAddonMessage = SendAddonMessage
local SEND_LIMIT = 10
local sendLimit = {SEND_LIMIT}
local function send(self)
	if self then
		sendTmr = nil
	end
	local t = debugprofilestop()
	for p=1,#prefix_sorted do
		sendLimit[p] = (sendLimit[p] or SEND_LIMIT) + floor((t - (sendPrev[p] or 0))/1000)
		if sendLimit[p] > SEND_LIMIT then
			sendLimit[p] = SEND_LIMIT
		elseif sendLimit[p] < -30 and sendPrev[p] and t < sendPrev[p] then
			sendPrev[p] = t
			sendLimit[p] = 0
		end
		if sendLimit[p] > 0 then
			local cp = 1
			for i=1,#sendPending do
				if sendLimit[p] <= 0 then
					break
				end
				local pendingNow = sendPending[cp]
				if (not pendingNow.prefixNum) or (pendingNow.prefixNum == p) then
					sendLimit[p] = sendLimit[p] - 1
					pendingNow[1] = prefix_sorted[p] --override prefix
					_SendAddonMessage(unpack(pendingNow))
					sendPrev[p] = debugprofilestop()
					if pendingNow.ondone then
						pendingNow.ondone()
					end
					tremove(sendPending, cp)
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
		if type(specialOpt.prefixNum)=="number" and specialOpt.prefixNum <= #prefix_sorted and specialOpt.prefixNum > 0 then
			entry.prefixNum = specialOpt.prefixNum
		end
		if type(specialOpt.ondone)=="function" then
			entry.ondone = specialOpt.ondone
		end
	end
	sendPending[#sendPending+1] = entry
	send()
end

function ART.F.SendExMsg(prefix, msg, tochat, touser, addonPrefix)
	addonPrefix = addonPrefix or "EARTADD"
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
	for _,mod in pairs(ART.OnAddonMessage) do
		mod:addonMessage(sender, prefix, ...)
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

_G["GEART"] = ART
_G["GART"] = ART
ART.frame:RegisterEvent("CHAT_MSG_ADDON")
ART.frame:RegisterEvent("ADDON_LOADED") 