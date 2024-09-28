local GlobalAddonName, ART = ...

local VART = nil

local module = ART:New("Note",ART.L.message)
local ELib,L = ART.lib,ART.L

local GetTime, GetSpecializationInfo = GetTime, GetSpecializationInfo
local string_gsub, strsplit, tonumber, format, string_match, floor, string_find, type, string_gmatch = string.gsub, strsplit, tonumber, format, string.match, floor, string.find, type, string.gmatch
local GetSpellInfo = ART.F.GetSpellInfo or GetSpellInfo
local NewVARTTableData

local GetSpecialization = GetSpecialization
if ART.isCata then
	GetSpecialization = function()
		local n,m = 1,1
		for spec=1,3 do
			local selectedNum = 0
			for talPos=1,22 do
				local name, iconTexture, tier, column, rank, maxRank, isExceptional, available = GetTalentInfo(spec, talPos)
				if name and maxRank > 0 and rank > 0 then
					selectedNum = selectedNum + 1
				end
			end
			if selectedNum > m then
				n = spec
				m = selectedNum
			end
		end
		return n
	end
	GetSpecializationInfo = function(specNum)
		local specs = ART.GDB.ClassSpecializationList[select(2,UnitClass'player')]
		if not specs or not specs[specNum] then
			return
		end
		local role = ART.GDB.ClassSpecializationRole[ specs[specNum] ]
		if role == "MELEE" or role == "RANGE" then
			role = "DAMAGER"
		elseif role == "HEAL" then
			role = "HEALER"
		end
		local _,name = GetSpecializationInfoForSpecID( specs[specNum] )
		return 0,name,0,0,role
	end
elseif ART.isClassic then
	GetSpecialization = ART.NULLfunc
end

module.db.otherIconsList = {
	{"{"..L.classLocalizate["WARRIOR"] .."}",crop=":16:16:0:0:256:256:0:64:0:64","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0,0.25,0,0.25},
	{"{"..L.classLocalizate["PALADIN"] .."}",crop=":16:16:0:0:256:256:0:64:128:192","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0,0.25,0.5,0.75},
	{"{"..L.classLocalizate["HUNTER"] .."}",crop=":16:16:0:0:256:256:0:64:64:128","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0,0.25,0.25,0.5},
	{"{"..L.classLocalizate["ROGUE"] .."}",crop=":16:16:0:0:256:256:127:190:0:64","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.49609375,0.7421875,0,0.25},
	{"{"..L.classLocalizate["PRIEST"] .."}",crop=":16:16:0:0:256:256:127:190:64:128","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.49609375,0.7421875,0.25,0.5},
	{"{"..L.classLocalizate["DEATHKNIGHT"] .."}",crop=":16:16:0:0:256:256:64:128:128:192","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.25,0.5,0.5,0.75},
	{"{"..L.classLocalizate["SHAMAN"] .."}",crop=":16:16:0:0:256:256:64:127:64:128","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.25,0.49609375,0.25,0.5},
	{"{"..L.classLocalizate["MAGE"] .."}",crop=":16:16:0:0:256:256:64:127:0:64","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.25,0.49609375,0,0.25},
	{"{"..L.classLocalizate["WARLOCK"] .."}",crop=":16:16:0:0:256:256:190:253:64:128","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.7421875,0.98828125,0.25,0.5},
	{"{"..L.classLocalizate["MONK"] .."}",crop=":16:16:0:0:256:256:128:189:128:192","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.5,0.73828125,0.5,0.75},
	{"{"..L.classLocalizate["DRUID"] .."}",crop=":16:16:0:0:256:256:190:253:0:64","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.7421875,0.98828125,0,0.25},
	{"{"..L.classLocalizate["DEMONHUNTER"] .."}",crop=":16:16:0:0:256:256:190:253:128:192","Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES",0.7421875,0.98828125,0.5,0.75},
	{"{"..L.classLocalizate["EVOKER"] .."}","interface/icons/classicon_evoker"},
	{"{wow}","Interface\\FriendsFrame\\Battlenet-WoWicon"},
	{"{d3}","Interface\\FriendsFrame\\Battlenet-D3icon"},
	{"{sc2}","Interface\\FriendsFrame\\Battlenet-Sc2icon"},
	{"{bnet}","Interface\\FriendsFrame\\Battlenet-Portrait"},
	{"{bnet1}","Interface\\FriendsFrame\\Battlenet-Battleneticon"},
	{"{alliance}","Interface\\FriendsFrame\\PlusManz-Alliance"},
	{"{horde}","Interface\\FriendsFrame\\PlusManz-Horde"},
	{"{hots}","Interface\\FriendsFrame\\Battlenet-HotSicon"},
	{"{ow}","Interface\\FriendsFrame\\Battlenet-Overwatchicon"},
	{"{sc1}","Interface\\FriendsFrame\\Battlenet-SCicon"},
	{"{barcade}","Interface\\FriendsFrame\\Battlenet-BlizzardArcadeCollectionicon"},
	{"{crashb}","Interface\\FriendsFrame\\Battlenet-CrashBandicoot4icon"},

	{"{tank}",path="Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",crop=":16:16:0:0:64:64:0:19:22:41","Interface\\LFGFrame\\UI-LFG-ICON-ROLES",0,0.26171875,0.26171875,0.5234375},
	{"{healer}",path="Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",crop=":16:16:0:0:64:64:20:39:1:20","Interface\\LFGFrame\\UI-LFG-ICON-ROLES",0.26171875,0.5234375,0,0.26171875},
	{"{dps}",path="Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",crop=":16:16:0:0:64:64:20:39:22:41","Interface\\LFGFrame\\UI-LFG-ICON-ROLES",0.26171875,0.5234375,0.26171875,0.5234375},
}

if ART.isClassic then
	tremove(module.db.otherIconsList,13)
	tremove(module.db.otherIconsList,12)
	tremove(module.db.otherIconsList,10)
	if not ART.isLK then tremove(module.db.otherIconsList,6) end
end

module.db.iconsLocalizatedNames = {
	L.raidtargeticon1,L.raidtargeticon2,L.raidtargeticon3,L.raidtargeticon4,L.raidtargeticon5,L.raidtargeticon6,L.raidtargeticon7,L.raidtargeticon8,
}
local iconsLangs = {"eng","de","it","fr","ru","es","pt"}
for _,lang in pairs(iconsLangs) do
	local new = {}
	module.db["icons"..lang.."Names"] = new
	for i=1,8 do
		new[i] = L["raidtargeticon"..i.."_"..lang]
	end
end

local frameStrataList = {"BACKGROUND","LOW","MEDIUM","HIGH","DIALOG","FULLSCREEN","FULLSCREEN_DIALOG","TOOLTIP"}

module.db.msgindex = -1
module.db.lasttext = ""

module.db.encounter_time_p = {}	--phases
module.db.encounter_time_c = {}	--custom
module.db.encounter_time_wa_uids = {}	--wa custom events
module.db.encounter_id = {}

local encounter_time_p = module.db.encounter_time_p
local encounter_time_c = module.db.encounter_time_c
local encounter_time_wa_uids = module.db.encounter_time_wa_uids
local encounter_id = module.db.encounter_id

local predefSpellIcons = {	--some talents can replace icons for basic spells
	[47536] = 237548,
	[1022] = 135964,
}

local function GSUB_Icon(spellID,iconSize)
	spellID = tonumber(spellID)

	if not iconSize or iconSize == "" then
		iconSize = 16
	else
		iconSize = min(tonumber(iconSize),40)
	end

	local preicon = predefSpellIcons[spellID]
	if preicon then
		return "|T"..preicon..":"..iconSize.."|t"
	end

	local spellTexture = select(3,GetSpellInfo(spellID))
	return "|T"..(spellTexture or "Interface\\Icons\\INV_MISC_QUESTIONMARK")..":"..iconSize.."|t"
end

local function GSUB_Player(anti,list,msg)
	list = {strsplit(",",list)}
	local found = false
	local myName = (ART.SDB.charName):lower()
	for i=1,#list do
		list[i] = list[i]:gsub("|?|c........",""):gsub("|?|r",""):lower()
		if strsplit("-",list[i]) == myName then
			found = true
			break
		end
	end

	if (found and anti == "") or (not found and anti == "!") then
		return msg
	else
		return ""
	end
end

local function GSUB_Encounter(list,msg)
	list = {strsplit(",",list)}
	local found = false
	for i=1,#list do
		list[i] = list[i]:gsub("|?|c........",""):gsub("|?|r",""):lower()
		if encounter_id[ list[i] ] then
			found = true
			break
		end
	end

	if found then
		return msg
	else
		return ""
	end
end

local classList = {
	[L.classLocalizate.WARRIOR:lower()] = 1,
	[L.classLocalizate.PALADIN:lower()] = 2,
	[L.classLocalizate.HUNTER:lower()] = 3,
	[L.classLocalizate.ROGUE:lower()] = 4,
	[L.classLocalizate.PRIEST:lower()] = 5,
	[L.classLocalizate.DEATHKNIGHT:lower()] = 6,
	[L.classLocalizate.SHAMAN:lower()] = 7,
	[L.classLocalizate.MAGE:lower()] = 8,
	[L.classLocalizate.WARLOCK:lower()] = 9,
	[L.classLocalizate.MONK:lower()] = 10,
	[L.classLocalizate.DRUID:lower()] = 11,
	[L.classLocalizate.DEMONHUNTER:lower()] = 12,
	[L.classLocalizate.EVOKER:lower()] = 13,
	["warrior"] = 1,
	["paladin"] = 2,
	["hunter"] = 3,
	["rogue"] = 4,
	["priest"] = 5,
	["deathknight"] = 6,
	["shaman"] = 7,
	["mage"] = 8,
	["warlock"] = 9,
	["monk"] = 10,
	["druid"] = 11,
	["demonhunter"] = 12,
	["evoker"] = 13,
	["war"] = 1,
	["pal"] = 2,
	["hun"] = 3,
	["rog"] = 4,
	["pri"] = 5,
	["dk"] = 6,
	["sham"] = 7,
	["lock"] = 9,
	["dru"] = 11,
	["dh"] = 12,
	["dragon"] = 13,
	["1"] = 1,
	["2"] = 2,
	["3"] = 3,
	["4"] = 4,
	["5"] = 5,
	["6"] = 6,
	["7"] = 7,
	["8"] = 7,
	["9"] = 9,
	["10"] = 10,
	["11"] = 11,
	["12"] = 12,
	["13"] = 13,
}

local function GSUB_Class(anti,list,msg)
	list = {strsplit(",",list)}
	local myClassIndex = select(3,UnitClass("player"))
	local found = false
	for i=1,#list do
		list[i] = list[i]:gsub("|?|c........",""):gsub("|?|r",""):lower()
		if classList[ list[i] ] == myClassIndex then
			found = true
			break
		end
	end

	if (found and anti == "") or (not found and anti == "!") then
		return msg
	else
		return ""
	end
end

local function GSUB_ClassUnique(list,msg)
	list = {strsplit(",",list)}
	local classInParty = {}
	for _, name, subgroup, class, guid, rank, level, online, isDead, combatRole in ART.F.IterateRoster, ART.F.GetRaidDiffMaxGroup() do
		if class then
			classInParty[ classList[class:lower()] or 0 ] = true
		end
	end

	local found = nil

	for i=1,#list do
		list[i] = list[i]:gsub("|?|c........",""):gsub("|?|r",""):lower()
		local classID = classList[ list[i] ]
		if classID and classInParty[classID] then
			found = classID
			break
		end
	end

	local myClassIndex = select(3,UnitClass("player"))
	if found == myClassIndex then
		found = true
	else
		found = false
	end

	if found then
		return msg
	else
		return ""
	end
end

local function GSUB_Race(anti,list,msg)
	list = {strsplit(",",list)}
	local myRace = select(2,UnitRace("player")):lower()
	local found = false
	for i=1,#list do
		list[i] = list[i]:gsub("|?|c........",""):gsub("|?|r",""):lower()
		if list[i] == myRace then
			found = true
			break
		end
	end

	if (found and anti == "") or (not found and anti == "!") then
		return msg
	else
		return ""
	end
end

local function GSUB_Group(anti,groups,msg)
	local myGroup = 1
	if IsInRaid() then
		for i=1,GetNumGroupMembers() do
			local name, _, subgroup = GetRaidRosterInfo(i)
			if name == ART.SDB.charName then
				myGroup = subgroup
				break
			end
		end
	end
	myGroup = tostring(myGroup)
	local found = groups:find(myGroup)

	if (found and anti == "") or (not found and anti == "!") then
		return msg
	else
		return ""
	end
end

--[[
formats:
{time:75}
{time:1:15}
{time:2:30,p2}	--start on phase 2, works only with bigwigs
{time:0:30,SCC:17:2}	--start on combat log event. format "event:spellID:counter", events: SCC (SPELL_CAST_SUCCESS), SCS (SPELL_CAST_START), SAA (SPELL_AURA_APPLIED), SAR (SPELL_AURA_REMOVED)
{time:0:30,e,customevent}	--start on ART.F.Note_Timer(customevent) function or "/rt note starttimer customevent" 
{time:2:30,wa:nzoth_hs1}	--run weakauras custom event ART_NOTE_TIME_EVENT with arg1 = nzoth_hs1, arg2 = time left (event runs every second when timer has 5 seconds or lower), arg3 = note line text
]]

local function GSUB_Time(preText,t,msg,newlinesym)
	local timeText, opts = strsplit(",", t, 2)

	local time = tonumber(timeText)
	if not time then
		local min, sec = strsplit(":", timeText)
		if min and sec then
			time = (tonumber(min) or 0) * 60 + (tonumber(sec) or 0)
		else
			time = -1
		end
	end
	local prefixText

	local anyType
	local now = GetTime()
	local waEventID
	local addGlow
	local isAllParam
	
	local optNow
	while opts do
		optNow, opts = strsplit(",", opts, 2)

		if optNow == "e" then
			if opts then
				optNow, opts = strsplit(",", opts, 2)
			else
				optNow = nil
			end
			if optNow then
				local customEventStart = encounter_time_c[optNow]
				if customEventStart then
					time = customEventStart + time - now
					--prefixText = "C "
					anyType = 1
				else
					anyType = 2
				end
			end
		elseif optNow:sub(1,1) == "p" then
			local isGlobalPhase,phase = optNow:match("^p(g?):?(.-)$")
			if phase and phase ~= "" then
				local prefixText = "P"..phase.." "

				local phaseStart = encounter_time_p[(isGlobalPhase == "g" and "g" or "")..phase]

				if phaseStart then
					time = phaseStart + time - now
					anyType = 1
				else
					anyType = 2
				end			
			end
		elseif optNow == "glow" then
			addGlow = 1
		elseif optNow == "glowall" then
			addGlow = 2
			isAllParam = true
		elseif optNow == "all" then
			isAllParam = true
		else
			local prefix, arg1 = strsplit(":", optNow, 2)
			if prefix == "wa" then
				waEventID = (waEventID and waEventID.."," or "")..arg1
			elseif prefix == "SCC" or prefix == "SCS" or prefix == "SAA" or prefix == "SAR" then
				local eventStart = module.db.encounter_counters_time[optNow]
				if eventStart then
					time = eventStart + time - now
					--prefixText = "E "
					anyType = 1
				else
					anyType = 2
				end
			end
		end
	end

	if not anyType and module.db.encounter_time then
		time = module.db.encounter_time + time - now
	end

	if waEventID and time <= 20 and type(WeakAuras)=="table" and ((module.db.encounter_time and not anyType) or anyType == 1) then
		local timeleft = time < 0 and 0 or ceil(time)
		if timeleft <= 5 or timeleft % 5 == 0 then
			for waEventIDnow in string_gmatch(waEventID, "[^,]+") do
				local wa_event_uid_cache = waEventIDnow..":"..timeleft..":"..preText..t..msg..newlinesym
				if not encounter_time_wa_uids[wa_event_uid_cache] then
					encounter_time_wa_uids[wa_event_uid_cache] = true
					if WeakAuras.ScanEvents and type(WeakAuras.ScanEvents)=="function" then
						WeakAuras.ScanEvents("EART_NOTE_TIME_EVENT",waEventIDnow,timeleft,msg)
						WeakAuras.ScanEvents("ART_NOTE_TIME_EVENT",waEventIDnow,timeleft,msg)
					end
				end
			end
		end
	end

	if not msg:find(ART.SDB.charName) and not msg:find("{everyone}") and VART.Note.TimerOnlyMy and not isAllParam then
		return ""
	end

	if time > 10 or not module.db.encounter_time or anyType == 2 then
		return preText.."|cffffed88"..(prefixText or "")..format("%d:%02d|r ",floor(time/60),time % 60)..msg..newlinesym
	elseif time < 0 then
		if VART.Note.TimerPassedHide then
			return ""
		else
			return preText.."|cff555555"..(prefixText or "")..msg:gsub("|c........",""):gsub("|r","").."|r"..newlinesym
		end
	else
		if time <= 5 and ((msg:find(ART.SDB.charName) and (VART.Note.TimerGlow or addGlow == 1)) or (addGlow == 2)) then
			module.db.glowStatus = true
		end
		return preText.."|cff00ff00"..(prefixText or "")..format("%d:%02d ",floor(time/60),time % 60)..msg:gsub("|c........",""):gsub("|r",""):gsub(ART.SDB.charName,"|r|cffff0000>%1<|r|cff00ff00").."|r"..newlinesym
	end
end

local function GSUB_Phase(anti,phase,msg)
	if not module.db.encounter_time then
		return msg
	else
		local isPhase
		local phaseNum = tonumber(phase)
		if phaseNum then
			isPhase = encounter_time_p[phase]
		elseif phase:sub(1,1) == "," then
			local cond1,cond2 = strsplit(",",phase:sub(2),nil)
			isPhase = cond1 and module.db.encounter_counters_time[cond1] and (not cond2 or not module.db.encounter_counters_time[cond2])
		else
			isPhase = encounter_time_p[phase]
		end
		if (isPhase and anti == "") or (not isPhase and anti == "!") then
			return msg
		else
			return ""
		end
	end
end

local allIcons = {
	["everyone"] = "",
}
for i=1,8 do
	local icon = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_"..i..":0|t"
	allIcons[ module.db.iconsLocalizatedNames[i] ] = icon
	allIcons[ "{rt"..i.."}" ] = icon

	for _,lang in pairs(iconsLangs) do
		allIcons[ module.db["icons"..lang.."Names"][i] ] = icon
	end
end
for i=1,#module.db.otherIconsList do
	local iconData = module.db.otherIconsList[i]	
	allIcons[ iconData[1] ] = "|T"..(iconData.path or iconData[2])..(iconData.crop or ":16").."|t"
end

local function GSUB_RaidIcon(text)
	return allIcons[text]
end

local GSUB_AutoColor_Data = {}
local function GSUB_AutoColorCreate()
	wipe(GSUB_AutoColor_Data)
	for _, name, subgroup, class, guid, rank, level, online, isDead, combatRole in ART.F.IterateRoster, ART.F.GetRaidDiffMaxGroup() do
		if class and name then
			class = ART.F.classColor(class)
			GSUB_AutoColor_Data[ name ] = "|c"..class..name.."|r"
			name = strsplit("-",name)
			GSUB_AutoColor_Data[ name ] = "|c"..class..name.."|r"
		end
	end
end
local function GSUB_AutoColor(text)
	return GSUB_AutoColor_Data[text]
end

local txtWithIcons
do
	txtWithIcons = function(self, t, onlyTimerUpdate)
		if not onlyTimerUpdate or not self.preTimerText then
			t = t or ""
	
			if t:find("{self}") then
				t = string_gsub(t,"{self}",VART.Note.SelfText or "")
			end
			
			local spec = GetSpecialization()
			if spec then
				local role = select(5,GetSpecializationInfo(spec))
				if role ~= "HEALER" then t = string_gsub(t,"{[Hh]}.-{/[Hh]}","") end
				if role ~= "TANK" then t = string_gsub(t,"{[Tt]}.-{/[Tt]}","") end
				if role ~= "DAMAGER" then t = string_gsub(t,"{[Dd]}.-{/[Dd]}","") end
			end
	
			t =    t:gsub("{0}.-{/0}","")
				:gsub("(\n{!?[CcPpGg]:?[^}]+})\n","%1")
				:gsub("\n({/[CcPpGg]}\n)","%1")
				:gsub("{(!?)[Pp]:([^}]+)}(.-){/[Pp]}",GSUB_Player)
				:gsub("{(!?)[Cc]:([^}]+)}(.-){/[Cc]}",GSUB_Class)
				:gsub("{[Cc][Ll][Aa][Ss][Ss][Uu][Nn][Ii][Qq][Uu][Ee]:([^}]+)}(.-){/[Cc][Ll][Aa][Ss][Ss][Uu][Nn][Ii][Qq][Uu][Ee]}",GSUB_ClassUnique)
				:gsub("{(!?)[Gg](%d+)}(.-){/[Gg]}",GSUB_Group)
				:gsub("{(!?)[Rr][Aa][Cc][Ee]:([^}]+)}(.-){/[Rr][Aa][Cc][Ee]}",GSUB_Race)
				:gsub("{[Ee]:([^}]+)}(.-){/[Ee]}",GSUB_Encounter)
				:gsub("{(!?)[Pp]([^}:][^}]*)}(.-){/[Pp]}",GSUB_Phase)
				:gsub("{icon:([^}]+)}","|T%1:16|t")
				:gsub("{spell:(%d+):?(%d*)}",GSUB_Icon)
				--:gsub("%b{}",GSUB_RaidIcon)
				:gsub("%b{}",allIcons)
				:gsub("||([cr])","|%1")
				--:gsub("[^ \n,]+",GSUB_AutoColor)
				:gsub("[^ \n,%(%)%[%]_%$#@!&]+",GSUB_AutoColor_Data)
				:gsub("\n+$", "")
	
			self.preTimerText = t
		else
			t = self.preTimerText
		end
	
		return t:gsub("([^\n]*){time:([0-9:%.]+[^{}]*)}([^\n]*)(\n?)",GSUB_Time)
			:gsub("%b{}",""), nil		
	end
end

function module.options:Load()
	self:CreateTilte()

	module.db.otherIconsAdditionalList = ART.isClassic and {} or {
		31821,62618,97462,98008,115310,64843,740,265202,108280,31884,196718,15286,64901,47536,246287,109964,33891,16191,108281,114049,51052,359816,363534,322118,325197,124974,197721,0,
		47788,33206,6940,102342,114030,1022,116849,633,204018,207399,370960,357170,370537,0,
		2825,32182,80353,0,
		106898,192077,46968,119381,179057,192058,30283,0,
		29166,32375,114018,108199,49576,116844,0,
		0,
		435136,438012,440849,462472,435138,438657,439037,434705,435341,449268,434776,440177,439419,443842,436255,455870,438324,434697,441451,440904,0,
		445570,444363,443042,461876,442530,445174,445016,445257,445936,443305,445518,451288,443612,438696,452237,0,
		434860,439559,442428,458272,435401,456420,439511,461401,459785,432969,435410,459273,461797,433475,0,
		439785,439778,452806,460789,439787,439795,439811,457877,444687,440193,439784,444094,439780,454989,439776,439815,439792,455287,458067,439789,0,
		443274,446351,446700,442430,450661,441362,452802,442526,442251,441612,442257,442660,438847,442263,458212,446349,446690,446694,0,
		435414,439576,440576,436950,436749,435486,440377,447174,436867,437620,442278,434645,439409,437343,437786,448364,438245,0,
		455080,449993,439992,460357,450483,460359,438656,460281,460360,438200,441634,450045,456235,438706,438218,438801,460600,440504,440158,438773,450129,441782,455863,455849,443092,455850,443063,450980,438677,451277,455363,443598,449857,0,
		437078,439299,451600,440607,438481,443915,445268,444829,443396,451832,451366,438976,460218,443325,447965,438846,443667,447950,443720,441556,443336,441084,448660,448046,447999,460366,441872,448488,445021,451607,445013,448300,437417,448458,445152,446012,451278,440899,447411,449940,455374,445877,444507,445623,439814,443888,444502,447170,445422,447076,460133,448147,441958,460315,449235,437592,441692,448176,441865,437093,443403,447983,0,
		0,
		422053,421038,422023,422039,421350,421986,421971,422026,429009,424352,425709,421840,421013,422373,425648,428992,425819,425816,421898,0,
		424347,429277,416056,414770,422776,423715,420251,419462,414425,414340,418533,426017,423108,414367,415624,419048,416998,0,
		421675,423494,429153,421672,427211,420934,421703,423117,420421,424218,421284,419054,421082,421616,427201,0,
		420937,424975,418187,421024,421032,423551,425389,418720,423522,420856,420409,426390,422372,420671,421020,420966,427602,421292,420525,421029,427010,424269,425114,420946,0,
		418535,417660,421326,418637,417653,421323,422461,421318,418522,428946,421594,426242,429032,427306,427343,428896,419485,421316,417610,426387,425531,417634,427252,424997,426524,425889,423719,417583,0,
		430485,430563,428471,426154,420846,425357,423195,427722,428273,418423,423993,429785,425794,425370,429108,423369,423842,428479,428012,421368,420907,426855,0,
		421643,421961,424233,425574,430325,422067,422577,426018,420950,426725,422172,421656,423896,421858,421455,422277,423904,422691,421532,0,
		425657,422503,424495,422000,424581,421939,424582,421603,430583,424665,422325,421398,424258,420236,425607,426669,427297,421884,424140,423260,421636,429166,422509,429740,424499,426687,425610,420240,0,
	}
	if ART.isCata then
		module.db.otherIconsAdditionalList = {
			"136224","135821","135808","135981","136209","135807","135813","463567","237588","237395","135822",0,
			"237582","133598","135790","236216","252172","524793","510756","132847",0,
			"514340","237555","135767","134157","136186","135818","132847","236297","132839","236305","236216","135811","237588","135788","135823","135827","512617","459026","135808","132929","237553","459027","237582","451169","132360","135867","237554",0,
			"135834","132103","132090","136022","132152","132155","132324","135813","135830","136224",0,
			"132847","135279","425958","236220","136106","136136","132839","136160","237570","133265","236216",0,
			"451164","236225","236310","459027","132847","458737","237588","135811",0,
			"525023","132221","525024","525025","525026","451164","135818","135822","135826","236301","135807","135859","236228","135265","135827","512617","132315","136100","464484","236216","515200","132847","451169","135821","135805","135788",0,
			0,
			"332402","132108","425956","132363","451165","425957",0,
			"136201","132303","136224","237298","136158","236280","463569","252178",0,
			"237561","132303","237569","135809","136016","134820","136171","236271",0,
			"429385","136014","237236","136048","135840","236209","132852","136049","254883","135851","294033",0,
			"425950","134154","132146","134430","135994","132291","136223","134155","134157","134156","425953","425957","134153","237566",0,
			"132337","425954","135752","425955","236299","236312","136129","525023","460700","132352","425960","135291","425953","135826","237530","132367",0,
			"132847","538040","538041","133035","236372","525023","236290","135805","459026","132842","538042","538043","463567",0,
			"135821","237536","135860","237513","575541","236316","135818","135822","134156","236305","236216","132312","236154","136106","134157","135734","134155","237556","575534","538040","575535","134158","575536","524795","237514",0,

		}
	elseif ART.isBC then
		module.db.otherIconsAdditionalList = {
			26983,2825,32182,16190,0,0,
			38219,38215,36459,38246,37478,37138,37675,37640,37641,38441,38445,37764,38316,38310,38509,38280,0,
			34172,25778,34162,39329,42783,11829,36834,36815,34480,30225,37027,36723,35879,"135188","135507","135379","132455","133528","135682","134976",0,
		}
	end

	function self:DebugGetIcons(notUseJJBox,onlyTextures)
		local L,U,F,C,P
		local RES = nil
		function F(eID)
			local f=select(4,EJ_GetEncounterInfoByIndex(eID))
			repeat 
				local I=C_EncounterJournal.GetSectionInfo(f)
				local O=I and (I.headerType == 3)
				if O then 
					f=I.siblingSectionID 
				end 
			until not O 
			return f 
		end
		function C(f) 
			local I=C_EncounterJournal.GetSectionInfo(f) 
			if I.firstChildSectionID then 
				C(I.firstChildSectionID)
			end 
			if onlyTextures then
				if I.abilityIcon and I.abilityIcon~=0 then 
					L[I.abilityIcon]=true 
				end 
			else
				if I.spellID and I.spellID~=0 and P(I.spellID) then 
					L[I.spellID]=true 
				end 
			end
			if I.siblingSectionID then 
				C(I.siblingSectionID) 
			end 
		end
		function P(s)
			local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
			local i=GetSpellTexture(s)
			if not U[i] then 
				U[i]=1 
				return true 
			end 
		end 
		local i = 1
		while EJ_GetEncounterInfoByIndex(i) do
			L,U={},{} 
			local f=F(i) 
			C(f)
			local s="" 
			for q,w in pairs(L)do 
				s=s..(onlyTextures and '"' or "")..q..(onlyTextures and '"' or "").."," 
			end 
			print(s..'0,')
			if not notUseJJBox then
				JJBox(s..'0,') 
			else
				RES = (RES or "")..s.."0,\n"
			end
			i = i + 1
		end
		if notUseJJBox then
			GART.F:Export2(RES)
		end
	end
	--/run GART.A.Note.options:DebugGetIcons(true)

	if not ART.isClassic then
		module.db.encountersList = ART.F.GetEncountersList(true,false,true)
		tinsert(module.db.encountersList,ART.F.table_find(module.db.encountersList,1582,1) or #module.db.encountersList,{EXPANSION_NAME8..": "..DUNGEONS,-1182,-1183,-1184,-1185,-1186,-1187,-1188,-1189})
		tinsert(module.db.encountersList,ART.F.table_find(module.db.encountersList,909,1) or #module.db.encountersList,{EXPANSION_NAME7..": "..DUNGEONS,-1012,-968,-1041,-1022,-1030,-1023,-1002,-1001,-1036,-1021})
	else
		module.db.encountersList = {}
	end

	module.db.mapToEncounter = {
		--BfD
		[1358] = {2265,2263,2266},
		[1352] = {2276,2280},
		[1353] = 2271,
		[1354] = 2268,
		[1357] = 2272,
		[1364] = 2281,

		--Uldir
		[1148] = 2144,
		[1149] = 2141,
		[1151] = 2136,
		[1153] = 2128,
		[1152] = 2134,
		[1154] = {2145,2135},
		[1155] = 2122,

		--5ppl
		[1010] = -1012,
		[934] = -968,	[935] = -968,
		[1004] = -1041,
		[1041] = -1022,	[1042] = -1022,
		[1038] = -1030,	[1043] = -1030,

		[1162] = -1023,
		[974] = -1002,	[975] = -1002,	[974] = -1002,	[975] = -1002,	[976] = -1002,	[977] = -1002,	[978] = -1002,	[979] = -1002,	[980] = -1002,
		[936] = -1001,
		[1039] = -1036,	[1040] = -1036,
		[1015] = -1021,	[1016] = -1021,	[1017] = -1021,	[1018] = -1021,	[1029] = -1021,

		--nyalotha
		[1581] = {2329,2327,2334},
		[1592] = 2328,
		[1593] = 2336,
		[1590] = 2333,
		[1591] = 2331,
		[1594] = 2335,
		[1595] = 2343,
		[1596] = 2345,
		[1597] = {2337,2344},

		--5ppl
		[1666] = -1182,	[1667] = -1182,	[1668] = -1182,
		[1674] = -1183,	[1697] = -1183,
		[1669] = -1184,
		[1663] = -1185,	[1664] = -1185,	[1665] = -1185,
		[1693] = -1186,	[1694] = -1186,	[1695] = -1186,
		[1683] = -1187,	[1684] = -1187,	[1685] = -1187,	[1687] = -1187,
		[1677] = -1188,	[1678] = -1188,	[1679] = -1188,	[1680] = -1188,
		[1675] = -1189,	[1676] = -1189,

		--nathria
		[1735] = {2398,2418,2383,2399},
		[1744] = 2406,
		[1745] = 2405,
		[1746] = 2402,
		[1747] = {2417,2407},
		[1748] = 2407,
		[1750] = 2412,

		--sod
		[1998] = 2423,
		[1999] = {2433,2429},
		[2000] = {2432,2434,2430},
		[2001] = {2436,2431,2422},
		[2002] = 2435,

		--sotfo
		[2047] = 2512,
		[2048] = 2540,
		[2049] = {2544,2539},
		[2061] = {2542,2553,2529},
		[2050] = 2546,
		[2052] = {2543,2549},
		[2051] = 2537,

		--a
		[2166] = {2688,2693,2680,2689,2683},
		[2167] = 2687,
		[2168] = 2682,
		[2169] = 2684,
		[2170] = 2685,

		[2232] = 2820,
		[2244] = {2731,2737},
		[2240] = {2708,2728},
		[2233] = 2824,
		[2237] = 2786,
		[2238] = 2677,
	}


	function self:GetBossName(bossID)
		return bossID < 0 and L.EJInstanceName[ -bossID ] or L.bossName[ bossID ]
	end

	local BlackNoteNow = nil
	local NoteIsSelfNow = nil
	self.IsMainNoteNow = true

	self.decorationLine = ELib:DecorationLine(self,true,"BACKGROUND",-5):Point("TOPLEFT",self,0,-16):Point("BOTTOMRIGHT",self,"TOPRIGHT",0,-36)

	self.tab = ELib:Tabs(self,0,L.message,L.minimapmenuset,L.Profiles,HELP_LABEL):Point(0,-36):Size(850,598):SetTo(1)
	self.tab:SetBackdropBorderColor(0,0,0,0)
	self.tab:SetBackdropColor(0,0,0,0)

	self.tab.tabs[1]:SetPoint("TOPLEFT",0,20)

	ELib:DecorationLine(self.tab.tabs[1]):Point("TOPLEFT",0,-129):Point("BOTTOMRIGHT",'x',"TOPRIGHT",0,-130)

	self.NotesList = ELib:ScrollList(self.tab.tabs[1]):Size(230,467+20):Point(0,-131):AddDrag():HideBorders()
	self.NotesList.selected = 1
	self.NotesList.LINE_PADDING_LEFT = 2
	self.NotesList.SCROLL_WIDTH = 12

	self.NotesList.Frame.ScrollBar:Size(10,0):Point("TOPRIGHT",0,0):Point("BOTTOMRIGHT",0,0)
	self.NotesList.Frame.ScrollBar.buttonUP:HideBorders()
	self.NotesList.Frame.ScrollBar.buttonDown:HideBorders()

	ELib:DecorationLine(self.NotesList.Frame.ScrollBar):Point("TOPLEFT",-1,1):Point("BOTTOMRIGHT",'x',"BOTTOMLEFT",0,0)
	ELib:DecorationLine(self.tab.tabs[1]):Point("TOPLEFT",self.NotesList,"TOPRIGHT",0,1):Point("BOTTOMLEFT",self,"BOTTOM",0,0):Size(1,0)

	local function SwapBlackNotes(noteFrom,noteTo)
		if noteTo < 1 or noteFrom < 1 or noteTo > #VART.Note.Black or noteFrom > #VART.Note.Black or not VART.Note.Black[noteTo] or not VART.Note.Black[noteFrom] then
			return
		end
		local text = VART.Note.Black[noteTo]
		local title = VART.Note.BlackNames[noteTo]
		local boss = VART.Note.AutoLoad[noteTo]
		local lastUpdateName = VART.Note.BlackLastUpdateName[noteTo]
		local lastUpdateTime = VART.Note.BlackLastUpdateTime[noteTo]

		VART.Note.Black[noteTo] = VART.Note.Black[noteFrom]
		VART.Note.BlackNames[noteTo] = VART.Note.BlackNames[noteFrom]
		VART.Note.AutoLoad[noteTo] = VART.Note.AutoLoad[noteFrom]
		VART.Note.BlackLastUpdateName[noteTo] = VART.Note.BlackLastUpdateName[noteFrom]
		VART.Note.BlackLastUpdateTime[noteTo] = VART.Note.BlackLastUpdateTime[noteFrom]

		VART.Note.Black[noteFrom] = text
		VART.Note.BlackNames[noteFrom] = title
		VART.Note.AutoLoad[noteFrom] = boss
		VART.Note.BlackLastUpdateName[noteFrom] = lastUpdateName
		VART.Note.BlackLastUpdateTime[noteFrom] = lastUpdateTime

		module.options:NotesListUpdateNames()
		module.options.NotesList.selected = noteTo + 2
		module.options.NotesList:Update()
	end

	self.NotesList.ButtonMoveUp = CreateFrame("Button",nil,self.NotesList)
	self.NotesList.ButtonMoveUp:Hide()
	self.NotesList.ButtonMoveUp:SetSize(8,8)
	self.NotesList.ButtonMoveUp:SetScript("OnClick",function(self)
		SwapBlackNotes(self.index,self.index - 1)
	end)
	self.NotesList.ButtonMoveUp.i = self.NotesList.ButtonMoveUp:CreateTexture()
	self.NotesList.ButtonMoveUp.i:SetPoint("CENTER")
	self.NotesList.ButtonMoveUp.i:SetSize(16,16)
	self.NotesList.ButtonMoveUp.i:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
	self.NotesList.ButtonMoveUp.i:SetTexCoord(0.25,0.3125,0.625,0.5)

	self.NotesList.ButtonMoveDown = CreateFrame("Button",nil,self.NotesList)
	self.NotesList.ButtonMoveDown:Hide()
	self.NotesList.ButtonMoveDown:SetSize(8,8)
	self.NotesList.ButtonMoveDown:SetScript("OnClick",function(self)
		SwapBlackNotes(self.index,self.index + 1)
	end)
	self.NotesList.ButtonMoveDown.i = self.NotesList.ButtonMoveDown:CreateTexture()
	self.NotesList.ButtonMoveDown.i:SetPoint("CENTER")
	self.NotesList.ButtonMoveDown.i:SetSize(16,16)
	self.NotesList.ButtonMoveDown.i:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\DiesalGUIcons16x256x128")
	self.NotesList.ButtonMoveDown.i:SetTexCoord(0.25,0.3125,0.5,0.625)


	self.NotesList.UpdateAdditional = function(self,val)
		self.ButtonMoveUp:Hide()
		self.ButtonMoveDown:Hide()
		for i=1,#self.List do
			local line = self.List[i]
			if line.index == 1 or line.index == 2 or line.index == #self.L or line.index == self.selected then
				line.ignoreDrag = true
			else
				line.ignoreDrag = false
			end
		end
		for i=1,#self.List-1 do
			if self.selected == self.List[i].index then
				self.ButtonMoveUp:SetPoint("BOTTOMRIGHT",self.List[i],"RIGHT",-2,0)
				self.ButtonMoveDown:SetPoint("TOPRIGHT",self.List[i],"RIGHT",-2,0)
				self.ButtonMoveUp:SetParent(self.List[i])
				self.ButtonMoveDown:SetParent(self.List[i])
				self.ButtonMoveUp.index = self.List[i].index - 2
				self.ButtonMoveDown.index = self.List[i].index - 2
				if i > 3 then
					self.ButtonMoveUp:Show()
				end
				if i >= 3 and i <= #self.List-2 then
					self.ButtonMoveDown:Show()
				end
				return
			end
		end
	end

	local function NotesListUpdateNames()
		local bossesToGreen = {}
		local mapID = C_Map.GetBestMapForUnit("player")
		if mapID and module.db.mapToEncounter[mapID] then
			local encounters = module.db.mapToEncounter[mapID]
			if type(encounters) == 'table' then
				for i=1,#encounters do
					bossesToGreen[ encounters[i] ] = true
				end
			else
				bossesToGreen[encounters] = true
			end
		end
		self.NotesList.L = {}

		self.NotesList.L[1] = "|cff55ee55"..L.messageTab1
		self.NotesList.L[2] = L.NoteSelf
		for i=1,#VART.Note.Black do
			self.NotesList.L[i+2] = (VART.Note.AutoLoad[i] and (bossesToGreen[ VART.Note.AutoLoad[i] ] and "|cff00ff00" or "|cffffff00").."["..module.options:GetBossName(VART.Note.AutoLoad[i]).."]|r" or "")..(VART.Note.BlackNames[i] or i)
		end
		self.NotesList.L[#self.NotesList.L + 1] = "|cff00aaff"..L.NoteAdd
		self.NotesList:Update()
	end
	NotesListUpdateNames()
	self.NotesListUpdateNames = NotesListUpdateNames

	local function UpdatePageAfterGettingNote()
		if NoteIsSelfNow then
			self.NotesList:SetListValue(2)
		elseif BlackNoteNow then
			self.NotesList:SetListValue(BlackNoteNow + 2)
		else
			self.NotesList:SetListValue(1)
		end
	end
	self.UpdatePageAfterGettingNote = UpdatePageAfterGettingNote

	module.options.LastIndex = 1
	function self.NotesList:SetListValue(index)
		module.options.LastIndex = index

		module.options.buttonsend:SetShown(index == 1)
		module.options.buttoncopy:SetShown(index > 2)
		module.options.buttonwindow:SetShown(index > 2)
		module.options.buttoncopyPersonal:SetShown(index > 2)

		BlackNoteNow = nil
		NoteIsSelfNow = nil
		module.options.IsMainNoteNow = nil

		if index == 1 then
			module.options.DraftName:Enable()
			module.options.RemoveDraft:Disable()
			module.options.autoLoadDropdown:Enable()
		elseif index > 2 then
			module.options.DraftName:Enable()
			module.options.RemoveDraft:Enable()
			module.options.autoLoadDropdown:Enable()
		else
			module.options.DraftName:Disable()
			module.options.RemoveDraft:Disable()
			module.options.autoLoadDropdown:Disable()
		end

		if index == 1 then
			module.options.NoteEditBox.EditBox:SetText(VART.Note.Text1 or "")
			--module.options.DraftName:SetText( L.messageTab1 )

			module.options.IsMainNoteNow = true

			module.options.DraftName:SetText( VART.Note.DefName or "" )

			module.options.autoLoadDropdown:SetText(VART.Note.AutoLoad[0] and module.options:GetBossName(VART.Note.AutoLoad[0]) or "-")
		elseif index == 2 then
			module.options.NoteEditBox.EditBox:SetText(VART.Note.SelfText or "")
			module.options.DraftName:SetText( L.NoteSelf )

			module.options.autoLoadDropdown:SetText("-")

			NoteIsSelfNow = true
		elseif index == #self.L then
			VART.Note.Black[#VART.Note.Black + 1] = ""
			tinsert(self.L,#self.L - 1,#VART.Note.Black)
			module.options.NoteEditBox.EditBox:SetText("")
			self:Update()

			BlackNoteNow = #VART.Note.Black
			module.options.DraftName:SetText( "" )

			NotesListUpdateNames()

			module.options.autoLoadDropdown:SetText("-")
		else
			index = index - 2
			if IsShiftKeyDown() then
			--	VART.Note.Black[index] = VART.Note.Text1
			end
			module.options.NoteEditBox.EditBox:SetText(VART.Note.Black[index] or "")

			BlackNoteNow = index
			module.options.DraftName:SetText( VART.Note.BlackNames[index] or "" )

			module.options.autoLoadDropdown:SetText(VART.Note.AutoLoad[index] and module.options:GetBossName(VART.Note.AutoLoad[index]) or "-")
		end
	end

	self.NotesList:SetScript("OnShow",function(self)
		NotesListUpdateNames()
	end)

	function self.NotesList:HoverListValue(isHover,index)
		if not isHover then
			GameTooltip_Hide()
		else
			GameTooltip:SetOwner(self,"ANCHOR_CURSOR")
			GameTooltip:AddLine(self.L[index])
			if index == 2 then
				GameTooltip:AddLine(L.NoteSelfTooltip)
			elseif index ~= #self.L and index > 2 then
				local i = index - 2
				if VART.Note.BlackLastUpdateName[i] then
					GameTooltip:AddLine(L.NoteLastUpdate..": "..VART.Note.BlackLastUpdateName[i].." ("..date("%d.%m.%Y %H:%M",VART.Note.BlackLastUpdateTime[i] or 0)..")")
				end
				--GameTooltip:AddLine(L.NoteTabCopyTooltip)
			end
			GameTooltip:Show()
		end
	end

	function self.NotesList:OnDragFunction(obj1,obj2)
		local index1,index2 = obj1.index,obj2.index

		if index2 < 3 or index2 >= #self.L then
			return
		end
		index1,index2 = index1 - 2,index2 - 2

		local tmpBlack = VART.Note.Black[index1]
		local tmpBlackNames = VART.Note.BlackNames[index1]
		local tmpAutoLoad = VART.Note.AutoLoad[index1]
		local tmpBlackLastUpdateName = VART.Note.BlackLastUpdateName[index1]
		local tmpBlackLastUpdateTime = VART.Note.BlackLastUpdateTime[index1]
		if index1 < index2 then
			for i=index1,index2-1 do
				VART.Note.Black[i] = VART.Note.Black[i + 1]
				VART.Note.BlackNames[i] = VART.Note.BlackNames[i + 1]
				VART.Note.AutoLoad[i] = VART.Note.AutoLoad[i + 1]
				VART.Note.BlackLastUpdateName[i] = VART.Note.BlackLastUpdateName[i + 1]
				VART.Note.BlackLastUpdateTime[i] = VART.Note.BlackLastUpdateTime[i + 1]
			end
		else
			for i=index1,index2+1,-1 do
				VART.Note.Black[i] = VART.Note.Black[i - 1]
				VART.Note.BlackNames[i] = VART.Note.BlackNames[i - 1]
				VART.Note.AutoLoad[i] = VART.Note.AutoLoad[i - 1]
				VART.Note.BlackLastUpdateName[i] = VART.Note.BlackLastUpdateName[i - 1]
				VART.Note.BlackLastUpdateTime[i] = VART.Note.BlackLastUpdateTime[i - 1]
			end
		end
		VART.Note.Black[index2] = tmpBlack
		VART.Note.BlackNames[index2] = tmpBlackNames
		VART.Note.AutoLoad[index2] = tmpAutoLoad
		VART.Note.BlackLastUpdateName[index2] = tmpBlackLastUpdateName
		VART.Note.BlackLastUpdateTime[index2] = tmpBlackLastUpdateTime

		NotesListUpdateNames()
	end

	self.DuplicateDraft = ELib:Button(self.tab.tabs[1],L.NoteDuplicate):Size(120,19):Point("RIGHT",0,0):Point("TOP",self.NotesList,0,1):OnClick(function (self)
		local pos = #VART.Note.Black + 1

		local text = module.options.LastIndex == 1 and (VART.Note.Text1 or "") or
				module.options.LastIndex == 2 and (VART.Note.SelfText or "") or
				(VART.Note.Black[module.options.LastIndex - 2] or "")
		local title = (module.options.LastIndex > 2 and VART.Note.BlackNames[module.options.LastIndex - 2]) or 
				(module.options.LastIndex == 1 and VART.Note.DefName)
		if not title then title = nil end

		local boss = module.options.LastIndex == 1 and VART.Note.AutoLoad[0] or
				module.options.LastIndex > 2 and VART.Note.AutoLoad[module.options.LastIndex - 2]
		if not boss then boss = nil end

		local lastUpdateName = module.options.LastIndex > 2 and VART.Note.BlackLastUpdateName[module.options.LastIndex - 2]
		if not lastUpdateName then lastUpdateName = nil end

		local lastUpdateTime = module.options.LastIndex > 2 and VART.Note.BlackLastUpdateTime[module.options.LastIndex - 2]
		if not lastUpdateTime then lastUpdateTime = nil end

		VART.Note.Black[pos] = text
		VART.Note.BlackNames[pos] = title
		VART.Note.AutoLoad[pos] = boss
		VART.Note.BlackLastUpdateName[pos] = lastUpdateName
		VART.Note.BlackLastUpdateTime[pos] = lastUpdateTime

		NotesListUpdateNames()
		module.options.NotesList:SetListValue(pos+2)
		module.options.NotesList.selected = pos+2
		module.options.NotesList:Update()
	end)
	self.DuplicateDraft:HideBorders()

	self.RemoveDraft = ELib:Button(self.tab.tabs[1],L.NoteRemove):Size(120,19):Point("RIGHT",self.DuplicateDraft,"LEFT",-5,0):Point("TOP",self.NotesList,0,1):Disable():OnClick(function (self)
		if not BlackNoteNow then
			return
		end
		local size = #VART.Note.Black
		for i=BlackNoteNow,size do
			if i < size then
				VART.Note.Black[i] = VART.Note.Black[i + 1]
				VART.Note.BlackNames[i] = VART.Note.BlackNames[i + 1]
				VART.Note.AutoLoad[i] = VART.Note.AutoLoad[i + 1]
				VART.Note.BlackLastUpdateName[i] = VART.Note.BlackLastUpdateName[i + 1]
				VART.Note.BlackLastUpdateTime[i] = VART.Note.BlackLastUpdateTime[i + 1]
			else
				VART.Note.Black[i] = nil
				VART.Note.BlackNames[i] = nil
				VART.Note.AutoLoad[i] = nil
				VART.Note.BlackLastUpdateName[i] = nil
				VART.Note.BlackLastUpdateTime[i] = nil
			end
		end
		NotesListUpdateNames()
		if BlackNoteNow == (#module.options.NotesList.L - 2) then
			BlackNoteNow = BlackNoteNow - 1
		end
		module.options.NotesList:SetListValue(2+BlackNoteNow)
		module.options.NotesList.selected = 2+(BlackNoteNow or 0)	--blacknote_id can be nil if all blacks are removed
		module.options.NotesList:Update()
	end)
	self.RemoveDraft:HideBorders()

	self.DraftName = ELib:Edit(self.tab.tabs[1]):Size(0,18):Tooltip(L.NoteDraftName):Text(VART.Note.DefName or L.messageTab1):Point("TOPLEFT",self.NotesList,"TOPRIGHT",8,0):Point("RIGHT",self.RemoveDraft,"LEFT",-5,0):BackgroundText(L.NoteDraftName):OnChange(function(self,isUser)
		self:BackgroundTextCheck()
		if not isUser then return end
		if BlackNoteNow then
			VART.Note.BlackNames[ BlackNoteNow ] = self:GetText()
			NotesListUpdateNames()
		elseif not BlackNoteNow and not NoteIsSelfNow then
			VART.Note.DefName = self:GetText()
		end
	end)
	self.DraftName:SetBackdropColor(0, 0, 0, 0) 
	self.DraftName:SetBackdropBorderColor(0, 0, 0, 0)
	self.DraftName:HideBorders()

	ELib:DecorationLine(self.tab.tabs[1]):Point("TOP",0,-129-20):Point("LEFT",self.NotesList,"RIGHT",0,0):Point("RIGHT",'x',0,0):Size(0,1)

	local function autoLoadDropdown_SetValue(self,encounterID)
		local index = BlackNoteNow or 0

		VART.Note.AutoLoad[index] = encounterID

		module.options.autoLoadDropdown:SetText(encounterID and module.options:GetBossName(encounterID) or "-")
		NotesListUpdateNames()
		ELib:DropDownClose()
	end

	self.autoLoadDropdown = ELib:DropDown(self.tab.tabs[1],550,25):AddText(ENCOUNTER_JOURNAL_ENCOUNTER..":"):Point("TOPRIGHT",self.DuplicateDraft,"BOTTOMRIGHT",-2,-1):Size(550):SetText(VART.Note.AutoLoad[0] and L.bossName[ VART.Note.AutoLoad[0] ] or "-")
	do
		local List = self.autoLoadDropdown.List
		List[#List+1] = {
			text = NO,
			func = autoLoadDropdown_SetValue,
		}
		for i=1,#module.db.encountersList do
			local instance = module.db.encountersList[i]
			List[#List+1] = {
				text = type(instance[1])=='string' and instance[1] or (C_Map.GetMapInfo(instance[1] or 0) or {}).name or "???",
				isTitle = true,
			}
			for j=2,#instance do
				List[#List+1] = {
					text = module.options:GetBossName(instance[j]),
					arg1 = instance[j],
					func = autoLoadDropdown_SetValue,
				}
			end
		end
	end
	self.autoLoadDropdown:HideBorders()
	self.autoLoadDropdown.Background:Hide()
	self.autoLoadDropdown.Background:SetPoint("BOTTOMRIGHT",0,1)
	self.autoLoadDropdown.Background:SetColorTexture(1,1,1,.3)
	self.autoLoadDropdown.Text:SetJustifyH("LEFT")
	self.autoLoadDropdown:SetScript("OnMouseDown",function(self)
		self.Button:Click()
	end)
	self.autoLoadDropdown:SetScript("OnEnter",function(self)
		self.Background:Show()
	end)
	self.autoLoadDropdown:SetScript("OnLeave",function(self)
		self.Background:Hide()
	end)
	if ART.isClassic then
		self.autoLoadDropdown:Hide()
	end

	ELib:DecorationLine(self.tab.tabs[1]):Point("TOP",0,-129-40):Point("LEFT",self.NotesList,"RIGHT",0,0):Point("RIGHT",'x',0,0):Size(0,1)

	local IsFormattingOn = VART.Note.OptionsFormatting
	local IconsFormattingList = {}
	self.optFormatting = ELib:Check(self.tab.tabs[1],FORMATTING,VART.Note.OptionsFormatting):Point("TOPLEFT",self.NotesList,"TOPRIGHT",15,-41):Size(15,15):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.OptionsFormatting = true
		else
			VART.Note.OptionsFormatting = nil
		end
		IsFormattingOn = VART.Note.OptionsFormatting
		module.options.NotesList:SetListValue(module.options.LastIndex or 1)
	end)  

	ELib:DecorationLine(self.tab.tabs[1]):Point("TOP",0,-129-60):Point("LEFT",self.NotesList,"RIGHT",0,0):Point("RIGHT",'x',0,0):Size(0,1)

	self.NoteEditBox = ELib:MultiEdit(self.tab.tabs[1]):Point("TOPLEFT",self.NotesList,"TOPRIGHT",2,-61):Size(616,395)
	ELib:Border(self.NoteEditBox,0)


	local function GSUB_Icon_Options(unformatted,spellID,iconSize)
		local iconText
		spellID = tonumber(spellID)
	
		if not iconSize or iconSize == "" then
			iconSize = 0
		else
			iconSize = min(tonumber(iconSize),40)
		end
	
		local preicon = predefSpellIcons[spellID]
		if preicon then
			iconText = "|T"..preicon..":"..iconSize.."|t"
		else
			local spellTexture = select(3,GetSpellInfo(spellID))
			iconText = "|T"..(spellTexture or "Interface\\Icons\\INV_MISC_QUESTIONMARK")..":"..iconSize..":"..iconSize..":-6:0|t"
		end

		IconsFormattingList[iconText] = unformatted
	
		return iconText
	end

	self.NoteEditBox.EditBox._SetText = self.NoteEditBox.EditBox.SetText
	function self.NoteEditBox.EditBox:SetText(text)
		if IsFormattingOn then
			--wipe(IconsFormattingList)
			text = text:gsub("||([cr])","|%1")
				--:gsub("({spell:(%d+):?(%d*)})",GSUB_Icon_Options)
		end
		return self:_SetText(text)
	end


	function self.NoteEditBox.EditBox:OnTextChanged(isUser)
		if not isUser and (not module.options.InsertFix or GetTime() - module.options.InsertFix > 0.1) then
			return
		end
		local text = self:GetText()
		if IsFormattingOn then
			text = text:gsub("|([cr])","||%1")
				--:gsub("|T.-|t",IconsFormattingList)
		end
		if NoteIsSelfNow then
			VART.Note.SelfText = text
			module.allframes:UpdateText()
		elseif BlackNoteNow then
			VART.Note.Black[ BlackNoteNow ] = text

			VART.Note.BlackLastUpdateName[BlackNoteNow] = ART.SDB.charKey
			VART.Note.BlackLastUpdateTime[BlackNoteNow] = time()
		else
			VART.Note.Text1 = text
			if module.frame.text:GetText() ~= txtWithIcons(module.frame, VART.Note.Text1) then
				module.options.buttonsend:Anim(true)
			else
				module.options.buttonsend:Anim(false)
			end
			module.allframes:UpdateText()
		end
	end
	local last_highlight_start,last_highlight_end,last_cursor_pos = 0,0,0
	local IsFormattingOn_Saved
	self.NoteEditBox.EditBox:SetScript("OnKeyDown",function(self,key)
		if IsFormattingOn and key == "LCTRL" then
			module.options.InsertFix = nil
			IsFormattingOn_Saved = true
			IsFormattingOn = nil
			local h_start,h_end = module.options.NoteEditBox:GetTextHighlight()
			local h_cursor = self:GetCursorPosition()
			local text = module.options.NoteEditBox.EditBox:GetText()

			last_highlight_start,last_highlight_end,last_cursor_pos = h_start,h_end,h_cursor

			local c_start,c_end,c_cursor = 0,0,0
			text:sub(1,h_start):gsub("|([cr])",function() c_start = c_start + 1 end)
			text:sub(1,h_end):gsub("|([cr])",function() c_end = c_end + 1 end)
			text:sub(1,h_cursor):gsub("|([cr])",function() c_cursor = c_cursor + 1 end)

			text = text:gsub("|([cr])","||%1")
			module.options.NoteEditBox.EditBox:_SetText(text)

			module.options.NoteEditBox.EditBox:HighlightText( h_start+c_start, h_end+c_end )
			module.options.NoteEditBox.EditBox:SetCursorPosition( h_cursor+c_cursor )
		end
	end)
	self.NoteEditBox.EditBox:SetScript("OnKeyUp",function(self,key)
		if IsFormattingOn_Saved and key == "LCTRL" then
			ART.F:AddCoroutine(function()
				coroutine.yield("await")	--wait for redraw from wow engine to recognize all updated text.
				local text = module.options.NoteEditBox.EditBox:GetText()
				local h_start,h_end = module.options.NoteEditBox:GetTextHighlight()
				local h_cursor = self:GetCursorPosition()
				local c_start,c_end,c_cursor = 0,0,0
				text:sub(1,h_start):gsub("||([cr])",function() c_start = c_start + 1 end)
				text:sub(1,h_end):gsub("||([cr])",function() c_end = c_end + 1 end)
				text:sub(1,h_cursor):gsub("||([cr])",function() c_cursor = c_cursor + 1 end)
	
				IsFormattingOn = true
				IsFormattingOn_Saved = nil
				module.options.InsertFix = nil
				module.options.NotesList:SetListValue(module.options.LastIndex or 1)
				module.options.NoteEditBox.EditBox:HighlightText( h_start-c_start,h_end-c_end )
				module.options.NoteEditBox.EditBox:SetCursorPosition( h_cursor-c_cursor )
			end)
		end
	end)

	self.buttonsend = ELib:Button(self.tab.tabs[1],L.messagebutsend):Size(0,30):Point("LEFT",self.NotesList,"TOPRIGHT",4,0):Point("BOTTOM",self,"BOTTOM",0,2):Point("RIGHT",self,"RIGHT",-2,0):Tooltip(L.messagebutsendtooltip):OnClick(function (self)
		module.frame:Save() 

		if IsShiftKeyDown() then
			local text = VART.Note.Text1 or ""
			text = text:gsub("||c........","")
			text = text:gsub("||r","")
			text = text:gsub("||T.-:0||t ","")
			for i=1,8 do
				text = text:gsub(module.db.iconsLocalizatedNames[i],"{rt"..i.."}")
				for _,lang in pairs(iconsLangs) do
					text = text:gsub(module.db["icons"..lang.."Names"][i],"{rt"..i.."}")
				end
			end
			text = text:gsub("%b{}",function(p)
				if p and p:match("^{rt%d}$") then
					return p
				else
					return ""
				end
			end)
			if ART.isBC and ART.locale == "ruRU" then	--fix bug for icons on ru client
				text = text:gsub("%b{}",function(p)
					if p and p:match("^{rt%d}$") then
						return module.db.iconsLocalizatedNames[tonumber(p:match("%d+") or "") or 0]
					end
				end)
			end

			local lines = {strsplit("\n", text)}
			for i=1,#lines do
				if lines[i] ~= "" then
					SendChatMessage(lines[i],(IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT") or (IsInRaid() and "RAID") or "PARTY")
				end
			end
		end

		module.options.buttonsend:Anim(false)
	end) 

	function self.buttonsend:Anim(on)
		if on then
			self.t = self.t or 0
			self:SetScript("OnUpdate",function(self,elapsed)
				self.t = (self.t + elapsed) % 4

				local c = 0.05 * (self.t > 2 and (4-self.t) or self.t)

				self.Texture:SetGradient("VERTICAL",CreateColor(0.0+c,0.06+c,0.0+c,1), CreateColor(0.05+c,0.21+c,0.05+c,1))
			end)
		else
			self:SetScript("OnUpdate",nil)
			self.Texture:SetGradient("VERTICAL",CreateColor(0.05,0.06,0.09,1), CreateColor(0.20,0.21,0.25,1))
		end
	end

	self.buttoncopyPersonal = ELib:Button(self.tab.tabs[1],L.NoteMoveToPersonal):Size(180,30):Point("BOTTOM",self,"BOTTOM",0,2):Point("RIGHT",self,"RIGHT",-2,0):OnClick(function (self)
		if not BlackNoteNow then
			return
		end
		VART.Note.SelfText = VART.Note.Black[BlackNoteNow]

		module.options.NotesList:SetListValue(2)

		module.options.NotesList.selected = 2
		module.options.NotesList:Update()

		module.allframes:UpdateText()
	end) 
	self.buttoncopyPersonal:Hide()

	self.buttonwindow = ELib:Button(self.tab.tabs[1],L.NoteShowInNewWindow):Size(180,30):Point("LEFT",self.NotesList,"TOPRIGHT",4,0):Point("BOTTOM",self,"BOTTOM",0,2):Tooltip(L.NoteShowInNewWindowTooltip):OnClick(function (self)
		if not BlackNoteNow then
			return
		end
		if IsControlKeyDown() then
			local window = module:IsWindowOpenedForDraft(BlackNoteNow)
			if window then
				window:ClearAllPoints()
				window:SetPoint("CENTER")

				window:SetSize(200,100)
				return
			end
		elseif IsShiftKeyDown() then
			local window = module:IsWindowOpenedForDraft(BlackNoteNow)
			if window then
				window:Disable()
				return
			end
		end
		module:AddWindow(BlackNoteNow) 
	end) 
	self.buttonwindow:Hide()

	self.buttoncopy = ELib:Button(self.tab.tabs[1],L.messageButCopy):Size(0,30):Point("LEFT",self.buttonwindow,"RIGHT",5,0):Point("BOTTOM",self,"BOTTOM",0,2):Point("RIGHT",self.buttoncopyPersonal,"LEFT",-5,0):OnClick(function (self)
		if not BlackNoteNow then
			return
		end
		module.frame:Save(BlackNoteNow) 

		module.options.NotesList:SetListValue(1)

		module.options.NotesList.selected = 1
		module.options.NotesList:Update()
	end) 
	self.buttoncopy:Hide()

	local function AddTextToEditBox(self,text,mypos,noremove)
		local addedText = nil
		if not self then
			addedText = text
		else
			addedText = self.iconText
			if IsShiftKeyDown() then
				addedText = self.iconTextShift
			end
		end
		if not noremove then
			module.options.NoteEditBox.EditBox:Insert("")
		end
		local txt = module.options.NoteEditBox.EditBox:GetText()
		local pos = module.options.NoteEditBox.EditBox:GetCursorPosition()
		if not self and type(mypos)=='number' then
			pos = mypos
		end
		txt = string.sub (txt, 1 , pos) .. addedText .. string.sub (txt, pos+1)
		module.options.InsertFix = GetTime()
		module.options.NoteEditBox.EditBox:SetText(txt)
		local adjust = 0
		if IsFormattingOn then
			addedText:gsub("||",function() adjust = adjust + 1 end)
		end
		module.options.NoteEditBox.EditBox:SetCursorPosition(pos+addedText:len()-adjust)
	end

	self.buttonicons = {}
	for i=1,8 do
		local button = CreateFrame("Button", nil,self.tab.tabs[1])
		self.buttonicons[i] = button
		button:SetSize(18,18)
		button:SetPoint("TOPLEFT", 10+(i-1)*20,-30)
		button.back = button:CreateTexture(nil, "BACKGROUND")
		button.back:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..i)
		button.back:SetAllPoints()
		button:RegisterForClicks("LeftButtonDown")
		button.iconText = module.db.iconsLocalizatedNames[i]
		button:SetScript("OnClick", AddTextToEditBox)
	end
	for i=1,13 do
		local button = CreateFrame("Button", nil,self.tab.tabs[1])
		self.buttonicons[i] = button
		button:SetSize(18,18)
		button:SetPoint("TOPLEFT", 170+(i-1)*20,-30)
		button.back = button:CreateTexture(nil, "BACKGROUND")
		local iconData = module.db.otherIconsList[i]
		button.back:SetTexture(iconData[2])
		if iconData[3] then
			button.back:SetTexCoord(unpack(iconData,3,6))
		end
		button.back:SetAllPoints()
		button:RegisterForClicks("LeftButtonDown")
		button.iconText = iconData[1]
		button:SetScript("OnClick", AddTextToEditBox)
	end

	self.OtherIconsButton = ELib:Button(self.tab.tabs[1],L.NoteOtherIcons):Size(120,20):Point("TOPLEFT",self.buttonicons[#self.buttonicons],"TOPRIGHT",5,1):OnClick(function()
		module.options.OtherIconsFrame:ShowClick("TOPRIGHT")
	end)

	self.OtherIconsFrame = ELib:Popup(L.NoteOtherIcons):Size(300,300)
	self.OtherIconsFrame.ScrollFrame = ELib:ScrollFrame(self.OtherIconsFrame):Size(self.OtherIconsFrame:GetWidth()-10,self.OtherIconsFrame:GetHeight()-25):Point("TOP",0,-20):Height(500)

	local function CreateOtherIcon(pointX,pointY,texture,iconText)
		local self = CreateFrame("Button", nil,self.OtherIconsFrame.ScrollFrame.C)
		self:SetSize(18,18)
		self:SetPoint("TOPLEFT",pointX,pointY)
		self.texture = self:CreateTexture(nil, "BACKGROUND")
		self.texture:SetTexture(texture)
		self.texture:SetAllPoints()
		self:RegisterForClicks("LeftButtonDown")
		self.iconText = iconText
		self:SetScript("OnClick", AddTextToEditBox)
		return self
	end
	self.OtherIconsFrame.CreateOtherIcon = CreateOtherIcon

	self.OtherIconsFrame.OnShow = function(self)
		self.OnShow = nil
		local GetSpellInfo = GetSpellInfo
		local line = 1
		local inLine = 0
		for i=14,#module.db.otherIconsList-3 do
			local iconData = module.db.otherIconsList[i]
			local icon = CreateOtherIcon(5+inLine*20,-2-(line-1)*20,iconData[2],iconData[1])
			if iconData[3] then
				icon.texture:SetTexCoord( unpack(iconData,3,6) )
			end
			inLine = inLine + 1
			if inLine > 12 then
				line = line + 1
				inLine = 0
			end
		end
		if inLine > 0 then
			line = line + 1
		end
		inLine = 0
		for i=1,#module.db.otherIconsAdditionalList do
			local spellID = module.db.otherIconsAdditionalList[i]
			if spellID == 0 then
				line = line + 1
				inLine = 0
			elseif type(spellID) == 'string' then
				CreateOtherIcon(5+inLine*20,-2-(line-1)*20,spellID,"{icon:"..spellID.."}")
				inLine = inLine + 1
				if inLine > 12 and (not module.db.otherIconsAdditionalList[i+1] or module.db.otherIconsAdditionalList[i+1]~=0) then
					line = line + 1
					inLine = 0
				end
			else
				local _,_,spellTexture = GetSpellInfo( spellID )
				if predefSpellIcons[spellID] then
					spellTexture = predefSpellIcons[spellID]
				end

				CreateOtherIcon(5+inLine*20,-2-(line-1)*20,spellTexture,"{spell:"..spellID.."}")
				inLine = inLine + 1
				if inLine > 12 and (not module.db.otherIconsAdditionalList[i+1] or module.db.otherIconsAdditionalList[i+1]~=0) then
					line = line + 1
					inLine = 0
				end
			end
		end
		module.options.OtherIconsFrame.ScrollFrame:SetNewHeight( max(module.options.OtherIconsFrame:GetHeight()-40 , line * 20 + 4) )
	end

	self:SetScript("OnHide",function (self)
		self.OtherIconsFrame:Hide()
	end)

	self.dropDownColor = ELib:DropDown(self.tab.tabs[1],170,10):Point(558,-30):Size(100):SetText(L.NoteColor)
	self.dropDownColor.list = {
		{L.NoteColorRed,"|cffff0000"},
		{L.NoteColorGreen,"|cff00ff00"},
		{L.NoteColorBlue,"|cff0000ff"},
		{L.NoteColorYellow,"|cffffff00"},
		{L.NoteColorPurple,"|cffff00ff"},
		{L.NoteColorAzure,"|cff00ffff"},
		{L.NoteColorBlack,"|cff000000"},
		{L.NoteColorGrey,"|cff808080"},
		{L.NoteColorRedSoft,"|cffee5555"},
		{L.NoteColorGreenSoft,"|cff55ee55"},
		{L.NoteColorBlueSoft,"|cff5555ee"},
	}
	local classNames = ART.GDB.ClassList
	for i,class in ipairs(classNames) do
		local colorTable = RAID_CLASS_COLORS[class]
		if colorTable and type(colorTable)=="table" then
			self.dropDownColor.list[#self.dropDownColor.list + 1] = {L.classLocalizate[class] or class,"|c"..(colorTable.colorStr or "ffaaaaaa")}
		end
	end
	self.dropDownColor:SetScript("OnEnter",function (self)
		ELib.Tooltip.Show(self,"ANCHOR_LEFT",L.NoteColor,{L.NoteColorTooltip1,1,1,1,true},{L.NoteColorTooltip2,1,1,1,true})
	end)
	self.dropDownColor:SetScript("OnLeave",function ()
		ELib.Tooltip:Hide()
	end)
	function self.dropDownColor:SetValue(colorCode)
		ELib:DropDownClose()

		local selectedStart,selectedEnd = module.options.NoteEditBox.EditBox:GetTextHighlight()
		colorCode = string.gsub(colorCode,"|","||")
		if selectedStart == selectedEnd then
			AddTextToEditBox(nil,colorCode.."||r",nil,true)
		else
			AddTextToEditBox(nil,"||r",selectedEnd,true)
			AddTextToEditBox(nil,colorCode,selectedStart,true)
		end
	end
	for i=1,#self.dropDownColor.list do
		local colorData = self.dropDownColor.list[i]
		self.dropDownColor.List[i] = {
			text = colorData[2]..colorData[1],
			func = self.dropDownColor.SetValue,
			justifyH = "CENTER",
			arg1 = colorData[2],
		}
	end
	self.dropDownColor.Lines = #self.dropDownColor.List

	local function RaidNamesOnEnter(self)
		self.html:SetShadowColor(0.2, 0.2, 0.2, 1)
	end
	local function RaidNamesOnLeave(self)
		self.html:SetShadowColor(0, 0, 0, 1)
	end
	self.raidnames = {}
	for i=1,40 do
		local button = CreateFrame("Button", nil,self.tab.tabs[1])
		self.raidnames[i] = button
		button:SetSize(93,14)
		button:SetPoint("TOPLEFT", 15+math.floor((i-1)/5)*95,-55-14*((i-1)%5))

		button.html = ELib:Text(button,"",11):Color()
		button.html:SetAllPoints()
		button.txt = ""
		button:RegisterForClicks("LeftButtonDown")
		button.iconText = ""
		button:SetScript("OnClick", AddTextToEditBox)

		button:SetScript("OnEnter", RaidNamesOnEnter)
		button:SetScript("OnLeave", RaidNamesOnLeave)
	end

	self.lastUpdate = ELib:Text(self.tab.tabs[1],"",11):Size(600,20):Point("TOPLEFT",self.NotesList,"BOTTOMLEFT",3,-6):Top():Color()
	if VART.Note.LastUpdateName and VART.Note.LastUpdateTime then
		self.lastUpdate:SetText( L.NoteLastUpdate..": "..VART.Note.LastUpdateName.." ("..date("%H:%M:%S %d.%m.%Y",VART.Note.LastUpdateTime)..")" )
	end
	self.lastUpdate:Hide()

	self.chkEnable = ELib:Check(self,L.Enable,VART.Note.enabled):Point(720,-17):Tooltip("/rt note|n/rt n"):Size(18,18):AddColorState():TextButton():OnClick(function(self) 
		if self:GetChecked() then
			module:Enable()
		else
			module:Disable()
		end
	end)

	self.chkFix = ELib:Check(self,L.messagebutfix,VART.Note.Fix):Point(590,-17):Tooltip(L.messagebutfixtooltip):Size(18,18):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.Fix = true
			module.allframes:SetMovable(false)
			module.allframes:EnableMouse(false)
			module.allframes.buttonResize:Hide()
			module.allframes:SetShadowComment(false)
		else
			VART.Note.Fix = nil
			module.allframes:SetMovable(true)
			module.allframes:EnableMouse(true)
			module.allframes.buttonResize:Show()
			module.allframes:SetShadowComment(true)
		end
	end) 

	self.chkOnlyPromoted = ELib:Check(self.tab.tabs[2],L.NoteOnlyPromoted,VART.Note.OnlyPromoted):Point(15,-15):Tooltip(L.NoteOnlyPromotedTooltip):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.OnlyPromoted = true
		else
			VART.Note.OnlyPromoted = nil
		end
	end)  


	self.chkOnlyInRaid = ELib:Check(self.tab.tabs[2],L.MarksBarDisableInRaid,VART.Note.HideOutsideRaid):Point(15,-40):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.HideOutsideRaid = true
		else
			VART.Note.HideOutsideRaid = nil
		end
		module:Visibility()
	end) 

	self.chkOnlyInRaidKInstance = ELib:Check(self.tab.tabs[2],L.NoteShowOnlyInRaid,VART.Note.ShowOnlyInRaid):Point(15,-65):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.ShowOnlyInRaid = true
			module:RegisterEvents('ZONE_CHANGED_NEW_AREA')
		else
			VART.Note.ShowOnlyInRaid = nil
			module:UnregisterEvents('ZONE_CHANGED_NEW_AREA')
		end
		module:Visibility()
	end) 

	self.chkOnlySelf = ELib:Check(self.tab.tabs[2],L.NoteShowOnlyPersonal,VART.Note.ShowOnlyPersonal):Point(15,-90):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.ShowOnlyPersonal = true
		else
			VART.Note.ShowOnlyPersonal = nil
		end
		module.allframes:UpdateText()
	end) 

	self.chkSelfWindow = ELib:Check(self.tab.tabs[2],L.NotePersonalWindow,VART.Note.PersonalWindow):Point(15,-115):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.PersonalWindow = true
			module.frame_personal:Enable()
		else
			VART.Note.PersonalWindow = nil
			module.frame_personal:Disable()
		end
		module.allframes:UpdateText()
	end) 



	self.chkHideInCombat = ELib:Check(self.tab.tabs[2],L.NoteHideInCombat,VART.Note.HideInCombat):Point(15,-140):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.HideInCombat = true
			module:RegisterEvents('PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED')
		else
			VART.Note.HideInCombat = nil
			module:UnregisterEvents('PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED')
		end
		module:Visibility()
	end) 

	self.chkSaveAllNew = ELib:Check(self.tab.tabs[2],L.NoteSaveAllNew,VART.Note.SaveAllNew):Point(15,-165):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.SaveAllNew = true
		else
			VART.Note.SaveAllNew = nil
		end
	end) 

	self.chkEnableWhenReceive = ELib:Check(self.tab.tabs[2],L.NoteEnableWhenReceive,VART.Note.EnableWhenReceive):Point(15,-190):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.EnableWhenReceive = true
		else
			VART.Note.EnableWhenReceive = nil
		end
	end) 

	self.sliderFontSize = ELib:Slider(self.tab.tabs[2],L.NoteFontSize):Size(300):Point(16,-225):Range(6,72):SetTo(VART.Note.FontSize or 12):OnChange(function(self,event) 
		event = event - event%1
		VART.Note.FontSize = event
		module.allframes:UpdateFont()
		self.tooltipText = event
		self:tooltipReload(self)
	end)

	local function DropDownFont_Click(_,arg)
		VART.Note.FontName = arg
		local FontNameForDropDown = arg:match("\\([^\\]*)$")
		module.options.dropDownFont:SetText(FontNameForDropDown or arg)
		ELib:DropDownClose()
		module.allframes:UpdateFont()
	end

	self.dropDownFont = ELib:DropDown(self.tab.tabs[2],350,10):Point(15,-255):Size(300)
	for i=1,#ART.F.fontList do
		self.dropDownFont.List[i] = {}
		local info = self.dropDownFont.List[i]
		info.text = ART.F.fontList[i]
		info.arg1 = ART.F.fontList[i]
		info.func = DropDownFont_Click
		info.font = ART.F.fontList[i]
		info.justifyH = "CENTER" 
	end
	for name,font in ART.F.IterateMediaData("font") do
		local info = {}
		self.dropDownFont.List[#self.dropDownFont.List+1] = info

		info.text = name
		info.arg1 = font
		info.func = DropDownFont_Click
		info.font = font
		info.justifyH = "CENTER" 
	end
	do
		local arg = VART.Note.FontName or ART.F.defFont
		local FontNameForDropDown = arg:match("\\([^\\]*)$")
		self.dropDownFont:SetText(FontNameForDropDown or arg)
	end

	self.chkOutline = ELib:Check(self.tab.tabs[2],L.messageOutline,VART.Note.Outline):Point("LEFT",self.dropDownFont,"RIGHT",15,0):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.Outline = true
		else
			VART.Note.Outline = nil
		end
		module.allframes:UpdateFont()
	end) 

	self.slideralpha = ELib:Slider(self.tab.tabs[2],L.messagebutalpha):Size(300):Point(16,-300):Range(0,100):SetTo(VART.Note.Alpha or 100):OnChange(function(self,event) 
		event = event - event%1
		VART.Note.Alpha = event
		module.allframes:SetAlpha(event/100)
		self.tooltipText = event
		self:tooltipReload(self)
	end)

	self.sliderscale = ELib:Slider(self.tab.tabs[2],L.messagebutscale):Size(300):Point(16,-370):Range(5,200):SetTo(VART.Note.Scale or 100):OnChange(function(self,event) 
		event = event - event%1
		VART.Note.Scale = event
		module.allframes:ScaleFix(event/100)
		self.tooltipText = event
		self:tooltipReload(self)
	end)

	self.slideralphaback = ELib:Slider(self.tab.tabs[2],L.messageBackAlpha):Size(300):Point(16,-335):Range(0,100):SetTo(VART.Note.ScaleBack or 100):OnChange(function(self,event) 
		event = event - event%1
		VART.Note.ScaleBack = event
		module.allframes.background:SetColorTexture(0, 0, 0, event/100)
		self.tooltipText = event
		self:tooltipReload(self)
	end)

	self.moreOptionsDropDown = ELib:DropDown(self.tab.tabs[2],275,#frameStrataList+1):Point(15,-405):Size(300):SetText(L.NoteFrameStrata)

	local function moreOptionsDropDown_SetVaule(_,arg)
		VART.Note.Strata = arg
		ELib:DropDownClose()
		for i=1,#self.moreOptionsDropDown.List-1 do
			self.moreOptionsDropDown.List[i].checkState = VART.Note.Strata == self.moreOptionsDropDown.List[i].arg1
		end
		module.allframes:SetFrameStrata(arg)
	end

	for i=1,#frameStrataList do
		self.moreOptionsDropDown.List[i] = {
			text = frameStrataList[i],
			checkState = VART.Note.Strata == frameStrataList[i],
			radio = true,
			arg1 = frameStrataList[i],
			func = moreOptionsDropDown_SetVaule,
		}
	end
	tinsert(self.moreOptionsDropDown.List,{text = L.minimapmenuclose, func = function()
		ELib:DropDownClose()
	end})

	self.ButtonToCenter = ELib:Button(self.tab.tabs[2],L.MarksBarResetPos):Size(300,20):Point(15,-435):Tooltip(L.MarksBarResetPosTooltip):OnClick(function()
		VART.Note.Left = nil
		VART.Note.Top = nil

		module.allframes:ClearAllPoints()
		module.allframes:SetPoint("CENTER",UIParent, "CENTER", 0, 0)
	end) 

	ELib:DecorationLine(self.tab.tabs[2]):Point("LEFT",0,0):Point("RIGHT",0,0):Size(0,1):Point("TOP",self.ButtonToCenter,"BOTTOM",0,-5)
	ELib:Text(self.tab.tabs[2],L.NoteTimers,14):Point("TOP",self.ButtonToCenter,"BOTTOM",0,-9):Point("LEFT",20,0):Color()

	self.chkTimersHidePassed = ELib:Check(self.tab.tabs[2],L.NoteTimersHidePassed,VART.Note.TimerPassedHide):Point("TOPLEFT",self.ButtonToCenter,"BOTTOMLEFT",0,-25):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.TimerPassedHide = true
		else
			VART.Note.TimerPassedHide = nil
		end
	end)

	self.chkTimersGlow = ELib:Check(self.tab.tabs[2],L.NoteTimersGlow,VART.Note.TimerGlow):Point("TOPLEFT",self.chkTimersHidePassed,"BOTTOMLEFT",0,-5):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.TimerGlow = true
		else
			VART.Note.TimerGlow = nil
		end
	end)

	self.chkTimersOnlyMy = ELib:Check(self.tab.tabs[2],L.NoteTimersOnlyMy,VART.Note.TimerOnlyMy):Point("TOPLEFT",self.chkTimersGlow,"BOTTOMLEFT",0,-5):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.TimerOnlyMy = true
		else
			VART.Note.TimerOnlyMy = nil
		end
		module.allframes:UpdateText()
	end)

	local testGlowDelay
	local function TestGlow()
		module.allframes:HideGlow()
		module.allframes:ShowGlow()
		if testGlowDelay then
			testGlowDelay:Cancel()
		end
		testGlowDelay = C_Timer.NewTimer(3,function()
			module.allframes:HideGlow()
		end)
	end

	self.frameTypeGlow1 = ELib:Radio(self.tab.tabs[2],""):Point("LEFT",self.chkTimersGlow,425,0):OnClick(function() 
		self.frameTypeGlow1:SetChecked(true)
		self.frameTypeGlow2:SetChecked(false)
		self.frameTypeGlow3:SetChecked(false)
		VART.Note.TimerGlowType = 1

		TestGlow()
	end)
	self.frameTypeGlow1.f = CreateFrame("Frame",nil,self.frameTypeGlow1)
	self.frameTypeGlow1.f:SetPoint("LEFT",self.frameTypeGlow1,"RIGHT",5,0)
	self.frameTypeGlow1.f:SetSize(40,15)

	self.frameTypeGlow2 = ELib:Radio(self.tab.tabs[2],""):Point("LEFT",self.frameTypeGlow1,100,0):OnClick(function() 
		self.frameTypeGlow1:SetChecked(false)
		self.frameTypeGlow2:SetChecked(true)
		self.frameTypeGlow3:SetChecked(false)
		VART.Note.TimerGlowType = 2

		TestGlow()
	end)
	self.frameTypeGlow2.f = CreateFrame("Frame",nil,self.frameTypeGlow2)
	self.frameTypeGlow2.f:SetPoint("LEFT",self.frameTypeGlow2,"RIGHT",5,0)
	self.frameTypeGlow2.f:SetSize(40,15)

	self.frameTypeGlow3 = ELib:Radio(self.tab.tabs[2],""):Point("LEFT",self.frameTypeGlow2,100,0):OnClick(function() 
		self.frameTypeGlow1:SetChecked(false)
		self.frameTypeGlow2:SetChecked(false)
		self.frameTypeGlow3:SetChecked(true)
		VART.Note.TimerGlowType = 3

		TestGlow()
	end)
	self.frameTypeGlow3.f = CreateFrame("Frame",nil,self.frameTypeGlow3)
	self.frameTypeGlow3.f:SetPoint("LEFT",self.frameTypeGlow3,"RIGHT",5,0)
	self.frameTypeGlow3.f:SetSize(40,15)

	local LCG = LibStub("LibCustomGlow-1.0",true)
	if LCG then
		LCG.PixelGlow_Start(self.frameTypeGlow1.f,nil,nil,nil,nil,2,1,1) 
		LCG.AutoCastGlow_Start(self.frameTypeGlow3.f)
		LCG.ButtonGlow_Start(self.frameTypeGlow2.f)
	end

	if VART.Note.TimerGlowType == 2 then
		self.frameTypeGlow2:SetChecked(true)
	elseif VART.Note.TimerGlowType == 3 then
		self.frameTypeGlow3:SetChecked(true)
	else
		self.frameTypeGlow1:SetChecked(true)
	end

	if VART.Note.Text1 then 
		self.NoteEditBox.EditBox:SetText(VART.Note.Text1) 
	end



	--> Profiles

	local profilesTab = self.tab.tabs[3]

	local function GetCurrentProfileName()
		return VART.Note.Profiles.Now=="default" and L.ProfilesDefault or VART.Note.Profiles.Now
	end

	profilesTab.currentText = ELib:Text(profilesTab,L.ProfilesCurrent,11):Size(650,200):Point(15,-15):Top():Color()
	profilesTab.currentName = ELib:Text(profilesTab,"",14):Size(650,200):Point(210,-15):Top():Color(1,1,0)

	profilesTab.currentName.UpdateText = function(self)
		self:SetText(GetCurrentProfileName())
	end
	profilesTab.currentName:UpdateText()

	profilesTab.choseText = ELib:Text(profilesTab,L.ProfilesChooseDesc,11):Size(650,200):Point(15,-40):Top():Color()

	profilesTab.choseNewText = ELib:Text(profilesTab,L.ProfilesNew,11):Size(650,200):Point(15,-75+12):Top()
	profilesTab.choseNew = ELib:Edit(profilesTab):Size(170,20):Point(10,-75)

	profilesTab.choseNewButton = ELib:Button(profilesTab,L.ProfilesAdd):Size(70,20):Point("LEFT",profilesTab.choseNew,"RIGHT",0,0):OnClick(function (self)
		local text = profilesTab.choseNew:GetText()
		profilesTab.choseNew:SetText("")
		if text == "" or text == "default" or VART.Note.Profiles.List[text] or text == VART.Note.Profiles.Now then
			return
		end
		VART.Note.Profiles.List[text] = ART.F.table_copy2(NewVARTTableData)

		StaticPopupDialogs["EART_NOTE_ACTIVATENEW"] = {
			text = L.ProfilesActivateAlert,
			button1 = L.YesText,
			button2 = L.NoText,
			OnAccept = function()
				module:SelectProfile(text)
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show("EART_NOTE_ACTIVATENEW")
	end)

	profilesTab.choseSelectText = ELib:Text(profilesTab,L.ProfilesSelect,11):Size(605,200):Point(335,-75+12):Top()
	profilesTab.choseSelectDropDown = ELib:DropDown(profilesTab,220,10):Point(330,-75):Size(235):SetText(LFG_LIST_SELECT)

	local function GetCurrentProfilesList(func)
		local list = {
			{ text = GetCurrentProfileName(), func = func, arg1 = VART.Note.Profiles.Now, _sort = "0" },
		}
		for name,_ in pairs(VART.Note.Profiles.List) do
			if name ~= VART.Note.Profiles.Now then
				list[#list + 1] = { text = name == "default" and L.ProfilesDefault or name, func = func, arg1 = name, _sort = "1"..name }
			end
		end
		sort(list,function(a,b) return a._sort < b._sort end)
		return list
	end

	function profilesTab.choseSelectDropDown:ToggleUpadte()
		self.List = GetCurrentProfilesList(function(_,arg1)
			ELib:DropDownClose()
			module:SelectProfile(arg1)
		end)
	end

	local function CopyProfile(name)
		local newdb = VART.Note.Profiles.List[name]
		local currname = VART.Note.Profiles.Now
		if module:SelectProfile(name) then
			VART.Note.Profiles.List[name] = newdb
			VART.Note.Profiles.Now = currname

			profilesTab.currentName:UpdateText()

			print(L.cd2ProfileCopySuccess:format(name))
		end
	end
	profilesTab.copyText = ELib:Text(profilesTab,L.ProfilesCopy,11):Size(605,200):Point(15,-120+12):Top()
	profilesTab.copyDropDown = ELib:DropDown(profilesTab,220,10):Point(10,-120):Size(235)
	function profilesTab.copyDropDown:ToggleUpadte()
		self.List = GetCurrentProfilesList(function(_,arg1)
			ELib:DropDownClose()
			CopyProfile(arg1)
		end)
		for i=1,#self.List do
			if self.List[i].arg1 == VART.Note.Profiles.Now then
				tremove(self.List, i)
				break
			end
		end
	end

	local function DeleteProfile(name)
		StaticPopupDialogs["EART_NOTE_PROFILES_REMOVE"] = {
			text = L.ProfilesDeleteAlert,
			button1 = L.YesText,
			button2 = L.NoText,
			OnAccept = function()
				VART.Note.Profiles.List[name] = nil
				profilesTab:UpdateAutoTexts()
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
		StaticPopup_Show("EART_NOTE_PROFILES_REMOVE")
	end
	profilesTab.deleteText = ELib:Text(profilesTab,L.ProfilesDelete,11):Size(605,200):Point(15,-160+12):Top()
	profilesTab.deleteDropDown = ELib:DropDown(profilesTab,220,10):Point(10,-160):Size(235)
	function profilesTab.deleteDropDown:ToggleUpadte()
		self.List = GetCurrentProfilesList(function(_,arg1)
			ELib:DropDownClose()
			DeleteProfile(arg1)
		end)
		for i=#self.List,1,-1 do
			if self.List[i].arg1 == VART.Note.Profiles.Now then
				tremove(self.List, i)
			elseif self.List[i].arg1 == "default" then
				tremove(self.List, i)
			end
		end
	end


	profilesTab.importWindow, profilesTab.exportWindow = ART.F.CreateImportExportWindows()

	function profilesTab.importWindow:ImportFunc(str)
		local headerLen = str:sub(1,4) == "EART" and 8 or 7

		local header = str:sub(1,headerLen)
		if (header:sub(1,headerLen-1) ~= "EARTCDP" and header:sub(1,headerLen-1) ~= "ARTCDP") or (header:sub(headerLen,headerLen) ~= "0" and header:sub(headerLen,headerLen) ~= "1") then
			StaticPopupDialogs["EART_EXCD_IMPORT"] = {
				text = "|cffff0000"..ERROR_CAPS.."|r "..L.ProfilesFail3,
				button1 = OKAY,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
			StaticPopup_Show("EART_EXCD_IMPORT")
			return
		end

		profilesTab:TextToProfile(str:sub(headerLen+1),header:sub(headerLen,headerLen)=="0")
	end

	profilesTab.exportButton = ELib:Button(profilesTab,L.ProfilesExport):Size(235,25):Point(10,-200):OnClick(function (self)
		profilesTab.exportWindow:NewPoint("CENTER",UIParent,0,0)
		profilesTab:ProfileToText()
	end)

	profilesTab.importButton = ELib:Button(profilesTab,L.ProfilesImport):Size(235,25):Point("LEFT",profilesTab.exportButton,"RIGHT",85,0):OnClick(function (self)
		profilesTab.importWindow:NewPoint("CENTER",UIParent,0,0)
		profilesTab.importWindow:Show()
	end)

	local IGNORE_PROFILE_KEYS = {
		["Profiles"] = true,
		["Black"] = true,
		["BlackNames"] = true,
		["BlackLastUpdateName"] = true,
		["BlackLastUpdateTime"] = true,
		["AutoLoad"] = true,

		["SelfText"] = true,
		["Text1"] = true,
	}
	function profilesTab:ProfileToText()
		local new = {}
		for key,val in pairs(VART.Note) do
			if not IGNORE_PROFILE_KEYS[key] then
				new[key] = val
			end
		end
		local strlist = ART.F.TableToText(new)
		strlist[1] = "0,"..strlist[1]
		local str = table.concat(strlist)

		local compressed
		if #str < 1000000 then
			compressed = LibDeflate:CompressDeflate(str,{level = 5})
		end
		local encoded = "ARTCDP"..(compressed and "1" or "0")..LibDeflate:EncodeForPrint(compressed or str)

		ART.F.dprint("Str len:",#str,"Encoded len:",#encoded)

		if ART.isDev then
			module.db.exportTable = new
		end
		profilesTab.exportWindow.Edit:SetText(encoded)
		profilesTab.exportWindow:Show()
	end

	function profilesTab:SaveDataFilter(res)
		local KeysToSave = {
			["Profiles"] = true,
		}
		local R = {
			data = {},
			Restore = function(self,t) 
				for k,v in pairs(self.data) do
					t[k] = v
				end
			end
		}
		for k,v in pairs(KeysToSave) do
			R.data[k] = res[k]
		end
		return R
	end
	function profilesTab:LockedFilter(res)
		local KeysToErase = {
			["Profiles"] = true,

			["Black"] = true,
			["BlackNames"] = true,
			["BlackLastUpdateName"] = true,
			["BlackLastUpdateTime"] = true,
			["AutoLoad"] = true,
	
			["SelfText"] = true,
			["Text1"] = true,
		}
		for k,v in pairs(KeysToErase) do
			res[k] = nil
		end
	end

	function profilesTab:TextToProfile(str,uncompressed)
		local decoded = LibDeflate:DecodeForPrint(str)
		local decompressed
		if uncompressed then
			decompressed = decoded
		else
			decompressed = LibDeflate:DecompressDeflate(decoded)
		end
		decoded = nil

		local _,tableData = strsplit(",",decompressed,2)
		decompressed = nil

		local successful, res = pcall(ART.F.TextToTable,tableData)
		if ART.isDev then
			module.db.lastImportDB = res
			if module.db.exportTable and type(res)=="table" then
				module.db.diffTable = {}
				print("Compare table",ART.F.table_compare(res,module.db.exportTable,module.db.diffTable))
			end
		end
		if successful and res then
			profilesTab:LockedFilter(res)
			StaticPopupDialogs["EART_NOTE_IMPORT"] = {
				text = L.cd2ProfileRewriteAlert,
				button1 = APPLY,
				button2 = L.ProfilesSaveAsNew,
				button2 = CANCEL,
				selectCallbackByIndex = true,
				OnButton1 = function()
					local saved = profilesTab:SaveDataFilter(VART.Note)
					ART.F.table_rewrite(VART.Note,res)
					saved:Restore(VART.Note)
					module:ReloadProfile()
					res = nil
				end,
				OnButton2 = function()
					ART.F.ShowInput(L.ProfilesNewProfile,function(_,name)
						if name == "" or VART.Note.Profiles.List[name] or name == "default" or name == VART.Note.Profiles.Now then
							res = nil
							return
						end
						VART.Note.Profiles.List[name] = res
						module:SelectProfile(name)
						res = nil
					end,nil,nil,nil,function(self)
						local name = self:GetText()
						if name == "" or VART.Note.Profiles.List[name] or name == "default" or name == VART.Note.Profiles.Now then
							self:GetParent().OK:Disable()
						else
							self:GetParent().OK:Enable()
						end
					end)
				end,
				OnButton3 = function()
					res = nil
				end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
		else
			StaticPopupDialogs["EART_NOTE_IMPORT"] = {
				text = L.ProfilesFail1..(res and "\nError code: "..res or ""),
				button1 = OKAY,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
		end

		StaticPopup_Show("EART_NOTE_IMPORT")
	end


	profilesTab.autoText = ELib:Text(profilesTab,L.cd2AutoChangeTooltip,12):Size(605,200):Point(10,-240):Top():Color()

	local function GetTextProfileName(profileName)
		if not profileName then
			return
		end
		local prefix
		if profileName == VART.Note.Profiles.Now then
			prefix = "|cff00ff00"
		elseif not VART.Note.Profiles.List[profileName] then
			prefix = "|cffff0000"
		end
		if profileName == "default" then
			profileName = L.ProfilesDefault
		end
		return (prefix or "")..profileName
	end
	function profilesTab:UpdateAutoTexts()
		self.autoRaidDown:SetText(GetTextProfileName(VART.Note.Profiles.Raid) or "|cff999999"..L.cd2DontChange)
		self.autoDungDown:SetText(GetTextProfileName(VART.Note.Profiles.Dung) or "|cff999999"..L.cd2DontChange)
		self.autoArenaDown:SetText(GetTextProfileName(VART.Note.Profiles.Arena) or "|cff999999"..L.cd2DontChange)
		self.autoBGDown:SetText(GetTextProfileName(VART.Note.Profiles.BG) or "|cff999999"..L.cd2DontChange)
		self.autoOtherDown:SetText(GetTextProfileName(VART.Note.Profiles.Other) or "|cff999999"..L.cd2DontChange)

		for _,dd in pairs({self.autoSpec1Down,self.autoSpec2Down,self.autoSpec3Down,self.autoSpec4Down}) do
			dd:SetText(GetTextProfileName(VART.Note.Profiles[dd.OptKey]) or "|cff999999"..L.cd2DontChange)
		end
	end

	local function AutoDropDown_ToggleUpadte(self)
		local func = function(_,arg1)
			ELib:DropDownClose()
			VART.Note.Profiles[self.OptKey] = arg1
			profilesTab:UpdateAutoTexts()
			C_Timer.After(2,module.CheckZoneProfiles)
		end
		self.List = GetCurrentProfilesList(func)
		tinsert(self.List,1,{text = L.cd2DontChange, func = func})
	end

	profilesTab.autoRaidDown = ELib:DropDown(profilesTab,220,10):Point(10,-270):Size(235):AddText(RAID,11,function(self)self:NewPoint("TOPLEFT",'x',5,12):Color(1,.82,0,1) end)
	profilesTab.autoRaidDown.OptKey = "Raid"
	profilesTab.autoRaidDown.ToggleUpadte = AutoDropDown_ToggleUpadte

	profilesTab.autoDungDown = ELib:DropDown(profilesTab,220,10):Point("TOPLEFT",profilesTab.autoRaidDown,0,-40):Size(235):AddText(CALENDAR_TYPE_DUNGEON,11,function(self)self:NewPoint("TOPLEFT",'x',5,12):Color(1,.82,0,1) end)
	profilesTab.autoDungDown.OptKey = "Dung"
	profilesTab.autoDungDown.ToggleUpadte = AutoDropDown_ToggleUpadte

	profilesTab.autoArenaDown = ELib:DropDown(profilesTab,220,10):Point("TOPLEFT",profilesTab.autoRaidDown,320,0):Size(235):AddText(ARENA,11,function(self)self:NewPoint("TOPLEFT",'x',5,12):Color(1,.82,0,1) end)
	profilesTab.autoArenaDown.OptKey = "Arena"
	profilesTab.autoArenaDown.ToggleUpadte = AutoDropDown_ToggleUpadte

	profilesTab.autoBGDown = ELib:DropDown(profilesTab,220,10):Point("TOPLEFT",profilesTab.autoArenaDown,0,-40):Size(235):AddText(BATTLEGROUND,11,function(self)self:NewPoint("TOPLEFT",'x',5,12):Color(1,.82,0,1) end)
	profilesTab.autoBGDown.OptKey = "BG"
	profilesTab.autoBGDown.ToggleUpadte = AutoDropDown_ToggleUpadte

	profilesTab.autoOtherDown = ELib:DropDown(profilesTab,220,10):Point("TOPLEFT",profilesTab.autoDungDown,0,-40):Size(235):AddText(OTHER,11,function(self)self:NewPoint("TOPLEFT",'x',5,12):Color(1,.82,0,1) end)
	profilesTab.autoOtherDown.OptKey = "Other"
	profilesTab.autoOtherDown.ToggleUpadte = AutoDropDown_ToggleUpadte

	local class = (select(2,UnitClass'player')) or ""

	profilesTab.autoTextSpec = ELib:Text(profilesTab,L.cd2AutoChangeSpecTooltip,12):Size(605,200):Point(10,-380):Top():Color()

	profilesTab.autoSpec1Down = ELib:DropDown(profilesTab,220,10):Point(10,-410):Size(235)
	profilesTab.autoSpec1Down.OptKey = "Spec1" .. class
	profilesTab.autoSpec1Down.ToggleUpadte = AutoDropDown_ToggleUpadte

	profilesTab.autoSpec2Down = ELib:DropDown(profilesTab,220,10):Point("TOPLEFT",profilesTab.autoSpec1Down,0,-40):Size(235)
	profilesTab.autoSpec2Down.OptKey = "Spec2" .. class
	profilesTab.autoSpec2Down.ToggleUpadte = AutoDropDown_ToggleUpadte

	profilesTab.autoSpec3Down = ELib:DropDown(profilesTab,220,10):Point("TOPLEFT",profilesTab.autoSpec1Down,320,0):Size(235)
	profilesTab.autoSpec3Down.OptKey = "Spec3" .. class
	profilesTab.autoSpec3Down.ToggleUpadte = AutoDropDown_ToggleUpadte

	profilesTab.autoSpec4Down = ELib:DropDown(profilesTab,220,10):Point("TOPLEFT",profilesTab.autoSpec2Down,320,0):Size(235)
	profilesTab.autoSpec4Down.OptKey = "Spec4" .. class
	profilesTab.autoSpec4Down.ToggleUpadte = AutoDropDown_ToggleUpadte

	if not GetSpecializationInfo then
		profilesTab.autoTextSpec:Hide()
		profilesTab.autoSpec1Down:Hide()
		profilesTab.autoSpec2Down:Hide()
		profilesTab.autoSpec3Down:Hide()
		profilesTab.autoSpec4Down:Hide()
	else
		for i=1,4 do
			local _, name = GetSpecializationInfo(i)
			if name then
				profilesTab["autoSpec"..i.."Down"]:AddText(name,11,function(self)self:NewPoint("TOPLEFT",'x',5,12):Color(1,.82,0,1) end)
			else
				profilesTab["autoSpec"..i.."Down"]:Hide()
			end
		end
	end

	profilesTab:UpdateAutoTexts()

	profilesTab.chkKeepText = ELib:Check(profilesTab,L.NoteProfilesKeepText,VART.Note.Profiles.KeepText):Point("TOPLEFT",profilesTab.autoSpec2Down,"BOTTOMLEFT",0,-25):OnClick(function(self) 
		if self:GetChecked() then
			VART.Note.Profiles.KeepText = true
		else
			VART.Note.Profiles.KeepText = nil
		end
	end)



	self.textHelp = ELib:Text(self.tab.tabs[4],
		"|cffffff00||cffRRGGBB|r...|cffffff00||r|r - "..L.NoteHelp1..
		((not ART.isClassic or ART.isCata) and "|n|cffffff00{D}|r...|cffffff00{/D}|r - "..format(L.NoteHelp2,DAMAGER) or "")..
		((not ART.isClassic or ART.isCata) and "|n|cffffff00{H}|r...|cffffff00{/H}|r - "..format(L.NoteHelp2,HEALER) or "")..
		((not ART.isClassic or ART.isCata) and "|n|cffffff00{T}|r...|cffffff00{/T}|r - "..format(L.NoteHelp2,TANK) or "")..
		"|n|cffffff00{spell:|r|cff00ff0017|r|cffffff00}|r - "..L.NoteHelp3..
		"|n|cffffff00{self}|r - "..L.NoteHelp4..
		"|n|cffffff00{p:|r|cff00ff00JaneD|r|cffffff00,|r|cff00ff00JennyB-HowlingFjord|r|cffffff00}|r...|cffffff00{/p}|r - "..L.NoteHelp5..
		"|n|cffffff00{!p:|r|cff00ff00Leeroy|r|cffffff00,|r|cff00ff00Juron|r|cffffff00}|r...|cffffff00{/p}|r - "..L.NoteHelp5b..
		"|n|cffffff00{icon:|r|cff00ff00Interface/Icons/inv_hammer_unique_sulfuras|r|cffffff00}|r - "..L.NoteHelp6..
		"|n|cffffff00{c:|r|cff00ff00Paladin,Priest|r|cffffff00}|r...|cffffff00{/c}|r - "..L.NoteHelp8..
		"|n|cffffff00{!c:|r|cff00ff00Mage,Hunter|r|cffffff00}|r...|cffffff00{/c}|r - "..L.NoteHelp8b..
		"|n|cffffff00{g|r|cff00ff002|r|cffffff00}|r...|cffffff00{/g}|r - "..L.NoteHelp10..
		"|n|cffffff00{!g|r|cff00ff0034|r|cffffff00}|r...|cffffff00{/g}|r - "..L.NoteHelp10b..
		(ART.isClassic and "|n|cffffff00{race:|r|cff00ff00troll,orc|r|cffffff00}|r...|cffffff00{/race}|r - "..L.NoteHelp11 or "")..
		(ART.isClassic and "|n|cffffff00{!race:|r|cff00ff00dwarf|r|cffffff00}|r...|cffffff00{/race}|r - "..L.NoteHelp11b or "")..
		("|n|cffffff00{time:|r|cff00ff002:45|r|cffffff00}|r - "..L.NoteHelp7 or "")..
		(not ART.isClassic and "|n|cffffff00{p|r|cff00ff002|r|cffffff00}|r...|cffffff00{/p}|r - "..L.NoteHelp9 or "")
	):Point("TOPLEFT",10,-20):Point("TOPRIGHT",-10,-20):Color()

	self.advancedHelp = ELib:Button(self.tab.tabs[4],L.NoteHelpAdvanced):Size(400,20):Point("TOP",self.textHelp,"BOTTOM",0,-20):OnClick(function() 
		--module.options.textHelpAdv:SetShown(not module.options.textHelpAdv:IsShown())
		module.options.advancedScroll:SetShown(not module.options.advancedScroll:IsShown())
	end)

	self.advancedScroll = ELib:ScrollFrame(self.tab.tabs[4]):Size(850,100):Point("TOP",self.advancedHelp,"BOTTOM",0,-20):Point("BOTTOM",self.tab.tabs[4],"BOTTOM",0,0):Height(400):Shown(false)
	self.advancedScroll.C:SetWidth(850 - 16)
	ELib:Border(self.advancedScroll,0)
	ELib:DecorationLine(self.advancedScroll):Point("TOPLEFT",0,1):Point("BOTTOMRIGHT",'x',"TOPRIGHT",0,0)

	self.textHelpAdv = ELib:Text(self.advancedScroll.C,
		"|cffffff00{time:|r|cff00ff001:06,p2|r|cffffff00}|r - "..L.NoteHelpAdv1..
		"|n|cffffff00{time:|r|cff00ff000:30,SCC:17:2|r|cffffff00}|r - "..L.NoteHelpAdv2..
		"|n   "..(HUD_EDIT_MODE_ENABLE_ADVANCED_OPTIONS or "Advanced Options")..": |cffffff00{time:|cff00ff00TIME|r,|cff00ff00SCC/SCS/SAA/SAR|r:|cff00ff00SPELL_ID|r:|cff00ff00SPELL_COUNT|r:|cff00ffffSOURCE_NAME|r:|cff00ffffPHASE|r}|r"..
		"|n|cffffff00{time:|r|cff00ff002:00,e,customevent|r|cffffff00}|r - "..L.NoteHelpAdv3..
		"|n|cffffff00{time:|r|cff00ff003:40,glowall|r|cffffff00}|r - "..L.NoteHelpAdv6..
		"|n|cffffff00{time:|r|cff00ff004:15,glow|r|cffffff00}|r - "..L.NoteHelpAdv7..
		"|n|cffffff00{time:|r|cff00ff000:45,wa:nzoth_hs1|r|cffffff00}|r - "..L.NoteHelpAdv4..
		"|n   WA Function example:|n   Events: |cffffff00ART_NOTE_TIME_EVENT|r|n   |cffff8bf3function(event,...)|n     if event == \"ART_NOTE_TIME_EVENT\" then|n       local timerName, timeLeft, noteText = ...|n       if timerName == \"nzoth_hs1\" and timeLeft == 3 then|n         return true|n       end|n     end|n   end|r|n"..
		"|n"..L.NoteHelpAdv5.."|n |cffe6ff15{time:0:30,SCC:17:2,wa:eventName1,wa:eventName2}|r|n |cffff9f05{time:1:40,p:Shade of Kael'thas}|r|n |cffe6ff15{p,SCC:17:2}Until end of the fight{/p}|r|n |cffff9f05{p,SCC:17:2,SCC:17:3}Until second condition{/p}|r|n |cffe6ff15{pShade of Kael'thas}Phase with name{/p}|r|n |cffff9f05{time:0:20,p2,wa:use_hs,glowall}|r"..
		"|n |cffe6ff15{time:65,SCC:17:2:"..UnitName'player'.."} Count casts only for player "..UnitName'player'.." |r|n |cffe6ff15{time:1:05,SCC:17:2::p3} Count casts only on phase 3 |r"
	):Point("LEFT",10,0):Point("RIGHT",-10,0):Point("TOP",0,-5):Color()

	local height = self.textHelpAdv:GetHeight()
	if height and height > 100 then
		self.advancedScroll:Height(height + 10)
	end

	module:RegisterEvents("GROUP_ROSTER_UPDATE")

	function self:OnShow()
		module.main:GROUP_ROSTER_UPDATE()
	end

	function self:UpdateOptions()
		self.chkEnable:SetChecked(VART.Note.enabled)
		self.chkEnable:ColorState()
		self.chkFix:SetChecked(VART.Note.Fix)
		self.chkOnlyPromoted:SetChecked(VART.Note.OnlyPromoted)
		self.chkOnlyInRaid:SetChecked(VART.Note.HideOutsideRaid)
		self.chkOnlyInRaidKInstance:SetChecked(VART.Note.ShowOnlyInRaid)
		self.chkOnlySelf:SetChecked(VART.Note.ShowOnlyPersonal)
		self.chkSelfWindow:SetChecked(VART.Note.PersonalWindow)
		self.chkHideInCombat:SetChecked(VART.Note.HideInCombat)
		self.chkSaveAllNew:SetChecked(VART.Note.SaveAllNew)
		self.chkEnableWhenReceive:SetChecked(VART.Note.EnableWhenReceive)
		self.sliderFontSize:SetTo(VART.Note.FontSize or 12)
		do
			local arg = VART.Note.FontName or ART.F.defFont
			local FontNameForDropDown = arg:match("\\([^\\]*)$")
			self.dropDownFont:SetText(FontNameForDropDown or arg)
		end
		self.chkOutline:SetChecked(VART.Note.Outline)
		self.slideralpha:SetTo(VART.Note.Alpha or 100)
		self.sliderscale:SetTo(VART.Note.Scale or 100)
		self.slideralphaback:SetTo(VART.Note.ScaleBack or 100)
		self.chkTimersHidePassed:SetChecked(VART.Note.TimerPassedHide)
		self.chkTimersGlow:SetChecked(VART.Note.TimerGlow)
		self.chkTimersOnlyMy:SetChecked(VART.Note.TimerOnlyMy)

		self.frameTypeGlow1:SetChecked(false)
		self.frameTypeGlow1:SetChecked(false)
		self.frameTypeGlow1:SetChecked(false)
		if VART.Note.TimerGlowType == 2 then
			self.frameTypeGlow2:SetChecked(true)
		elseif VART.Note.TimerGlowType == 3 then
			self.frameTypeGlow3:SetChecked(true)
		else
			self.frameTypeGlow1:SetChecked(true)
		end

		UpdatePageAfterGettingNote()

		self.tab.tabs[3].currentName:UpdateText()
		self.tab.tabs[3]:UpdateAutoTexts()
	end

	self.isWide = true
end

local function NoteWindow_OnDragStart(self)
	if self:IsMovable() then
		self:StartMoving()
	end
end

local function NoteWindow_OnDragStop(self)
	self:StopMovingOrSizing()
	VART.Note[self.Name.."Left"] = self:GetLeft()
	VART.Note[self.Name.."Top"] = self:GetTop()
end

local function NoteWindow_OnSizeChanged(self, width, height)
	local width_, height_ = self:GetSize()
	if VART and VART.Note then
		VART.Note[self.Name.."Width"] = width
		VART.Note[self.Name.."Height"] = height

		self:UpdateText()
	end
	self.sf.C:SetWidth( width_ )
end

local function NoteWindow_UpdateFont(self)
	local font = VART and VART.Note and VART.Note.FontName or ART.F.defFont
	local size = VART and VART.Note and VART.Note.FontSize or 12
	local outline = VART and VART.Note and VART.Note.Outline and "OUTLINE" or ""
	local isValidFont = self.text:SetFont(font,size,outline)
	local c = 2
	while self["text"..c] do
		self["text"..c]:SetFont(font,size,outline)
		c = c + 1
	end

	if not isValidFont then 
		self.text:SetFont(GameFontNormal:GetFont(),size,outline)

		local c = 2
		while self["text"..c] do
			self["text"..c]:SetFont(GameFontNormal:GetFont(),size,outline)
			c = c + 1
		end
	end
end

local function NoteWindow_UpdateText(self,onlyTimerUpdate)
	module.db.glowStatus = nil

	local text = txtWithIcons(self, self:GetRawText(), onlyTimerUpdate)

	local c = 2
	while self["text"..c] do
		self["text"..c]:SetText(" ")
		c = c + 1
	end
	
	if #text > 8192 then
		local lennow = 0
		local texts = {""}
		local c = 1
		for w in string.gmatch(text,"[^\n]+\n*") do
			lennow = lennow + #w
			if lennow > 8192 then
				c = c + 1
				texts[c] = ""
				lennow = #w
			end
			texts[c] = texts[c] .. w
		end

		self.text:SetText(texts[1])

		local anyNew = false
		for i=2,c do
			anyNew = self.text:Add(i) or anyNew
			self["text"..i]:SetText(texts[i])
		end
		if anyNew then
			self:UpdateFont()
		end
	else
		self.text:SetText(text)
	end	

	if module.db.glowStatus and not self.GlowShowed then
		self:ShowGlow()
		self.GlowShowed = true
	elseif not module.db.glowStatus and self.GlowShowed then
		self:HideGlow()
		self.GlowShowed = false
	end

	ART.F:FireCallback("Note_UpdateText",self)
end

local glowColor = {0,1,0,1}
local function NoteWindow_ShowGlow(self)
	local LCG = LibStub("LibCustomGlow-1.0",true)
	if not LCG then
		return
	end

	if VART.Note.TimerGlowType == 2 then
		LCG.ButtonGlow_Start(self)
	elseif VART.Note.TimerGlowType == 3 then
		LCG.AutoCastGlow_Start(self,glowColor,16,nil,2)
	else
		LCG.PixelGlow_Start(self,glowColor,nil,nil,nil,3,1,1) 
	end
end
local function NoteWindow_HideGlow(self)
	local LCG = LibStub("LibCustomGlow-1.0",true)
	if LCG then
		LCG.ButtonGlow_Stop(self)
		LCG.AutoCastGlow_Stop(self)
		LCG.PixelGlow_Stop(self)
	end
end

local function NoteWindow_TextFixLag(self)
	self:SetParent(self:GetParent().sf.C)
	self:ClearAllPoints()
	self:SetPoint("TOPLEFT",5,-5)
	self:SetPoint("TOPRIGHT",-5,-5)
end

local function NoteWindow_TextAdd(self,c)
	local parent = self.mf
	if parent["text"..c] then
		return
	end
	local text = parent:CreateFontString(nil,"ARTWORK")
	parent["text"..c] = text
	text:SetParent(parent.sf.C)
	text:SetFont(ART.F.defFont, 12, "")
	local prev = c == 2 and parent.text or parent["text"..(c-1)]
	text:SetPoint("TOPLEFT",prev,"BOTTOMLEFT",0,0)
	text:SetPoint("TOPRIGHT",prev,"BOTTOMRIGHT",0,0)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetText(" ")
	text:SetNonSpaceWrap(true)

	return true
end

local function NoteWindow_SetShadowComment(self,val)
	if val then
		ART.lib.AddShadowComment(self,nil,L.message)
	else
		ART.lib.AddShadowComment(self,1)
	end
end

local function NoteWindow_UpdateVisual(self)
	self:ClearAllPoints()
	if VART.Note[self.Name.."Left"] and VART.Note[self.Name.."Top"] then 
		self:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",VART.Note[self.Name.."Left"],VART.Note[self.Name.."Top"])
	else
		self:SetPoint("TOPLEFT",UIParent,"CENTER",-150,250)
	end

	self:SetSize(VART.Note[self.Name.."Width"] or 300,VART.Note[self.Name.."Height"] or 200) 

	if VART.Note.Alpha then 
		self:SetAlpha(VART.Note.Alpha/100) 
	else
		self:SetAlpha(1) 
	end
	if VART.Note.Scale then 
		self:SetScale(VART.Note.Scale/100) 
	else
		self:SetScale(1) 
	end
	if VART.Note.ScaleBack then
		self.background:SetColorTexture(0, 0, 0, VART.Note.ScaleBack/100)
	else
		self.background:SetColorTexture(0, 0, 0, 1)
	end
	if VART.Note.Fix then
		self:SetMovable(false)
		self:EnableMouse(false)
		self.buttonResize:Hide()
	else
		self:SetMovable(true)
		self:EnableMouse(true)
		self.buttonResize:Show()
		self:SetShadowComment(true)
	end

	if VART.Note.Strata and ART.F.table_find(frameStrataList,VART.Note.Strata) then
		self:SetFrameStrata(VART.Note.Strata)
	end
end

local function NoteWindow_Enable(self)
	self.Show = self._Show
	self:Show()
end
local function NoteWindow_Disable(self)
	self.Show = self.Hide
	self:Hide()
end

local function NoteWindow_ScaleFix(self,val)
	ART.F.SetScaleFix(self,val)
end

local function NoteWindow_Custom_OnEvent(self,event,...)
	if event == "MODIFIER_STATE_CHANGED" and self:IsShown() and not InCombatLockdown() then
		local key,state = ...
		if key == "LSHIFT" then
			if state == 1 then
				self:EnableMouse(true)
				self:SetPassThroughButtons("LeftButton")
				self.mouseOn = true
			else
				if VART.Note.Fix then
					self:EnableMouse(false)
				end
				self:SetPassThroughButtons()
				self.mouseOn = false
			end
		end
	end
end

local function NoteWindow_Custom_OnMouseDown(self,button)
	if self.mouseOn and IsShiftKeyDown() and button == "RightButton" then
		self:Disable()
		if VART.Note.Fix then
			self:EnableMouse(false)
		end
		self.mouseOn = false
	end
end

local function NoteWindow_RawNull()
	return ""
end


local allWindows = {}

function module:CreateNoteWindow(windowName,isCustomWindow)
	windowName = windowName or ""
	
	local frame = CreateFrame("Frame","ARTNote"..windowName,UIParent)
	frame.Name = windowName
	frame:SetSize(200,100)
	frame:SetPoint("CENTER",UIParent, "CENTER", 0, 0)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", NoteWindow_OnDragStart)
	frame:SetScript("OnDragStop", NoteWindow_OnDragStop)
	frame:SetFrameStrata("HIGH")
	frame:SetResizable(true)
	frame:SetResizeBounds(30, 30, 2000, 2000)
	frame:SetScript("OnSizeChanged", NoteWindow_OnSizeChanged)
	frame:Hide() 
	frame._Show = frame.Show

	if isCustomWindow then
		frame:RegisterEvent"MODIFIER_STATE_CHANGED"
		frame:SetScript("OnEvent",NoteWindow_Custom_OnEvent)
		frame:SetScript("OnMouseDown",NoteWindow_Custom_OnMouseDown)
	end


	frame.SetShadowComment = NoteWindow_SetShadowComment
	frame.UpdateVisual = NoteWindow_UpdateVisual
	frame.Enable = NoteWindow_Enable
	frame.Disable = NoteWindow_Disable
	frame.ScaleFix = NoteWindow_ScaleFix

	frame.GetRawText = NoteWindow_RawNull
	
	frame.sf = CreateFrame("ScrollFrame", nil, frame)
	frame.sf:SetPoint("TOPLEFT",0,0)
	frame.sf:SetAllPoints()
	frame.sf.C = CreateFrame("Frame", nil, frame.sf) 
	frame.sf:SetScrollChild(frame.sf.C)
	frame.sf.C:SetSize(200,20000)
	frame.sf:Hide()
	
	ELib:FixPreloadFont(frame,function() 
		if VART then
			frame.text:SetFont(GameFontWhite:GetFont(),11,"")
			frame:UpdateFont() 
			return true
		end
	end)
	
	frame.UpdateFont = NoteWindow_UpdateFont
	
	ART.F:RegisterCallback("CallbackRegistered", function(_,eventName)
		if eventName == "Note_UpdateText" then
			frame:UpdateText()
		end
	end)
	ART.F:RegisterCallback("CallbackUnregistered", function(_,eventName,_,callbacks)
		if callbacks ~= 0 then
			return
		elseif eventName == "Note_UpdateText" then
			frame:UpdateText()
		end
	end)
	
	frame.UpdateText = NoteWindow_UpdateText
	frame.ShowGlow = NoteWindow_ShowGlow
	frame.HideGlow = NoteWindow_HideGlow
	
	
	frame.background = frame:CreateTexture(nil, "BACKGROUND")
	frame.background:SetColorTexture(0, 0, 0, 1)
	frame.background:SetAllPoints()
	
	frame.text = frame:CreateFontString(nil,"ARTWORK")
	frame.text.mf = frame
	frame.text:SetFont(ART.F.defFont, 12, "")
	frame.text:SetPoint("TOPLEFT",5,-5)
	frame.text:SetPoint("TOPRIGHT",-5,-5)
	frame.text:SetJustifyH("LEFT")
	frame.text:SetJustifyV("TOP")
	frame.text:SetText(" ")
	
	frame.text.FixLag = NoteWindow_TextFixLag
	
	frame.sf:Show()
	frame.text:FixLag()
	
	frame.text:SetNonSpaceWrap(true)
	
	frame.text.Add = NoteWindow_TextAdd
	
	frame.buttonResize = CreateFrame("Frame",nil,frame)
	frame.buttonResize:SetSize(15,15)
	frame.buttonResize:SetPoint("BOTTOMRIGHT", 0, 0)
	frame.buttonResize.back = frame.buttonResize:CreateTexture(nil, "BACKGROUND")
	frame.buttonResize.back:SetTexture("Interface\\AddOns\\"..GlobalAddonName.."\\media\\Resize.tga")
	frame.buttonResize.back:SetAllPoints()
	frame.buttonResize:SetScript("OnMouseDown", function(self)
		frame:StartSizing()
	end)
	frame.buttonResize:SetScript("OnMouseUp", function(self)
		frame:StopMovingOrSizing()
	end)

	frame.red_back = CreateFrame("Frame",nil,frame)
	frame.red_back:SetPoint("TOPLEFT",0,0)
	frame.red_back:SetPoint("BOTTOMRIGHT",0,0)
	frame.red_back.b = frame.red_back:CreateTexture(nil, "BACKGROUND", nil, 1)
	frame.red_back.b:SetColorTexture(1, 0, 0, .2)
	frame.red_back.b:SetAllPoints()
	frame.red_back.s = ELib:Shadow(frame.red_back,20)
	frame.red_back.s:SetBackdropBorderColor(1, 0, 0, .2)
	frame.red_back:Hide()
	local red_back_t = 1
	frame.red_back:SetScript("OnShow",function()
		red_back_t = 3
	end)
	frame.red_back:SetScript("OnUpdate",function(self,tmr)
		red_back_t = red_back_t - tmr
		if red_back_t <= 0 then
			self:Hide()
			return
		end
		self.s:SetBackdropBorderColor(1, 0, 0, max(0, .4 * min(2,red_back_t)/2))
		self.b:SetColorTexture(1, 0, 0, max(0, .4 * min(2,red_back_t)/2))
	end)

	allWindows[#allWindows+1] = frame

	return frame
end

module.frame = module:CreateNoteWindow()
module.frame.GetRawText = function()
	if VART.Note.ShowOnlyPersonal then
		return "{self}"
	elseif VART.Note.PersonalWindow then
		return VART.Note.Text1 or ""
	elseif type(VART.Note.Text1)=="string" and not VART.Note.Text1:find("{self}") then
		return (VART.Note.Text1) .. (VART.Note.Text1~="" and VART.Note.Text1~=" " and "\n" or "") .. "{self}"
	else
		return VART.Note.Text1 or ""
	end
end

module.frame_personal = module:CreateNoteWindow("Personal")
module.frame_personal.GetRawText = function()
	return "{self}"
end

local window_count = 0
function module:AddWindow(blackNoteID,forceWindowID)
	if not blackNoteID then
		return
	end
	if forceWindowID and (type(forceWindowID) ~= "number" or forceWindowID > 20) then
		forceWindowID = nil
	end
	local w
	for i=1,#allWindows do
		local window = allWindows[i]
		if forceWindowID and window.Name == tostring(forceWindowID) then
			w = window
			break
		elseif not forceWindowID and window.bID == blackNoteID and window:IsShown() then
			w = window
			break
		elseif not forceWindowID and tonumber(window.Name) and not window:IsShown() and not w then
			w = window
		end
	end
	if not w then
		if forceWindowID then
			repeat
				window_count = window_count + 1
				w = module:CreateNoteWindow(tostring(window_count),true)
				w:UpdateVisual()
			until (window_count - 1) == forceWindowID
		end
		window_count = window_count + 1
		w = module:CreateNoteWindow(tostring(window_count),true)
		w:UpdateVisual()
	end
	w.bID = blackNoteID
	w.GetRawText = function()
		return VART.Note.Black[blackNoteID] or ""
	end
	w:UpdateText()
	w:Enable()
	w.red_back:Show()
end

function module:IsWindowOpenedForDraft(blackNoteID)
	for i=1,#allWindows do
		local window = allWindows[i]
		if window.bID == blackNoteID then
			return window
		end
	end
end

module.allframes = {}
setmetatable(module.allframes, {__index = function(table, key)
	if not allWindows[1][key] then
		return
	end
	if type(allWindows[1][key]) == "function" then
		return function(_, ...)
			for i=1,#allWindows do
				allWindows[i][key](allWindows[i],...)
			end
		end
	else
		local nt = {}
		setmetatable(nt,{__index = function(_, key2)
			return function(_, ...)
				for i=1,#allWindows do
					allWindows[i][key][key2](allWindows[i][key],...)
				end
			end
		end})
		return nt
	end
end})


function module.frame:Save(blackNoteID)
	VART.Note.Text1 = (blackNoteID and VART.Note.Black[blackNoteID] or VART.Note.Text1 or "")

	ART.F:FireCallback("Note_SendText",VART.Note.Text1)

	if not blackNoteID and module.options.NoteEditBox and VART.Note.OptionsFormatting then
	--	VART.Note.Text1 = VART.Note.Text1:gsub("|([Ttcr])","||%1")
	end

	if #VART.Note.Text1 == 0 then
		VART.Note.Text1 = " "
	end
	local txttosand = VART.Note.Text1
	local arrtosand = {}
	local j = 1
	local indextosnd = tostring(GetTime())..tostring(math.random(1000,9999))
	for i=1,#txttosand do
		if i%220 == 0 then
			arrtosand[j]=string.sub (txttosand, (j-1)*220+1, j*220)
			j = j + 1
		elseif i == #txttosand then
			arrtosand[j]=string.sub (txttosand, (j-1)*220+1)
			j = j + 1
		end
	end
	local encounterID = VART.Note.AutoLoad[blackNoteID or 0] or "-"
	local noteName = (blackNoteID and VART.Note.BlackNames[blackNoteID]) or (not blackNoteID and VART.Note.DefName) or ""

	if blackNoteID then
		VART.Note.AutoLoad[0] = VART.Note.AutoLoad[blackNoteID]
		VART.Note.DefName = VART.Note.BlackNames[blackNoteID]
		if VART.Note.DefName then
			VART.Note.DefName = VART.Note.DefName:gsub("%*$","")
		end
	end

	if ART.isClassic and not ART.isLK and false then
		local MSG_LIMIT_COUNT = 10
		local MSG_LIMIT_TIME = 6
		if #arrtosand >= MSG_LIMIT_COUNT and module.options.buttonsend then
			module.options.buttonsend:Disable()
			C_Timer.After(floor((#arrtosand+1)/MSG_LIMIT_COUNT * MSG_LIMIT_TIME),function()
				module.options.buttonsend:Enable()
			end)
		end
		for i=1,#arrtosand,MSG_LIMIT_COUNT do
			local start = i
			C_Timer.After(floor((start-1)/MSG_LIMIT_COUNT) * MSG_LIMIT_TIME + 0.05,function()
				for j=start,min(#arrtosand,start+MSG_LIMIT_COUNT-1) do
					ART.F.SendExMsg("multiline",indextosnd.."\t"..arrtosand[j])
				end
			end)
		end
		C_Timer.After(floor((#arrtosand)/MSG_LIMIT_COUNT) * MSG_LIMIT_TIME + 0.1,function()
			ART.F.SendExMsg("multiline_add",ART.F.CreateAddonMsg(indextosnd,encounterID,noteName))
		end)
	else
		for i=1,#arrtosand do
			ART.F.SendExMsg("multiline",indextosnd.."\t"..arrtosand[i])
		end
		ART.F.SendExMsg("multiline_add",ART.F.CreateAddonMsg(indextosnd,encounterID,noteName))
	end
end 

function module.frame:Clear() 
	module.options.NoteEditBox.EditBox:SetText("") 
end 

function module:addonMessage(sender, prefix, ...)
	if prefix == "multiline" then
		if VART.Note.OnlyPromoted and IsInRaid() and not ART.F.IsPlayerRLorOfficer(sender) then
			return
		end

		VART.Note.LastUpdateName = sender
		VART.Note.LastUpdateTime = time()

		local msgnowindex,lastnowtext = ...
		if tostring(msgnowindex) == tostring(module.db.msgindex) then
			module.db.lasttext = module.db.lasttext .. lastnowtext
		else
			module.db.lasttext = lastnowtext
		end
		module.db.msgindex = msgnowindex
		VART.Note.Text1 = module.db.lasttext
		ART.F:FireCallback("Note_ReceivedText",VART.Note.Text1)
		module.allframes:UpdateText()
		if module.options.NoteEditBox then
			if module.options.IsMainNoteNow then
				module.options.NoteEditBox.EditBox:SetText(VART.Note.Text1)
			end

			module.options.lastUpdate:SetText( L.NoteLastUpdate..": "..VART.Note.LastUpdateName.." ("..date("%H:%M:%S %d.%m.%Y",VART.Note.LastUpdateTime)..")" )
		end
		VART.Note.AutoLoad[0] = nil
		if module.options.UpdatePageAfterGettingNote then
			module.options.UpdatePageAfterGettingNote()
		end
		if VART.Note.EnableWhenReceive and not VART.Note.enabled then
			module:Enable()
		end
		module.allframes.red_back:Show()
		if type(WeakAuras)=="table" and WeakAuras.ScanEvents and type(WeakAuras.ScanEvents)=="function" then
			WeakAuras.ScanEvents("EART_NOTE_UPDATE")
			WeakAuras.ScanEvents("ART_NOTE_UPDATE")
		end
	elseif prefix == "multiline_add" then
		if VART.Note.OnlyPromoted and IsInRaid() and not ART.F.IsPlayerRLorOfficer(sender) then
			return
		end
		if sender == ART.SDB.charKey then
			return
		end
		local msgIndex,encounterID,noteName = ...
		if tostring(msgIndex) ~= tostring(module.db.msgindex) then
			return
		end
		encounterID = tonumber(encounterID)
		if noteName == "" then noteName = nil end
		VART.Note.AutoLoad[0] = encounterID
		VART.Note.DefName = noteName
		if VART.Note.SaveAllNew then
			local finded = false
			if noteName then
				noteName = noteName:gsub("%*+$","").."*"
				for i=1,#VART.Note.Black do
					if VART.Note.BlackNames[i] == noteName and VART.Note.AutoLoad[i] == encounterID then
						VART.Note.Black[i] = VART.Note.Text1
						VART.Note.AutoLoad[i] = encounterID
						VART.Note.BlackLastUpdateName[i] = sender
						VART.Note.BlackLastUpdateTime[i] = time()
						finded = true
						if module:IsWindowOpenedForDraft(i) then
							module.allframes:UpdateText()
						end
						break
					end
				end
			elseif encounterID then
				for i=1,#VART.Note.Black do
					if VART.Note.AutoLoad[i] == encounterID and (not VART.Note.BlackNames[i] or VART.Note.BlackNames[i] == "") then
						VART.Note.Black[i] = VART.Note.Text1
						VART.Note.BlackLastUpdateName[i] = sender
						VART.Note.BlackLastUpdateTime[i] = time()
						finded = true
						if module:IsWindowOpenedForDraft(i) then
							module.allframes:UpdateText()
						end
						break
					end
				end

			end
			if not finded then
				local newIndex = #VART.Note.Black + 1
				VART.Note.Black[newIndex] = VART.Note.Text1
				VART.Note.AutoLoad[newIndex] = encounterID
				VART.Note.BlackNames[newIndex] = noteName
				VART.Note.BlackLastUpdateName[newIndex] = sender
				VART.Note.BlackLastUpdateTime[newIndex] = time()
				if module.options.NotesListUpdateNames then
					module.options.NotesListUpdateNames()
				end
			end
		end 
		if module.options.UpdatePageAfterGettingNote then
			module.options.UpdatePageAfterGettingNote()
		end
	elseif prefix == "multiline_timer_sync" then
		local name = ...
		ART.F.Note_Timer(name)
	end 
end 

local gruevent = {}

NewVARTTableData = {
	OnlyPromoted = true,
	OptionsFormatting = true,
	Strata = "HIGH",
}

local isFirstLoad

function module.main:ADDON_LOADED()
	VART = _G.VART
	VART.Note = VART.Note or ART.F.table_copy2(NewVARTTableData)

	VART.Note.Profiles = VART.Note.Profiles or {}
	VART.Note.Profiles.List = VART.Note.Profiles.List or {}
	VART.Note.Profiles.Now = VART.Note.Profiles.Now or "default"

	VART.Note.Black = VART.Note.Black or {}
	VART.Note.AutoLoad = VART.Note.AutoLoad or {}

	VART.Note.FontSize = VART.Note.FontSize or 12

	VART.Note.Strata = VART.Note.Strata or "HIGH"

	VART.Note.BlackNames = VART.Note.BlackNames or {}

	for i=1,3 do
		VART.Note.Black[i] = VART.Note.Black[i] or ""
	end

	VART.Note.BlackLastUpdateName = VART.Note.BlackLastUpdateName or {}
	VART.Note.BlackLastUpdateTime = VART.Note.BlackLastUpdateTime or {}

	if VART.Note.enabled then 
		module:Enable()
	else
		module:Disable()
	end
	C_Timer.After(5,function()
		module.allframes:UpdateFont()
	end)

	if VART.Note.Text1 then 
		module.allframes:UpdateText()
	end

	module:RegisterAddonMessage()
	module:RegisterSlash()

	module.allframes:UpdateVisual()

	module:RegisterEvents('ZONE_CHANGED_NEW_AREA','PLAYER_SPECIALIZATION_CHANGED')
	if ART.isCata then
		module:RegisterEvents('PLAYER_TALENT_UPDATE')
	end
	if not isFirstLoad then
		isFirstLoad = true
		C_Timer.After(2,module.CheckZoneProfiles)
		C_Timer.After(2,function() module.main:PLAYER_TALENT_UPDATE() end)
	end
end

function module.main:PLAYER_LOGIN()
	if VART.Note.enabled then
		module.allframes:UpdateText()
	end
end


function module:Enable()
	VART.Note.enabled = true
	if module.options.chkEnable then
		module.options.chkEnable:SetChecked(true)
	end
	module:RegisterEvents("PLAYER_LOGIN","ENCOUNTER_END","ENCOUNTER_START")
	if VART.Note.HideOutsideRaid then
		module:RegisterEvents("GROUP_ROSTER_UPDATE")
	end
	if VART.Note.HideInCombat then
		module:RegisterEvents('PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED')
	end
	if VART.Note.PersonalWindow then
		module.frame_personal:Enable()
	else
		module.frame_personal:Disable()
	end
	module:Visibility()
	GSUB_AutoColorCreate()
end

function module:Disable()
	VART.Note.enabled = nil
	if module.options.chkEnable then
		module.options.chkEnable:SetChecked(false)
	end
	module:UnregisterEvents('PLAYER_REGEN_DISABLED','PLAYER_REGEN_ENABLED',"PLAYER_LOGIN","ENCOUNTER_END","ENCOUNTER_START")
	module:Visibility()
end

local Note_CombatState = false

function module:Visibility()
	local bool = true
	if not VART.Note.enabled then
		bool = bool and false
	end
	if bool and VART.Note.HideOutsideRaid then
		if GetNumGroupMembers() > 0 then
			bool = bool and true
		else
			bool = bool and false
		end
	end
	if bool and VART.Note.HideInCombat then
		if Note_CombatState then
			bool = bool and false
		else
			bool = bool and true
		end
	end
	if bool and VART.Note.ShowOnlyInRaid then
		local _,zoneType = IsInInstance()
		if zoneType == "raid" then
			bool = bool and true
		else
			bool = bool and false
		end
	end

	if bool then
		module.allframes:Show()
	else
		module.allframes:Hide()
	end
end

local party_uids = {'player','party1','party2','party3','party4'}
function module.main:GROUP_ROSTER_UPDATE()
	C_Timer.After(1, module.Visibility)
	GSUB_AutoColorCreate()
	if not module.options.raidnames or not module.options:IsVisible() then
		return
	end
	for i=1,8 do gruevent[i] = 0 end
	for _,name,subgroup,class in ART.F.IterateRoster do
		gruevent[subgroup] = gruevent[subgroup] + 1
		local cR,cG,cB = ART.F.classColorNum(class)

		local POS = gruevent[subgroup] + (subgroup - 1) * 5
		local obj = module.options.raidnames[POS]

		if obj then
			name = ART.F.delUnitNameServer(name)
			local colorCode = ART.F.classColor(class)
			obj.iconText = "||c"..colorCode..name.."||r "
			obj.iconTextShift = name
			obj.html:SetText(name)
			obj.html:SetTextColor(cR, cG, cB, 1)
		end
	end
	for i=1,8 do
		for j=(gruevent[i]+1),5 do
			local frame = module.options.raidnames[(i-1)*5+j]
			frame.iconText = ""
			frame.iconTextShift = ""
			frame.html:SetText("")
		end
	end
end 
function module.main:PLAYER_REGEN_DISABLED()
	Note_CombatState = true
	module:Visibility()
end
function module.main:PLAYER_REGEN_ENABLED()
	Note_CombatState = false
	module:Visibility()
end

function module.main:ZONE_CHANGED_NEW_AREA()
	C_Timer.After(1,module.CheckZoneProfiles)

	if VART.Note.enabled and VART.Note.ShowOnlyInRaid then
		C_Timer.After(5, module.Visibility)
	end
end

function module.main:PLAYER_SPECIALIZATION_CHANGED(unit)
	if VART.Note.enabled and unit == "player" then
		module.allframes:UpdateText()
	end

	if unit ~= "player" or not GetSpecialization then
		return
	end

	local spec = GetSpecialization()
	if not spec then
		return
	end

	local class = (select(2,UnitClass'player')) or ""

	local key = "Spec" .. spec .. class
	if VART.Note.Profiles[key] then
		module:SelectProfile(VART.Note.Profiles[key])
	end
end

function module.main:PLAYER_TALENT_UPDATE(unit)
	module.main:PLAYER_SPECIALIZATION_CHANGED("player")
end


do
	local ResetCLEUData
	local currPhase = 1
	local currGlobalPhase = 1

	function module.main:SetPhase(stage, globalStage)
		wipe(encounter_time_p)
		local t = GetTime()
		encounter_time_p[stage] = t
		encounter_time_p[tostring(stage)] = t
		currPhase = stage
		ResetCLEUData(true)
		if globalStage then
			encounter_time_p["g"..tostring(globalStage)] = t
			currGlobalPhase = globalStage
		else
			currGlobalPhase = currGlobalPhase + 1
		end
		--[[
		if module.db.encounter_counters_time then
			for k,v in pairs(module.db.encounter_counters_time) do
				if k:find(":p%d+$") then
					module.db.encounter_counters_time[k]=nil
				end
			end
		end
		]]
		if module.frame:IsShown() then
			module.allframes:UpdateText()
		end
	end

	local BossPhasesBossmodAdded
	local function BossPhasesBossmod()
		if BossPhasesBossmodAdded then
			return
		end
		if type(BigWigsLoader)=='table' and BigWigsLoader.RegisterMessage then
			BigWigsLoader.RegisterMessage({}, "BigWigs_SetStage", function(event, addon, stage)
				if stage then
					module.main:SetPhase(stage)
				end
			end)

			BossPhasesBossmodAdded = true
		elseif type(DBM)=='table' and DBM.RegisterCallback then
			DBM:RegisterCallback("DBM_SetStage", function(event, addon, modId, stage, encounterId, globalStage)
				if stage then
					module.main:SetPhase(stage, globalStage)
				end
			end)

			BossPhasesBossmodAdded = true
		end
	end

	local phaseCombatEvents = {}
	function module.main:ENCOUNTER_START(encounterID, encounterName, difficultyID, groupSize)
		local noteText = (VART.Note.Text1 or "")..(VART.Note.SelfText or "")
		if encounterID and encounterName then
			encounter_id[tostring(encounterID)] = true
			encounter_id[encounterName] = true
		end
		local timeInText = noteText:find("{time:([0-9:]+[^{}]*)}")
		local phaseInText = noteText:find("{[Pp]([^}:][^}]*)}(.-){/[Pp]}")
		if timeInText or (phaseInText and ((type(BigWigsLoader)=='table') or (type(DBM)=='table'))) then
			wipe(encounter_time_c)
			wipe(encounter_time_wa_uids)
			module.db.encounter_time = GetTime()
			encounter_time_p[1] = module.db.encounter_time
			encounter_time_p["1"] = module.db.encounter_time
			currPhase = 1
			currGlobalPhase = 1
			BossPhasesBossmod()

			ResetCLEUData()

			if timeInText then
				module:RegisterTimer()
			end

			local anyEvent
			string_gsub(noteText,"{time:[0-9:]+[^}]*,(S[^{},]+)[,}]",function(str)
				local event,spellID,count,name,phase = strsplit(":",str)
				if tonumber(count or "") and tonumber(spellID or "") and event and module.db.encounter_counters[event] then
					anyEvent = true
					module.db.encounter_counters[event][tonumber(spellID)] = 0
					if name and name ~= "" then
						if not module.db.encounter_counters[event].name[name] then
							module.db.encounter_counters[event].name[name] = {}
						end
						module.db.encounter_counters[event].name[name][tonumber(spellID)] = 0
					end
				end
			end)
			wipe(phaseCombatEvents)
			string_gsub(noteText,"{[Pp],(S[^{},]+),?(S?[^{},]*)[,}]",function(str1,str2)
				for _,str in pairs({str1,str2}) do
					if str ~= "" then
						local event,spellID,count = strsplit(":",str)
						if tonumber(count or "") and tonumber(spellID or "") and event and module.db.encounter_counters[event] then
							anyEvent = true
							module.db.encounter_counters[event][tonumber(spellID)] = 0
							phaseCombatEvents[str] = true
						end
					end
				end
			end)
			if anyEvent then
				wipe(module.db.encounter_counters_time)
				module:RegisterEvents("COMBAT_LOG_EVENT_UNFILTERED")
			end
		end
		module.allframes:UpdateText()
	end
	function module.main:ENCOUNTER_END()
		wipe(encounter_id)

		module:UnregisterTimer()
		module.db.encounter_time = nil
		wipe(encounter_time_p)
		wipe(encounter_time_c)
		wipe(encounter_time_wa_uids)

		module:UnregisterEvents("COMBAT_LOG_EVENT_UNFILTERED")

		ResetCLEUData()
		module.allframes:UpdateText()
	end
	local tmr = 0
	function module:timer(elapsed)
		tmr = tmr + elapsed
		if tmr > 1 then
			tmr = 0
			if module.frame:IsShown() then
				module.allframes:UpdateText(true)
			end
		end
	end

	module.db.encounter_counters_time = {}
	module.db.encounter_counters = {
		SCC = {},
		SCS = {},
		SAA = {},
		SAR = {},
	}
	function ResetCLEUData(only_phase_data)
		if not only_phase_data then
			wipe(module.db.encounter_counters.SCC)
			wipe(module.db.encounter_counters.SCS)
			wipe(module.db.encounter_counters.SAA)
			wipe(module.db.encounter_counters.SAR)
			wipe(module.db.encounter_counters_time)
		  
			module.db.encounter_counters.SCC.name = {}
			module.db.encounter_counters.SCS.name = {}
			module.db.encounter_counters.SAA.name = {}
			module.db.encounter_counters.SAR.name = {}
		end

		module.db.encounter_counters.SCC.phase = {}
		module.db.encounter_counters.SCS.phase = {}
		module.db.encounter_counters.SAA.phase = {}
		module.db.encounter_counters.SAR.phase = {}
	end
	ResetCLEUData()
	local ECT = module.db.encounter_counters_time
	local SCC = module.db.encounter_counters.SCC
	local SCS = module.db.encounter_counters.SCS
	local SAA = module.db.encounter_counters.SAA
	local SAR = module.db.encounter_counters.SAR
	local function AddCounter(table,tableName,spellID,spellTarget)
		table[spellID] = table[spellID] + 1
		if spellTarget and table.name[spellTarget] then table.name[spellTarget][spellID] = table.name[spellTarget][spellID] + 1 end
		table.phase[spellID] = (table.phase[spellID] or 0) + 1

		local key_w_counter = tableName..":"..spellID..":"..table[spellID]
		local key_wo_counter = tableName..":"..spellID..":"..0
		local key_w_phase = tableName..":"..spellID..":"..(table.phase[spellID] or 0).."::p"..(currPhase or 1)
		local key_w_gphase = tableName..":"..spellID..":"..(table.phase[spellID] or 0).."::pg"..(currGlobalPhase or 1)
		local key_w_name
		if spellTarget then
			key_w_name = tableName..":"..spellID..":"..(table.name[spellTarget] and table.name[spellTarget][spellID] or 0)..":"..(spellTarget or "")
		end
		local t = GetTime()
		ECT[ key_w_counter ] = t
		ECT[ key_wo_counter ] = t
		ECT[ key_w_phase ] = t
		ECT[ key_w_gphase ] = t
		if key_w_name then ECT[ key_w_name ] = t end
		if phaseCombatEvents[key_w_counter] or phaseCombatEvents[key_wo_counter] then
			if module.frame:IsShown() then
				module.allframes:UpdateText()
			end
		end
	end

	function module.main.COMBAT_LOG_EVENT_UNFILTERED(_,event,_,_,sourceName,_,_,_,destName,_,_,spellID)
		if event == "SPELL_CAST_SUCCESS" then
			if SCC[spellID] then
				return AddCounter(SCC,"SCC",spellID,sourceName)
			end
		elseif event == "SPELL_CAST_START" then
			if SCS[spellID] then
				return AddCounter(SCS,"SCS",spellID,sourceName)
			end
		elseif event == "SPELL_AURA_APPLIED" then
			if SAA[spellID] then
				return AddCounter(SAA,"SAA",spellID,destName)
			end
		elseif event == "SPELL_AURA_REMOVED" then
			if SAR[spellID] then
				return AddCounter(SAR,"SAR",spellID,destName)
			end
		end
	end


	function ART.F.Note_Timer(name)
		if not name then
			return
		end
		if not module.db.encounter_time then
			module.main:ENCOUNTER_START()
		end
		encounter_time_c[name] = GetTime()
	end
	function ART.F.Note_SyncTimer(name)
		if not name then
			return
		end
		ART.F.SendExMsg("multiline_timer_sync",name)
	end
end

do
	local IGNORE_PROFILE_KEYS = {
		["Profiles"] = true,
		["Black"] = true,
		["BlackNames"] = true,
		["BlackLastUpdateName"] = true,
		["BlackLastUpdateTime"] = true,
		["AutoLoad"] = true,
	}
	function module:SaveCurrentProfiletoDB()
		local profileName = VART.Note.Profiles.Now

		local saveDB = {}
		VART.Note.Profiles.List[ profileName ] = saveDB

		for key,val in pairs(VART.Note) do
			if not IGNORE_PROFILE_KEYS[key] then
				if type(val) == "table" then
					saveDB[key] = ART.F.table_copy2(val)
				else
					saveDB[key] = val
				end
			end
		end
	end
	function module:SelectProfile(name)
		if name == VART.Note.Profiles.Now or not name then
			return
		end
		if not VART.Note.Profiles.List[name] then
			return
		end
		module:SaveCurrentProfiletoDB()

		local savedText
		if VART.Note.Profiles.KeepText then
			savedText = {
				Text1 = VART.Note.Text1,
				SelfText = VART.Note.SelfText,
			}
		end

		local savedKeys = {}
		for key in pairs(IGNORE_PROFILE_KEYS) do
			if VART.Note[key] then
				savedKeys[key] = VART.Note[key]
			end
		end
		ART.F.table_rewrite(VART.Note,VART.Note.Profiles.List[name])
		for key,val in pairs(savedKeys) do
			VART.Note[key] = val
		end

		VART.Note.Profiles.Now = name

		if savedText then
			for k,v in pairs(savedText) do
				VART.Note[k] = v
			end
		end

		module:ReloadProfile()

		VART.Note.Profiles.List[name] = nil	--remove data only if reload is successful

		return true
	end
	function module:ReloadProfile()
		module.main:ADDON_LOADED()
		if module.options.UpdateOptions then
			module.options:UpdateOptions()
		end
	end

	function module:CheckZoneProfiles()
		local _, zoneType = GetInstanceInfo()

		if zoneType == "arena" then
			if VART.Note.Profiles.Arena then
				module:SelectProfile(VART.Note.Profiles.Arena)
			end
		elseif zoneType == "party" then
			if VART.Note.Profiles.Dung then
				module:SelectProfile(VART.Note.Profiles.Dung)
			end
		elseif zoneType == "raid" then
			if VART.Note.Profiles.Raid then
				module:SelectProfile(VART.Note.Profiles.Raid)
			end
		elseif zoneType == "pvp" then
			if VART.Note.Profiles.BG then
				module:SelectProfile(VART.Note.Profiles.BG)
			end
		else
			if VART.Note.Profiles.Other then
				module:SelectProfile(VART.Note.Profiles.Other)
			end
		end
	end
end


function module:slash(arg)
	if arg == "note" or arg == "n" then
		if VART.Note.enabled then 
			module:Disable()
		else
			module:Enable()
		end
	elseif arg == "editnote" or arg == "edit note" then
		ART.Options:Open(module.options)
	elseif arg == "note timer" then
		if module.db.encounter_time then
			module.main:ENCOUNTER_END()
			print('timer ended')
		else
			module.main:ENCOUNTER_START()
			print('timer started')
		end
	elseif arg and arg:find("^note starttimer ") then
		local timer = arg:match("^note starttimer (.-)$")
		if timer then
			ART.F.Note_Timer(timer)
		end
	elseif arg and arg:find("^note synctimer ") then
		local timer = arg:match("^note synctimer (.-)$")
		if timer then
			ART.F.Note_SyncTimer(timer)
		end
	elseif arg and arg:find("^note set ") then
		local name = arg:match("^note set (.-)$")
		if name then
			local nameNumber = tonumber(name)
			for i=1,#VART.Note.Black do
				local blackName = VART.Note.BlackNames[i]
				if (blackName and blackName:lower() == name) or (nameNumber == i) then
					module.frame:Save(i)
					return
				end
			end
		end
	elseif arg and arg:find("^note phase ") then
		local phase = arg:match("^note phase (.-)$")
		if phase then
			module.main:SetPhase(phase)
			print("Set phase",phase)
		end
	elseif arg and arg:find("^note show ") then
		local name = arg:match("^note show (.-)$")
		if name then
			local nameNumber = tonumber(name)
			for i=1,#VART.Note.Black do
				local blackName = VART.Note.BlackNames[i]
				if (blackName and blackName:lower() == name) or (nameNumber == i) then
					module:AddWindow(i)
				end
			end
		end
	elseif arg == "help" then
		print("|cff00ff00/rt note|r - hide/show note")
		print("|cff00ff00/rt editnote|r - open notes tab")
		print("|cff00ff00/rt note set |cffffff00NOTENAME|r|r - set & send note with NOTENAME name")
		print("|cff00ff00/rt note timer|r - simulate boss encounter start [for timers feature]")
		print("|cff00ff00/rt note starttimer |cffffff00TIMERNAME|r|r - start custom timer")
	end
end

function module:GetText(removeColors,removeExtraSpaces)
	local text = VART.Note.Text1 or ""
	if removeColors then
		text = text:gsub("|c........",""):gsub("|r","")
	end
	if removeExtraSpaces then
		text = text:gsub(" *\n","\n"):gsub(" *$",""):gsub(" +"," ")
	end
	return text
end
ART.F.GetNote = module.GetText
--- you can use to get note text GART.F:GetNote()