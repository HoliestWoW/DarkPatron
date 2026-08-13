-- =====================================================================
-- 1. DATABASE & INITIALIZATION
-- =====================================================================
local addonName, DP = ...
local DP_Core = CreateFrame("Frame", "DarkPatronCore")

local defaults = {
    DarkFavor = 0,
    DarkSigils = 0,
    ApexSigils = 0,
    MaxTalentsAllowed = 0,
    MaxGearQuality = 1, 
    MaxActiveSlots = 3, 
    HasJourneymanCavalry = false,
    HasMasterCavalry = false,
    HasExpertCavalry = false,
    HasArtisanCavalry = false,
    HasCapstone = false,
    HasAlchemistGrace = false, 
    HasTravelerStep = false,   
    HasArtisanSanction = false,
    HasBank = false,      
    HasAuction = false,   
    HasMail = false,      
    HasWorldsBoon = false,
    HasAlchemistSight = false,
    ActiveMissions = {}, 
    PoolOfSix = {},     
	EliteBounties = {},
    RecentlyCompleted = {},
    CompletedElites = {},
    ContractTypesCompleted = {}, 
    FirstEliteKilled = nil,      
    FailedPactsCount = 0, 
    TotalPactsAccepted = 0,
    TotalPactsCompleted = 0,
    CurrentStreak = 0,
	PeakStreak = 0,
    LastPactTime = 0,
    LastBoardRefresh = 0,
    HasInitializedAwakening = false, 
    HasSeenIntro = false,
    IsDead = false,
    DeathEpitaph = nil,
	CollapsedPacts = {},
	TrackerBgHidden = false,
    TrackerWidth = 260,
}

DP_Core:RegisterEvent("ADDON_LOADED")
DP_Core:RegisterEvent("PLAYER_ENTERING_WORLD")
DP_Core:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
DP_Core:RegisterEvent("CHARACTER_POINTS_CHANGED")
DP_Core:RegisterEvent("PLAYER_REGEN_ENABLED")
DP_Core:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
DP_Core:RegisterEvent("CHAT_MSG_LOOT")
DP_Core:RegisterEvent("CHAT_MSG_MONEY")
DP_Core:RegisterEvent("CHAT_MSG_SYSTEM") 
DP_Core:RegisterEvent("QUEST_TURNED_IN")
DP_Core:RegisterEvent("QUEST_LOG_UPDATE")
DP_Core:RegisterEvent("PLAYER_UPDATE_RESTING")
DP_Core:RegisterEvent("ZONE_CHANGED_NEW_AREA")
DP_Core:RegisterEvent("ZONE_CHANGED")
DP_Core:RegisterEvent("BANKFRAME_OPENED")
DP_Core:RegisterEvent("AUCTION_HOUSE_SHOW")
DP_Core:RegisterEvent("MAIL_SHOW")
DP_Core:RegisterEvent("PLAYER_LOGOUT")
DP_Core:RegisterEvent("COMPANION_UPDATE")
DP_Core:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
DP_Core:RegisterEvent("PLAYER_DEAD")
DP_Core:RegisterEvent("PLAYER_LEVEL_UP")
DP_Core:RegisterEvent("CHAT_MSG_ADDON")

local devMode = false
local DEVELOPER_IDENTITY = "HoliestWoW-Dreamscythe"

local DP_EvaluateBazaarAlert, PatronWhisper, ShowPatronToast, RecordCompletedPact, RefillMissionPool

local function DP_FormatNumber(n)
    local formatted = tostring(math.floor(n or 0))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local TriggerMap = {
    ["SWING_DAMAGE"] = 1,
    ["DAMAGE_TAKEN"] = 2,
    ["ANY_DAMAGE"] = 3,
    ["PARTY_KILL"] = 4,
    ["DEFENSE_ROLL"] = 5,
    ["SPELL_DAMAGE"] = 6,
    ["INTERRUPT_SPELL"] = 7,
    ["FETCH_ITEM"] = 8,
    ["DUEL_WIN"] = 9,
    ["MAKGORA_WIN"] = 10,
    ["MONEY_LOOT"] = 11,
    ["QUEST_COMPLETE"] = 12,
    ["FALLING_DAMAGE"] = 13,
    ["DUNGEON_CLEAR"] = 14,
    ["SPECIFIC_KILL"] = 15
}

local function GetRarityCode(rarity)
    if rarity == "Rare" then return "R"
    elseif rarity == "Elite" then return "E"
    elseif rarity == "Rare Elite" or rarity == "Boss" then return "RE"
    else return "S" end
end

local function GetSpentTalentPoints()
    local spent = 0
    for tab = 1, GetNumTalentTabs() do
        for i = 1, GetNumTalents(tab) do
            local _, _, _, _, rank = GetTalentInfo(tab, i)
            spent = spent + rank
        end
    end
    return spent
end

local function GivesExperience(targetLevel)
    local pLvl = UnitLevel("player") or 1
    local grayLevel = 0
    
    if pLvl <= 5 then
        grayLevel = 0
    elseif pLvl <= 39 then
        grayLevel = pLvl - math.floor(pLvl / 10) - 5
    else
        grayLevel = pLvl - math.floor(pLvl / 5) - 1
    end
    
    return targetLevel > grayLevel
end

local function DP_InsertPactToChat(mission)
    if not mission then return end
    
    -- Strip brackets, colons, pipes, tildes, and percent signs to keep regex parsing safe
    local title = mission.title and tostring(mission.title):gsub(":", ""):gsub("%[", ""):gsub("%]", ""):gsub("%%", ""):gsub("%|", ""):gsub("%~", "") or "Pact"
    local rarity = mission.rarity or "Standard"
    local goal = mission.goal or 1
    local desc = mission.desc and tostring(mission.desc):gsub(":", ""):gsub("%[", ""):gsub("%]", ""):gsub("%%", ""):gsub("%|", ""):gsub("%~", "") or ""

    -- The plain text tag sent to the server (What non-addon users see)
    -- Using ~ instead of | because WoW treats | as a restricted UI escape character
    local plainTextTag = string.format("[DPact: %s ~ %s ~ %d ~ %s]", title, rarity, goal, desc)
    
    local editBox = ChatEdit_GetActiveWindow()
    if editBox then
        editBox:Insert(plainTextTag)
    else
        local defaultBox = ChatEdit_ChooseBoxForSend()
        if defaultBox then
            ChatEdit_ActivateChat(defaultBox)
            defaultBox:Insert(plainTextTag)
        end
    end
end

local function DarkPatron_ChatFilter(self, event, msg, author, ...)
    if not msg then return false, msg, author, ... end
    
    -- Intercept the exact plain text format (now using ~) and convert it to an addon hyperlink
    local updatedMsg = msg:gsub("%[DPact: (.-) %~ (.-) %~ (%d+) %~ (.-)%]", function(title, rarity, goal, desc)
        local color = "ffffffff" 
        if rarity == "Rare" then color = "ff0070dd"
        elseif rarity == "Elite" then color = "ffa335ee"
        elseif rarity == "Rare Elite" or rarity == "Boss" then color = "ffff8000" end
        
        -- Prefix with "Pact:" so Questie's aggressive fuzzy-matcher ignores the string
        -- The hidden data format: dpactchat:title:goal:rarity:desc
        return string.format("\124c%s\124Hdpactchat:%s:%s:%s:%s\124h[Pact: %s]\124h\124r", color, title, goal, rarity, desc, title)
    end)
    return false, updatedMsg, author, ...
end

local chatEvents = { 
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", 
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", 
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", 
    "CHAT_MSG_CHANNEL", 
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", 
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", 
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER"
}

for _, evt in ipairs(chatEvents) do
    ChatFrame_AddMessageEventFilter(evt, DarkPatron_ChatFilter)
end

if C_ChatInfo then C_ChatInfo.RegisterAddonMessagePrefix("DP_JUSTICE") end

local function HashIdentity(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 4294967295
    end
    return tostring(hash)
end

local SOVEREIGN_HASH = "4292962553"

-- Helper function to match the tooltip rarity text color to your chat hex colors
local function GetRarityColor(rarity)
    if rarity == "Rare" then return 0.0, 0.44, 0.87
    elseif rarity == "Elite" then return 0.64, 0.21, 0.93
    elseif rarity == "Rare Elite" or rarity == "Boss" then return 1.0, 0.5, 0.0
    else return 1.0, 1.0, 1.0 end -- Standard White
end

-- Unified tooltip builder to keep both hover and click tooltips identical
local function BuildPactTooltip(tooltip, linkType, linkArgs)
    local title = linkArgs[2]
    if not title then return end
    
    tooltip:ClearLines()
    tooltip:AddLine("Dark Patron Pact", 0.64, 0.21, 0.93)
    tooltip:AddLine(title, 1, 1, 1)
    
    if linkType == "dpactchat" then
        local goal, rarity = linkArgs[3], linkArgs[4]
        local desc = ""
        for i = 5, #linkArgs do desc = desc .. (i == 5 and "" or ":") .. tostring(linkArgs[i]) end
        
        if goal and tonumber(goal) > 1 then tooltip:AddLine("Goal Requirement: " .. goal, 1, 1, 1) end
        
        local r, g, b = GetRarityColor(rarity)
        tooltip:AddLine("Rarity: " .. (rarity or "Standard"), r, g, b)
        tooltip:AddLine(" ")
        
        if desc and desc ~= "" then
            tooltip:AddLine(desc, 1, 0.82, 0, true)
            tooltip:AddLine(" ")
        end
    elseif linkType == "dpact" then
        local rarity, desc, reward = linkArgs[3], linkArgs[4], linkArgs[5]
        local r, g, b = GetRarityColor(rarity)
        tooltip:AddLine("Rarity: " .. (rarity or "Standard"), r, g, b)
        tooltip:AddLine(" ")
        if desc and desc ~= "" then
            tooltip:AddLine(desc, 1, 0.82, 0, true)
            tooltip:AddLine(" ")
        end
        if reward and reward ~= "" then
            tooltip:AddLine(reward, 0.64, 0.21, 0.93)
        end
    end
    
    tooltip:AddLine("A binding contract issued by the Dark Patron.", 1, 0.82, 0, true)
    tooltip:Show()
end

-- 1. Pre-hook SetItemRef (Triggers when CLICKING the link in chat)
local orig_SetItemRef = SetItemRef
function SetItemRef(link, text, button, chatFrame)
    local linkArgs = {strsplit(":", link)}
    local linkType = linkArgs[1]
    
    if linkType == "dpactchat" or linkType == "dpact" then
        -- Use the standard UI persistent ItemRefTooltip for clicked links
        ShowUIPanel(ItemRefTooltip)
        if not ItemRefTooltip:IsVisible() then
            ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
        end
        BuildPactTooltip(ItemRefTooltip, linkType, linkArgs)
        return
    end
    
    -- Let the default UI handle all normal items, spells, and quests
    return orig_SetItemRef(link, text, button, chatFrame)
end

-- 2. Hook OnHyperlinkEnter (Triggers when HOVERING the link in chat)
GameTooltip:HookScript("OnHyperlinkEnter", function(self, link, text, button)
    local linkArgs = {strsplit(":", link)}
    local linkType = linkArgs[1]
    
    if linkType == "dpactchat" or linkType == "dpact" then
        self:SetOwner(UIParent, "ANCHOR_CURSOR")
        BuildPactTooltip(self, linkType, linkArgs)
    end
end)

-- =====================================================================
-- 2. PROCEDURAL GRAMMAR, INTERNAL MAPPINGS & ROSTERS
-- =====================================================================
local Adjectives = { "Bloody", "Iron", "Relentless", "Shadowy", "Sorrowful", "Abyssal", "Ruthless", "Crimson", "Forsaken", "Savage", "Grim", "Vengeful", "Silent", "Zealous", "Reckless", "Foolish", "Mad" }
local Nouns = { "Blood", "Iron", "Carnage", "Sorrow", "Malice", "Shadows", "Dominance", "Restitution", "the Abyss", "Ruin", "Despair", "Ashes", "Dust", "Gluttony", "Pride" }

local ZoneLoadingScreens = {
    -- Classic Standalones
    ["Ragefire Chasm"] = "LoadScreenRagefireChasm",
    ["Wailing Caverns"] = "LoadScreenWailingCaverns",
    ["The Deadmines"] = "LoadScreenDeadmines",
    ["Shadowfang Keep"] = "LoadScreenShadowFangKeep",
    ["The Stockade"] = "LoadScreenStormwindStockade",
    ["Blackfathom Deeps"] = "LoadScreenBlackfathomDeeps",
    ["Gnomeregan"] = "LoadScreenGnomeregan",
    ["Razorfen Kraul"] = "LoadScreenRazorfenKraul",
    ["Razorfen Downs"] = "LoadScreenRazorfenDowns",
    ["Uldaman"] = "LoadScreenUldaman",
    ["Zul'Farrak"] = "LoadScreenZulFarrak",
    ["Maraudon"] = "LoadScreenMaraudon",
    ["Temple of Atal'Hakkar"] = "LoadScreenSunkenTemple",
    ["Blackrock Depths"] = "LoadScreenBlackrockDepths",
    ["Scholomance"] = "LoadScreenScholomance",
    
    -- Scarlet Monastery Wings
    ["Scarlet Monastery: Graveyard"] = "LoadScreenScarletMonastery2",
    ["Scarlet Monastery: Library"] = "LoadScreenScarletMonastery2",
    ["Scarlet Monastery: Armory"] = "LoadScreenScarletMonastery2",
    ["Scarlet Monastery: Cathedral"] = "LoadScreenScarletMonastery2",
    
    -- Blackrock Spire Wings
    ["Lower Blackrock Spire"] = "LoadScreenBlackrockSpire",
    ["Upper Blackrock Spire"] = "LoadScreenBlackrockSpire",
    
    -- Stratholme Wings
    ["Stratholme (Live)"] = "LoadScreenStrathome",
    ["Stratholme (Undead)"] = "LoadScreenStrathome",
    
    -- Dire Maul Wings
    ["Dire Maul (East)"] = "LoadScreenDireMaul",
    ["Dire Maul (North)"] = "LoadScreenDireMaul",
    ["Dire Maul (West)"] = "LoadScreenDireMaul",

    -- TBC Dungeons
    ["Hellfire Ramparts"] = "LOADSCREENHELLFIRECITADEL",
    ["The Blood Furnace"] = "LOADSCREENHELLFIRECITADEL",
    ["The Shattered Halls"] = "LOADSCREENHELLFIRECITADEL",
    ["The Slave Pens"] = "LOADSCREENCOILFANG",
    ["The Underbog"] = "LOADSCREENCOILFANG",
    ["Mana-Tombs"] = "LOADSCREENAUCHINDOUN",
    ["Auchenai Crypts"] = "LOADSCREENAUCHINDOUN",
    ["Sethekk Halls"] = "LOADSCREENAUCHINDOUN",
    ["Shadow Labyrinth"] = "LOADSCREENAUCHINDOUN",
    ["Old Hillsbrad Foothills"] = "LOADSCREENCAVERNSTIME",
    ["The Black Morass"] = "LOADSCREENCAVERNSTIME",
    ["The Botanica"] = "LOADSCREENTEMPESTKEEP",
    ["The Mechanar"] = "LOADSCREENTEMPESTKEEP",
    ["The Arcatraz"] = "LOADSCREENTEMPESTKEEP",
    ["Magisters' Terrace"] = "LoadScreenSunwell",
	
	-- Classic Raids
    ["Zul'Gurub"] = "LoadScreenZulGurub",
    ["Molten Core"] = "LoadScreenMoltenCore",
    ["Onyxia's Lair"] = "LOADSCREENKALIMDOR",
    ["Blackwing Lair"] = "LoadScreenBlackWingLair",
    ["Ruins of Ahn'Qiraj"] = "LoadScreenAhnQiraj20man",
    ["Ahn'Qiraj"] = "LoadScreenAhnQiraj40man",
    ["Naxxramas"] = "LoadScreenNaxxramas",
    
    -- TBC Raids
    ["Karazhan"] = "LoadScreenKarazhan",
    ["Zul'Aman"] = "LoadScreenZulAman2",
    ["Gruul's Lair"] = "LOADSCREENGRUULSLAIR",
    ["Magtheridon's Lair"] = "LOADSCREENHELLFIRECITADELRAID",
    ["Serpentshrine Cavern"] = "LOADSCREENCOILFANG",
    ["Tempest Keep"] = "LOADSCREENTEMPESTKEEP",
    ["Hyjal Summit"] = "LOADSCREENCAVERNSTIME",
    ["Black Temple"] = "LOADSCREENBLACKTEMPLE",
    ["Sunwell Plateau"] = "LoadScreenSunwell5Man"
}

local ActionTemplates = {
    -- Core Combat
    { trigger = "SWING_DAMAGE", baseDesc = "Land %s successful physical attacks.", baseGoal = 35, baseFavor = 1, reqMelee = true, patterns = { "The [Adj] Striker", "Striker of [Noun]" } },
    { trigger = "DAMAGE_TAKEN", baseDesc = "Survive taking %s total damage in combat.", baseGoal = 200, baseFavor = 1, isStat = true, patterns = { "The [Adj] Martyr", "Trial of the Martyr" } },
    { trigger = "ANY_DAMAGE", baseDesc = "Inflict %s total damage across all combat.", baseGoal = 350, baseFavor = 1, isStat = true, patterns = { "The [Adj] Annihilator", "Path of the Annihilator" } },
    { trigger = "PARTY_KILL", baseDesc = "Strike the killing blow on %s hostile targets.", baseGoal = 15, baseFavor = 1, patterns = { "The [Adj] Executioner", "Decree of the Executioner" } },
    { trigger = "DEFENSE_ROLL", baseDesc = "Parry, Dodge, or Block %s incoming attacks.", baseGoal = 15, baseFavor = 1, reqDefense = true, patterns = { "The [Adj] Bulwark", "Trial of the Bulwark" } },
    { trigger = "INTERRUPT_SPELL", baseDesc = "Successfully interrupt enemy spellcasts %s times.", baseGoal = 5, baseFavor = 1, reqInterrupt = true, patterns = { "The [Adj] Silencer", "Vow of the Silencer" } },
    { trigger = "UNARMED_DAMAGE", baseDesc = "Land %s successful unarmed melee attacks.", baseGoal = 20, baseFavor = 2, reqMelee = true, patterns = { "The [Adj] Brawler", "Fists of [Noun]" } },
    { trigger = "NAKED_COMBAT", baseDesc = "Land %s attacks while wearing no chest armor.", baseGoal = 20, baseFavor = 2, patterns = { "The [Adj] Exhibitionist", "Pride of the Foolish" } },

    -- Elemental Magic
    { trigger = "SPELL_CAST_SUCCESS", baseDesc = "Successfully cast %s spells.", baseGoal = 50, baseFavor = 1, reqCaster = true, patterns = { "The [Adj] Weaver", "Words of [Noun]" } },
    { trigger = "FROST_DAMAGE", baseDesc = "Deal %s Frost damage to enemies.", baseGoal = 300, baseFavor = 1, isStat = true, reqFrost = true, patterns = { "The [Adj] Glacier", "Chill of the Void" } },
    { trigger = "SHADOW_DAMAGE", baseDesc = "Deal %s Shadow damage to enemies.", baseGoal = 300, baseFavor = 1, isStat = true, reqShadow = true, patterns = { "The [Adj] Cultist", "Whispers of the Abyss" } },
    { trigger = "NATURE_DAMAGE", baseDesc = "Deal %s Nature damage to enemies.", baseGoal = 300, baseFavor = 1, isStat = true, reqNature = true, patterns = { "The [Adj] Storm", "Wrath of [Noun]" } },
    { trigger = "ARCANE_DAMAGE", baseDesc = "Deal %s Arcane damage to enemies.", baseGoal = 300, baseFavor = 1, isStat = true, reqArcane = true, patterns = { "The [Adj] Scholar", "Surge of [Noun]" } },
    { trigger = "HOLY_FIRE_DAMAGE", baseDesc = "Deal %s Holy or Fire damage.", baseGoal = 250, baseFavor = 1, isStat = true, reqHolyFire = true, patterns = { "The [Adj] Zealot", "Purging [Noun]" } },

    -- Abstinence & Constraints (Hard Resets)
    { trigger = "PURITY_KILL", baseDesc = "Strike the killing blow on %s targets without casting ANY Shadow magic. Fails on cast.", baseGoal = 10, baseFavor = 1, reqShadow = true, patterns = { "The Grimoire's Vow", "Rite of Purity" } },
	{ trigger = "PURITY_KILL_NATURE", baseDesc = "Strike the killing blow on %s targets without casting ANY Nature magic.", baseGoal = 10, baseFavor = 1, reqNature = true, patterns = { "The Earth's Vow", "Rite of Purity" } },
    { trigger = "FLAWLESS_KILL", baseDesc = "Strike the killing blow on %s targets without taking ANY damage. Fails on hit.", baseGoal = 5, baseFavor = 2, patterns = { "The [Adj] Ghost", "Flawless Execution" } },
    { trigger = "PACIFIST_SURVIVAL", baseDesc = "Survive taking %s damage without dealing ANY damage yourself. Fails on hit.", baseGoal = 150, baseFavor = 2, isStat = true, patterns = { "The [Adj] Pacifist", "Vow of Non-Violence" } },

    -- Economy & World
    { trigger = "FETCH_ITEM", baseDesc = "Acquire and stockpile %s %s.", baseGoal = 10, baseFavor = 2, patterns = { "The Hoarder's Tribute", "Tribute of [Noun]" } },
    { trigger = "MONEY_LOOT", baseDesc = "Loot %s copper coins from the world.", baseGoal = 50, baseFavor = 1, isStat = true, patterns = { "The [Adj] Mercenary", "Greed of the [Adj] Mercenary" } },
    { trigger = "QUEST_COMPLETE", baseDesc = "Successfully complete and turn in %s quests.", baseGoal = 3, baseFavor = 2, patterns = { "The [Adj] Adventurer", "Path of the Adventurer" } },
    { trigger = "GATHER_NODE", baseDesc = "Successfully gather from %s resource nodes.", baseGoal = 8, baseFavor = 2, reqGatherer = true, patterns = { "The [Adj] Harvester", "Bounty of the Earth" } },
    { trigger = "LOOT_JUNK", baseDesc = "Loot %s poor quality (gray) items.", baseGoal = 15, baseFavor = 1, patterns = { "The [Adj] Scavenger", "Riches in [Noun]" } },
    { trigger = "FALLING_DAMAGE", baseDesc = "Survive taking %s falling damage.", baseGoal = 100, baseFavor = 1, isStat = true, patterns = { "The [Adj] Plunge", "Gravity's [Noun]" } },
	
	-- Tradeskill & Hobby
    { trigger = "FISH_CATCH", baseDesc = "Successfully catch %s items from the waters of Azeroth.", baseGoal = 25, baseFavor = 2, reqFishing = true, patterns = { "The [Adj] Angler", "Bounty of the Depths" } },
    { trigger = "CRAFT_ITEM", baseDesc = "Craft, forge, or cook %s items using your professions.", baseGoal = 20, baseFavor = 2, patterns = { "The [Adj] Artisan", "Master of the Forge" } },
	{ trigger = "WELL_FED_KILL", baseDesc = "Strike the killing blow on %s targets while maintaining the Well Fed buff.", baseGoal = 15, baseFavor = 1, patterns = { "The [Adj] Banquet", "Glutton's [Noun]" } },
    { trigger = "ENCHANTED_SWING", baseDesc = "Land %s melee attacks while your weapon is temporarily enhanced (Stones/Poisons/Imbues).", baseGoal = 50, baseFavor = 1, reqMelee = true, patterns = { "The [Adj] Edge", "Blade of [Noun]" } },
	
	-- The Bestiary (Typed Hunting)
    { trigger = "TYPED_KILL", targetName = "Undead", baseDesc = "Purge %s Undead creatures.", baseGoal = 15, baseFavor = 1, patterns = { "The Gravewalker", "Rest for the Wicked" } },
    { trigger = "TYPED_KILL", targetName = "Beast", baseDesc = "Hunt down %s wild Beasts.", baseGoal = 20, baseFavor = 1, patterns = { "The Apex Predator", "Culling the Wild" } },
    { trigger = "TYPED_KILL", targetName = "Demon", baseDesc = "Banish %s Demons back to the nether.", baseGoal = 10, baseFavor = 2, patterns = { "The Exorcist", "Contract: The Nether" } },
    { trigger = "TYPED_KILL", targetName = "Humanoid", baseDesc = "Execute %s Humanoids.", baseGoal = 15, baseFavor = 1, patterns = { "The Mercenary", "A Bounty of Blood" } },
    { trigger = "TYPED_KILL", targetName = "Elemental", baseDesc = "Shatter %s Elementals.", baseGoal = 10, baseFavor = 2, patterns = { "The Stormbreaker", "Dust to Dust" } },
    
    -- Vulnerability & Deprivation
    { trigger = "NO_BUFF_KILL", baseDesc = "Strike the killing blow on %s targets while having ZERO helpful buffs or auras active.", baseGoal = 10, baseFavor = 2, patterns = { "The [Adj] Null", "Mortal Frailty" } },
    { trigger = "DEBUFFED_KILL", baseDesc = "Strike the killing blow on %s targets while YOU are suffering from a poison, disease, curse, or bleed.", baseGoal = 5, baseFavor = 3, patterns = { "The [Adj] Masochist", "Blood for Blood" } },
    { trigger = "GRAY_WEAPON_KILL", baseDesc = "Strike the killing blow on %s targets while wielding only a Poor (Gray) or Common (White) weapon.", baseGoal = 15, baseFavor = 2, reqMelee = true, patterns = { "The Peasant's Ire", "Iron & Rust" } },
    
    -- Utility & Control
    { trigger = "CROWD_CONTROL", baseDesc = "Successfully incapacitate %s enemies (Polymorph, Sap, Trap, Fear, etc).", baseGoal = 15, baseFavor = 1, patterns = { "The [Adj] Warden", "Chains of the Patron" } },
    { trigger = "DISPEL_PURGE", baseDesc = "Successfully Dispel, Purge, or Cleanse %s auras.", baseGoal = 10, baseFavor = 2, patterns = { "The [Adj] Inquisitor", "Rite of Cleansing" } },
    { trigger = "MOB_DRAIN", baseDesc = "Successfully drain or siphon %s Health or Mana from enemies.", baseGoal = 500, baseFavor = 2, isStat = true, reqShadow = true, patterns = { "The [Adj] Leech", "Hunger of the Void" } },
    
    -- Environmental & Sadism
    { trigger = "DROWNING_SURVIVAL", baseDesc = "Hold your breath until you take drowning damage, then survive, %s times.", baseGoal = 2, baseFavor = 2, patterns = { "The [Adj] Lungs", "Kiss of the Depths" } },
    { trigger = "EXPLORE_ZONES", baseDesc = "Discover %s new map areas or sub-zones.", baseGoal = 5, baseFavor = 2, patterns = { "The [Adj] Nomad", "Mapping the Abyss" } },
    { trigger = "CRITTER_SLAUGHTER", baseDesc = "Ruthlessly slaughter %s harmless critters (Level 1).", baseGoal = 50, baseFavor = 1, patterns = { "The [Adj] Monster", "Pest Control" } },
    { trigger = "OVERKILL_STRIKE", baseDesc = "Deliver a single, devastating strike that deals %s or more damage at once.", baseGoal = 150, baseFavor = 2, isStat = true, patterns = { "The [Adj] Hammer", "Shattering Force" } },
    
    -- Elites & PvP
    { trigger = "RISKY_KILL", baseDesc = "Strike the killing blow on %s enemies while below 33%% health.", baseGoal = 3, baseFavor = 2, patterns = { "The [Adj] Survivor", "Dance with [Noun]" } },
    { trigger = "DUEL_WIN", baseDesc = "Emerge victorious in %s non-lethal duels.", baseGoal = 2, baseFavor = 2, isPvP = true, patterns = { "The [Adj] Duelist", "Contract: The Duelist" } },
    { trigger = "MAKGORA_WIN", baseDesc = "Emerge victorious from a Mak'gora duel to the death.", baseGoal = 1, baseFavor = 25, isPvP = true, isLegendary = true, minLvl = 19, reqHardcore = true, patterns = { "The Blood Debt", "Trial of the True [Noun]" } },
	
	-- Legendary
	{ 
        trigger = "SPECIFIC_KILL_ELITE",
        baseDesc = "Phase 1: Execute 500 Elite enemies that yield experience.", 
        baseGoal = 500, 
        baseFavor = 0, 
        isLegendary = true, 
        minLvl = isTBC and 70 or 60,
        patterns = { "The Blood Tithe", "The Blood Tithe" },
        idOverride = "LEGENDARY_BLOOD_TITHE",
        phases = {
            { trigger = "DUNGEON_BOSS_KILL", goal = 100, desc = "Phase 2: Slay 100 Dungeon Bosses that yield experience." },
            { trigger = "FETCH_ITEM", targetName = "Runecloth", goal = 1000, desc = "Phase 3: Acquire and stockpile 1,000 Runecloth." }
        }
    }
}

local DungeonBossDB = {
    -- RFC
    [11520]=true, [11517]=true, [11518]=true, [11519]=true,
    -- WC
    [3653]=true, [3671]=true, [3669]=true, [3670]=true, [3674]=true, [3673]=true, [5775]=true, [3654]=true,
    -- Deadmines
    [644]=true, [642]=true, [1763]=true, [646]=true, [647]=true, [639]=true,
    -- SFK
    [3914]=true, [3886]=true, [3887]=true, [4278]=true, [4279]=true, [3872]=true, [4274]=true, [3927]=true, [4275]=true,
    -- Stocks
    [1696]=true, [1666]=true, [1717]=true, [1663]=true, [1716]=true,
    -- BFD
    [4887]=true, [4831]=true, [6243]=true, [12902]=true, [12876]=true, [4832]=true, [4830]=true, [4829]=true,
    -- Gnomer
    [7361]=true, [7079]=true, [6235]=true, [6229]=true, [6228]=true, [7800]=true,
    -- RFK
    [6168]=true, [4424]=true, [4428]=true, [4420]=true, [4422]=true, [4421]=true,
    -- SM
    [3983]=true, [4543]=true, [3974]=true, [6487]=true, [3975]=true, [3976]=true, [3977]=true, [4542]=true,
    -- RFD
    [7355]=true, [7356]=true, [7357]=true, [7354]=true, [8567]=true, [7358]=true,
    -- Ulda
    [6910]=true, [6906]=true, [7228]=true, [7023]=true, [7206]=true, [7291]=true, [4854]=true, [2748]=true,
    -- ZF
    [8127]=true, [7272]=true, [7271]=true, [7796]=true, [7275]=true, [7604]=true, [7795]=true, [7267]=true, [7797]=true,
    -- Mara
    [13282]=true, [12258]=true, [12236]=true, [12225]=true, [12203]=true, [13601]=true, [13596]=true, [12201]=true,
    -- Sunken Temple
    [5713]=true, [8580]=true, [5721]=true, [5720]=true, [5710]=true, [5711]=true, [5719]=true, [5722]=true, [8443]=true, [5709]=true,
    -- BRD
    [9025]=true, [9016]=true, [9319]=true, [9018]=true, [10096]=true, [9024]=true, [9033]=true, [8983]=true, [9543]=true, [9537]=true, [9499]=true, [9502]=true, [9017]=true, [9056]=true, [9041]=true, [9042]=true, [9156]=true, [9938]=true, [9019]=true,
    -- BRS
    [9196]=true, [9236]=true, [9237]=true, [10596]=true, [10584]=true, [9736]=true, [10268]=true, [10220]=true, [9568]=true, [9816]=true, [10429]=true, [10339]=true, [10430]=true, [10363]=true,
    -- Scholo
    [10506]=true, [10503]=true, [11622]=true, [10433]=true, [10432]=true, [10508]=true, [10505]=true, [11261]=true, [10901]=true, [10507]=true, [10504]=true, [10502]=true, [1853]=true,
    -- Strat
    [11058]=true, [10393]=true, [10558]=true, [10516]=true, [11143]=true, [10808]=true, [11032]=true, [10997]=true, [11120]=true, [10811]=true, [10813]=true, [10435]=true, [10809]=true, [10437]=true, [11121]=true, [10438]=true, [10436]=true, [10439]=true, [10440]=true,
    -- Dire Maul
    [14354]=true, [14327]=true, [13280]=true, [11490]=true, [11492]=true, [14326]=true, [14322]=true, [14321]=true, [14323]=true, [14325]=true, [14324]=true, [11501]=true, [11489]=true, [11487]=true, [11467]=true, [11488]=true, [11496]=true, [11486]=true
}

local isTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)

local DungeonDB = {
    -- Classic Dungeons (With TBC Hardcore-compliant max levels)
    { name = "Ragefire Chasm", instanceID = 2437, minLvl = 13, maxLvl = (isTBC and 20 or 20), faction = "Horde", bossCount = 4 }, 
    { name = "Wailing Caverns", instanceID = 718, minLvl = 15, maxLvl = (isTBC and 24 or 24), bossCount = 8 }, 
    { name = "The Deadmines", instanceID = 1581, minLvl = 15, maxLvl = (isTBC and 24 or 26), faction = "Alliance", bossCount = 6 }, 
    { name = "Shadowfang Keep", instanceID = 209, minLvl = 18, maxLvl = (isTBC and 25 or 30), bossCount = 9 }, 
    { name = "The Stockade", instanceID = 717, minLvl = 22, maxLvl = (isTBC and 29 or 32), faction = "Alliance", bossCount = 5 }, 
    { name = "Blackfathom Deeps", instanceID = 719, minLvl = 20, maxLvl = (isTBC and 28 or 32), bossCount = 8 }, 
    { name = "Gnomeregan", instanceID = 721, minLvl = 28, maxLvl = (isTBC and 32 or 38), bossCount = 6 }, 
    { name = "Razorfen Kraul", instanceID = 491, minLvl = 28, maxLvl = (isTBC and 31 or 38), bossCount = 6 }, 
    
    -- SM Wings (All share ID 796)
    { name = "Scarlet Monastery: Graveyard", instanceID = 796, minLvl = 30, maxLvl = (isTBC and 44 or 45), bossCount = 2 }, 
    { name = "Scarlet Monastery: Library", instanceID = 796, minLvl = 33, maxLvl = (isTBC and 44 or 45), bossCount = 2 }, 
    { name = "Scarlet Monastery: Armory", instanceID = 796, minLvl = 35, maxLvl = (isTBC and 44 or 45), bossCount = 1 }, 
    { name = "Scarlet Monastery: Cathedral", instanceID = 796, minLvl = 38, maxLvl = (isTBC and 44 or 45), bossCount = 3 }, 
    
    { name = "Razorfen Downs", instanceID = 722, minLvl = 38, maxLvl = (isTBC and 41 or 46), bossCount = 6 }, 
    { name = "Uldaman", instanceID = 1337, minLvl = 40, maxLvl = (isTBC and 44 or 51), bossCount = 8 }, 
    { name = "Zul'Farrak", instanceID = 1176, minLvl = 42, maxLvl = (isTBC and 50 or 54), bossCount = 9 }, 
    { name = "Maraudon", instanceID = 2100, minLvl = 45, maxLvl = (isTBC and 52 or 55), bossCount = 8 }, 
    { name = "Temple of Atal'Hakkar", instanceID = 1477, minLvl = 50, maxLvl = (isTBC and 54 or 60), bossCount = 10 }, 
    { name = "Blackrock Depths", instanceID = 1584, minLvl = 52, maxLvl = 60, bossCount = 19 }, 
    
    -- BRS Wings (All share ID 1583)
    { name = "Lower Blackrock Spire", instanceID = 1583, minLvl = 56, maxLvl = (isTBC and 62 or 60), bossCount = 9 }, 
    { name = "Upper Blackrock Spire", instanceID = 1583, minLvl = 58, maxLvl = (isTBC and 62 or 60), bossCount = 5 }, 
    
    { name = "Scholomance", instanceID = 2057, minLvl = 58, maxLvl = (isTBC and 62 or 60), bossCount = 13 }, 
    
    -- Stratholme Wings (All share ID 2017)
    { name = "Stratholme (Live)", instanceID = 2017, minLvl = 58, maxLvl = (isTBC and 62 or 60), bossCount = 11 }, 
    { name = "Stratholme (Undead)", instanceID = 2017, minLvl = 58, maxLvl = (isTBC and 62 or 60), bossCount = 8 }, 
    
    -- Dire Maul Wings (All share ID 2557)
    { name = "Dire Maul (East)", instanceID = 2557, minLvl = 56, maxLvl = (isTBC and 62 or 60), bossCount = 5 }, 
    { name = "Dire Maul (North)", instanceID = 2557, minLvl = 56, maxLvl = (isTBC and 62 or 60), bossCount = 7 }, 
    { name = "Dire Maul (West)", instanceID = 2557, minLvl = 56, maxLvl = (isTBC and 62 or 60), bossCount = 6 },

    -- TBC Dungeons
    { name = "Hellfire Ramparts", instanceID = 3562, minLvl = 59, maxLvl = 67, bossCount = 3 },
    { name = "The Blood Furnace", instanceID = 3713, minLvl = 61, maxLvl = 68, bossCount = 3 },
    { name = "The Slave Pens", instanceID = 3717, minLvl = 62, maxLvl = 69, bossCount = 3 },
    { name = "The Underbog", instanceID = 3716, minLvl = 63, maxLvl = 70, bossCount = 4 },
    { name = "Mana-Tombs", instanceID = 3792, minLvl = 64, maxLvl = 70, bossCount = 3 },
    { name = "Auchenai Crypts", instanceID = 3790, minLvl = 65, maxLvl = 70, bossCount = 2 },
    { name = "Sethekk Halls", instanceID = 3791, minLvl = 67, maxLvl = 70, bossCount = 2 },
    { name = "Shadow Labyrinth", instanceID = 3789, minLvl = 67, maxLvl = 70, bossCount = 4 },
    { name = "Old Hillsbrad Foothills", instanceID = 2367, minLvl = 66, maxLvl = 70, bossCount = 3 },
    { name = "The Black Morass", instanceID = 2366, minLvl = 68, maxLvl = 70, bossCount = 3 },
    { name = "The Shattered Halls", instanceID = 3714, minLvl = 69, maxLvl = 70, bossCount = 3 },
    { name = "The Botanica", instanceID = 3847, minLvl = 69, maxLvl = 70, bossCount = 5 }, 
    { name = "The Mechanar", instanceID = 3849, minLvl = 69, maxLvl = 70, bossCount = 3 },
    { name = "The Arcatraz", instanceID = 3848, minLvl = 70, maxLvl = 70, bossCount = 4 },
    { name = "Magisters' Terrace", instanceID = 4131, minLvl = 70, maxLvl = 70, bossCount = 4 }
}

local RaidDB = {
    -- Classic Raids
    { name = "Zul'Gurub", instanceID = 1977, minLvl = 60, bossGoal = 5 }, 
    { name = "Molten Core", instanceID = 2717, minLvl = 60, bossGoal = 8 }, 
    { name = "Onyxia's Lair", instanceID = 249, minLvl = 60, bossGoal = 1 }, 
    { name = "Blackwing Lair", instanceID = 2677, minLvl = 60, bossGoal = 6 }, 
    { name = "Ruins of Ahn'Qiraj", instanceID = 3429, minLvl = 60, bossGoal = 4 }, 
    { name = "Ahn'Qiraj", instanceID = 3428, minLvl = 60, bossGoal = 7 }, 
    { name = "Naxxramas", instanceID = 3456, minLvl = 60, bossGoal = 10 }, 
    
    -- TBC Raids
    { name = "Karazhan", instanceID = 3457, minLvl = 70, bossGoal = 10 },
    { name = "Zul'Aman", instanceID = 3805, minLvl = 70, bossGoal = 4 },
    { name = "Gruul's Lair", instanceID = 3923, minLvl = 70, bossGoal = 2 },
    { name = "Magtheridon's Lair", instanceID = 3836, minLvl = 70, bossGoal = 1 },
    { name = "Serpentshrine Cavern", instanceID = 3607, minLvl = 70, bossGoal = 6 },
    { name = "Tempest Keep", instanceID = 3845, minLvl = 70, bossGoal = 4 },
    { name = "Hyjal Summit", instanceID = 3606, minLvl = 70, bossGoal = 5 },
    { name = "Black Temple", instanceID = 3959, minLvl = 70, bossGoal = 9 },
    { name = "Sunwell Plateau", instanceID = 4075, minLvl = 70, bossGoal = 6 }
}

local function IsGroupValidForDungeon(instanceID)
    local dInfo = nil
    for _, d in ipairs(DungeonDB) do
        if d.instanceID == instanceID then
            dInfo = d
            break
        end
    end
    
    -- If it's a Raid or not in the DungeonDB, skip the check
    if not dInfo then return true end 

    -- Support both standard parties and Raid frames (for 10-man UBRS/LBRS)
    local prefix = IsInRaid() and "raid" or "party"
    local maxCount = IsInRaid() and 40 or 4

    for i = 1, maxCount do
        local unit = prefix .. i
        -- Ensure the unit exists and is NOT the player (preserving self-grandfathering)
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local memberLvl = UnitLevel(unit)
            
            -- If their level is readable, enforce the strict level brackets
            if memberLvl > 0 and (memberLvl > dInfo.maxLvl or memberLvl < dInfo.minLvl) then
                return false
            end
        end
    end
    
    return true
end

local function GetDeterministicHash(trigger, goal, offset)
    local hash = 0
    local str = trigger .. tostring(goal) .. tostring(offset)
    for i = 1, #str do hash = (hash * 31 + string.byte(str, i)) % 1000000 end
    return hash
end

local function GetPlayerSkillLevel(skillName)
    for i = 1, GetNumSkillLines() do
        local name, _, _, skillRank = GetSkillLineInfo(i)
        if name == skillName then return skillRank end
    end
    return 0
end

local function IsWellFed()
    for i = 1, 40 do
        local name = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if name == "Well Fed" then return true end
    end
    return false
end

local function HasTempWeaponEnchant()
    local hasMainHandEnchant, _, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
    return hasMainHandEnchant or hasOffHandEnchant
end

local function PlayerHasSkill(skillName)
    for i = 1, GetNumSkillLines() do
        local name = select(1, GetSkillLineInfo(i))
        if name == skillName then return true end
    end
    return false
end

local function IsSelfFound()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if spellId == 431567 then return true end
    end
    local hcLoaded = false
    if C_AddOns and C_AddOns.IsAddOnLoaded then hcLoaded = C_AddOns.IsAddOnLoaded("Hardcore")
    elseif type(IsAddOnLoaded) == "function" then hcLoaded = IsAddOnLoaded("Hardcore") end
    if hcLoaded and Hardcore_Character then
        local hasDied = Hardcore_Character.deaths and #Hardcore_Character.deaths > 0
        local hasFailed = Hardcore_Character.failed == true
        if not hasDied and not hasFailed then return true end
    end
    return false
end

local function PlayerCanComplete(template, pLvl)
    local _, pClass = UnitClass("player")
    local pFaction = UnitFactionGroup("player")
    if template.minLvl and pLvl < template.minLvl then return false end
    if template.reqHardcore and not (C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive()) then return false end
    if template.reqMelee and not (pClass == "WARRIOR" or pClass == "ROGUE" or pClass == "PALADIN" or pClass == "SHAMAN" or pClass == "HUNTER" or pClass == "DRUID") then return false end
    if template.reqCaster and not (pClass == "MAGE" or pClass == "PRIEST" or pClass == "WARLOCK" or pClass == "SHAMAN" or pClass == "DRUID" or pClass == "PALADIN") then return false end
    if template.reqHolyFire and not (pClass == "PALADIN" or pClass == "PRIEST" or pClass == "MAGE" or pClass == "WARLOCK" or pClass == "SHAMAN") then return false end
    
    -- Elemental Specifics Fix
    if template.reqShadow and not (pClass == "WARLOCK" or pClass == "PRIEST") then return false end
    if template.reqFrost and not (pClass == "MAGE" or (pClass == "SHAMAN" and pLvl >= 20)) then return false end
    if template.reqNature and not (pClass == "DRUID" or pClass == "SHAMAN" or pClass == "HUNTER") then return false end
    if template.reqArcane and not (pClass == "MAGE" or pClass == "DRUID" or pClass == "HUNTER" or pClass == "PRIEST") then return false end
    
    if template.reqDefense and not (pClass == "WARRIOR" or pClass == "PALADIN" or pClass == "ROGUE" or pClass == "HUNTER" or pClass == "SHAMAN") then return false end
    if template.reqInterrupt then
        if pClass == "SHAMAN" and pLvl < 4 then return false end
        if (pClass == "WARRIOR" or pClass == "ROGUE") and pLvl < 12 then return false end
        if pClass == "MAGE" and pLvl < 24 then return false end
        if pClass == "PALADIN" or pClass == "DRUID" or pClass == "HUNTER" or pClass == "PRIEST" or pClass == "WARLOCK" then return false end
    end 
    local expectedMinSkill = math.max(1, (pLvl * 5) - 50)
    
    if template.trigger == "GATHER_NODE" then
        local m = GetPlayerSkillLevel("Mining"); local h = GetPlayerSkillLevel("Herbalism"); local s = GetPlayerSkillLevel("Skinning")
        if math.max(m, h, s) < expectedMinSkill then return false end
    end
    
    if template.trigger == "DUNGEON_CLEAR" then
        local hasValidDung = false
        for _, d in ipairs(DungeonDB) do 
            if pLvl >= d.minLvl and pLvl <= d.maxLvl and (not d.faction or d.faction == pFaction) then 
                hasValidDung = true 
                break 
            end 
        end
        if not hasValidDung then return false end
    end
    
    if template.trigger == "FETCH_ITEM" then
        local hasValidItem = false
        for _, item in ipairs(DP.TradeGoodsDB) do
            if item.reqProf then
                local pSkill = GetPlayerSkillLevel(item.reqProf)
                if pSkill >= expectedMinSkill and pSkill >= item.minSkill and pSkill <= (item.maxSkill + 50) then hasValidItem = true break end
            else
                if pLvl >= item.minLvl and pLvl <= (item.maxLvl + 10) then hasValidItem = true break end
            end
        end
        if not hasValidItem then return false end
    end

    if template.trigger == "FISH_CATCH" then
        local hasValidItem = false; local pSkill = GetPlayerSkillLevel("Fishing")
        if pSkill >= expectedMinSkill then
            for _, item in ipairs(DP.FishingDB) do if pSkill >= item.minSkill and pSkill <= (item.maxSkill + 50) then hasValidItem = true break end end
        end
        if not hasValidItem then return false end
    end

    if template.trigger == "CRAFT_ITEM" then
        local hasValidItem = false
        for _, item in ipairs(DP.CraftingDB) do
            local pSkill = GetPlayerSkillLevel(item.reqProf)
            
            -- First, check if they meet the skill requirements
            if pSkill >= expectedMinSkill and pSkill >= item.minSkill and pSkill <= (item.maxSkill + 50) then 
                
                -- Second, check if the item requires a specialization they don't have
                if not item.reqSpec or PlayerHasSkill(item.reqSpec) then
                    hasValidItem = true 
                    break 
                end
            end
        end
        if not hasValidItem then return false end
    end
    return true
end

local function GenerateProceduralContract(allowRare)
    local pLvl = UnitLevel("player") or 1
    local validActions = {}
    for _, a in ipairs(ActionTemplates) do
        if PlayerCanComplete(a, pLvl) then table.insert(validActions, a) end
    end
    
    local template = validActions[math.random(#validActions)]
	
    -- FIX: Move the Mak'gora reroll to the top so we don't calculate text for a discarded template!
    if template.trigger == "MAKGORA_WIN" and math.random(1, 100) > 5 then
        template = validActions[math.random(#validActions)]
    end

    if template.isLegendary and math.random(1, 100) > 3 then
        local standardActions = {}
        for _, a in ipairs(validActions) do
            if not a.isLegendary then table.insert(standardActions, a) end
        end
        if #standardActions > 0 then
            template = standardActions[math.random(#standardActions)]
        end
    end
    
    -- DUAL-CURVE MATH
    local finalGoal = template.baseGoal
    if not template.isLegendary then
        if template.isStat then
            local statScale = 1 + ((pLvl * pLvl) * 0.022)
            finalGoal = math.floor(template.baseGoal * statScale)
        else
            local countScale = 1 + (pLvl * 0.04)
            finalGoal = math.floor(template.baseGoal * countScale)
        end
    end
    
    local targetNameStr = ""
    local displayNameStr = "" -- NEW: Decouples the UI text from the API spell
    local targetZoneStr = ""
    local expectedMinSkill = math.max(1, (pLvl * 5) - 50)
	local customDesc = nil
    
    if template.trigger == "FETCH_ITEM" then
        local validItems = {}
        for _, item in ipairs(DP.TradeGoodsDB) do
            if item.reqProf then
                local pSkill = GetPlayerSkillLevel(item.reqProf)
                if pSkill >= expectedMinSkill and pSkill >= item.minSkill and pSkill <= (item.maxSkill + 50) then table.insert(validItems, item) end
            else
                if pLvl >= item.minLvl and pLvl <= (item.maxLvl + 10) then table.insert(validItems, item) end
            end
        end
        local chosenItem = (#validItems > 0) and validItems[math.random(#validItems)] or TradeGoodsDB[1]
        targetNameStr = chosenItem.name
        
        -- FIX: Smart Pluralization for Fetch Quests
        displayNameStr = chosenItem.outputName or targetNameStr
        if not chosenItem.outputName then
            if string.match(displayNameStr, "Bar$") or string.match(displayNameStr, "Ore$") or string.match(displayNameStr, "Stone$") or string.match(displayNameStr, "Potion$") or string.match(displayNameStr, "Elixir$") then
                displayNameStr = displayNameStr .. "s"
            end
        end
        
    elseif template.trigger == "GATHER_NODE" then
        local validGathers = {}
        if GetPlayerSkillLevel("Mining") >= expectedMinSkill then 
            table.insert(validGathers, {spell = "Mining", desc = "Successfully strike %s mineral veins."}) 
        end
        if GetPlayerSkillLevel("Herbalism") >= expectedMinSkill then 
            table.insert(validGathers, {spell = "Herb Gathering", desc = "Successfully harvest %s wild herbs."}) 
        end
        if GetPlayerSkillLevel("Skinning") >= expectedMinSkill then 
            table.insert(validGathers, {spell = "Skinning", desc = "Successfully skin %s creatures."}) 
        end
        
        local chosen = (#validGathers > 0) and validGathers[math.random(#validGathers)] or {spell = "Mining", desc = "Successfully strike %s mineral veins."}
        targetNameStr = chosen.spell
        customDesc = chosen.desc

    elseif template.trigger == "FISH_CATCH" then
        local validItems = {}; local pSkill = GetPlayerSkillLevel("Fishing")
        for _, item in ipairs(DP.FishingDB) do
            if pSkill >= expectedMinSkill and pSkill >= item.minSkill and pSkill <= (item.maxSkill + 50) then table.insert(validItems, item) end
        end
        local chosenItem = (#validItems > 0) and validItems[math.random(#validItems)] or FishingDB[1]
        targetNameStr = chosenItem.name
        
    elseif template.trigger == "CRAFT_ITEM" then
        local validItems = {}
        for _, item in ipairs(DP.CraftingDB) do
            local pSkill = GetPlayerSkillLevel(item.reqProf)
            if pSkill >= expectedMinSkill and pSkill >= item.minSkill and pSkill <= (item.maxSkill + 50) then table.insert(validItems, item) end
        end
        local chosenItem = (#validItems > 0) and validItems[math.random(#validItems)] or DP.CraftingDB[1]
        targetNameStr = chosenItem.name
        
        local itemBaseGoal = chosenItem.baseGoal or 3
        local countScale = 1 + (pLvl * 0.04)
        finalGoal = math.floor(itemBaseGoal * countScale)
        
        local verb = chosenItem.verb or "Craft"
        
        -- FIX: Smart Grammar Parsing for Professions
        displayNameStr = chosenItem.outputName or targetNameStr
        if not chosenItem.outputName then
            -- Safely remove the verb if it exists at the start of the item name (e.g. "Smelt Copper" -> "Copper")
            local verbPattern = "^" .. string.lower(verb) .. "%s*"
            local startIdx, endIdx = string.find(string.lower(displayNameStr), verbPattern)
            if startIdx then
                displayNameStr = string.sub(displayNameStr, endIdx + 1)
            end
            
            -- Auto-append "Bars" if it's a Smelting action
            if string.lower(verb) == "smelt" and not string.find(string.lower(displayNameStr), "bar") then
                displayNameStr = displayNameStr .. " Bars"
            end
            
            -- Auto-pluralize forged items or alchemy
            if string.match(displayNameStr, "Potion$") or string.match(displayNameStr, "Elixir$") or string.match(displayNameStr, "Flask$") or string.match(displayNameStr, "Stone$") then
                displayNameStr = displayNameStr .. "s"
            end
        end
        
        customDesc = verb .. " %s %s."
        
    elseif template.trigger == "DUNGEON_CLEAR" then
        local validDungeons = {}; local pFaction = UnitFactionGroup("player")
        for _, dungeon in ipairs(DungeonDB) do
            if pLvl >= dungeon.minLvl and pLvl <= dungeon.maxLvl and (not dungeon.faction or dungeon.faction == pFaction) then 
                table.insert(validDungeons, dungeon) 
            end
        end
        local chosenDung = (#validDungeons > 0) and validDungeons[math.random(#validDungeons)] or DungeonDB[1]
        targetNameStr = chosenDung.name
        targetZoneStr = chosenDung.name
    end
    
    local isTimed = (math.random(1, 100) <= 15) and not template.isLegendary
    local timeLimit = 0
    if isTimed then timeLimit = math.random(15, 30) * 60 end
    
    local favorPayout = template.baseFavor + math.floor(pLvl / 20)
    local rarity = "Standard"
    local baseRewardText = ""
    
    if template.isLegendary then
        rarity = "Rare Elite"
        baseRewardText = "Reward: +1 Apex Sigil, +35 Favor"
    else
        if allowRare and not isTimed and math.random(1, 100) <= 5 then
            rarity = "Rare"
            favorPayout = favorPayout + 1
            finalGoal = math.ceil(finalGoal * 1.25)
        end
        baseRewardText = string.format("Reward: +%d Dark Favor", favorPayout)
    end
    
    local patternIdx = (GetDeterministicHash(template.trigger, finalGoal, "Pattern") % #template.patterns) + 1
    local adjIdx = (GetDeterministicHash(template.trigger, finalGoal, "Adj") % #Adjectives) + 1
    local nounIdx = (GetDeterministicHash(template.trigger, finalGoal, "Noun") % #Nouns) + 1

    local pattern = template.patterns[patternIdx]
    local baseTitle = pattern:gsub("%[Adj%]", Adjectives[adjIdx]):gsub("%[Noun%]", Nouns[nounIdx])

    local baseFormat = customDesc or template.baseDesc
    local formattedGoal = DP_FormatNumber(finalGoal)
    local finalDesc = ""
    
    -- FIX: Count the number of string placeholders in the template to avoid sloppy argument passing
    local numStringTokens = select(2, string.gsub(baseFormat, "%%s", ""))
    
    if numStringTokens == 2 and targetNameStr ~= "" then 
        local finalName = (displayNameStr ~= nil and displayNameStr ~= "") and displayNameStr or targetNameStr
        finalDesc = string.format(baseFormat, formattedGoal, finalName) 
    else 
        finalDesc = string.format(baseFormat, formattedGoal) 
    end
    
    return { 
        id = GetDeterministicHash(template.trigger, finalGoal, "ID"), 
        title = baseTitle, 
        desc = finalDesc, 
        rarity = rarity, 
        rewardText = baseRewardText, 
        favor = favorPayout, 
        goal = finalGoal, 
        current = 0, 
        trigger = template.trigger, 
        targetName = targetNameStr, 
        zone = targetZoneStr, 
        isPvP = template.isPvP or false, 
        isLegendary = template.isLegendary or false, 
        isTimed = isTimed, 
        timeLimit = timeLimit, 
        expiresAt = 0 
    }
end

local function GenerateAllDungeonContracts(pLvl)
    local validContracts = {}
    local pFaction = UnitFactionGroup("player")
    for _, dungeon in ipairs(DungeonDB) do
        if pLvl >= dungeon.minLvl and pLvl <= dungeon.maxLvl and (not dungeon.faction or dungeon.faction == pFaction) then 
            local bossGoal = dungeon.bossCount or 3
            local sigilPayout = (bossGoal >= 8) and 2 or 1
            local favorPayout = bossGoal * 5
            local rewardStr = string.format("Reward: +%d Dark Sigil%s, +%d Favor", sigilPayout, sigilPayout > 1 and "s" or "", favorPayout)
            
            local dynamicDesc = ""
            if bossGoal == 1 then
                dynamicDesc = string.format("Slay the only boss inside %s.", dungeon.name)
            elseif bossGoal == 2 then
                dynamicDesc = string.format("Slay both bosses inside %s.", dungeon.name)
            else
                dynamicDesc = string.format("Slay all %d bosses inside %s.", bossGoal, dungeon.name)
            end
            
            table.insert(validContracts, { 
                id = "DUNGEON_" .. dungeon.instanceID,
                title = "Purge of " .. dungeon.name, 
                desc = dynamicDesc,
                rarity = "Elite", 
                rewardText = rewardStr, 
                favor = favorPayout, 
                sigils = sigilPayout, 
                goal = bossGoal, 
                current = 0, 
                trigger = "DUNGEON_BOSS_KILL", 
                targetName = dungeon.name, 
                targetInstanceID = dungeon.instanceID, 
                zone = dungeon.name, 
                isPvP = false, 
                isLegendary = false, 
                isTimed = false,
                reqMinLvl = dungeon.minLvl, -- Store the exact requirements!
                reqMaxLvl = dungeon.maxLvl
            })
        end
    end
    return validContracts
end

local function GenerateAllRaidContracts(pLvl)
    local validContracts = {}
    local isTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
    local reqLevel = isTBC and 70 or 60
    
    if pLvl < reqLevel then return validContracts end 
    
    for _, raid in ipairs(RaidDB) do
        if (not isTBC and raid.minLvl == 60) or (isTBC and raid.minLvl == 70) then
            
            -- Dynamic Grammar Check
            local dynamicDesc = ""
            if raid.bossGoal == 1 then
                dynamicDesc = string.format("Slay the only boss inside %s.", raid.name)
            elseif raid.bossGoal == 2 then
                dynamicDesc = string.format("Slay both bosses inside %s.", raid.name)
            else
                dynamicDesc = string.format("Slay all %d raid bosses inside %s.", raid.bossGoal, raid.name)
            end
            
            table.insert(validContracts, { 
                id = "RAID_" .. raid.instanceID,
                title = "The Apex Hunt: " .. raid.name, 
                desc = dynamicDesc, 
                rarity = "Rare Elite", 
                rewardText = "Reward: +2 Apex Sigils, +50 Favor", 
                favor = 50, 
                goal = raid.bossGoal, 
                current = 0, 
                trigger = "DUNGEON_BOSS_KILL", 
                targetName = raid.name, 
                targetInstanceID = raid.instanceID, 
                zone = raid.name, 
                isPvP = false, 
                isLegendary = true, 
                isTimed = true, 
                timeLimit = 604800 
            })
        end
    end
    return validContracts
end

local function CheckLevelMilestoneDungeons()
    if not DarkPatronDB then return end
    local pLvl = UnitLevel("player") or 1
    local pFaction = UnitFactionGroup("player")
    local guid = UnitGUID("player") or "Unknown"
    
    DarkPatronDB.DungeonBounties = DarkPatronDB.DungeonBounties or {}
    
    -- 1. Purge outleveled or invalid dungeons from the waiting stack
    for i = #DarkPatronDB.DungeonBounties, 1, -1 do
        local waitingDung = DarkPatronDB.DungeonBounties[i]
        local stillValid = false
        for _, dbDung in ipairs(DungeonDB) do
            if dbDung.instanceID == waitingDung.targetInstanceID then
                if pLvl >= dbDung.minLvl and pLvl <= dbDung.maxLvl and (not dbDung.faction or dbDung.faction == pFaction) then
                    stillValid = true
                end
                break
            end
        end
        if not stillValid then
            table.remove(DarkPatronDB.DungeonBounties, i)
        end
    end

    -- 2. Generate the fresh stack and merge only what is missing
    local newStack = GenerateAllDungeonContracts(pLvl)
    local addedNew = false

    if newStack and #newStack > 0 then
        for _, newContract in ipairs(newStack) do
            local isDuplicate = false
            
            -- Check if it's already waiting in the stack
            for _, existing in ipairs(DarkPatronDB.DungeonBounties) do
                if existing.targetInstanceID == newContract.targetInstanceID then
                    isDuplicate = true
                    break
                end
            end
            
            if not isDuplicate and DarkPatronDB.ActiveMissions then
                for _, active in ipairs(DarkPatronDB.ActiveMissions) do
                    if active.trigger == "DUNGEON_BOSS_KILL" and active.targetInstanceID == newContract.targetInstanceID then
                        isDuplicate = true
                        break
                    end
                end
            end
            
            if not isDuplicate and DarkPatronDB.CompletedElites then
                local expectedId = newContract.id .. "-" .. guid
                for _, completedId in ipairs(DarkPatronDB.CompletedElites) do
                    if completedId == newContract.id or completedId == expectedId then
                        isDuplicate = true
                        break
                    end
                end
            end
            
            if not isDuplicate then
                table.insert(DarkPatronDB.DungeonBounties, newContract)
                addedNew = true
            end
        end
    end

    if addedNew then
        if ShowPatronToast then 
            ShowPatronToast("New Dungeon Pacts have opened in your Ledger!") 
        end
        PlaySound(8831) -- Quest unlock sound
    end
end

-- =====================================================================
-- 3. THE PATRON'S VEIL & VOID DEBT AUDIT LOGIC
-- =====================================================================
local Veil = CreateFrame("Frame", "PatronsVeil", UIParent)
Veil:SetAllPoints(UIParent)
-- Pushed to the background so your Bags and Character Sheet stay full-color
Veil:SetFrameStrata("BACKGROUND") 
Veil:SetFrameLevel(0)
Veil:Hide()

local veilBg = Veil:CreateTexture(nil, "BACKGROUND")
veilBg:SetAllPoints(Veil)
veilBg:SetTexture("Interface\\Buttons\\WHITE8X8")
veilBg:SetVertexColor(0.02, 0.02, 0.05, 0.92)

local veilText = Veil:CreateFontString(nil, "OVERLAY", "QuestFont_Enormous")
veilText:SetPoint("CENTER", 0, 150)
veilText:SetTextColor(1, 0, 0)

local isViolating = false
local equippedTracker = {} -- Tracks your legal gear for perfect auto-swapping

-- Safe API fallbacks to prevent nil errors across different WoW client versions
local GetBagSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
local GetBagItemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
local PickupBagItem = C_Container and C_Container.PickupContainerItem or PickupContainerItem

local function CheckViolations()
    if not DarkPatronDB then return end
    isViolating = false
    local violationReason = ""

    for slot = 1, 19 do
        if slot ~= 4 and slot ~= 19 then
            local itemLink = GetInventoryItemLink("player", slot)
            if itemLink then
                local _, _, itemQuality = GetItemInfo(itemLink)
                
                if itemQuality and itemQuality > DarkPatronDB.MaxGearQuality then
                    isViolating = true
                    violationReason = "FORBIDDEN ARTIFACT (Unequip illegal gear)"
                    
                    if not InCombatLockdown() then 
                        -- 1. Rip the forbidden item off the character
                        PickupInventoryItem(slot) 
                        
                        if CursorHasItem() then
                            local itemPlaced = false
                            
                            -- Phase 1: If we replaced a legal item, find it and swap it back immediately
                            if equippedTracker[slot] then
                                -- Extract the itemID safely from the tracked item link
                                local oldItemID = tonumber(equippedTracker[slot]:match("item:(%d+)"))
                                
                                if oldItemID then
                                    for bag = 0, 4 do
                                        local numSlots = GetBagSlots(bag)
                                        if numSlots and numSlots > 0 then
                                            for bagSlot = 1, numSlots do
                                                if GetBagItemID(bag, bagSlot) == oldItemID then
                                                    PickupBagItem(bag, bagSlot) -- Drops illegal item, picks up old item
                                                    PickupInventoryItem(slot)   -- Equips the old item back!
                                                    itemPlaced = true
                                                    break
                                                end
                                            end
                                        end
                                        if itemPlaced then break end
                                    end
                                end
                            end
                            
                            -- Phase 2: If the slot was previously empty (no item to swap back), drop it in an empty bag slot
                            if not itemPlaced then
                                for bag = 0, 4 do
                                    local numSlots = GetBagSlots(bag)
                                    if numSlots and numSlots > 0 then
                                        for bagSlot = 1, numSlots do
                                            if not GetBagItemID(bag, bagSlot) then
                                                PickupBagItem(bag, bagSlot) 
                                                itemPlaced = true
                                                break
                                            end
                                        end
                                    end
                                    if itemPlaced then break end
                                end
                            end
                        end
                    end
                else
                    -- The item is legal. Update our memory tracker.
                    equippedTracker[slot] = itemLink
                end
            else
                -- The slot is legally empty. Clear memory for this slot.
                equippedTracker[slot] = nil
            end
        end
    end

    if isViolating then 
        Veil:Show() 
        veilText:SetText(violationReason) 
    else 
        Veil:Hide() 
    end
end

-- =====================================================================
-- 4. ON-SCREEN TRACKER, MINIMAP ICON & DRAG GHOST
-- =====================================================================
local MinimapBtn = CreateFrame("Button", "DarkPatronMinimapBtn", UIParent)
MinimapBtn:SetSize(32, 32)
MinimapBtn:SetFrameStrata("MEDIUM")
MinimapBtn:SetFrameLevel(8)
MinimapBtn:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -5, -5)

local icon = MinimapBtn:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowWordPain")
icon:SetSize(21, 21)
icon:SetPoint("CENTER", 0, 0)

local pulseGlow = MinimapBtn:CreateTexture(nil, "ARTWORK")
pulseGlow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
pulseGlow:SetBlendMode("ADD")
pulseGlow:SetSize(50, 50)
pulseGlow:SetPoint("CENTER", 0, 0)
pulseGlow:SetVertexColor(0.9, 0.2, 1.0) 
pulseGlow:Hide()

local pulseAnimGroup = pulseGlow:CreateAnimationGroup()
local alpha1 = pulseAnimGroup:CreateAnimation("Alpha")
alpha1:SetFromAlpha(0.1); alpha1:SetToAlpha(1.0); alpha1:SetDuration(0.8); alpha1:SetOrder(1)
local alpha2 = pulseAnimGroup:CreateAnimation("Alpha")
alpha2:SetFromAlpha(1.0); alpha2:SetToAlpha(0.1); alpha2:SetDuration(0.8); alpha2:SetOrder(2)
pulseAnimGroup:SetLooping("REPEAT")

function DP_EvaluateBazaarAlert()
    if not DarkPatronDB then return "", {} end
    
    local currentState = ""
    local newAlerts = {}
    
    -- Parse old state tokens into a quick lookup table
    local oldStateMap = {}
    if DarkPatronDB.LastSeenAlertState then
        for token in string.gmatch(DarkPatronDB.LastSeenAlertState, "([^;]+)") do
            oldStateMap[token] = true
        end
    end
    
    -- 1. Check Bazaar Unlocks
    if DarkPatronDB.MaxGearQuality == 1 and DarkPatronDB.DarkFavor >= 35 then 
        currentState = currentState .. "Gear;" 
        if not oldStateMap["Gear"] then table.insert(newAlerts, "Uncommon Armaments unlocked") end
    end
    if not DarkPatronDB.HasBank and DarkPatronDB.DarkFavor >= 40 then 
        currentState = currentState .. "Bank;" 
        if not oldStateMap["Bank"] then table.insert(newAlerts, "The Hoarder's Key available") end
    end
    if not DarkPatronDB.HasAlchemistGrace and DarkPatronDB.DarkFavor >= 35 then 
        currentState = currentState .. "Alch;" 
        if not oldStateMap["Alch"] then table.insert(newAlerts, "The Alchemist's Grace available") end
    end
    
    -- 2. Check Dungeon Bounties (Track new dungeon IDs dynamically)
    local newDungeonCount = 0
    if DarkPatronDB.DungeonBounties and #DarkPatronDB.DungeonBounties > 0 then
        for _, d in ipairs(DarkPatronDB.DungeonBounties) do
            currentState = currentState .. d.id .. ";"
            if not oldStateMap[d.id] then
                newDungeonCount = newDungeonCount + 1
            end
        end
        if newDungeonCount > 0 then
            table.insert(newAlerts, string.format("%d new Dungeon Pact%s arrived", newDungeonCount, newDungeonCount > 1 and "s" or ""))
        end
    end
    
    -- We only pulse if there are strictly *new* unacknowledged things
    if #newAlerts > 0 then 
        pulseGlow:Show() 
        if not pulseAnimGroup:IsPlaying() then
            pulseAnimGroup:Play() 
        end
    else 
        pulseGlow:Hide() 
        pulseAnimGroup:Stop() 
    end
    
    return currentState, newAlerts
end

local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT", 0, 0)

MinimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
MinimapBtn:SetScript("OnClick", function() if PatronsLedger and PatronsLedger:IsShown() then PatronsLedger:Hide() else PatronsLedger:Show() end end)

local minimapHoverTimer

MinimapBtn:SetScript("OnEnter", function(self)
    self.isHovered = true
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    
    local function UpdateMinimapTooltip()
        if not self.isHovered then return end
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Dark Patron", 0.64, 0.21, 0.93)
        GameTooltip:AddLine(" ")
        
        if DarkPatronDB then
            GameTooltip:AddDoubleLine("Dark Favor:", tostring(DarkPatronDB.DarkFavor or 0), 1, 1, 1, 1, 0.82, 0)
            GameTooltip:AddDoubleLine("Dark Sigils:", tostring(DarkPatronDB.DarkSigils or 0), 1, 1, 1, 0.64, 0.21, 0.93)
            GameTooltip:AddDoubleLine("Apex Sigils:", tostring(DarkPatronDB.ApexSigils or 0), 1, 1, 1, 1, 0.5, 0)
            GameTooltip:AddLine(" ")
            
            -- Fetch fresh unread notifications
            local _, newAlerts = DP_EvaluateBazaarAlert()
            if newAlerts and #newAlerts > 0 then
                GameTooltip:AddLine("|cffffd700New Ledger Activity:|r", 1, 1, 1)
                for _, line in ipairs(newAlerts) do
                    GameTooltip:AddLine("• " .. line, 0.9, 0.9, 0.9, true)
                end
                GameTooltip:AddLine(" ")
            end
            
            local lastRefresh = DarkPatronDB.LastBoardRefresh or time()
            local timeSinceRefresh = time() - lastRefresh
            local timeUntilNext = math.max(0, 3600 - timeSinceRefresh)
            local mins = math.floor(timeUntilNext / 60)
            local secs = timeUntilNext % 60
            
            GameTooltip:AddDoubleLine("Board Refresh:", string.format("%02d:%02d", mins, secs), 0.8, 0.8, 0.8, 1, 1, 1)
        else
            GameTooltip:AddLine("Data uninitialized", 1, 0, 0)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffaaaaaaLeft-click to open/close Ledger|r", 1, 1, 1)
        GameTooltip:Show()
    end

    UpdateMinimapTooltip()
    minimapHoverTimer = C_Timer.NewTicker(1, UpdateMinimapTooltip)
end)

MinimapBtn:SetScript("OnLeave", function(self)
    self.isHovered = false
    if minimapHoverTimer then
        minimapHoverTimer:Cancel()
        minimapHoverTimer = nil
    end
    GameTooltip:Hide()
end)

-- Forward declare Tracker, StreakFrame, and UpdateTracker
local Tracker, StreakFrame, UpdateTracker

-- 1. Create Tracker Frame
Tracker = CreateFrame("Frame", "DarkPatronTracker", UIParent, "BackdropTemplate")
Tracker:SetSize(260, 20)
Tracker:SetPoint("RIGHT", UIParent, "RIGHT", -80, 0)
Tracker:SetMovable(true)
Tracker:SetResizable(true)
if Tracker.SetMinResize then
    Tracker:SetMinResize(240, 30)
    Tracker:SetMaxResize(500, 600)
end
Tracker:EnableMouse(true)
Tracker:RegisterForDrag("LeftButton")
Tracker:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
Tracker:SetScript("OnDragStop", Tracker.StopMovingOrSizing)

-- Restore saved background/width preferences
C_Timer.After(0.5, function()
    if DarkPatronDB and DarkPatronDB.TrackerBgHidden then
        Tracker:SetBackdrop(nil)
    else
        Tracker:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        Tracker:SetBackdropColor(0.05, 0.05, 0.1, 0.85)
    end
    if DarkPatronDB and DarkPatronDB.TrackerWidth then
        Tracker:SetWidth(DarkPatronDB.TrackerWidth)
        if StreakFrame then StreakFrame:SetWidth(DarkPatronDB.TrackerWidth) end
    end
end)

local resizeGrip = CreateFrame("Button", nil, Tracker)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", 0, 0)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

resizeGrip:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self.isSizing = true
        Tracker:StartSizing("BOTTOMRIGHT")
    end
end)

resizeGrip:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self.isSizing = false
        Tracker:StopMovingOrSizing()
        DarkPatronDB.TrackerWidth = Tracker:GetWidth()
        if StreakFrame then StreakFrame:SetWidth(Tracker:GetWidth()) end
        for i = 1, 4 do
            if Tracker.RowButtons[i] then
                Tracker.RowButtons[i]:SetWidth(Tracker:GetWidth() - 30)
            end
        end
        UpdateTracker()
    end
end)

resizeGrip:SetScript("OnUpdate", function(self)
    if self.isSizing then
        local cursorX, _ = GetCursorPosition()
        local scale = Tracker:GetEffectiveScale()
        local newWidth = (cursorX / scale) - Tracker:GetLeft()
        if newWidth >= 240 and newWidth <= 500 then
            Tracker:SetWidth(newWidth)
            if StreakFrame then StreakFrame:SetWidth(newWidth) end
            for i = 1, 4 do
                if Tracker.RowButtons[i] then
                    Tracker.RowButtons[i]:SetWidth(newWidth - 30)
                end
            end
            UpdateTracker()
        end
    end
end)

Tracker.Header = Tracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Tracker.Header:SetPoint("TOPLEFT", 10, -10)
Tracker.Header:SetText("Active Pacts")

-- 2. Create StreakFrame once cleanly
StreakFrame = CreateFrame("Frame", "DarkPatronStreakFrame", UIParent, "BackdropTemplate")
StreakFrame:SetSize(260, 18)
StreakFrame:SetPoint("TOP", Tracker, "BOTTOM", 0, -2)
StreakFrame:SetMovable(true)
StreakFrame:EnableMouse(true)
StreakFrame:RegisterForDrag("LeftButton")
StreakFrame:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
StreakFrame:SetScript("OnDragStop", StreakFrame.StopMovingOrSizing)
StreakFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
StreakFrame:SetBackdropColor(0.05, 0.05, 0.1, 0.85)
StreakFrame:Hide()

local StreakBar = CreateFrame("StatusBar", nil, StreakFrame)
StreakBar:SetPoint("TOPLEFT", 4, -4)
StreakBar:SetPoint("BOTTOMRIGHT", -4, 4)
StreakBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
StreakBar:SetMinMaxValues(0, 1200)

local spark = StreakBar:CreateTexture(nil, "OVERLAY")
spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
spark:SetSize(32, 32)
spark:SetBlendMode("ADD")

local StreakText = StreakBar:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
StreakText:SetPoint("CENTER")

-- 3. Initialize row frames and interactive collapse buttons
Tracker.Rows = {}
Tracker.RowButtons = {}
Tracker.CollapseButtons = {}

for i = 1, 4 do
    local rowBtn = CreateFrame("Button", nil, Tracker)
    rowBtn:SetWidth(Tracker:GetWidth() - 30)
    rowBtn:RegisterForClicks("LeftButtonUp")
    
    local collapseBtn = CreateFrame("Button", nil, rowBtn)
    collapseBtn:SetSize(14, 14)
    collapseBtn:SetPoint("TOPLEFT", 0, -2)
    collapseBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    collapseBtn:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
    collapseBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
    local row = rowBtn:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
    row:SetPoint("TOPLEFT", 18, 0)
    row:SetPoint("TOPRIGHT", rowBtn, "TOPRIGHT", -5, 0)
    row:SetJustifyH("LEFT")
    row:SetJustifyV("TOP")
	row:SetWordWrap(true)
    
    local function ToggleCollapse()
        DarkPatronDB.CollapsedPacts = DarkPatronDB.CollapsedPacts or {}
        DarkPatronDB.CollapsedPacts[i] = not DarkPatronDB.CollapsedPacts[i]
        UpdateTracker()
    end
    
    rowBtn:SetScript("OnClick", function(self, button)
		if IsShiftKeyDown() and DarkPatronDB.ActiveMissions[i] then
			DP_InsertPactToChat(DarkPatronDB.ActiveMissions[i])
		else
			ToggleCollapse()
		end
	end)
    collapseBtn:SetScript("OnClick", ToggleCollapse)
    
    Tracker.Rows[i] = row
    Tracker.RowButtons[i] = rowBtn
    Tracker.CollapseButtons[i] = collapseBtn
end

UpdateTracker = function()
    if not DarkPatronDB then Tracker:Hide() StreakFrame:Hide() return end
    
    if DP_EvaluateBazaarAlert then DP_EvaluateBazaarAlert() end
    
    local activeCount = (DarkPatronDB.ActiveMissions and #DarkPatronDB.ActiveMissions > 0) and #DarkPatronDB.ActiveMissions or 0
    local streak = DarkPatronDB.CurrentStreak or 0
    local lastTime = DarkPatronDB.LastPactTime or 0
    local hasStreak = (streak > 0 and lastTime > 0)

    if activeCount == 0 and not hasStreak then 
        Tracker:Hide() 
        StreakFrame:Hide()
        return 0
    end
    
    Tracker:Show()
    local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    local currentY = -30
    
    DarkPatronDB.CollapsedPacts = DarkPatronDB.CollapsedPacts or {}

    for i = 1, 4 do
        if i <= maxSlots then
			Tracker.RowButtons[i]:SetWidth(Tracker:GetWidth() - 30)
            Tracker.RowButtons[i]:SetPoint("TOPLEFT", 15, currentY)
            local m = DarkPatronDB.ActiveMissions[i]
            if m then
                local isCollapsed = DarkPatronDB.CollapsedPacts[i] or false
                
                if isCollapsed then
                    Tracker.CollapseButtons[i]:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                    Tracker.CollapseButtons[i]:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
                else
                    Tracker.CollapseButtons[i]:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                    Tracker.CollapseButtons[i]:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
                end
                Tracker.CollapseButtons[i]:Show()

                -- Apply Hex colors dynamically to the title based on rarity
                local titleColor = "|cffffd700" -- Gold for Standard
                if m.rarity == "Rare Elite" or m.rarity == "Boss" then titleColor = "|cffff8000"
                elseif m.rarity == "Elite" then titleColor = "|cffa335ee"
                elseif m.rarity == "Rare" then titleColor = "|cff0070dd"
                end
                
                local descColor = "|cffffffff" -- White for desc

                local displayText = ""
                if isCollapsed then
                    displayText = string.format("%s%s|r", titleColor, m.title)
                else
                    local progressText = (m.goal and m.goal > 1) and string.format("\nProgress: %d / %d", m.current or 0, m.goal) or ""
                    local timeText = ""
                    if m.isTimed and m.expiresAt then
                        local remain = m.expiresAt - time()
                        if remain > 0 then timeText = string.format("\n|cffaaaaaaTime Remaining: %02d:%02d|r", math.floor(remain / 60), remain % 60) else timeText = "\n|cffff0000FAILED|r" end
                    end
                    displayText = string.format("%s%s|r\n%s%s%s%s|r", titleColor, m.title, descColor, m.desc, progressText, timeText)
                end
                
                Tracker.Rows[i]:SetText(displayText)
                local h = Tracker.Rows[i]:GetStringHeight()
                Tracker.RowButtons[i]:SetHeight(h)

                -- Force standard base color so inline colors do the work
                Tracker.Rows[i]:SetTextColor(1, 1, 1) 
                Tracker.RowButtons[i]:Show()
                currentY = currentY - h - 12
            else
                Tracker.CollapseButtons[i]:Hide()
                Tracker.Rows[i]:SetText(string.format("Slot %d: Empty", i))
                Tracker.Rows[i]:SetTextColor(0.5, 0.5, 0.5)
                local h = Tracker.Rows[i]:GetStringHeight()
                Tracker.RowButtons[i]:SetHeight(h)
                Tracker.RowButtons[i]:Show()
                currentY = currentY - h - 12
            end
        else
            Tracker.RowButtons[i]:Hide()
        end
    end

    Tracker:SetHeight(math.abs(currentY) + 15)

    if hasStreak then
        StreakFrame:ClearAllPoints()
        StreakFrame:SetPoint("TOP", Tracker, "BOTTOM", 0, -5)
        StreakFrame:Show()
    else
        StreakFrame:Hide()
    end
end

C_Timer.NewTicker(0.25, function()
    if not DarkPatronDB then return end
    
    local currentTime = time()
    local lastTime = DarkPatronDB.LastPactTime or 0
    local streak = DarkPatronDB.CurrentStreak or 0
    
    if streak == 0 or lastTime == 0 then
        if StreakFrame:IsShown() then StreakFrame:Hide() end
        return
    end
    
    if not StreakFrame:IsShown() then StreakFrame:Show() end

    local elapsed = currentTime - lastTime
    local remaining = math.max(0, 1200 - elapsed)
    
    StreakBar:SetValue(remaining)
    
    local ratio = remaining / 1200
    if ratio > 0.5 then
        StreakBar:SetStatusBarColor(1, 0.82, 0) -- Gold
    elseif ratio > 0.2 then
        StreakBar:SetStatusBarColor(1, 0.5, 0)   -- Orange
    else
        StreakBar:SetStatusBarColor(0.8, 0.1, 0.1) -- Crimson Red
    end
    
    local barWidth = StreakBar:GetWidth()
    local fillWidth = barWidth * (remaining / 1200)
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", StreakBar, "LEFT", fillWidth, 0)
    
    local mins = math.floor(remaining / 60)
    local secs = remaining % 60
    
    if StreakFrame:GetWidth() < 120 then
        StreakText:SetText(string.format("%d | %02d:%02d", streak, mins, secs))
    else
        StreakText:SetText(string.format("Streak: %d | Time: %02d:%02d", streak, mins, secs))
    end
end)

local DragGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
DragGhost:SetFrameStrata("TOOLTIP")
DragGhost:Hide()
DragGhost:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
DragGhost:SetAlpha(0.85) -- Slight transparency for the ghosting effect

DragGhost.bgImage = DragGhost:CreateTexture(nil, "BORDER")
DragGhost.bgImage:SetPoint("TOPLEFT", 4, -4)
DragGhost.bgImage:SetPoint("BOTTOMRIGHT", -4, 4)

DragGhost.title = DragGhost:CreateFontString(nil, "OVERLAY")
DragGhost.desc = DragGhost:CreateFontString(nil, "OVERLAY")
DragGhost.reward = DragGhost:CreateFontString(nil, "OVERLAY")

local function StartDragging(sourceType, index, sourceFrame)
    DragGhost.sourceType = sourceType
    DragGhost.sourceIndex = index
    
    -- Clone Dimensions
    DragGhost:SetSize(sourceFrame:GetSize())
    
    -- Clone Frame Colors
    local br, bg, bb, ba = sourceFrame:GetBackdropBorderColor()
    DragGhost:SetBackdropBorderColor(br, bg, bb, ba)
    local cr, cg, cb, ca = sourceFrame:GetBackdropColor()
    DragGhost:SetBackdropColor(cr, cg, cb, ca)

    -- Clone Background Art
    if sourceFrame.bgImage and sourceFrame.bgImage:IsShown() then
        DragGhost.bgImage:SetTexture(sourceFrame.bgImage:GetTexture())
        DragGhost.bgImage:SetTexCoord(sourceFrame.bgImage:GetTexCoord())
        local vr, vg, vb, va = sourceFrame.bgImage:GetVertexColor()
        DragGhost.bgImage:SetVertexColor(vr, vg, vb, va)
        DragGhost.bgImage:Show()
    else
        DragGhost.bgImage:Hide()
    end

    -- Clone Title
    DragGhost.title:SetFontObject(sourceFrame.title:GetFontObject())
    DragGhost.title:SetText(sourceFrame.title:GetText())
    local tr, tg, tb, ta = sourceFrame.title:GetTextColor()
    DragGhost.title:SetTextColor(tr, tg, tb, ta)
    DragGhost.title:SetWidth(sourceFrame.title:GetWidth())
    DragGhost.title:SetWordWrap(true)
    DragGhost.title:ClearAllPoints()
    DragGhost.title:SetPoint("TOP", DragGhost, "TOP", 0, -12)

    -- Clone Description
    DragGhost.desc:SetFontObject(sourceFrame.desc:GetFontObject())
    DragGhost.desc:SetText(sourceFrame.desc:GetText())
    local dr, dg, db, da = sourceFrame.desc:GetTextColor()
    DragGhost.desc:SetTextColor(dr, dg, db, da)
    DragGhost.desc:SetSize(sourceFrame.desc:GetSize())
    DragGhost.desc:SetJustifyH(sourceFrame.desc:GetJustifyH())
    DragGhost.desc:SetJustifyV(sourceFrame.desc:GetJustifyV())
    DragGhost.desc:ClearAllPoints()
    DragGhost.desc:SetPoint("TOP", DragGhost.title, "BOTTOM", 0, -2)

    -- Clone Reward
    DragGhost.reward:SetFontObject(sourceFrame.reward:GetFontObject())
    DragGhost.reward:SetText(sourceFrame.reward:GetText())
    local rr, rg, rb, ra = sourceFrame.reward:GetTextColor()
    DragGhost.reward:SetTextColor(rr, rg, rb, ra)
    DragGhost.reward:ClearAllPoints()
    local _, _, _, _, yOfs = sourceFrame.reward:GetPoint(1)
    DragGhost.reward:SetPoint("BOTTOM", DragGhost, "BOTTOM", 0, yOfs or 6)

    DragGhost:Show()
    DragGhost:SetScript("OnUpdate", function(self) 
        local x, y = GetCursorPosition()
        local s = self:GetEffectiveScale()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/s, y/s) 
    end)
end

local function StopDragging() 
    DragGhost:Hide()
    DragGhost:SetScript("OnUpdate", nil) 
end

-- =====================================================================
-- 5. FORWARD DECLARATIONS & LEDGER UI
-- =====================================================================
local Ledger, BoardContainer, BazaarContainer, ApexContainer, BazaarScroll, BazaarScrollChild, BazaarScrollBar, ApexScroll, ApexScrollChild, ApexScrollBar, tabBazaarBtn, tabBoardBtn, tabApexBtn, tabChronicleBtn, refreshBtn, storeCardsList, apexCardsList, activeCards, poolButtons, txtFavor, txtSigils, txtApex, UpdateTutorialPage, WelcomeModal, currentStep

Ledger = CreateFrame("Frame", "PatronsLedger", UIParent, "UIPanelDialogTemplate")
Ledger:SetSize(750, 660)
Ledger:SetPoint("CENTER")
Ledger:SetMovable(true)
Ledger:EnableMouse(true)
Ledger:RegisterForDrag("LeftButton")
Ledger:SetScript("OnDragStart", Ledger.StartMoving)
Ledger:SetScript("OnDragStop", Ledger.StopMovingOrSizing)
Ledger:SetFrameStrata("FULLSCREEN_DIALOG")
Ledger:Hide()
Ledger.Title:SetText("The Patron's Ledger")
tinsert(UISpecialFrames, Ledger:GetName())

local titleText = _G["PatronsLedgerTitleText"]
if titleText then titleText:ClearAllPoints(); titleText:SetPoint("TOP", Ledger, "TOP", 0, -12) end

for _, child in ipairs({Ledger:GetChildren()}) do
    if child:IsObjectType("Button") then
        child:Hide()
        child:SetAlpha(0)
        child:EnableMouse(false)
        child:UnregisterAllEvents()
        child.Show = function() end 
    end
end

local customCloseBtn = CreateFrame("Button", nil, Ledger, "UIPanelCloseButton")
customCloseBtn:SetPoint("TOPRIGHT", Ledger, "TOPRIGHT", 3, 0)
customCloseBtn:SetScript("OnClick", function() Ledger:Hide() end)

local HelpBtn = CreateFrame("Button", nil, Ledger, "UIPanelButtonTemplate")
HelpBtn:SetSize(20, 18)
HelpBtn:SetPoint("RIGHT", customCloseBtn, "LEFT", -10, 1)
HelpBtn:SetText("?")
HelpBtn:SetScript("OnClick", function() currentStep = 1; UpdateTutorialPage(); WelcomeModal:Show() end)

txtFavor = Ledger:CreateFontString(nil, "OVERLAY", "GameFontNormal")
txtFavor:SetPoint("BOTTOMLEFT", 20, 15)

txtSigils = Ledger:CreateFontString(nil, "OVERLAY", "GameFontNormal")
txtSigils:SetPoint("BOTTOMLEFT", 140, 15)

txtApex = Ledger:CreateFontString(nil, "OVERLAY", "GameFontNormal")
txtApex:SetPoint("BOTTOMLEFT", 260, 15)

tabChronicleBtn = CreateFrame("Button", nil, Ledger, "UIPanelButtonTemplate")
tabChronicleBtn:SetSize(110, 24)
tabChronicleBtn:SetPoint("TOPRIGHT", -40, -35)
tabChronicleBtn:SetText("Chronicle")

tabApexBtn = CreateFrame("Button", nil, Ledger, "UIPanelButtonTemplate")
tabApexBtn:SetSize(115, 24)
tabApexBtn:SetPoint("TOPRIGHT", -160, -35)
tabApexBtn:SetText("Apex Sanctum")

tabBazaarBtn = CreateFrame("Button", nil, Ledger, "UIPanelButtonTemplate")
tabBazaarBtn:SetSize(110, 24)
tabBazaarBtn:SetPoint("TOPRIGHT", -280, -35)
tabBazaarBtn:SetText("Bazaar")

tabBoardBtn = CreateFrame("Button", nil, Ledger, "UIPanelButtonTemplate")
tabBoardBtn:SetSize(110, 24)
tabBoardBtn:SetPoint("TOPRIGHT", -400, -35)
tabBoardBtn:SetText("Bounty Board")

local currentView = "board"
BoardContainer = CreateFrame("Frame", nil, Ledger)
BoardContainer:SetAllPoints(Ledger)

-- === CHRONICLE VIEW CONTAINER ===
local ChronicleContainer = CreateFrame("Frame", nil, Ledger)
ChronicleContainer:SetAllPoints(Ledger)
ChronicleContainer:Hide()

local chronicleHeader = ChronicleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
chronicleHeader:SetPoint("TOPLEFT", 20, -75)
chronicleHeader:SetText("The Chronicle of the Void:")

local ChroniclePageText = ChronicleContainer:CreateFontString(nil, "OVERLAY", "GameFontWhite")
ChroniclePageText:SetPoint("TOPLEFT", 40, -110)
ChroniclePageText:SetSize(670, 480)
ChroniclePageText:SetJustifyH("LEFT")
ChroniclePageText:SetJustifyV("TOP")
ChroniclePageText:SetFont("Fonts\\MORPHEUS.ttf", 16) 

local function GetPlayerArchetype()
    if not DarkPatronDB.ContractTypesCompleted then return "Drifter", "surviving by any means necessary" end
    local highestTrigger = ""; local highestCount = 0
    for trigger, count in pairs(DarkPatronDB.ContractTypesCompleted) do
        if count > highestCount then highestCount = count highestTrigger = trigger end
    end
    if highestTrigger == "PARTY_KILL" or highestTrigger == "SPECIFIC_KILL" then return "Executioner", "leaving a trail of bodies in their wake"
    elseif highestTrigger == "FETCH_ITEM" or highestTrigger == "MONEY_LOOT" then return "Scavenger", "hoarding the realm's wealth for the Patron"
    elseif highestTrigger == "DUNGEON_CLEAR" then return "Delver", "plunging into the deepest, darkest depths of Azeroth"
    elseif highestTrigger == "MAKGORA_WIN" or highestTrigger == "DUEL_WIN" then return "Gladiator", "dominating their peers in brutal combat"
    else return "Mercenary", "taking whatever bloody work the board provided" end
end

local function GenerateChroniclePages()
    local pages = {}
    local pName = UnitName("player") or "The Wanderer"
    local pClass = UnitClass("player") or "mortal"
    local pLvl = UnitLevel("player") or 1
	local completedCount = DarkPatronDB.TotalPactsCompleted or 0
    local peakStreak = DarkPatronDB.PeakStreak or 0
    
    if not DarkPatronDB or (DarkPatronDB.TotalPactsAccepted or 0) == 0 then
        if DarkPatronDB.IsDead and DarkPatronDB.DeathEpitaph then
            return { DarkPatronDB.DeathEpitaph }
        else
            return {"The parchment is cold and blank. Your story has yet to be written in blood.\n\nFulfill your first pact to begin."}
        end
    end

    local archetype, archeDesc = GetPlayerArchetype()
    
    -- Randomized, grounded opening hooks reflecting life and conflict in Azeroth/Outland
    local introHooks = {
        string.format("The Ledger bears the mark of %s, a %s who walked the dark path as a %s, %s.", pName, string.lower(pClass), archetype, archeDesc),
        string.format("In the shadow of the faction war and the ruins of a broken world, the Dark Patron's eye fell upon %s. As a %s operating under the %s discipline, they carved their path by %s.", pName, string.lower(pClass), archetype, archeDesc),
        string.format("The ink of the Veil records the chronicle of %s. A %s shaped by the %s creed, they survived the board across the contested lands by %s.", pName, string.lower(pClass), archetype, archeDesc)
    }
    
    local hookIdx = (GetDeterministicHash(pName, pLvl, "ChronicleIntro") % #introHooks) + 1
    local p1 = introHooks[hookIdx] .. "\n\n"
    
    p1 = p1 .. string.format("To date, they have bound their soul to %d fulfilled pacts, weathering trials that broke lesser mercenaries across Azeroth and Outland.\n\n", completedCount)

    if DarkPatronDB.FirstEliteKilled then 
        p1 = p1 .. string.format("Travelers still whisper of the day they tracked down and executed %s. That first major kill proved they were a true predator, not mere prey.\n\n", DarkPatronDB.FirstEliteKilled) 
    else 
        p1 = p1 .. "Though they have navigated the board's standard contracts, the head of a true regional Elite has yet to grace their ledger. The Patron watches, waiting for them to draw blood.\n\n" 
    end
    table.insert(pages, p1)

    -- Page 2: Momentum, Industry, and Risks
    local p2 = ""
    if peakStreak >= 5 then
        p2 = p2 .. string.format("At the height of their dark momentum, they forged an unbroken chain of %d rapid executions, turning the battlefield into a ruthless harvest.\n\n", peakStreak)
    end

    local fails = DarkPatronDB.FailedPactsCount or 0
    if fails == 0 and DarkPatronDB.TotalPactsAccepted > 5 then 
        p2 = p2 .. "Their discipline was absolute; not a single broken promise or abandoned pact stained their record. The Veil honors such cold perfection.\n\n"
    elseif fails > 0 and fails < 5 then 
        p2 = p2 .. string.format("Ambition has its costs on the road. They turned away from the Patron's demands %d times, paying the heavy blood tax of Favor to survive their own miscalculations.\n\n", fails)
    elseif fails >= 5 then 
        p2 = p2 .. string.format("Their overreach constantly threatened to undo them. With %d fractured pacts, they bled Favor endlessly just to keep the Patron's wrath at bay.\n\n", fails) 
    end
	
    local conqueredInstances = {}
    if DarkPatronDB.CompletedElites then
        for _, eliteId in ipairs(DarkPatronDB.CompletedElites) do
            if type(eliteId) == "string" then
                if eliteId:find("^DUNGEON_") then
                    local instanceID = tonumber(eliteId:match("^DUNGEON_(%d+)"))
                    for _, d in ipairs(DungeonDB) do
                        if d.instanceID == instanceID then table.insert(conqueredInstances, d.name) break end
                    end
                elseif eliteId:find("^RAID_") then
                    local instanceID = tonumber(eliteId:match("^RAID_(%d+)"))
                    for _, r in ipairs(RaidDB) do
                        if r.instanceID == instanceID then table.insert(conqueredInstances, r.name) break end
                    end
                end
            end
        end
    end

    if #conqueredInstances > 0 then
        local dungeonText = "The depths of the world hold no terror for them. They have systematically purged the most dangerous strongholds in the realm, leaving only silence in the halls of "
        if #conqueredInstances == 1 then
            dungeonText = dungeonText .. conqueredInstances[1] .. ".\n\n"
        elseif #conqueredInstances == 2 then
            dungeonText = dungeonText .. conqueredInstances[1] .. " and " .. conqueredInstances[2] .. ".\n\n"
        else
            for i = 1, #conqueredInstances do
                if i == #conqueredInstances then
                    dungeonText = dungeonText .. "and " .. conqueredInstances[i] .. ".\n\n"
                else
                    dungeonText = dungeonText .. conqueredInstances[i] .. ", "
                end
            end
        end
        p2 = p2 .. dungeonText
    end

    -- Industrial / Gathering check
    local gatheringCount = (DarkPatronDB.ContractTypesCompleted and DarkPatronDB.ContractTypesCompleted["GATHER_NODE"] or 0)
    local craftCount = (DarkPatronDB.ContractTypesCompleted and DarkPatronDB.ContractTypesCompleted["CRAFT_ITEM"] or 0)
    if gatheringCount > 3 or craftCount > 3 then
        p2 = p2 .. "Unlike those who rely entirely on raw violence, they rooted their survival in the material economy—striking mineral veins, harvesting wild herbs, and forging goods to feed the Ledger's demands.\n\n"
    end

    if DarkPatronDB.MaxGearQuality >= 3 then 
        p2 = p2 .. "Refusing to perish in common rags, they secured the rights to rare armaments from the Bazaar, turning material wealth into lethal protection.\n\n" 
    end
    if p2 ~= "" then table.insert(pages, p2) end

    -- Page 3: Endgame and the Ascent
    local p3 = ""
    if DarkPatronDB.ApexSigils > 0 or DarkPatronDB.HasCapstone then
        p3 = p3 .. "Having pushed past mortal boundaries, they wrenched forbidden Apex Sigils from the toughest raids of the realm. "
        if DarkPatronDB.HasCapstone then 
            p3 = p3 .. "With this power, they shattered their class limits, unlocking ultimate talents designed to overwhelm any challenger.\n\n" 
        else 
            p3 = p3 .. "They hoard this rare currency tightly, biding their time for absolute mastery.\n\n" 
        end
    end
    
    if DarkPatronDB.HasMasterCavalry then 
        p3 = p3 .. "Now, they ride like a storm across the continents atop an Epic mount, a terrifying blur of shadow and steel.\n\n" 
    elseif DarkPatronDB.HasJourneymanCavalry then 
        p3 = p3 .. "Backed by the Patron's sanction, they traded Favor for the loyalty of a swift mount, crossing contested territory where others walked on foot.\n\n" 
    end

    local maxLvl = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC) and 70 or 60
    if pLvl >= maxLvl and not DarkPatronDB.HasMasterCavalry then 
        p3 = p3 .. "Standing at the absolute precipice of max-level power, they survey a scarred world. Though the summit is reached, true transcendence still requires the final Sanctum sanctions.\n\n" 
    end

    if p3 ~= "" then table.insert(pages, p3) end

    if DarkPatronDB.IsDead and DarkPatronDB.DeathEpitaph then 
        table.insert(pages, DarkPatronDB.DeathEpitaph) 
    end
    
    return #pages > 0 and pages or {"The parchment is cold and blank."}
end

local currentChroniclePage = 1
local chroniclePages = {}

local btnPrevPage = CreateFrame("Button", nil, ChronicleContainer)
btnPrevPage:SetSize(32, 32); btnPrevPage:SetPoint("BOTTOMLEFT", 40, 20); btnPrevPage:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"); btnPrevPage:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down"); btnPrevPage:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD"); btnPrevPage:Hide()

local btnNextPage = CreateFrame("Button", nil, ChronicleContainer)
btnNextPage:SetSize(32, 32); btnNextPage:SetPoint("BOTTOMRIGHT", -40, 20); btnNextPage:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"); btnNextPage:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down"); btnNextPage:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD"); btnNextPage:Hide()

local function UpdateChronicleView()
    ChroniclePageText:SetText(chroniclePages[currentChroniclePage])
    if currentChroniclePage == #chroniclePages and DarkPatronDB.IsDead then ChroniclePageText:SetTextColor(0.8, 0.1, 0.1) else ChroniclePageText:SetTextColor(1, 1, 1) end
    if currentChroniclePage > 1 then btnPrevPage:Show() else btnPrevPage:Hide() end
    if currentChroniclePage < #chroniclePages then btnNextPage:Show() else btnNextPage:Hide() end
end

btnPrevPage:SetScript("OnClick", function() if currentChroniclePage > 1 then currentChroniclePage = currentChroniclePage - 1; PlaySound(834); UpdateChronicleView() end end)
btnNextPage:SetScript("OnClick", function() if currentChroniclePage < #chroniclePages then currentChroniclePage = currentChroniclePage + 1; PlaySound(834); UpdateChronicleView() end end)

-- =====================================================================
-- CUSTOM UI PARTICLE ENGINE
-- =====================================================================
local ParticleEngine = CreateFrame("Frame") -- Invisible engine to run the OnUpdate
local activeParticles, availableParticles, glowingCards = {}, {}, {}

-- Instead of raw textures on a top-level frame, we create individual Frames
for i = 1, 60 do 
    local p = CreateFrame("Frame", nil, UIParent)
    local tex = p:CreateTexture(nil, "ARTWORK") -- Draw below text (OVERLAY) but above backgrounds
    tex:SetAllPoints()
    tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    tex:SetBlendMode("ADD")
    
    p.tex = tex
    p:Hide()
    p.isActive = false; p.velX = 0; p.velY = 0; p.life = 0
    table.insert(availableParticles, p)
end

local function SpawnCardParticle(card, rarity)
    local p = table.remove(availableParticles)
    if not p then return end
    
    p:SetParent(card)
    p:SetFrameLevel(card:GetFrameLevel())
    card:SetClipsChildren(true) 
    
    local size = math.random(10, 18); p:SetSize(size, size); local width = card:GetWidth()
    p.posX = math.random(-(width / 2.5), (width / 2.5)); p.posY = (size / 2) + 4; p.baseAlpha = 0.8
    
    -- KILLED THE TORNADO: Almost zero horizontal shooting speed
    p.velX = (math.random() - 0.5) * 4 
    -- Slower, steadier upward drift like an ember
    p.velY = math.random(15, 25) 
    
    -- Give each ember a unique, gentle sway
    p.wiggleOffset = math.random() * 100
    p.wiggleSpeed = math.random(2, 4)
    
    if rarity == "Rare" then p.tex:SetVertexColor(0.2, 0.8, 1.0) 
    elseif rarity == "Elite" then p.tex:SetVertexColor(0.6, 0.2, 1.0) 
    else p.tex:SetVertexColor(1.0, 0.6, 0.0) end 
    
    p.life = math.random(1000, 2000) / 1000; p.parentCard = card; p.isActive = true; p:SetAlpha(p.baseAlpha)
    p:ClearAllPoints(); p:SetPoint("CENTER", card, "BOTTOM", p.posX, p.posY); p:Show()
    
    table.insert(activeParticles, p)
end

local particleTimer = 0
ParticleEngine:SetScript("OnUpdate", function(self, elapsed)
    if #glowingCards == 0 and #activeParticles == 0 then
        return
    end
    
    local now = GetTime()
    particleTimer = particleTimer + elapsed
    
    -- Steady, decoupled spawn rate
    if #glowingCards > 0 and particleTimer >= 0.08 then
        particleTimer = 0
        local targetCard = glowingCards[math.random(#glowingCards)]
        if targetCard:IsShown() and targetCard.missionRarity then 
            SpawnCardParticle(targetCard, targetCard.missionRarity) 
        end
    end

    for i = #activeParticles, 1, -1 do
        local p = activeParticles[i]
        
        p.posX = p.posX + (p.velX * elapsed)
        p.posY = p.posY + (p.velY * elapsed)
        p.life = p.life - elapsed
        
        if p.life <= 0 or not p.parentCard:IsShown() then
            p.isActive = false; p:Hide(); 
            p:SetParent(UIParent); p:ClearAllPoints(); 
            table.remove(activeParticles, i); table.insert(availableParticles, p)
        else
            -- Apply a smooth, gentle horizontal sway simulating rising heat
            local sway = math.sin(now * p.wiggleSpeed + p.wiggleOffset) * 10 * elapsed
            p.posX = p.posX + sway
            
            local curA = math.min(p.life, 1.0) * p.baseAlpha
            p:SetAlpha(curA)
            p:SetPoint("CENTER", p.parentCard, "BOTTOM", p.posX, p.posY)
        end
    end
end)

-- =====================================================================
-- CARD THEME & VISUAL ENGINE
-- =====================================================================
local function ApplyCardTheme(card, mission)
    for i = #glowingCards, 1, -1 do if glowingCards[i] == card then table.remove(glowingCards, i) end end
    card.missionRarity = nil
    
    if not mission then
        card.rarityText:SetText(""); card.title:SetTextColor(1, 1, 1); card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1); card:SetBackdropColor(0.05, 0.05, 0.1, 0.85); if card.bgImage then card.bgImage:Hide() end; return
    end
    
    -- Strips the bracketed text completely
    card.rarityText:SetText("")
    
    if mission.rarity == "Rare Elite" or mission.rarity == "Boss" then
        card.title:SetTextColor(1, 0.5, 0); card:SetBackdropBorderColor(1, 0.5, 0, 1); card.missionRarity = mission.rarity; table.insert(glowingCards, card)
    elseif mission.rarity == "Elite" then
        card.title:SetTextColor(0.64, 0.21, 0.93); card:SetBackdropBorderColor(0.64, 0.21, 0.93, 1); card.missionRarity = mission.rarity; table.insert(glowingCards, card)
    elseif mission.rarity == "Rare" then
        card.title:SetTextColor(0, 0.44, 0.87); card:SetBackdropBorderColor(0, 0.44, 0.87, 1); card.missionRarity = mission.rarity; table.insert(glowingCards, card)
    elseif mission.rarity == "Standard" then
        card.title:SetTextColor(1, 0.82, 0); card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    if not card.bgImage then card.bgImage = card:CreateTexture(nil, "BORDER"); card.bgImage:SetPoint("TOPLEFT", 4, -4); card.bgImage:SetPoint("BOTTOMRIGHT", -4, 4) end
    
    -- FIX: Frame cropping logic based on card size
    if card:GetWidth() > 300 then 
        card.bgImage:SetTexCoord(0, 1, 0.35, 0.55) 
    else 
        -- Strictly left-side crop to avoid the center logo
        card.bgImage:SetTexCoord(0, 0.45, 0.15, 0.65) 
    end
    
    local loadScreenSuffix = nil
    if (mission.trigger == "DUNGEON_BOSS_KILL" or mission.rarity == "Boss") and mission.zone and ZoneLoadingScreens[mission.zone] then loadScreenSuffix = ZoneLoadingScreens[mission.zone] end

    if loadScreenSuffix then 
        card.bgImage:SetTexture("Interface\\Glues\\LoadingScreens\\" .. loadScreenSuffix .. ".blp"); 
        
        if card:GetWidth() > 300 then
            card.bgImage:SetVertexColor(0.65, 0.65, 0.65, 1)
        else
            card.bgImage:SetVertexColor(0.20, 0.20, 0.20, 1)
        end
        
        card.bgImage:Show(); 
        card:SetBackdropColor(0, 0, 0, 0.85) 
    else 
        card.bgImage:Hide(); 
        card:SetBackdropColor(0.05, 0.05, 0.1, 0.85) 
    end
end

local BoardWarning = BoardContainer:CreateFontString(nil, "OVERLAY", "GameFontRed")
BoardWarning:SetPoint("TOP", BoardContainer, "TOP", 0, -60)
BoardWarning:SetText("You must be in a rested area to Modify Pacts or Reshuffle.")
BoardWarning:Hide()

activeCards = {}
local activeHeader = BoardContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
activeHeader:SetPoint("TOPLEFT", 20, -105)
activeHeader:SetText("Active Pacts (Drag to Reorder):")

for i = 1, 4 do
    local card = CreateFrame("Frame", nil, BoardContainer, "BackdropTemplate")
    card:SetSize(170, 110)
    card:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
    card:EnableMouse(true); card:RegisterForDrag("LeftButton")
	
    card:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() and DarkPatronDB.ActiveMissions[i] then
            DP_InsertPactToChat(DarkPatronDB.ActiveMissions[i])
        end
    end)
    card:SetScript("OnDragStart", function(self)
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if canEdit and DarkPatronDB.ActiveMissions[i] then 
            StartDragging("active", i, self) 
            self:SetAlpha(0) -- Hide the original card
        end
    end)
    card:SetScript("OnDragStop", function(self)
        StopDragging(); 
        self:SetAlpha(1) -- Snap it back into existence if dropped
        local maxSlots = DarkPatronDB.MaxActiveSlots or 3
        for j = 1, maxSlots do
            if activeCards[j]:IsMouseOver() and j ~= i and DarkPatronDB.ActiveMissions[i] then
                local movingData = table.remove(DarkPatronDB.ActiveMissions, i)
                local targetIdx = math.min(j, #DarkPatronDB.ActiveMissions + 1)
                table.insert(DarkPatronDB.ActiveMissions, targetIdx, movingData)
                Ledger:GetScript("OnShow")(Ledger); UpdateTracker(); break
            end
        end
    end)
    
    card.rarityText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny"); card.rarityText:SetPoint("TOP", card, "TOP", 0, -4)
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); card.title:SetPoint("TOP", card.rarityText, "BOTTOM", 0, 0); card.title:SetWidth(155); card.title:SetWordWrap(true)
    card.desc = card:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny"); card.desc:SetSize(155, 40); card.desc:SetPoint("TOP", card.title, "BOTTOM", 0, -2); card.desc:SetJustifyH("CENTER"); card.desc:SetJustifyV("TOP")
    card.reward = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); card.reward:SetPoint("BOTTOM", card, "BOTTOM", 0, 28); card.reward:SetTextColor(1, 0.82, 0)
    
    card.btn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate"); card.btn:SetSize(120, 20); card.btn:SetPoint("BOTTOM", card, "BOTTOM", 0, 5)
    card.btn:SetScript("OnClick", function()
        if IsShiftKeyDown() and DarkPatronDB.ActiveMissions[i] then
            DP_InsertPactToChat(DarkPatronDB.ActiveMissions[i])
            return
        end
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if not canEdit then print("Dark Patron: You must be resting (Inn/Capital City) to modify pacts.") return end

        local taxCost = activeCards[i].btn.taxOverride or 2
        if DarkPatronDB.DarkFavor < taxCost then print(string.format("Dark Patron: Abandoning a pact requires %d Dark Favor.", taxCost)) return end
        
        DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - taxCost
        if taxCost > 0 then
            DarkPatronDB.CurrentStreak = 0 
            DarkPatronDB.FailedPactsCount = (DarkPatronDB.FailedPactsCount or 0) + 1
            PatronWhisper("Cowardice has a price. Your momentum is shattered.")
            print(string.format("Dark Patron: Paid %d Dark Favor to abandon active pact.", taxCost))
        else print("Dark Patron: PvP Pact abandoned freely.") end

        if DarkPatronDB.ActiveMissions[i] then
            RecordCompletedPact(DarkPatronDB.ActiveMissions[i])
            table.remove(DarkPatronDB.ActiveMissions, i)
            RefillMissionPool()
            Ledger:GetScript("OnShow")(Ledger)
            UpdateTracker()
        end
    end)
    activeCards[i] = card
end

local poolHeader = BoardContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
poolHeader:SetPoint("TOPLEFT", 20, -255)
poolHeader:SetText("Bounty Board (Drag Tile to Active Pacts to Accept):")

poolButtons = {}
for i = 1, 6 do
    local row = math.floor((i - 1) / 3); local col = (i - 1) % 3
    local btnCard = CreateFrame("Frame", nil, BoardContainer, "BackdropTemplate")
    btnCard:SetSize(230, 105); btnCard:SetPoint("TOPLEFT", 20 + (col * 240), -280 - (row * 115))
    btnCard:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
    btnCard:EnableMouse(true); btnCard:RegisterForDrag("LeftButton")
    
	btnCard:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() and DarkPatronDB.PoolOfSix[i] then
            DP_InsertPactToChat(DarkPatronDB.PoolOfSix[i])
        end
    end)
    btnCard:SetScript("OnDragStart", function(self)
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if canEdit and DarkPatronDB.PoolOfSix[i] then 
            StartDragging("board", i, self) 
            self:SetAlpha(0) -- Hide the original card
        end
    end)
    btnCard:SetScript("OnDragStop", function(self)
        StopDragging(); 
        self:SetAlpha(1) -- Snap it back into existence if dropped
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if not canEdit then print("Dark Patron: You must be in a rested area to modify pacts.") return end

        local droppedOnActive = false; local maxSlots = DarkPatronDB.MaxActiveSlots or 3
        for j = 1, maxSlots do if activeCards[j]:IsMouseOver() then droppedOnActive = true break end end
        if droppedOnActive then
            if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
            local chosen = DarkPatronDB.PoolOfSix[i]; DarkPatronDB.PoolOfSix[i] = nil
            if chosen.isTimed then chosen.expiresAt = time() + chosen.timeLimit end 
            table.insert(DarkPatronDB.ActiveMissions, chosen)
            
            DarkPatronDB.TotalPactsAccepted = (DarkPatronDB.TotalPactsAccepted or 0) + 1
            if not DarkPatronDB.HasInitializedAwakening and DarkPatronDB.TotalPactsAccepted >= maxSlots then
                DarkPatronDB.HasInitializedAwakening = true
                print("|cffff0000[Dark Patron]: You must now be resting (Inn/Capital City) to access the board.|r")
            end
            Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
        end
    end)
    
    btnCard.rarityText = btnCard:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny"); btnCard.rarityText:SetPoint("TOP", btnCard, "TOP", 0, -4)
    btnCard.title = btnCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); btnCard.title:SetPoint("TOP", btnCard.rarityText, "BOTTOM", 0, 0); btnCard.title:SetWidth(210); btnCard.title:SetWordWrap(true)
    btnCard.desc = btnCard:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny"); btnCard.desc:SetSize(210, 35); btnCard.desc:SetPoint("TOP", btnCard.title, "BOTTOM", 0, -2); btnCard.desc:SetJustifyH("CENTER"); btnCard.desc:SetJustifyV("TOP")
    btnCard.reward = btnCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); btnCard.reward:SetPoint("BOTTOM", btnCard, "BOTTOM", 0, 27); btnCard.reward:SetTextColor(1, 0.82, 0)
    
    btnCard.acceptBtn = CreateFrame("Button", nil, btnCard, "UIPanelButtonTemplate"); btnCard.acceptBtn:SetSize(90, 18); btnCard.acceptBtn:SetPoint("BOTTOM", btnCard, "BOTTOM", 0, 6); btnCard.acceptBtn:SetText("Accept Pact")
    btnCard.acceptBtn:SetScript("OnClick", function()
        if IsShiftKeyDown() and DarkPatronDB.PoolOfSix[i] then
            DP_InsertPactToChat(DarkPatronDB.PoolOfSix[i])
            return
        end
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if not canEdit then print("Dark Patron: You must be in a rested area to modify pacts.") return end

        if DarkPatronDB.PoolOfSix[i] then
            local maxSlots = DarkPatronDB.MaxActiveSlots or 3
            if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
            local chosen = DarkPatronDB.PoolOfSix[i]; DarkPatronDB.PoolOfSix[i] = nil
            if chosen.isTimed then chosen.expiresAt = time() + chosen.timeLimit end 
            table.insert(DarkPatronDB.ActiveMissions, chosen)
            
            DarkPatronDB.TotalPactsAccepted = (DarkPatronDB.TotalPactsAccepted or 0) + 1
            if not DarkPatronDB.HasInitializedAwakening and DarkPatronDB.TotalPactsAccepted >= maxSlots then
                DarkPatronDB.HasInitializedAwakening = true
                print("|cffff0000[Dark Patron]: The Veil descends. You must now rest in a rested area to commune with the board.|r")
            end
            Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
        end
    end)
    poolButtons[i] = btnCard
end

-- === DEDICATED DUNGEON CARD UI ===
Ledger.CurrentDungeonIndex = 1

local DungeonCard = CreateFrame("Frame", nil, BoardContainer, "BackdropTemplate")
DungeonCard:SetSize(710, 75); DungeonCard:SetPoint("BOTTOM", BoardContainer, "BOTTOM", 0, 80)
DungeonCard:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
DungeonCard:EnableMouse(true); DungeonCard:RegisterForDrag("LeftButton")

DungeonCard.StackBg1 = CreateFrame("Frame", nil, BoardContainer, "BackdropTemplate")
DungeonCard.StackBg1:SetSize(700, 75); DungeonCard.StackBg1:SetPoint("BOTTOM", DungeonCard, "BOTTOM", 0, -6); DungeonCard.StackBg1:SetFrameLevel(DungeonCard:GetFrameLevel() - 1)
DungeonCard.StackBg1:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }}); DungeonCard.StackBg1:SetBackdropColor(0.05, 0.05, 0.1, 0.95)

DungeonCard.StackBg2 = CreateFrame("Frame", nil, BoardContainer, "BackdropTemplate")
DungeonCard.StackBg2:SetSize(690, 75); DungeonCard.StackBg2:SetPoint("BOTTOM", DungeonCard.StackBg1, "BOTTOM", 0, -6); DungeonCard.StackBg2:SetFrameLevel(DungeonCard.StackBg1:GetFrameLevel() - 1)
DungeonCard.StackBg2:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }}); DungeonCard.StackBg2:SetBackdropColor(0.05, 0.05, 0.1, 0.95)

DungeonCard.rarityText = DungeonCard:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny"); DungeonCard.rarityText:SetPoint("TOP", DungeonCard, "TOP", 0, -6)
DungeonCard.title = DungeonCard:CreateFontString(nil, "OVERLAY", "GameFontNormal"); DungeonCard.title:SetPoint("TOP", DungeonCard.rarityText, "BOTTOM", 0, -1); DungeonCard.title:SetWidth(450)
DungeonCard.desc = DungeonCard:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny"); DungeonCard.desc:SetPoint("TOP", DungeonCard.title, "BOTTOM", 0, -2); DungeonCard.desc:SetWidth(450)
DungeonCard.reward = DungeonCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); DungeonCard.reward:SetPoint("BOTTOM", DungeonCard, "BOTTOM", 0, 6); DungeonCard.reward:SetTextColor(1, 0.82, 0)
DungeonCard.levelReq = DungeonCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
DungeonCard.levelReq:SetPoint("LEFT", DungeonCard, "LEFT", 20, 0)
DungeonCard.levelReq:SetTextColor(0.8, 0.8, 0.8) -- Soft silver color
DungeonCard.acceptBtn = CreateFrame("Button", nil, DungeonCard, "UIPanelButtonTemplate"); DungeonCard.acceptBtn:SetSize(110, 20); DungeonCard.acceptBtn:SetPoint("RIGHT", DungeonCard, "RIGHT", -15, 0); DungeonCard.acceptBtn:SetText("Accept Pact")

DungeonCard.NextBtn = CreateFrame("Button", nil, DungeonCard); DungeonCard.NextBtn:SetSize(24, 24); DungeonCard.NextBtn:SetPoint("RIGHT", DungeonCard.acceptBtn, "LEFT", -15, 0)
DungeonCard.NextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"); DungeonCard.NextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down"); DungeonCard.NextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
DungeonCard.NextBtn:SetScript("OnClick", function() if not DarkPatronDB.DungeonBounties then return end Ledger.CurrentDungeonIndex = Ledger.CurrentDungeonIndex + 1 if Ledger.CurrentDungeonIndex > #DarkPatronDB.DungeonBounties then Ledger.CurrentDungeonIndex = 1 end Ledger:GetScript("OnShow")(Ledger) end)

DungeonCard.PrevBtn = CreateFrame("Button", nil, DungeonCard); DungeonCard.PrevBtn:SetSize(24, 24); DungeonCard.PrevBtn:SetPoint("RIGHT", DungeonCard.NextBtn, "LEFT", -5, 0)
DungeonCard.PrevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"); DungeonCard.PrevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down"); DungeonCard.PrevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
DungeonCard.PrevBtn:SetScript("OnClick", function() if not DarkPatronDB.DungeonBounties then return end Ledger.CurrentDungeonIndex = Ledger.CurrentDungeonIndex - 1 if Ledger.CurrentDungeonIndex < 1 then Ledger.CurrentDungeonIndex = #DarkPatronDB.DungeonBounties end Ledger:GetScript("OnShow")(Ledger) end)

DungeonCard.StackCounter = DungeonCard:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny"); DungeonCard.StackCounter:ClearAllPoints(); DungeonCard.StackCounter:SetPoint("TOP", DungeonCard.NextBtn, "BOTTOM", -15, -2); DungeonCard.StackCounter:SetTextColor(0.8, 0.8, 0.8)

DungeonCard:SetScript("OnDragStart", function(self)
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    local currentContract = DarkPatronDB.DungeonBounties and DarkPatronDB.DungeonBounties[Ledger.CurrentDungeonIndex]
    if canEdit and currentContract then 
        StartDragging("dungeon", 7, self) 
        self:SetAlpha(0) -- Hide the original card (Reveals the next card in the stack behind it!)
    end
end)
DungeonCard:SetScript("OnDragStop", function(self)
    StopDragging(); 
    self:SetAlpha(1) -- Snap it back into existence if dropped
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if not canEdit then print("Dark Patron: You must be in a rested area to modify pacts.") return end

    local droppedOnActive = false; local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    for j = 1, maxSlots do if activeCards[j]:IsMouseOver() then droppedOnActive = true break end end
    if droppedOnActive then
        if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
        local chosen = table.remove(DarkPatronDB.DungeonBounties, Ledger.CurrentDungeonIndex)
        table.insert(DarkPatronDB.ActiveMissions, chosen)
        
        if #DarkPatronDB.DungeonBounties == 0 then DarkPatronDB.DungeonBounties = nil Ledger.CurrentDungeonIndex = 1 elseif Ledger.CurrentDungeonIndex > #DarkPatronDB.DungeonBounties then Ledger.CurrentDungeonIndex = #DarkPatronDB.DungeonBounties end
        Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
    end
end)
DungeonCard.acceptBtn:SetScript("OnClick", function()
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if not canEdit then print("Dark Patron: You must be in a rested area to modify pacts.") return end
    local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
    local chosen = table.remove(DarkPatronDB.DungeonBounties, Ledger.CurrentDungeonIndex)
    table.insert(DarkPatronDB.ActiveMissions, chosen)
    if #DarkPatronDB.DungeonBounties == 0 then DarkPatronDB.DungeonBounties = nil Ledger.CurrentDungeonIndex = 1 elseif Ledger.CurrentDungeonIndex > #DarkPatronDB.DungeonBounties then Ledger.CurrentDungeonIndex = #DarkPatronDB.DungeonBounties end
    Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
end)
DungeonCard:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() and DarkPatronDB.DungeonBounties and DarkPatronDB.DungeonBounties[Ledger.CurrentDungeonIndex] then
        DP_InsertPactToChat(DarkPatronDB.DungeonBounties[Ledger.CurrentDungeonIndex])
    end
end)

refreshBtn = CreateFrame("Button", "DarkPatronRefreshBtn", BoardContainer, "UIPanelButtonTemplate"); refreshBtn:SetSize(160, 25); refreshBtn:SetPoint("BOTTOM", BoardContainer, "BOTTOM", 0, 45); refreshBtn:SetText("Reshuffle Board")
local autoRefreshTimerText = BoardContainer:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny"); autoRefreshTimerText:SetPoint("BOTTOM", refreshBtn, "TOP", 0, -37); autoRefreshTimerText:SetTextColor(0.6, 0.6, 0.6)

refreshBtn:SetScript("OnClick", function()
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if not canEdit then print("Dark Patron: You must be resting (Inn/Capital City) to reshuffle the board.") return end
    local cost = DarkPatronDB.HasTravelerStep and 0 or 1
    if cost == 0 then
        DarkPatronDB.PoolOfSix = {}; DarkPatronDB.LastBoardRefresh = time(); RefillMissionPool(); Ledger:GetScript("OnShow")(Ledger); print("DARK PATRON: Board reshuffled freely (Pathfinder's Intuition).")
    elseif DarkPatronDB.DarkFavor >= cost then
        DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - cost; DarkPatronDB.PoolOfSix = {}; DarkPatronDB.LastBoardRefresh = time(); RefillMissionPool(); Ledger:GetScript("OnShow")(Ledger)
    else print("Dark Patron: Insufficient Dark Favor.") end
end)

-- === TARGETED HUNTS (ELITE) DRAWER ===
Ledger.CurrentEliteIndex = 1

-- Parent to Ledger directly so FrameLevel math works seamlessly
local EliteCardContainer = CreateFrame("Frame", nil, Ledger, "BackdropTemplate")
-- Increased width slightly to compensate for the portion tucked behind the main window
EliteCardContainer:SetSize(230, 240)
-- Tuck it underneath the right edge of the main Ledger frame (Notice the -18 X-offset)
EliteCardContainer:SetPoint("TOPLEFT", Ledger, "TOPRIGHT", -18, -100) 
-- Drop it one layer behind the main window so the left border is cleanly hidden
EliteCardContainer:SetFrameLevel(Ledger:GetFrameLevel() - 1)

EliteCardContainer:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
-- Slightly darker background to sell the shadow/depth of a lower layer
EliteCardContainer:SetBackdropColor(0.02, 0.02, 0.04, 0.98)

local ecHeader = EliteCardContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
-- Shifted slightly right (8) to center it in the visually exposed portion of the drawer
ecHeader:SetPoint("TOP", 8, -15)
ecHeader:SetText("Targeted Hunts")

local ECard = CreateFrame("Frame", nil, EliteCardContainer, "BackdropTemplate")
ECard:SetSize(170, 150)
-- Shifted slightly right to avoid the main window overlap
ECard:SetPoint("TOP", 8, -40)
ECard:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
ECard:EnableMouse(true)
ECard:RegisterForDrag("LeftButton")

ECard.rarityText = ECard:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
ECard.rarityText:SetPoint("TOP", ECard, "TOP", 0, -6)
ECard.title = ECard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ECard.title:SetPoint("TOP", ECard.rarityText, "BOTTOM", 0, -1)
ECard.title:SetWidth(155)
ECard.desc = ECard:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny")
ECard.desc:SetSize(155, 60)
ECard.desc:SetPoint("TOP", ECard.title, "BOTTOM", 0, -2)
ECard.desc:SetJustifyH("CENTER")
ECard.desc:SetJustifyV("TOP")
ECard.reward = ECard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ECard.reward:SetPoint("BOTTOM", ECard, "BOTTOM", 0, 30)
ECard.reward:SetTextColor(1, 0.82, 0)

ECard.acceptBtn = CreateFrame("Button", nil, ECard, "UIPanelButtonTemplate")
ECard.acceptBtn:SetSize(120, 20)
ECard.acceptBtn:SetPoint("BOTTOM", ECard, "BOTTOM", 0, 6)
ECard.acceptBtn:SetText("Accept Pact")

ECard.NextBtn = CreateFrame("Button", nil, EliteCardContainer)
ECard.NextBtn:SetSize(24, 24)
ECard.NextBtn:SetPoint("BOTTOMRIGHT", EliteCardContainer, "BOTTOMRIGHT", -25, 15)
ECard.NextBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
ECard.NextBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
ECard.NextBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
ECard.NextBtn:SetScript("OnClick", function() if not DarkPatronDB.EliteBounties then return end Ledger.CurrentEliteIndex = Ledger.CurrentEliteIndex + 1 if Ledger.CurrentEliteIndex > #DarkPatronDB.EliteBounties then Ledger.CurrentEliteIndex = 1 end Ledger:GetScript("OnShow")(Ledger) end)

ECard.PrevBtn = CreateFrame("Button", nil, EliteCardContainer)
ECard.PrevBtn:SetSize(24, 24)
-- Pushed right so it doesn't get eclipsed by the main frame overlap
ECard.PrevBtn:SetPoint("BOTTOMLEFT", EliteCardContainer, "BOTTOMLEFT", 40, 15)
ECard.PrevBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
ECard.PrevBtn:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
ECard.PrevBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
ECard.PrevBtn:SetScript("OnClick", function() if not DarkPatronDB.EliteBounties then return end Ledger.CurrentEliteIndex = Ledger.CurrentEliteIndex - 1 if Ledger.CurrentEliteIndex < 1 then Ledger.CurrentEliteIndex = #DarkPatronDB.EliteBounties end Ledger:GetScript("OnShow")(Ledger) end)

ECard.StackCounter = EliteCardContainer:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny")
-- Shifted right to maintain center balance
ECard.StackCounter:SetPoint("BOTTOM", 8, 20)
ECard.StackCounter:SetTextColor(0.8, 0.8, 0.8)

ECard:SetScript("OnDragStart", function(self)
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    local currentContract = DarkPatronDB.EliteBounties and DarkPatronDB.EliteBounties[Ledger.CurrentEliteIndex]
    if canEdit and currentContract then 
        StartDragging("elite", 8, self) 
        self:SetAlpha(0) -- Hide the original card
    end
end)

ECard:SetScript("OnDragStop", function(self)
    StopDragging(); 
    self:SetAlpha(1) -- Snap it back into existence if dropped
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if not canEdit then print("Dark Patron: You must be in a rested area to modify pacts.") return end

    local droppedOnActive = false; local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    for j = 1, maxSlots do if activeCards[j]:IsMouseOver() then droppedOnActive = true break end end
    if droppedOnActive then
        if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
        local chosen = table.remove(DarkPatronDB.EliteBounties, Ledger.CurrentEliteIndex)
        table.insert(DarkPatronDB.ActiveMissions, chosen)
        
        if #DarkPatronDB.EliteBounties == 0 then DarkPatronDB.EliteBounties = nil Ledger.CurrentEliteIndex = 1 elseif Ledger.CurrentEliteIndex > #DarkPatronDB.EliteBounties then Ledger.CurrentEliteIndex = #DarkPatronDB.EliteBounties end
        Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
    end
end)

ECard.acceptBtn:SetScript("OnClick", function()
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if not canEdit then print("Dark Patron: You must be in a rested area to modify pacts.") return end
    local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
    
    local chosen = table.remove(DarkPatronDB.EliteBounties, Ledger.CurrentEliteIndex)
    table.insert(DarkPatronDB.ActiveMissions, chosen)
    
    if #DarkPatronDB.EliteBounties == 0 then DarkPatronDB.EliteBounties = nil Ledger.CurrentEliteIndex = 1 elseif Ledger.CurrentEliteIndex > #DarkPatronDB.EliteBounties then Ledger.CurrentEliteIndex = #DarkPatronDB.EliteBounties end
    Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
end)
ECard:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() and DarkPatronDB.EliteBounties and DarkPatronDB.EliteBounties[Ledger.CurrentEliteIndex] then
        DP_InsertPactToChat(DarkPatronDB.EliteBounties[Ledger.CurrentEliteIndex])
    end
end)

-- === BAZAAR STORE VIEW CONTAINERS ===
BazaarContainer = CreateFrame("Frame", nil, Ledger); BazaarContainer:SetAllPoints(Ledger); BazaarContainer:Hide()
local bazaarHeader = BazaarContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3"); bazaarHeader:SetPoint("TOPLEFT", 20, -75); bazaarHeader:SetText("The Patron's Bazaar (Endgame Progression):")
local BazaarWarning = BazaarContainer:CreateFontString(nil, "OVERLAY", "GameFontWhite"); BazaarWarning:SetPoint("TOP", BazaarContainer, "TOP", 0, -60); BazaarWarning:SetText("Sanctions permanently bend the rules of the realm to your favor.")

BazaarScroll = CreateFrame("ScrollFrame", nil, BazaarContainer); BazaarScroll:SetPoint("TOPLEFT", 20, -100); BazaarScroll:SetPoint("BOTTOMRIGHT", -40, 45); BazaarScroll:EnableMouseWheel(true)
BazaarScrollChild = CreateFrame("Frame", nil, BazaarScroll); BazaarScrollChild:SetSize(670, 600); BazaarScroll:SetScrollChild(BazaarScrollChild)
BazaarScrollBar = CreateFrame("Slider", nil, BazaarScroll, "UIPanelScrollBarTemplate"); BazaarScrollBar:SetPoint("TOPRIGHT", BazaarContainer, "TOPRIGHT", -15, -100); BazaarScrollBar:SetPoint("BOTTOMRIGHT", BazaarContainer, "BOTTOMRIGHT", -15, 45); BazaarScrollBar:SetMinMaxValues(0, 0); BazaarScrollBar:SetValueStep(30); BazaarScrollBar:SetValue(0); BazaarScrollBar:SetWidth(16); BazaarScrollBar:Show()

-- === APEX SANCTUM CONTAINERS ===
ApexContainer = CreateFrame("Frame", nil, Ledger); ApexContainer:SetAllPoints(Ledger); ApexContainer:Hide()
local apexBg = ApexContainer:CreateTexture(nil, "BACKGROUND")
-- Anchor it perfectly inside the metallic borders of the standard UI window
apexBg:SetPoint("TOPLEFT", 12, -30)
apexBg:SetPoint("BOTTOMRIGHT", -12, 12)
-- Use the native WoW grainy UI background texture
apexBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
-- Tint the actual texture deep crimson so it keeps the shading and grain
apexBg:SetVertexColor(0.8, 0.1, 0.1, 0.85)

local isTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
local maxLvl = isTBC and 70 or 60

local apexHeader = ApexContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
apexHeader:SetPoint("TOPLEFT", 20, -70)
apexHeader:SetText(string.format("The Apex Sanctum (Level %d Endgame & Conversion):", maxLvl))
apexHeader:SetTextColor(1, 0.2, 0.2)

local ExchangeBox = CreateFrame("Frame", nil, ApexContainer, "BackdropTemplate")
ExchangeBox:SetSize(670, 80); ExchangeBox:SetPoint("TOPLEFT", 20, -95)
ExchangeBox:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
ExchangeBox:SetBackdropBorderColor(0.8, 0.1, 0.1, 1)

local exTitle = ExchangeBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
exTitle:SetPoint("TOPLEFT", 15, -8); exTitle:SetText("Forbidden Currency Exchange (Downgrade & Liquidation):"); exTitle:SetTextColor(1, 0.4, 0.4)

local function CreateExchangeButton(parent, text, xOffset, onClickFunc, canAffordFunc)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(210, 22); btn:SetPoint("TOPLEFT", xOffset, -32); btn:SetText(text)
    btn:SetScript("OnClick", function() if not (IsResting() or devMode) then print("|cffff0000[Dark Patron]: You must be resting (Inn/Capital City) to exchange currency.|r") return end onClickFunc() end)
    btn.canAffordFunc = canAffordFunc; return btn
end

local btnDowngradeApex = CreateExchangeButton(ExchangeBox, "1 Apex -> 5 Dark Sigils", 15, function() if DarkPatronDB.ApexSigils >= 1 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 1; DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils + 5; PlaySound(8959); Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.ApexSigils >= 1 end)
local btnLiquidateApex = CreateExchangeButton(ExchangeBox, "1 Apex -> 50 Favor", 230, function() if DarkPatronDB.ApexSigils >= 1 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 1; DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + 50; PlaySound(8959); Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.ApexSigils >= 1 end)
local btnLiquidateDark = CreateExchangeButton(ExchangeBox, "1 Dark Sigil -> 10 Favor", 445, function() if DarkPatronDB.DarkSigils >= 1 then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - 1; DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + 10; PlaySound(8959); Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.DarkSigils >= 1 end)

ApexScroll = CreateFrame("ScrollFrame", nil, ApexContainer); ApexScroll:SetPoint("TOPLEFT", 20, -185); ApexScroll:SetPoint("BOTTOMRIGHT", -40, 45); ApexScroll:EnableMouseWheel(true)
ApexScrollChild = CreateFrame("Frame", nil, ApexScroll); ApexScrollChild:SetSize(670, 300); ApexScroll:SetScrollChild(ApexScrollChild)
ApexScrollBar = CreateFrame("Slider", nil, ApexScroll, "UIPanelScrollBarTemplate"); ApexScrollBar:SetPoint("TOPRIGHT", ApexContainer, "TOPRIGHT", -15, -185); ApexScrollBar:SetPoint("BOTTOMRIGHT", ApexContainer, "BOTTOMRIGHT", -15, 45); ApexScrollBar:SetMinMaxValues(0, 0); ApexScrollBar:SetValueStep(30); ApexScrollBar:SetValue(0); ApexScrollBar:SetWidth(16); ApexScrollBar:Show()

local function UpdateApexScrollStates()
    local maxRange = ApexScroll:GetVerticalScrollRange(); local currentVal = ApexScroll:GetVerticalScroll()
    ApexScrollBar:SetMinMaxValues(0, maxRange > 0 and maxRange or 0); ApexScrollBar:SetValue(currentVal)
    if maxRange <= 0 then ApexScrollBar.ScrollUpButton:Disable() ApexScrollBar.ScrollDownButton:Disable() else
        if currentVal <= 0 then ApexScrollBar.ScrollUpButton:Disable() else ApexScrollBar.ScrollUpButton:Enable() end
        if currentVal >= maxRange then ApexScrollBar.ScrollDownButton:Disable() else ApexScrollBar.ScrollDownButton:Enable() end
    end
end
ApexScrollBar.ScrollUpButton:SetScript("OnClick", function() local val = ApexScroll:GetVerticalScroll(); local newVal = math.max(0, val - 30); ApexScroll:SetVerticalScroll(newVal); ApexScrollBar:SetValue(newVal); UpdateApexScrollStates() end)
ApexScrollBar.ScrollDownButton:SetScript("OnClick", function() local val = ApexScroll:GetVerticalScroll(); local maxVal = ApexScroll:GetVerticalScrollRange(); local newVal = math.min(maxVal, val + 30); ApexScroll:SetVerticalScroll(newVal); ApexScrollBar:SetValue(newVal); UpdateApexScrollStates() end)
ApexScrollBar:SetScript("OnValueChanged", function(self, value) ApexScroll:SetVerticalScroll(value); UpdateApexScrollStates() end)
ApexScroll:SetScript("OnMouseWheel", function(self, delta) local current = self:GetVerticalScroll(); local limit = self:GetVerticalScrollRange(); local new = current - (delta * 40); if new < 0 then new = 0 elseif new > limit then new = limit end self:SetVerticalScroll(new); ApexScrollBar:SetValue(new); UpdateApexScrollStates() end)

local function UpdateBazaarScrollStates()
    local maxRange = BazaarScroll:GetVerticalScrollRange(); local currentVal = BazaarScroll:GetVerticalScroll()
    BazaarScrollBar:SetMinMaxValues(0, maxRange > 0 and maxRange or 0); BazaarScrollBar:SetValue(currentVal)
    if maxRange <= 0 then BazaarScrollBar.ScrollUpButton:Disable() BazaarScrollBar.ScrollDownButton:Disable() else
        if currentVal <= 0 then BazaarScrollBar.ScrollUpButton:Disable() else BazaarScrollBar.ScrollUpButton:Enable() end
        if currentVal >= maxRange then BazaarScrollBar.ScrollDownButton:Disable() else BazaarScrollBar.ScrollDownButton:Enable() end
    end
end

BazaarScrollBar.ScrollUpButton:SetScript("OnClick", function() local val = BazaarScroll:GetVerticalScroll(); local newVal = math.max(0, val - 30); BazaarScroll:SetVerticalScroll(newVal); BazaarScrollBar:SetValue(newVal); UpdateBazaarScrollStates() end)
BazaarScrollBar.ScrollDownButton:SetScript("OnClick", function() local val = BazaarScroll:GetVerticalScroll(); local maxVal = BazaarScroll:GetVerticalScrollRange(); local newVal = math.min(maxVal, val + 30); BazaarScroll:SetVerticalScroll(newVal); BazaarScrollBar:SetValue(newVal); UpdateBazaarScrollStates() end)
BazaarScrollBar:SetScript("OnValueChanged", function(self, value) BazaarScroll:SetVerticalScroll(value); UpdateBazaarScrollStates() end)
BazaarScroll:SetScript("OnMouseWheel", function(self, delta) local current = self:GetVerticalScroll(); local limit = self:GetVerticalScrollRange(); local new = current - (delta * 40); if new < 0 then new = 0 elseif new > limit then new = limit end self:SetVerticalScroll(new); BazaarScrollBar:SetValue(new); UpdateBazaarScrollStates() end)
storeCardsList = {}
apexCardsList = {}

local EliteBlacklist = {
    ["Headless Horseman"] = true, ["Ahune"] = true, ["Omen"] = true, 
    ["Coren Direbrew"] = true, ["Crown Chemical Co."] = true, ["Frost Lord Ahune"] = true
}

local EliteRoster = DP.EliteRoster or {}

-- Auto-injects true Bosses into the combat log tracker
for _, elite in ipairs(EliteRoster) do
    if elite.rarity == "Boss" then
        DungeonBossDB[elite.id] = true
    end
end

local function CreateStoreCard(isApexTab, index, titleText, descText, costText, onBuyClick, isUnlockedFunc, canAffordFunc, restrictedBySSF)
    local col = (index - 1) % 2; local row = math.floor((index - 1) / 2)
    local parentFrame = isApexTab and ApexScrollChild or BazaarScrollChild
    
    local card = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    card:SetSize(325, 80); card:SetPoint("TOPLEFT", 5 + (col * 335), - (row * 90))
    card:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
    
    if isApexTab then card:SetBackdropBorderColor(0.8, 0.1, 0.1, 1) end

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal"); card.title:SetPoint("TOPLEFT", 10, -10); card.title:SetText(titleText)
    if isApexTab then card.title:SetTextColor(1, 0.4, 0.4) end
    
    card.desc = card:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall"); card.desc:SetPoint("TOPLEFT", 10, -26); card.desc:SetSize(195, 45); card.desc:SetJustifyH("LEFT"); card.desc:SetJustifyV("TOP")
    card.originalDesc = descText; card.isUnlockedFunc = isUnlockedFunc; card.canAffordFunc = canAffordFunc; card.restrictedBySSF = restrictedBySSF
    
    card.btn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate"); card.btn:SetSize(100, 25); card.btn:SetPoint("RIGHT", card, "RIGHT", -10, 0); card.btn:SetText(costText)
    card.btn:SetScript("OnClick", function()
        if not (IsResting() or devMode) then print("|cffff0000[Dark Patron]: You must be resting (Inn/Capital City) to purchase upgrades.|r") return end
        onBuyClick()
    end)
    
    if isApexTab then table.insert(apexCardsList, card) else table.insert(storeCardsList, card) end
    return card
end

local function GetTalentCost()
    local p = DarkPatronDB.MaxTalentsAllowed or 0
    if p < 10 then
        return 10 -- First 10 points: Cheap early game unlocks
    elseif p < 25 then
        return 20 -- Points 11-25: Mid-tree progression
    elseif p < 40 then
        return 35 -- Points 26-40: Deep-tree commitments
    else
        return 50 -- Points 41+: Capped ceiling for ultimate builds
    end
end

local function UpdateBazaarUI()
    local isPlayerSSF = IsSelfFound()
    local bazaarCanEdit = IsResting() or devMode
    
    if storeCardsList[2] then 
        local cost = GetTalentCost()
        local maxAllowed = DarkPatronDB.MaxTalentsAllowed or 0
        local spent = GetSpentTalentPoints()
        local available = math.max(0, maxAllowed - spent)
        
        storeCardsList[2].btn:SetText(cost .. " Favor") 
        storeCardsList[2].originalDesc = string.format("Grants the right to allocate 1 additional talent point.\n\n|cffaaaaaaAvailable: %d|r", available)
    end
    
    local function RefreshList(cards)
        for _, card in ipairs(cards) do
            if card.restrictedBySSF and isPlayerSSF then
                card:SetAlpha(0.6); card.desc:SetText(card.originalDesc .. "\n|cffff0000[Forbidden in Self-Found]|r"); card.desc:SetTextColor(0.5, 0.5, 0.5); card.btn:Disable(); card.btn:Show()
            elseif card.isUnlockedFunc and card.isUnlockedFunc() then
                card:SetAlpha(0.6); card.btn:Hide(); card.desc:SetText("Sanction Acquired."); card.desc:SetTextColor(0, 1, 0)
            else
                card:SetAlpha(1); card.desc:SetText(card.originalDesc); card.desc:SetTextColor(1, 1, 1)
                local canAfford = card.canAffordFunc and card.canAffordFunc() or false
                if bazaarCanEdit and canAfford then card.btn:Enable() else card.btn:Disable() end
                card.btn:Show()
            end
        end
    end

    RefreshList(storeCardsList); RefreshList(apexCardsList)

    if btnDowngradeApex then if bazaarCanEdit and btnDowngradeApex.canAffordFunc() then btnDowngradeApex:Enable() else btnDowngradeApex:Disable() end end
    if btnLiquidateApex then if bazaarCanEdit and btnLiquidateApex.canAffordFunc() then btnLiquidateApex:Enable() else btnLiquidateApex:Disable() end end
    if btnLiquidateDark then if bazaarCanEdit and btnLiquidateDark.canAffordFunc() then btnLiquidateDark:Enable() else btnLiquidateDark:Disable() end end
end

local isTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
local groundLvl = isTBC and 30 or 40
local groundCost = isTBC and 3 or 5

-- LEVELING TAB CARDS
CreateStoreCard(false, 1, "Uncommon Armaments", "Unlock the right to equip Uncommon (Green) quality gear permanently.", "35 Favor", function() if DarkPatronDB.DarkFavor >= 35 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 35; DarkPatronDB.MaxGearQuality = 2; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.MaxGearQuality >= 2 end, function() return DarkPatronDB.DarkFavor >= 35 end)
CreateStoreCard(false, 2, "Grant of Knowledge", "Grants the right to allocate 1 additional talent point (Repeatable).", "", function() local cost = GetTalentCost() if DarkPatronDB.DarkFavor >= cost then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - cost; DarkPatronDB.MaxTalentsAllowed = (DarkPatronDB.MaxTalentsAllowed or 0) + 1; PlaySound(8959) CheckViolations(); if Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end end end, nil, function() return DarkPatronDB.DarkFavor >= GetTalentCost() end)
CreateStoreCard(false, 3, "Rare Armaments", "Unlock the right to equip Rare (Blue) quality gear permanently.", "2 Dark Sigils", function() if DarkPatronDB.DarkSigils >= 2 then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - 2; DarkPatronDB.MaxGearQuality = 3; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.MaxGearQuality >= 3 end, function() return DarkPatronDB.DarkSigils >= 2 end)
CreateStoreCard(false, 4, "Journeyman's Cavalry", string.format("Unlock the right to summon and ride your Level %d (60%% speed) mount.", groundLvl), groundCost .. " Dark Sigils", function() if DarkPatronDB.DarkSigils >= groundCost then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - groundCost; DarkPatronDB.HasJourneymanCavalry = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasJourneymanCavalry end, function() return DarkPatronDB.DarkSigils >= groundCost end)
CreateStoreCard(false, 5, "The Blood Contract", "Trade 50 Favor to hunt a level-appropriate Elite. Prioritizes local zone.", "50 Favor", function()
    if DarkPatronDB.DarkFavor >= 50 then
        local maxSlots = DarkPatronDB.MaxActiveSlots or 3
        if #DarkPatronDB.ActiveMissions >= maxSlots then print("The Void: Your Active Pacts are full. Discard one before signing a Blood Contract.") return end
        
        local pLvl = UnitLevel("player") or 1
        local pFaction = UnitFactionGroup("player") or "Any"
        local validElites = {}; local localElites = {}; local currentZone = GetRealZoneText() or ""
        
        for _, elite in ipairs(EliteRoster) do
            if not EliteBlacklist[elite.name] then
                if elite.level >= (pLvl - 7) and elite.level <= (pLvl + 4) and (elite.faction == "Any" or elite.faction == pFaction) then
                    local isUsed = false
                    local guid = UnitGUID("player") or "Unknown"
                    if DarkPatronDB.CompletedElites then 
                        for _, completedId in ipairs(DarkPatronDB.CompletedElites) do 
                            if completedId == elite.id or completedId == (elite.id .. "-" .. guid) then 
                                isUsed = true 
                                break 
                            end 
                        end 
                    end
                    for _, active in pairs(DarkPatronDB.ActiveMissions) do if active.targetName == elite.name then isUsed = true break end end
                    for _, poolItem in pairs(DarkPatronDB.PoolOfSix) do if poolItem.targetName == elite.name then isUsed = true break end end
                    if DarkPatronDB.EliteBounties then for _, eliteItem in ipairs(DarkPatronDB.EliteBounties) do if eliteItem.targetName == elite.name then isUsed = true break end end end
                    
                    if not isUsed then table.insert(validElites, elite) if string.find(elite.zone, currentZone) then table.insert(localElites, elite) end end
                end
            end
        end

        if #validElites == 0 then print("The Void: The Blood Contract is void. No valid targets remain.") return end
        
        local chosen = (#localElites > 0) and localElites[math.random(#localElites)] or validElites[math.random(#validElites)]
        DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 50
        local favorReward = (chosen.rarity == "Boss" or chosen.rarity == "Rare Elite") and 5 or 3
        local sigilReward = (chosen.rarity == "Boss" or chosen.rarity == "Rare Elite") and "+1 Apex Sigil" or "+1 Dark Sigil"
        
        DarkPatronDB.EliteBounties = DarkPatronDB.EliteBounties or {}
        table.insert(DarkPatronDB.EliteBounties, { id = chosen.id, title = string.format("%s", chosen.name), baseTitle = chosen.name, desc = string.format("Execute %s. (Located in %s)", chosen.name, chosen.zone), rarity = chosen.rarity, rewardText = "Reward: " .. sigilReward, favor = favorReward, goal = 1, current = 0, trigger = "SPECIFIC_KILL", targetName = chosen.name, zone = chosen.zone })
        
        PlaySound(8959)
        print("THE VOID: Blood Contract signed! A specific targeted Hunt has been bound to your ledger.")
        Ledger:GetScript("OnShow")(Ledger)
    else 
        print("The Void: Insufficient Favor (Requires 50).") 
    end
end, nil, function() return DarkPatronDB.DarkFavor >= 50 end)
CreateStoreCard(false, 6, "The Apex Rite", "Sacrifice Elite Dark Sigils to forge 1 forbidden Apex Sigil.", "5 Dark Sigils", function() if DarkPatronDB.DarkSigils >= 5 then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - 5; DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + 1; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) else print("Dark Patron: Insufficient Dark Sigils.") end end, nil, function() return DarkPatronDB.DarkSigils >= 5 end)
CreateStoreCard(false, 7, "The Alchemist's Grace", "Permanently reduce the Coward's Tax for abandoning active pacts down to 1 Favor.", "35 Favor", function() if DarkPatronDB.DarkFavor >= 35 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 35; DarkPatronDB.HasAlchemistGrace = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) else print("Dark Patron: Insufficient Dark Favor (Requires 35).") end end, function() return DarkPatronDB.HasAlchemistGrace end, function() return DarkPatronDB.DarkFavor >= 35 end)
CreateStoreCard(false, 8, "The Pathfinder's Intuition", "Permanently makes board reshuffles completely free (0 Favor cost).", "50 Favor", function() if DarkPatronDB.DarkFavor >= 50 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 50; DarkPatronDB.HasTravelerStep = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) else print("Dark Patron: Insufficient Dark Favor (Requires 50).") end end, function() return DarkPatronDB.HasTravelerStep end, function() return DarkPatronDB.DarkFavor >= 50 end)
CreateStoreCard(false, 9, "The Sovereign Awakening", "Gamble 30 Dark Favor for a 10% chance to forge 1 Apex Sigil. Failure destroys your Favor.", "30 Favor", function() if DarkPatronDB.DarkFavor >= 30 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 30; if math.random(1, 100) <= 10 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + 1; PlaySound(8959); print("DARK PATRON: THE AWAKENING SUCCEEDS! An Apex Sigil has been forged from the void!") else PlaySound(6243); print("DARK PATRON: The Sovereign rejects your offering... Your 30 Dark Favor is lost to the void.") end Ledger:GetScript("OnShow")(Ledger) end end, nil, function() return DarkPatronDB.DarkFavor >= 30 end)
CreateStoreCard(false, 10, "Extended Ledger", "Permanently unlock a 4th simultaneous Active Pact slot.", "50 Favor", function() if DarkPatronDB.DarkFavor >= 50 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 50; DarkPatronDB.MaxActiveSlots = 4; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return (DarkPatronDB.MaxActiveSlots or 3) >= 4 end, function() return DarkPatronDB.DarkFavor >= 50 end)
CreateStoreCard(false, 11, "The Hoarder's Key", "Unlock the right to access and use your Bank.", "40 Favor", function() if DarkPatronDB.DarkFavor >= 40 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 40; DarkPatronDB.HasBank = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasBank end, function() return DarkPatronDB.DarkFavor >= 40 end)
CreateStoreCard(false, 12, "The Merchant's Writ", "Unlock the right to buy and sell on the Auction House.", "40 Favor", function() if DarkPatronDB.DarkFavor >= 40 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 40; DarkPatronDB.HasAuction = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasAuction end, function() return DarkPatronDB.DarkFavor >= 40 end, true)
CreateStoreCard(false, 13, "The Courier's Seal", "Unlock the right to open and send Mail.", "20 Favor", function() if DarkPatronDB.DarkFavor >= 20 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 20; DarkPatronDB.HasMail = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasMail end, function() return DarkPatronDB.DarkFavor >= 20 end, true)
CreateStoreCard(false, 14, "Capstone Awakening", "Unlock your 31-point ultimate talent. Required to spend 31st point.", "1 Apex Sigil", function() if DarkPatronDB.ApexSigils >= 1 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 1; DarkPatronDB.HasCapstone = true; DarkPatronDB.MaxTalentsAllowed = DarkPatronDB.MaxTalentsAllowed + 1; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasCapstone end, function() return DarkPatronDB.ApexSigils >= 1 end)

-- === APEX ENDGAME SANCTUM CARDS ===
CreateStoreCard(true, 1, "Master's Cavalry", "Unlock the right to summon and ride your Epic (100% speed) ground mount.", "10 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 10 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 10; DarkPatronDB.HasMasterCavalry = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasMasterCavalry end, function() return DarkPatronDB.ApexSigils >= 10 end)
CreateStoreCard(true, 2, "Epic Armaments", "Unlock the right to equip Epic (Purple) gear permanently.", "5 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 5 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 5; DarkPatronDB.MaxGearQuality = 4; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.MaxGearQuality >= 4 end, function() return DarkPatronDB.ApexSigils >= 5 end)
CreateStoreCard(true, 3, "The Artisan's Sanction", "Unlock the right to equip and use Epic-quality crafted gear.", "3 Dark Sigils", function() if DarkPatronDB.DarkSigils >= 3 then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - 3; DarkPatronDB.HasArtisanSanction = true; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) else print("Dark Patron: Insufficient Dark Sigils.") end end, function() return DarkPatronDB.HasArtisanSanction end, function() return DarkPatronDB.DarkSigils >= 3 end)
CreateStoreCard(true, 4, "Alchemist's Sight", "Unlock the right to use powerful combat alterations (LIPs, Petris, FAPs).", "3 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 3 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 3; DarkPatronDB.HasAlchemistSight = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasAlchemistSight end, function() return DarkPatronDB.ApexSigils >= 3 end)
CreateStoreCard(true, 5, "Enchanter's Writ", "Unlock the right to apply high-tier endgame weapon enchants (Crusader, Spellpower).", "3 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 3 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 3; DarkPatronDB.HasEnchantersWrit = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasEnchantersWrit end, function() return DarkPatronDB.ApexSigils >= 3 end)
CreateStoreCard(true, 6, "The World's Boon", "Unlock the right to retain World Buffs. The Patron strips unsanctioned boons instantly.", "2 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 2 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 2; DarkPatronDB.HasWorldsBoon = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasWorldsBoon end, function() return DarkPatronDB.ApexSigils >= 2 end)
if isTBC then
    CreateStoreCard(true, 7, "Expert's Cavalry", "Unlock the right to summon and ride your Level 70 Flying (60% speed) mount.", "8 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 8 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 8; DarkPatronDB.HasExpertCavalry = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasExpertCavalry end, function() return DarkPatronDB.ApexSigils >= 8 end)
    
    CreateStoreCard(true, 8, "Artisan's Cavalry", "Unlock the right to ride your Level 70 Epic Flying (280% speed) mount.", "15 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 15 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 15; DarkPatronDB.HasArtisanCavalry = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasArtisanCavalry end, function() return DarkPatronDB.ApexSigils >= 15 end)
end

tabBoardBtn:SetScript("OnClick", function() if WelcomeModal and WelcomeModal:IsShown() then return end currentView = "board"; BoardContainer:Show(); BazaarContainer:Hide(); BazaarScrollBar:Hide(); ApexContainer:Hide(); ApexScrollBar:Hide(); ChronicleContainer:Hide() end)
tabBazaarBtn:SetScript("OnClick", function() if WelcomeModal and WelcomeModal:IsShown() then return end currentView = "bazaar"; BazaarContainer:Show(); BoardContainer:Hide(); BazaarScrollBar:Show(); ApexContainer:Hide(); ApexScrollBar:Hide(); ChronicleContainer:Hide(); UpdateBazaarScrollStates() end)

tabApexBtn:SetScript("OnClick", function()
    if WelcomeModal and WelcomeModal:IsShown() then return end
    local pLvl = UnitLevel("player") or 1
    local maxLvl = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC) and 70 or 60
    if pLvl < maxLvl and not devMode then
        print(string.format("|cffff0000[Dark Patron]: The Apex Sanctum remains sealed until you reach Level %d.|r", maxLvl))
        return
    end
    currentView = "apex"
    ApexContainer:Show(); BoardContainer:Hide(); BazaarContainer:Hide(); BazaarScrollBar:Hide(); ApexScrollBar:Show(); ChronicleContainer:Hide()
    UpdateApexScrollStates()
end)

tabChronicleBtn:SetScript("OnClick", function() if WelcomeModal and WelcomeModal:IsShown() then return end currentView = "chronicle"; ChronicleContainer:Show(); BoardContainer:Hide(); BazaarContainer:Hide(); BazaarScrollBar:Hide(); ApexContainer:Hide(); ApexScrollBar:Hide(); chroniclePages = GenerateChroniclePages(); currentChroniclePage = 1; UpdateChronicleView() end)

local DebugPanel = CreateFrame("Frame", nil, Ledger)
DebugPanel:SetSize(500, 30); DebugPanel:SetPoint("BOTTOMRIGHT", Ledger, "BOTTOMRIGHT", -15, 12); DebugPanel:Hide()
local function CreateDevBtn(name, text, xOffset, onClick) local btn = CreateFrame("Button", name, DebugPanel, "UIPanelButtonTemplate"); btn:SetSize(80, 20); btn:SetPoint("LEFT", DebugPanel, "LEFT", xOffset, 0); btn:SetText(text); btn:SetScript("OnClick", onClick); return btn end
CreateDevBtn("DevBtnFavor", "+10 Favor", 0, function() DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + 10; Ledger:GetScript("OnShow")(Ledger) end)
CreateDevBtn("DevBtnSigil", "+1 Sigil", 85, function() DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils + 1; Ledger:GetScript("OnShow")(Ledger) end)
CreateDevBtn("DevBtnReset", "RESET", 255, function() 
    DarkPatronDB.DarkFavor = 0; DarkPatronDB.DarkSigils = 0; DarkPatronDB.ApexSigils = 0; DarkPatronDB.MaxTalentsAllowed = 0; DarkPatronDB.MaxGearQuality = 1; DarkPatronDB.MaxActiveSlots = 3;
    DarkPatronDB.HasJourneymanCavalry = false; DarkPatronDB.HasMasterCavalry = false; DarkPatronDB.HasCapstone = false; DarkPatronDB.HasAlchemistGrace = false; DarkPatronDB.HasTravelerStep = false; DarkPatronDB.HasArtisanSanction = false; DarkPatronDB.HasBank = false; DarkPatronDB.HasAuction = false; DarkPatronDB.HasMail = false; DarkPatronDB.HasWorldsBoon = false; DarkPatronDB.HasAlchemistSight = false;
    DarkPatronDB.ActiveMissions = {}; DarkPatronDB.RecentlyCompleted = {}; DarkPatronDB.CompletedElites = {}; DarkPatronDB.ContractTypesCompleted = {}; DarkPatronDB.FirstEliteKilled = nil; DarkPatronDB.FailedPactsCount = 0; DarkPatronDB.TotalPactsAccepted = 0; DarkPatronDB.HasInitializedAwakening = false; DarkPatronDB.PoolOfSix = {}; DarkPatronDB.IsDead = false; DarkPatronDB.DeathEpitaph = nil;
    DarkPatronDB.CurrentStreak = 0; DarkPatronDB.LastPactTime = 0;
    RefillMissionPool(); print("DEV: Wiped & Awakening Reset."); CheckViolations(); Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
end)

Ledger:SetScript("OnShow", function()
    if DarkPatronDB then
        -- Acknowledge and dismiss the current alerts the moment the ledger is opened
        DarkPatronDB.LastSeenAlertState = DP_EvaluateBazaarAlert()
        DP_EvaluateBazaarAlert()
        
        txtFavor:SetText("Dark Favor: " .. DarkPatronDB.DarkFavor)
        txtSigils:SetText("Dark Sigils: " .. DarkPatronDB.DarkSigils)
        txtApex:SetText("Apex Sigils: " .. DarkPatronDB.ApexSigils)
    end
    if not DarkPatronDB.PoolOfSix or #DarkPatronDB.PoolOfSix == 0 then RefillMissionPool() end
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if canEdit then BoardWarning:Hide() else BoardWarning:Show() end
    
    local reshuffleCost = DarkPatronDB.HasTravelerStep and 0 or 1
    if DarkPatronDB.HasTravelerStep then refreshBtn:SetText("Reshuffle Board (Free)") else refreshBtn:SetText("Reshuffle Board (1 Favor)") end
    if canEdit and (reshuffleCost == 0 or DarkPatronDB.DarkFavor >= reshuffleCost) then refreshBtn:Enable() else refreshBtn:Disable() end
    
    local baseTaxCost = DarkPatronDB.HasAlchemistGrace and 1 or 2
    local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    local startX = (maxSlots == 3) and 110 or 20
    
    for i = 1, 4 do
        if i <= maxSlots then
            activeCards[i]:SetPoint("TOPLEFT", startX + ((i - 1) * 180), -125)
            local mData = DarkPatronDB.ActiveMissions[i]
            ApplyCardTheme(activeCards[i], mData)
            if mData then
                activeCards[i].title:SetText(mData.baseTitle or mData.title)
                if mData.goal and mData.goal > 1 then
                    local baseDesc = mData.desc:match("^(.-)%s*%(%d+/%d+%)$") or mData.desc
                    activeCards[i].desc:SetText(string.format("%s (%d/%d)", baseDesc, mData.current, mData.goal))
                else activeCards[i].desc:SetText(mData.desc) end
                
                local formattedReward = mData.rewardText:gsub(", ", "\n")
                
                if mData.isTimed then
                    local remain = mData.expiresAt - time()
                    if remain > 0 then activeCards[i].reward:SetText(formattedReward .. string.format("\n|cffaaaaaaLeft: %02d:%02d|r", math.floor(remain / 60), remain % 60)) else activeCards[i].reward:SetText(formattedReward .. "\n|cffff0000FAILED|r") end
                else activeCards[i].reward:SetText(formattedReward) end
                
                if mData.isPvP then activeCards[i].btn:SetText("Discard (Free PvP)") activeCards[i].btn.taxOverride = 0 else activeCards[i].btn:SetText(string.format("Discard (-%d Fav)", baseTaxCost)) activeCards[i].btn.taxOverride = baseTaxCost end
                if canEdit then activeCards[i].btn:Enable() else activeCards[i].btn:Disable() end
                activeCards[i].btn:Show(); activeCards[i]:Show()
            else
                activeCards[i].title:SetText("Empty Slot"); activeCards[i].desc:SetText("Drag a contract here to accept."); activeCards[i].reward:SetText(""); activeCards[i].btn:Hide(); activeCards[i]:Show()
            end
        else activeCards[i]:Hide() end
    end
    
    for i = 1, 6 do
        local mData = DarkPatronDB.PoolOfSix[i]
        ApplyCardTheme(poolButtons[i], mData)
        if mData then
            poolButtons[i].title:SetText(mData.baseTitle or mData.title); poolButtons[i].desc:SetText(mData.desc)
            
            local formattedReward = mData.rewardText:gsub(", ", "\n")
            
            if mData.isTimed then poolButtons[i].reward:SetText(formattedReward .. string.format("\n|cffff0000Limit: %dm|r", math.floor(mData.timeLimit / 60))) else poolButtons[i].reward:SetText(formattedReward) end
            if canEdit then poolButtons[i].acceptBtn:Enable() else poolButtons[i].acceptBtn:Disable() end
            poolButtons[i].acceptBtn:Show(); poolButtons[i]:Show()
        else
            poolButtons[i].title:SetText("No Contract"); poolButtons[i].desc:SetText("Reshuffle the board for new opportunities."); poolButtons[i].reward:SetText(""); poolButtons[i].acceptBtn:Hide(); poolButtons[i]:Show()
        end
    end
	
    local dList = DarkPatronDB.DungeonBounties
    if dList and #dList > 0 then
        if Ledger.CurrentDungeonIndex > #dList then Ledger.CurrentDungeonIndex = 1 end
        local activeDung = dList[Ledger.CurrentDungeonIndex]
        ApplyCardTheme(DungeonCard, activeDung)
        DungeonCard.title:SetText(activeDung.baseTitle or activeDung.title); DungeonCard.desc:SetText(activeDung.desc); DungeonCard.reward:SetText(activeDung.rewardText)
        
        if activeDung.reqMinLvl and activeDung.reqMaxLvl then
            DungeonCard.levelReq:SetText(string.format("Lvl %d - %d", activeDung.reqMinLvl, activeDung.reqMaxLvl))
            DungeonCard.levelReq:Show()
        else
            DungeonCard.levelReq:Hide()
        end

        if canEdit then DungeonCard.acceptBtn:Enable() else DungeonCard.acceptBtn:Disable() end
        
        local bR, bG, bB = DungeonCard:GetBackdropBorderColor()
        DungeonCard.StackBg1:SetBackdropBorderColor(bR, bG, bB, 1); DungeonCard.StackBg2:SetBackdropBorderColor(bR, bG, bB, 1)
        
       local function SetStackBg(bgFrame, offset)
            local idx = Ledger.CurrentDungeonIndex + offset
            while idx > #dList do idx = idx - #dList end
            local nextDung = dList[idx]
            if not bgFrame.bgImage then bgFrame.bgImage = bgFrame:CreateTexture(nil, "BORDER"); bgFrame.bgImage:SetPoint("TOPLEFT", 4, -4); bgFrame.bgImage:SetPoint("BOTTOMRIGHT", -4, 4); bgFrame.bgImage:SetTexCoord(0, 1, 0.25, 0.65) end
            if nextDung and nextDung.zone and ZoneLoadingScreens[nextDung.zone] then 
                bgFrame.bgImage:SetTexture("Interface\\Glues\\LoadingScreens\\" .. ZoneLoadingScreens[nextDung.zone] .. ".blp"); 
                bgFrame.bgImage:SetVertexColor(0.4, 0.4, 0.4, 1); 
                bgFrame.bgImage:Show() 
            else 
                bgFrame.bgImage:Hide() 
            end
        end

        if #dList > 1 then
            SetStackBg(DungeonCard.StackBg1, 1); DungeonCard.StackBg1:Show(); DungeonCard.PrevBtn:Show(); DungeonCard.NextBtn:Show(); DungeonCard.StackCounter:SetText(string.format("Stack: %d / %d", Ledger.CurrentDungeonIndex, #dList)); DungeonCard.StackCounter:Show()
            if #dList > 2 then SetStackBg(DungeonCard.StackBg2, 2); DungeonCard.StackBg2:Show() else DungeonCard.StackBg2:Hide() end
        else
            DungeonCard.StackBg1:Hide(); DungeonCard.StackBg2:Hide(); DungeonCard.PrevBtn:Hide(); DungeonCard.NextBtn:Hide(); DungeonCard.StackCounter:Hide()
        end
        DungeonCard.acceptBtn:Show(); DungeonCard:Show()
    else DungeonCard:Hide(); DungeonCard.StackBg1:Hide(); DungeonCard.StackBg2:Hide() end
	
	-- === UPDATE TARGETED HUNTS SIDE PANEL ===
    local eList = DarkPatronDB.EliteBounties
    if eList and #eList > 0 then
        if Ledger.CurrentEliteIndex > #eList then Ledger.CurrentEliteIndex = 1 end
        local activeElite = eList[Ledger.CurrentEliteIndex]
        ApplyCardTheme(ECard, activeElite)
        ECard.title:SetText(activeElite.baseTitle or activeElite.title)
        ECard.desc:SetText(activeElite.desc)
        ECard.reward:SetText(activeElite.rewardText)
        
        if canEdit then ECard.acceptBtn:Enable() else ECard.acceptBtn:Disable() end

        if #eList > 1 then
            ECard.PrevBtn:Show(); ECard.NextBtn:Show()
            ECard.StackCounter:SetText(string.format("Hunt: %d / %d", Ledger.CurrentEliteIndex, #eList))
            ECard.StackCounter:Show()
        else
            ECard.PrevBtn:Hide(); ECard.NextBtn:Hide(); ECard.StackCounter:Hide()
        end
        EliteCardContainer:Show()
    else 
        EliteCardContainer:Hide() 
    end
    
    UpdateBazaarUI()

    local pLvl = UnitLevel("player") or 1
    if pLvl >= 60 or devMode then
        tabApexBtn:SetAlpha(1)
    else
        tabApexBtn:SetAlpha(0.5)
    end

    if currentView == "board" then BoardContainer:Show(); BazaarContainer:Hide(); BazaarScrollBar:Hide(); ApexContainer:Hide(); ApexScrollBar:Hide(); ChronicleContainer:Hide()
    elseif currentView == "bazaar" then BazaarContainer:Show(); BoardContainer:Hide(); BazaarScrollBar:Show(); ApexContainer:Hide(); ApexScrollBar:Hide(); ChronicleContainer:Hide(); UpdateBazaarScrollStates()
    elseif currentView == "apex" then ApexContainer:Show(); BoardContainer:Hide(); BazaarContainer:Hide(); BazaarScrollBar:Hide(); ApexScrollBar:Show(); ChronicleContainer:Hide(); UpdateApexScrollStates()
    elseif currentView == "chronicle" then ChronicleContainer:Show(); BoardContainer:Hide(); BazaarContainer:Hide(); BazaarScrollBar:Hide(); ApexContainer:Hide(); ApexScrollBar:Hide() end

    if not DarkPatronDB.HasInitializedAwakening and (DarkPatronDB.TotalPactsAccepted or 0) >= maxSlots then DarkPatronDB.HasInitializedAwakening = true end
    if devMode then DebugPanel:Show() else DebugPanel:Hide() end
    UpdateTracker()
end)

-- =====================================================================
-- WORLD TOOLTIP INTEGRATION
-- =====================================================================
GameTooltip:HookScript("OnHyperlinkEnter", function(self, link, text, button)
    local linkType, title, rarity, desc, reward = strsplit(":", link)
    if linkType == "dpact" and title then
        self:SetOwner(UIParent, "ANCHOR_CURSOR")
        self:ClearLines()
        self:AddLine("Dark Patron Pact", 0.64, 0.21, 0.93)
        self:AddLine(title, 1, 1, 1)
        self:AddLine("Rarity: " .. (rarity or "Standard"), 0.64, 0.21, 0.93)
        self:AddLine(" ")
        if desc and desc ~= "" then
            self:AddLine(desc, 1, 0.82, 0, true)
            self:AddLine(" ")
        end
        if reward and reward ~= "" then
            self:AddLine(reward, 0.64, 0.21, 0.93)
        end
        self:Show()
    end
end)

GameTooltip:HookScript("OnHyperlinkLeave", function(self)
    if self:IsShown() and GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText() == "Dark Patron Pact" then
        self:Hide()
    end
end)

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if not unit then return end
    
    local unitName = UnitName(unit)
    
    if UnitIsUnit(unit, "player") and DarkPatronAccountDB and DarkPatronAccountDB.LegacyUnlocked then
        local nameText = _G[self:GetName().."TextLeft1"]
        if nameText then
            nameText:SetText(unitName .. ", the Patron's Hand")
        end
    end

    if not DarkPatronDB or not DarkPatronDB.ActiveMissions then return end
    local isHostile = not UnitIsFriend("player", unit) and not UnitIsPlayer(unit)

    for _, mission in ipairs(DarkPatronDB.ActiveMissions) do
        if mission.trigger == "SPECIFIC_KILL" and mission.targetName == unitName then
            self:AddLine("Dark Patron Target: " .. (mission.title or "Hunt"), 0.64, 0.21, 0.93)
            self:AddLine(string.format("Execute %s", unitName), 1, 0.5, 0)
            self:Show()
        elseif mission.trigger == "PARTY_KILL" and isHostile then
            self:AddLine("Dark Patron Pact: " .. (mission.title or "Bounty"), 0.64, 0.21, 0.93)
            self:AddLine(string.format("Hostile Kills: %d / %d", mission.current or 0, mission.goal), 1, 0.5, 0)
            self:Show()
        end
    end
end)

GameTooltip:HookScript("OnTooltipSetItem", function(self)
    if not DarkPatronDB or not DarkPatronDB.ActiveMissions then return end
    
    local itemName, link = self:GetItem()
    if not itemName then return end
    
    for _, mission in ipairs(DarkPatronDB.ActiveMissions) do
        if mission.trigger == "FETCH_ITEM" and mission.targetName == itemName then
            self:AddLine("Dark Patron Pact: " .. (mission.title or "Hoarder"), 0.64, 0.21, 0.93)
            self:AddLine(string.format("Gathered: %d / %d", mission.current or 0, mission.goal), 1, 0.5, 0)
            self:Show()
        end
    end
end)

SLASH_DARKPATRON1 = "/patron"
SlashCmdList["DARKPATRON"] = function(msg)
    if msg:match("^tell ") then
        local _, target, messageText = strsplit(" ", msg, 3)
        if target and messageText then
            SendChatMessage(messageText, "WHISPER", nil, target)
            C_ChatInfo.SendAddonMessage("DP_JUSTICE", "GM_WHISPER:" .. messageText, "WHISPER", target)
            print(string.format("|cff00ccff[Developer Outbox]|r to %s: %s", target, messageText))
        else
            print("|cff00ccff[Developer Outbox]|r: Syntax Error. Use: /patron tell <PlayerName> <message>")
        end
        
    elseif msg:match("^reply ") then
        local _, replyMsg = strsplit(" ", msg, 2)
        if replyMsg and replyMsg ~= "" then
            if C_ChatInfo then
                C_ChatInfo.SendAddonMessage("DP_JUSTICE", "DP_REPLY:" .. replyMsg, "WHISPER", DEVELOPER_IDENTITY)
                print(string.format("|cff00ccff[Dark Patron]|r: Sent reply to Developer: %s", replyMsg))
            end
        else
            print("|cff00ccff[Dark Patron]|r: Syntax Error. Use: /patron reply <your message>")
        end
        
    -- === NEW: DEV FORCE COMPLETE COMMAND ===
    elseif msg:match("^complete") then
        if not devMode then
            print("|cffff0000[Dark Patron]: You must have devMode = true at the top of the file to use this.|r")
            return
        end
        
        if DarkPatronDB.ActiveMissions and #DarkPatronDB.ActiveMissions > 0 then
            -- Grab the pact in Slot 1
            local mission = DarkPatronDB.ActiveMissions[1]
            -- Fake the progress to max
            mission.current = mission.goal
            -- Trigger the full cinematic reward and backfill cycle!
            FulfillMission(1, mission)
            print("|cff00ccff[Developer Mode]|r: Force-completed active pact in Slot 1.")
        else
            print("|cff00ccff[Developer Mode]|r: No active pacts to complete.")
        end
        
    elseif Ledger:IsShown() then 
        Ledger:Hide() 
    else 
        Ledger:Show() 
    end
end

-- =====================================================================
-- 6. VISUAL WALKTHROUGH & INTERACTIVE HIGHLIGHTS (TUTORIAL)
-- =====================================================================
WelcomeModal = CreateFrame("Frame", "DarkPatronWelcomeModal", UIParent, "BackdropTemplate")
WelcomeModal:SetSize(420, 280); WelcomeModal:SetPoint("LEFT", UIParent, "LEFT", 40, 0); WelcomeModal:SetFrameStrata("TOOLTIP"); WelcomeModal:SetMovable(true); WelcomeModal:EnableMouse(true); WelcomeModal:RegisterForDrag("LeftButton"); WelcomeModal:SetScript("OnDragStart", WelcomeModal.StartMoving); WelcomeModal:SetScript("OnDragStop", WelcomeModal.StopMovingOrSizing)
WelcomeModal:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }}); WelcomeModal:SetBackdropColor(0.05, 0.05, 0.1, 0.98); WelcomeModal:Hide()

WelcomeModal.Title = WelcomeModal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); WelcomeModal.Title:SetPoint("TOP", 0, -15); WelcomeModal.Title:SetText("Dark Patron: Field Guide")
WelcomeModal.PageIndicator = WelcomeModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); WelcomeModal.PageIndicator:SetPoint("TOP", WelcomeModal.Title, "BOTTOM", 0, -2); WelcomeModal.PageIndicator:SetTextColor(1, 0.82, 0)
WelcomeModal.StepIcon = WelcomeModal:CreateTexture(nil, "ARTWORK"); WelcomeModal.StepIcon:SetSize(36, 36); WelcomeModal.StepIcon:SetPoint("TOPLEFT", 20, -45)
WelcomeModal.SubHeader = WelcomeModal:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3"); WelcomeModal.SubHeader:SetPoint("TOPLEFT", 65, -48)
WelcomeModal.Content = WelcomeModal:CreateFontString(nil, "OVERLAY", "GameFontWhite"); WelcomeModal.Content:SetPoint("TOPLEFT", 20, -95); WelcomeModal.Content:SetSize(380, 140); WelcomeModal.Content:SetJustifyH("LEFT"); WelcomeModal.Content:SetJustifyV("TOP")

currentStep = 1
local flashTicker, currencyFlashTicker, buttonFlashTicker = nil, nil, nil

local function ClearAllHighlights()
    if flashTicker then flashTicker:Cancel() flashTicker = nil end
    if currencyFlashTicker then currencyFlashTicker:Cancel() currencyFlashTicker = nil end
    if buttonFlashTicker then buttonFlashTicker:Cancel() buttonFlashTicker = nil end
    if storeCardsList then for _, card in ipairs(storeCardsList) do card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1) end end
    if activeCards then for _, card in ipairs(activeCards) do card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1) end end
    if poolButtons then for _, card in ipairs(poolButtons) do card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1) end end
    if tabBazaarBtn then tabBazaarBtn:UnlockHighlight() end
    if tabBoardBtn then tabBoardBtn:UnlockHighlight() end
    if txtFavor then txtFavor:SetTextColor(1, 0.82, 0) end
    if txtSigils then txtSigils:SetTextColor(1, 0.82, 0) end
    if txtApex then txtApex:SetTextColor(1, 0.82, 0) end
    if tabBoardBtn then tabBoardBtn:Enable() end
    if tabBazaarBtn then tabBazaarBtn:Enable() end
end

local function HighlightCards(cardsTable, indices)
    ClearAllHighlights(); flashTicker = C_Timer.NewTicker(0.6, function() local r, g, b = 1, 0.82, 0 for _, idx in ipairs(indices) do local card = cardsTable[idx] if card and card:IsShown() then local currentR, _, _ = card:GetBackdropBorderColor() if currentR == r then card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1) else card:SetBackdropBorderColor(r, g, b, 1) end end end end)
end

local function FlashCurrencies()
    ClearAllHighlights(); currencyFlashTicker = C_Timer.NewTicker(0.6, function() local r = txtFavor:GetTextColor(); local targetR = (r == 1) and 0.2 or 1 if txtFavor then txtFavor:SetTextColor(targetR, 0.82, 0) end if txtSigils then txtSigils:SetTextColor(targetR, 0.82, 0) end if txtApex then txtApex:SetTextColor(targetR, 0.82, 0) end end)
end

local function FlashButtonStrobe(btn)
    ClearAllHighlights(); local highlighted = false; buttonFlashTicker = C_Timer.NewTicker(0.5, function() if btn and btn:IsShown() then if highlighted then btn:UnlockHighlight() highlighted = false else btn:LockHighlight() highlighted = true end end end)
end

local tutorialPages = {
    { title = "1. Gear Restrictions & Armaments", icon = "Interface\\Icons\\INV_Chest_Cloth_08", header = "Unlocking Higher Gear Tiers", text = "You start restricted to Common (White) gear. Equipping higher quality items without unlocking them causes the Veil to reject them.\n\n|cffffd700=> Look at the flashing Armament unlocks in the Bazaar below!|r", action = function() if PatronsLedger then PatronsLedger:Show() end currentView = "bazaar" if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end HighlightCards(storeCardsList, {1, 3, 5}) end },
    { title = "2. The Bounty Board", icon = "Interface\\Icons\\INV_Misc_Note_01", header = "Selecting Available Contracts", text = "The Bounty Board generates randomized contracts for you to choose from based on your level.\n\n|cffffd700=> Notice all 6 contract tiles flashing on your Bounty Board below!|r", action = function() if PatronsLedger then PatronsLedger:Show() end currentView = "board" if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end HighlightCards(poolButtons, {1, 2, 3, 4, 5, 6}) end },
    { title = "3. Active Pacts", icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength", header = "Dragging & Enabling Bounties", text = "To track and complete a bounty, click and drag a contract tile from the Bounty Board up into your |cffffffffActive Pacts|r slots.\n\n|cffffd700=> Notice the flashing Active Pact slots at the top!|r", action = function() if PatronsLedger then PatronsLedger:Show() end currentView = "board" if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end HighlightCards(activeCards, {1, 2, 3, 4}) end },
    { title = "4. Dark Favor Currency", icon = "Interface\\Icons\\INV_Misc_Coin_02", header = "Earning & Stacking Favor", text = "As you play and complete active contracts, you earn |cffffd700Dark Favor|r, which serves as your primary progression currency.\n\n|cffffd700=> Look at your flashing Dark Favor & Sigil tallies in the top-left!|r", action = function() if PatronsLedger then PatronsLedger:Show() end FlashCurrencies() end },
    { title = "5. The Patron's Bazaar", icon = "Interface\\Icons\\INV_Box_01", header = "Purchasing Sanctions", text = "While resting in an Inn or Capital City, open the Bazaar tab to spend your accumulated Dark Favor on permanent unlocks.\n\n|cffffd700=> Notice the strobing 'Patron's Bazaar' tab button at the top right!|r", action = function() if PatronsLedger then PatronsLedger:Show() end currentView = "board" if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end FlashButtonStrobe(tabBazaarBtn) end },
    { title = "6. Sigils & Sovereign Awakening", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", header = "Endgame Bounties & High Gambles", text = "Hunt down Elites for Dark Sigils, or risk 30 Dark Favor via |cffffffffThe Sovereign Awakening|r for a 10% chance at an Apex Sigil.\n\n|cffffd700=> Look at the flashing Sovereign Awakening gamble card below!|r", action = function() if PatronsLedger then PatronsLedger:Show() end currentView = "bazaar" if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end HighlightCards(storeCardsList, {12}) end }
}

local skipBtn, nextBtn, prevBtn

function UpdateTutorialPage()
    local page = tutorialPages[currentStep]
    WelcomeModal.Title:SetText(page.title); WelcomeModal.PageIndicator:SetText(string.format("%d / %d", currentStep, #tutorialPages)); WelcomeModal.StepIcon:SetTexture(page.icon); WelcomeModal.SubHeader:SetText(page.header); WelcomeModal.Content:SetText(page.text)
    if tabBoardBtn then tabBoardBtn:Disable() end; if tabBazaarBtn then tabBazaarBtn:Disable() end
    if currentStep == #tutorialPages then if nextBtn then nextBtn:SetText("Close") end if skipBtn then skipBtn:Hide() end else if nextBtn then nextBtn:SetText("Next") end if skipBtn then skipBtn:Show() end end
    if page.action then page.action() end
end

prevBtn = CreateFrame("Button", nil, WelcomeModal, "UIPanelButtonTemplate"); prevBtn:SetSize(80, 22); prevBtn:SetPoint("BOTTOMLEFT", 20, 15); prevBtn:SetText("Previous"); prevBtn:SetScript("OnClick", function() if currentStep > 1 then currentStep = currentStep - 1 UpdateTutorialPage() end end)
skipBtn = CreateFrame("Button", nil, WelcomeModal, "UIPanelButtonTemplate"); skipBtn:SetSize(90, 22); skipBtn:SetPoint("BOTTOM", 0, 15); skipBtn:SetText("Skip Tutorial"); skipBtn:SetScript("OnClick", function() ClearAllHighlights() if tabBoardBtn then tabBoardBtn:Enable() end if tabBazaarBtn then tabBazaarBtn:Enable() end WelcomeModal:Hide() end)
nextBtn = CreateFrame("Button", nil, WelcomeModal, "UIPanelButtonTemplate"); nextBtn:SetSize(80, 22); nextBtn:SetPoint("BOTTOMRIGHT", -20, 15); nextBtn:SetText("Next"); nextBtn:SetScript("OnClick", function() if currentStep < #tutorialPages then currentStep = currentStep + 1 UpdateTutorialPage() else ClearAllHighlights() if tabBoardBtn then tabBoardBtn:Enable() end if tabBazaarBtn then tabBazaarBtn:Enable() end WelcomeModal:Hide() end end)

-- =====================================================================
-- IMMERSION: WHISPERS & CINEMATIC SPLASH
-- =====================================================================
PatronWhisper = function(msg)
    local info = ChatTypeInfo["MONSTER_WHISPER"]
    DEFAULT_CHAT_FRAME:AddMessage("The Dark Patron whispers: " .. msg, info.r, info.g, info.b)
end

local SplashFrame = CreateFrame("Frame", "DarkPatronSplash", UIParent)
SplashFrame:SetSize(400, 150)
SplashFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
SplashFrame:SetFrameStrata("DIALOG")
SplashFrame:Hide()

SplashFrame.Header = SplashFrame:CreateFontString(nil, "OVERLAY", "QuestFont_Enormous")
SplashFrame.Header:SetPoint("TOP", 0, 0)
SplashFrame.Header:SetText("PACT FULFILLED")
SplashFrame.Header:SetTextColor(1, 0.82, 0) -- Gold

SplashFrame.RewardText = SplashFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
SplashFrame.RewardText:SetPoint("TOP", SplashFrame.Header, "BOTTOM", 0, -10)
SplashFrame.RewardText:SetTextColor(0.64, 0.21, 0.93) -- Epic Purple

-- Awesome pop-in and fade-out animation sequence
SplashFrame.Anim = SplashFrame:CreateAnimationGroup()
local scaleUp = SplashFrame.Anim:CreateAnimation("Scale")
scaleUp:SetScaleFrom(0.5, 0.5); scaleUp:SetScaleTo(1.2, 1.2); scaleUp:SetDuration(0.2); scaleUp:SetOrder(1)
local scaleSettle = SplashFrame.Anim:CreateAnimation("Scale")
scaleSettle:SetScaleFrom(1.2, 1.2); scaleSettle:SetScaleTo(1.0, 1.0); scaleSettle:SetDuration(0.2); scaleSettle:SetOrder(2)
local fadeSplash = SplashFrame.Anim:CreateAnimation("Alpha")
fadeSplash:SetFromAlpha(1); fadeSplash:SetToAlpha(0); fadeSplash:SetDuration(1.0); fadeSplash:SetStartDelay(2.5); fadeSplash:SetOrder(3)

SplashFrame.Anim:SetScript("OnFinished", function() SplashFrame:Hide() end)

local function PlayCinematicSplash(rewardMsg)
    SplashFrame.RewardText:SetText(rewardMsg)
    SplashFrame:SetAlpha(1)
    SplashFrame:Show()
    SplashFrame.Anim:Stop()
    SplashFrame.Anim:Play()
    -- Heavy thematic sound queue (Quest Complete + Deep Bell)
    PlaySound(878)
end

local ToastFrame = CreateFrame("Frame", "DarkPatronToast", UIParent, "BackdropTemplate")
ToastFrame:SetSize(300, 45)
ToastFrame:SetPoint("TOP", UIParent, "TOP", 0, -120)
ToastFrame:SetFrameStrata("DIALOG")
ToastFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
ToastFrame:SetBackdropColor(0.64, 0.21, 0.93, 0.9)
ToastFrame:Hide()

ToastFrame.Text = ToastFrame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
ToastFrame.Text:SetPoint("CENTER")

ToastFrame.AnimGroup = ToastFrame:CreateAnimationGroup()
local fadeOut = ToastFrame.AnimGroup:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1); fadeOut:SetToAlpha(0); fadeOut:SetDuration(1.5); fadeOut:SetStartDelay(3.5)
ToastFrame.AnimGroup:SetScript("OnFinished", function() ToastFrame:Hide() end)

ShowPatronToast = function(message)
    ToastFrame.Text:SetText(message)
    ToastFrame:SetAlpha(1)
    ToastFrame:Show()
    ToastFrame.AnimGroup:Stop()
    ToastFrame.AnimGroup:Play()
    PlaySound(3175) 
end

RecordCompletedPact = function(mission)
    if mission.rarity == "Elite" or mission.rarity == "Rare Elite" or mission.rarity == "Boss" then
        DarkPatronDB.CompletedElites = DarkPatronDB.CompletedElites or {}
        local guid = UnitGUID("player") or "Unknown"
        table.insert(DarkPatronDB.CompletedElites, mission.id .. "-" .. guid)
    else
        DarkPatronDB.RecentlyCompleted = DarkPatronDB.RecentlyCompleted or {}
        table.insert(DarkPatronDB.RecentlyCompleted, 1, mission.trigger .. (mission.targetName or ""))
        if #DarkPatronDB.RecentlyCompleted > 6 then table.remove(DarkPatronDB.RecentlyCompleted) end
    end
end

RefillMissionPool = function(isRetry)
    DarkPatronDB.PoolOfSix = DarkPatronDB.PoolOfSix or {}
    local safetyBrake = 0
    
    for slot = 1, 6 do
        while not DarkPatronDB.PoolOfSix[slot] and safetyBrake < 100 do
            safetyBrake = safetyBrake + 1
            local rareCount = 0
            for _, m in pairs(DarkPatronDB.ActiveMissions) do if m.rarity == "Rare" then rareCount = rareCount + 1 end end
            for _, m in pairs(DarkPatronDB.PoolOfSix) do if m.rarity == "Rare" then rareCount = rareCount + 1 end end
            
            local newContract = GenerateProceduralContract(rareCount == 0)
            local isDup = false
            for _, m in pairs(DarkPatronDB.ActiveMissions) do if m.trigger == newContract.trigger and m.targetName == newContract.targetName then isDup = true break end end
            for _, m in pairs(DarkPatronDB.PoolOfSix) do if m.trigger == newContract.trigger and m.targetName == newContract.targetName then isDup = true break end end
            
            DarkPatronDB.RecentlyCompleted = DarkPatronDB.RecentlyCompleted or {}
            for _, t in ipairs(DarkPatronDB.RecentlyCompleted) do if t == (newContract.trigger .. (newContract.targetName or "")) then isDup = true break end end
            
            if not isDup then DarkPatronDB.PoolOfSix[slot] = newContract end
        end
    end
    
    local pLvl = UnitLevel("player") or 1
    local maxLvl = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC) and 70 or 60
    if pLvl >= maxLvl or devMode then
        tabApexBtn:SetAlpha(1)
    else
        tabApexBtn:SetAlpha(0.5)
    end

    if (not DarkPatronDB.DungeonBounties or #DarkPatronDB.DungeonBounties == 0) and not isRetry and DarkPatronDB.HasSeenIntro then
        if pLvl == maxLvl and math.random(1, 100) <= 15 then
            if GenerateAllRaidContracts then
                local raidStack = GenerateAllRaidContracts(pLvl)
                if raidStack and #raidStack > 0 then
                    DarkPatronDB.DungeonBounties = raidStack
                    if ShowPatronToast then ShowPatronToast("A Legendary Raid Stack has appeared in the Ledger!") end
                end
            end
		--[[
        elseif math.random(1, 100) <= 25 then
            if GenerateAllDungeonContracts then
                local newStack = GenerateAllDungeonContracts(pLvl)
                if newStack and #newStack > 0 then
                    DarkPatronDB.DungeonBounties = newStack
                    if ShowPatronToast then ShowPatronToast("A new Elite Dungeon Pact stack has appeared in the Ledger!") end
                end
            end
			]]--
        end
    end

    if #DarkPatronDB.PoolOfSix < 6 and not isRetry then
        DarkPatronDB.RecentlyCompleted = {}
        RefillMissionPool(true)
    end
end

-- =====================================================================
-- 7. LIVE COMBAT & PROGRESS EVALUATION ENGINE
-- =====================================================================
local function FulfillMission(index, mission)
    if mission.phases and #mission.phases > 0 then
        local nextPhase = table.remove(mission.phases, 1)
        mission.trigger = nextPhase.trigger
        mission.goal = nextPhase.goal
        mission.desc = nextPhase.desc
        mission.current = 0
        if nextPhase.targetName then mission.targetName = nextPhase.targetName end
        
        PlaySound(878)
        PatronWhisper("The tithe deepens. A new phase of your contract begins.")
        UpdateTracker()
        if Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end
        return
    end
    local rewardString = ""; local currentTime = time()
    
    local currentStreak = DarkPatronDB.CurrentStreak or 0
    local lastPactTime = DarkPatronDB.LastPactTime or 0
    
    if currentStreak > 0 and lastPactTime > 0 then
        if (currentTime - lastPactTime) >= 1200 then 
            currentStreak = 0
        end
    end

    DarkPatronDB.CurrentStreak = currentStreak + 1
    DarkPatronDB.PeakStreak = math.max(DarkPatronDB.PeakStreak or 0, DarkPatronDB.CurrentStreak)
    DarkPatronDB.LastPactTime = currentTime
    
    local streakBonus = 0
    if DarkPatronDB.CurrentStreak > 0 and DarkPatronDB.CurrentStreak % 5 == 0 then 
        streakBonus = 2; PlaySound(565853); 
        
        local streakWhispers = {
            "Five pacts executed flawlessly. The blood of your victims stains the soil of Azeroth, mortal. A highly profitable streak... take your cut.",
            "Five souls harvested in rapid succession. A magnificent tithe to the Dark Patron. The shadows drink your offerings. Claim your Favor and continue the slaughter.",
            "Five threads severed. Every life you end deepens your dark covenant. Claim your miserable Favor, mortal, until the day your own blood is claimed.",
            "Five lives ended. The veil grows thinner with every soul you send across it. Take your reward, anomaly. The darkness hungers."
        }
        
        PatronWhisper(streakWhispers[math.random(#streakWhispers)]) 
    end

    if mission.isLegendary then 
        DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + 1; 
        DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + 35 + streakBonus; 
        rewardString = string.format("+1 Apex Sigil, +%d Dark Favor", 35 + streakBonus); 
        if streakBonus > 0 then rewardString = rewardString .. " (Combo Bonus!)" end 
    elseif mission.rarity == "Rare Elite" or mission.rarity == "Boss" then 
        DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + 1; 
        rewardString = "+1 Apex Sigil"; 
    elseif mission.rarity == "Elite" then 
        local sigilsEarned = mission.sigils or 1
        DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils + sigilsEarned
        
        local favorEarned = mission.favor or 0
        if favorEarned > 0 then
            DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + favorEarned
        end
        
        rewardString = string.format("+%d Dark Sigil%s", sigilsEarned, sigilsEarned > 1 and "s" or "")
        if favorEarned > 0 then
            rewardString = rewardString .. string.format(", +%d Dark Favor", favorEarned)
        end
    else 
        local favorEarned = (mission.favor or 1) + streakBonus; 
        DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + favorEarned; 
        rewardString = string.format("+%d Dark Favor", favorEarned); 
        if streakBonus > 0 then rewardString = rewardString .. " (Combo Bonus!)" end 
    end
    
    PlayCinematicSplash(rewardString); DP_EvaluateBazaarAlert()
	
    DarkPatronDB.TotalPactsCompleted = (DarkPatronDB.TotalPactsCompleted or 0) + 1
    DarkPatronDB.ContractTypesCompleted = DarkPatronDB.ContractTypesCompleted or {}
    DarkPatronDB.ContractTypesCompleted[mission.trigger] = (DarkPatronDB.ContractTypesCompleted[mission.trigger] or 0) + 1

    if (mission.rarity == "Elite" or mission.rarity == "Rare Elite" or mission.rarity == "Boss") and mission.trigger ~= "DUNGEON_BOSS_KILL" then
        if not DarkPatronDB.FirstEliteKilled then DarkPatronDB.FirstEliteKilled = mission.targetName or "a nameless terror" end
    end
    
    -- Construct a rich hyperlink for chat output
    local color = "ffffffff"
    if mission.rarity == "Rare" then color = "ff0070dd"
    elseif mission.rarity == "Elite" then color = "ffa335ee"
    elseif mission.rarity == "Rare Elite" or mission.rarity == "Boss" then color = "ffff8000" end

    local title = mission.title and tostring(mission.title):gsub(":", ""):gsub("%[", ""):gsub("%]", "") or "Pact"
    local desc = mission.desc and tostring(mission.desc):gsub(":", ""):gsub("\n", " ") or ""
    local rewardTextFull = mission.rewardText and tostring(mission.rewardText):gsub(":", "") or ""

    local hyperlink = string.format("\124c%s\124Hdpact:%s:%s:%s:%s\124h[%s]\124h\124r", color, title, mission.rarity or "Standard", desc, rewardTextFull, title)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("DARK PATRON: Contract Fulfilled %s!", hyperlink))

    if mission.id == "LEGENDARY_BLOOD_TITHE" then
        DarkPatronAccountDB = DarkPatronAccountDB or {}
        DarkPatronAccountDB.LegacyUnlocked = true
        PlaySound(8959)
        print("|cffffd700[Dark Patron]: THE BLOOD TITHE IS COMPLETE. Your lineage has earned the Patron's eternal favor. All future characters will inherit this legacy.|r")
    end

    RecordCompletedPact(mission); 
    table.remove(DarkPatronDB.ActiveMissions, index); 
    RefillMissionPool(); 
    if Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end; 
    UpdateTracker()
end

local lastQuestCount = 0

local function CheckCombatProgress(event, ...)
    if not DarkPatronDB or not DarkPatronDB.ActiveMissions then return end

    if event == "PLAYER_DEAD" then
        for i = #DarkPatronDB.ActiveMissions, 1, -1 do 
            local mission = DarkPatronDB.ActiveMissions[i]
            if mission.trigger == "FLAWLESS_KILL" then 
                mission.current = 0 
                UpdateTracker() 
            end 
        end
        
        -- Check if death is actually permanent (Official Hardcore, Addon Hardcore, or Self-Found)
        local isHardcoreActive = (C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive()) or IsSelfFound()
        
        if isHardcoreActive and not DarkPatronDB.IsDead then
            DarkPatronDB.IsDead = true
            local pName = UnitName("player") or "The Wanderer"; local pLvl = UnitLevel("player") or 1; local zone = GetRealZoneText() or "an unforgiving land"; local subZone = GetSubZoneText(); local location = subZone ~= "" and (subZone .. ", " .. zone) or zone
            local epitaph = string.format("But the path of the mercenary is short, and all blood debts are eventually collected.\n\nHere, the Chronicle ends.\n\nAt level %d, %s drew their final breath in %s. The Patron's protection faltered, and the mortal coil was severed. Their remaining pacts are void, their hoarded Favor is lost to the dust, and their name becomes but a forgotten whisper across Azeroth.\n\nRequiescat in pace.", pLvl, pName, location)
            DarkPatronDB.DeathEpitaph = epitaph
        end
    end
    
    if event == "QUEST_TURNED_IN" then
        for i = #DarkPatronDB.ActiveMissions, 1, -1 do
            local mission = DarkPatronDB.ActiveMissions[i]
            if mission.trigger == "QUEST_COMPLETE" then 
                mission.current = mission.current + 1
                if mission.current >= mission.goal then 
                    FulfillMission(i, mission) 
                else 
                    UpdateTracker() 
                end 
            end
        end
    end
    
    if event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        local pName = UnitName("player")
        if msg:find(pName .. " has defeated .* in a duel to the death") then
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                local mission = DarkPatronDB.ActiveMissions[i] 
                if mission.trigger == "MAKGORA_WIN" then 
                    mission.current = mission.current + 1; 
                    if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                end 
            end
        elseif msg:find("You have defeated .* in a duel") and not msg:find("to the death") then
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                local mission = DarkPatronDB.ActiveMissions[i] 
                if mission.trigger == "DUEL_WIN" then 
                    mission.current = mission.current + 1; 
                    if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                end 
            end
        end
        
        if msg:find("Discovered .*") or msg:find("discovered .*") then
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                local mission = DarkPatronDB.ActiveMissions[i]
                if mission.trigger == "EXPLORE_ZONES" then
                    mission.current = mission.current + 1
                    if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                end
            end
        end
    end

    if event == "CHAT_MSG_MONEY" then
        local msg = ...; local copperEarned = 0
        local g = msg:match("(%d+) Gold") if g then copperEarned = copperEarned + (tonumber(g) * 10000) end
        local s = msg:match("(%d+) Silver") if s then copperEarned = copperEarned + (tonumber(s) * 100) end
        local c = msg:match("(%d+) Copper") if c then copperEarned = copperEarned + tonumber(c) end
        
        if copperEarned > 0 then
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                local mission = DarkPatronDB.ActiveMissions[i] 
                if mission.trigger == "MONEY_LOOT" then 
                    mission.current = mission.current + copperEarned; 
                    if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                end 
            end
        end
    end

    if event == "CHAT_MSG_LOOT" then
        local msg = ...
        for i = #DarkPatronDB.ActiveMissions, 1, -1 do
            local mission = DarkPatronDB.ActiveMissions[i]
            if mission.trigger == "LOOT_JUNK" and msg:match("|cff9d9d9d.-|r") then 
                mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
            elseif mission.trigger == "LOOT_ANY" and (msg:find("You receive loot") or msg:find("You create")) then 
                mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
            elseif mission.trigger == "FETCH_ITEM" and mission.targetName then 
                if msg:find(mission.targetName) then 
                    local qty = msg:match("x(%d+)%."); mission.current = mission.current + (qty and tonumber(qty) or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                end 
            elseif mission.trigger == "FISH_CATCH" and msg:find("You receive loot") then
                if IsEquippedItemType("Fishing Poles") then
                    local qty = msg:match("x(%d+)%."); mission.current = mission.current + (qty and tonumber(qty) or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                end
            end
        end
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2 = CombatLogGetCurrentEventInfo()
        local amount = 0; local spellSchool = 0; local missType = nil; local spellName = ""; local blockedAmount = 0

        if subEvent == "SWING_DAMAGE" then 
            amount, _, _, _, blockedAmount = select(12, CombatLogGetCurrentEventInfo())
        elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then 
            spellSchool = select(14, CombatLogGetCurrentEventInfo())
            amount, _, _, _, blockedAmount = select(15, CombatLogGetCurrentEventInfo())
        elseif subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then 
            spellSchool = select(14, CombatLogGetCurrentEventInfo()); amount = select(15, CombatLogGetCurrentEventInfo())
        elseif subEvent == "SWING_MISSED" then
            missType = select(12, CombatLogGetCurrentEventInfo())
        elseif subEvent == "RANGE_MISSED" or subEvent == "SPELL_MISSED" then 
            missType = select(15, CombatLogGetCurrentEventInfo())
        elseif subEvent == "SPELL_AURA_APPLIED" then 
            spellName = select(13, CombatLogGetCurrentEventInfo())
        elseif subEvent == "ENVIRONMENTAL_DAMAGE" then 
            local envType, envAmount = select(12, CombatLogGetCurrentEventInfo()); if envType and type(envType) == "string" and string.upper(envType) == "FALLING" then amount = tonumber(envAmount) or 0 end 
        end
        
        if sourceGUID == UnitGUID("player") or sourceGUID == UnitGUID("pet") then
        
            -- NEW: Overkill & Drain Tracking
            if amount and amount > 0 then
                for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                    local mission = DarkPatronDB.ActiveMissions[i]
                    if mission.trigger == "OVERKILL_STRIKE" and amount >= mission.goal then
                        mission.current = mission.goal
                        FulfillMission(i, mission)
                    elseif mission.trigger == "MOB_DRAIN" and (spellName == "Drain Life" or spellName == "Drain Soul" or spellName == "Mana Burn" or spellName == "Siphon Life") then
                        mission.current = mission.current + amount
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    end
                end
            end

            -- NEW: Crowd Control & Purges
            if subEvent == "SPELL_AURA_APPLIED" then
                local ccSpells = { ["Polymorph"]=true, ["Sap"]=true, ["Freezing Trap"]=true, ["Fear"]=true, ["Shackle Undead"]=true, ["Gouge"]=true, ["Hibernate"]=true, ["Blind"]=true, ["Psychic Scream"]=true, ["Howl of Terror"]=true }
                if ccSpells[spellName] then
                    for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                        local mission = DarkPatronDB.ActiveMissions[i]
                        if mission.trigger == "CROWD_CONTROL" then
                            mission.current = mission.current + 1
                            if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                        end
                    end
                end
            end

            if subEvent == "SPELL_DISPEL" or subEvent == "SPELL_STOLEN" or subEvent == "SPELL_DISPEL_FAILED" then
                for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                    local mission = DarkPatronDB.ActiveMissions[i]
                    if mission.trigger == "DISPEL_PURGE" then
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    end
                end
            end
            
            local dealtNature = false
            if spellSchool and bit.band(spellSchool, 8) > 0 then dealtNature = true end
            
            local dealtShadow = false
            if spellSchool and bit.band(spellSchool, 32) > 0 then dealtShadow = true end
            
            local dealtAnyDamage = (subEvent == "SWING_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE")
            
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                local mission = DarkPatronDB.ActiveMissions[i]
                
                -- Hard Resets
                if mission.trigger == "PURITY_KILL" and dealtShadow then
                    if mission.current > 0 then mission.current = 0; UpdateTracker() end
                end
                if mission.trigger == "PURITY_KILL_NATURE" and dealtNature then
                    if mission.current > 0 then mission.current = 0; UpdateTracker() end
                end
                if mission.trigger == "PACIFIST_SURVIVAL" and dealtAnyDamage then
                    if mission.current > 0 then mission.current = 0; UpdateTracker() end
                end

                -- Normal Increments
                if mission.trigger == "INTERRUPT_SPELL" and subEvent == "SPELL_INTERRUPT" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "SPELL_CAST_SUCCESS" and subEvent == "SPELL_CAST_SUCCESS" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "AURA_APPLIED" and subEvent == "SPELL_AURA_APPLIED" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "CONSUME_FOOD" and subEvent == "SPELL_AURA_APPLIED" then if spellName == "Food" or spellName == "Drink" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "SWING_DAMAGE" and subEvent == "SWING_DAMAGE" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "ENCHANTED_SWING" and subEvent == "SWING_DAMAGE" then 
                    if HasTempWeaponEnchant() then 
                        mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                    end 
                end
                if mission.trigger == "UNARMED_DAMAGE" and subEvent == "SWING_DAMAGE" then local mainHandLink = GetInventoryItemLink("player", 16); if not mainHandLink then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "NAKED_COMBAT" and subEvent == "SWING_DAMAGE" then local chestLink = GetInventoryItemLink("player", 5); if not chestLink then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "ANY_DAMAGE" and (subEvent == "SWING_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE") then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "PHYSICAL_DAMAGE" then if subEvent == "SWING_DAMAGE" or (spellSchool == 1 and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE")) then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                
                -- Spell School Magic
                if mission.trigger == "FROST_DAMAGE" and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE") then if spellSchool and bit.band(spellSchool, 16) > 0 then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "SHADOW_DAMAGE" and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE") then if spellSchool and bit.band(spellSchool, 32) > 0 then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "NATURE_DAMAGE" and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE") then if spellSchool and bit.band(spellSchool, 8) > 0 then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "ARCANE_DAMAGE" and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE") then if spellSchool and bit.band(spellSchool, 64) > 0 then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "HOLY_FIRE_DAMAGE" and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE") then if spellSchool and (bit.band(spellSchool, 2) > 0 or bit.band(spellSchool, 4) > 0) then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                
                if mission.trigger == "CRIT_STRIKE" and subEvent:find("DAMAGE") then
                    local isCrit = false
                    if subEvent == "SWING_DAMAGE" then isCrit = select(18, CombatLogGetCurrentEventInfo()) else isCrit = select(21, CombatLogGetCurrentEventInfo()) end
                    if isCrit then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                end
            end
        end

        -- ==========================================
        -- KILL BOUNTIES (BULLETPROOF BOSS & XP KILLS)
        -- ==========================================
        local destNpcID = 0
        if destGUID then
            local _, _, _, _, _, idStr = strsplit("-", destGUID)
            if idStr then destNpcID = tonumber(idStr) or 0 end
        end

        if subEvent == "UNIT_DIED" and DungeonBossDB[destNpcID] then
            local currentZoneName = GetInstanceInfo()
            
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                local mission = DarkPatronDB.ActiveMissions[i]
                if mission.trigger == "DUNGEON_BOSS_KILL" then 
                    local isCorrectZone = false
                    if currentZoneName and currentZoneName ~= "" and mission.targetName then
                        if string.find(mission.targetName, currentZoneName, 1, true) or string.find(currentZoneName, mission.targetName, 1, true) then
                            isCorrectZone = true
                        end
                        if string.find(currentZoneName, "Atal'Hakkar") and string.find(mission.targetName, "Atal'Hakkar") then
                            isCorrectZone = true
                        end
                    end

                    if isCorrectZone then
                        if devMode or IsGroupValidForDungeon(mission.targetInstanceID) then
                            mission.current = mission.current + 1
                            if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                        else
                            print("|cffff0000[Dark Patron]: Boss kill invalidated! Group level restriction failed.|r")
                        end
                    end
                end
            end
        end

        -- 2. STANDARD KILLS (Filtered by XP, uses PARTY_KILL)
        if subEvent == "PARTY_KILL" then
            local targetLvl = UnitLevel("target")
            local awardsXp = true 
            
            if targetLvl and targetLvl > 0 and not devMode then
                awardsXp = GivesExperience(targetLvl)
            end

            if awardsXp then
                -- Build contextual flags for this exact kill
                local creatureType = UnitCreatureType("target") or ""
                local hasBuffs = false
                local hasDebuffs = false
                for b = 1, 40 do if UnitAura("player", b, "HELPFUL") then hasBuffs = true break end end
                for b = 1, 40 do if UnitAura("player", b, "HARMFUL") then hasDebuffs = true break end end
                
                local isGrayWep = false
                local mhLink = GetInventoryItemLink("player", 16)
                if mhLink then
                    local _, _, quality = GetItemInfo(mhLink)
                    if quality == 0 or quality == 1 then isGrayWep = true end
                else
                    isGrayWep = true -- Unarmed counts as poor weapon
                end
                
                for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                    local mission = DarkPatronDB.ActiveMissions[i]
                    if mission.trigger == "PARTY_KILL" then 
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    -- NEW TRACKERS
                    elseif mission.trigger == "TYPED_KILL" and creatureType == mission.targetName then
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    elseif mission.trigger == "NO_BUFF_KILL" and not hasBuffs then
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    elseif mission.trigger == "DEBUFFED_KILL" and hasDebuffs then
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    elseif mission.trigger == "GRAY_WEAPON_KILL" and isGrayWep then
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    -- END NEW TRACKERS
                    elseif mission.trigger == "PURITY_KILL" or mission.trigger == "PURITY_KILL_NATURE" then 
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    elseif mission.trigger == "FLAWLESS_KILL" then
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    elseif mission.trigger == "WELL_FED_KILL" then 
                        if IsWellFed() then 
                            mission.current = mission.current + 1
                            if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                        end
                    elseif mission.trigger == "HONORABLE_KILL" then 
                        local isPlayer = bit.band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) > 0
                        if isPlayer then 
                            mission.current = mission.current + 1
                            if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                        end
                    elseif mission.trigger == "RISKY_KILL" then 
                        local hpMax = UnitHealthMax("player")
                        if hpMax and hpMax > 0 and (UnitHealth("player") / hpMax) <= 0.33 then 
                            mission.current = mission.current + 1
                            if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                        end
                    elseif mission.trigger == "SPECIFIC_KILL" and destName == mission.targetName then 
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                    end
                end
            else
                -- If the kill DOES NOT award XP (Critters)
                local tLevel = UnitLevel("target")
                if tLevel and tLevel == 1 then
                    for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                        local mission = DarkPatronDB.ActiveMissions[i]
                        if mission.trigger == "CRITTER_SLAUGHTER" then
                            mission.current = mission.current + 1
                            if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                        end
                    end
                end
            end
        end

        -- ACTIONS SUFFERED BY PLAYER (INCOMING DAMAGE / DEFENSE)
        if destGUID == UnitGUID("player") then
            local tookDamage = (subEvent == "SWING_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" or subEvent == "ENVIRONMENTAL_DAMAGE")
            
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                local mission = DarkPatronDB.ActiveMissions[i]
                
                -- Hard Resets
                if mission.trigger == "FLAWLESS_KILL" and tookDamage and amount and amount > 0 then
                    if mission.current > 0 then mission.current = 0; UpdateTracker() end
                end
                
                -- Normal Increments
                if mission.trigger == "PACIFIST_SURVIVAL" and tookDamage and amount and amount > 0 then mission.current = mission.current + amount; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "FALLING_DAMAGE" and subEvent == "ENVIRONMENTAL_DAMAGE" and amount > 0 then mission.current = mission.current + amount; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "DAMAGE_TAKEN" and subEvent:find("DAMAGE") then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "HEALING_RECEIVED" and (subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL") then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "DROWNING_SURVIVAL" and subEvent == "ENVIRONMENTAL_DAMAGE" then 
                    local envType = select(12, CombatLogGetCurrentEventInfo())
                    if envType and type(envType) == "string" and string.upper(envType) == "DROWNING" then 
                        mission.current = mission.current + 1; 
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                    end 
                end
                if (subEvent == "SWING_MISSED" or subEvent == "RANGE_MISSED" or subEvent == "SPELL_MISSED") then
                    if mission.trigger == "DEFENSE_ROLL" and (missType == "PARRY" or missType == "DODGE" or missType == "BLOCK") then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    elseif mission.trigger == "DODGE_ATTACK" and missType == "DODGE" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                end
                if (subEvent == "SWING_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE") then
                    if mission.trigger == "DEFENSE_ROLL" and (blockedAmount and blockedAmount > 0) then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                end
            end
        end
    end
end

-- =====================================================================
-- 8. EVENT REGISTRATION & RESTRICTION HANDLERS
-- =====================================================================
DP_Core:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "DarkPatron" then
			DarkPatronDB = DarkPatronDB or {}
			for k, v in pairs(defaults) do
				if DarkPatronDB[k] == nil then
					DarkPatronDB[k] = v
				end
			end
			
            -- Sanitize & Safe-Initialize all values
			if DarkPatronDB.ActiveMissions then
				for _, m in ipairs(DarkPatronDB.ActiveMissions) do
					m.current = m.current or 0
					m.goal = m.goal or 1
					if m.isTimed then
                        if m.timeRemaining then
                            m.expiresAt = time() + m.timeRemaining
                            m.timeRemaining = nil
                        elseif not m.expiresAt then
                            m.expiresAt = time() + (m.timeLimit or 900)
                        end
					end
				end
			end

			if DarkPatronDB.DungeonBounty then DarkPatronDB.DungeonBounties = { DarkPatronDB.DungeonBounty }; DarkPatronDB.DungeonBounty = nil end
            DarkPatronDB.RecentlyCompleted = DarkPatronDB.RecentlyCompleted or {}
            DarkPatronDB.CompletedElites = DarkPatronDB.CompletedElites or {}
            DarkPatronDB.CurrentStreak = DarkPatronDB.CurrentStreak or 0
            
            DarkPatronAccountDB = DarkPatronAccountDB or {}
            if DarkPatronAccountDB.LegacyUnlocked and not DarkPatronDB.LegacyClaimed then
                DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + 100
                DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils + 1
                DarkPatronDB.MaxActiveSlots = 4
                DarkPatronDB.MaxGearQuality = 2
                DarkPatronDB.LegacyClaimed = true
                print("|cffffd700[Dark Patron]: The Sovereign's Legacy flows through your veins. You begin with the Patron's Blessing.|r")
            end
            
            if not DarkPatronDB.PoolOfSix or #DarkPatronDB.PoolOfSix == 0 then RefillMissionPool() end
            UpdateTracker()
			
            C_Timer.NewTicker(1, function()
                if DarkPatronDB then
                    -- 1. Live Streak Expiration Check
                    if (DarkPatronDB.CurrentStreak or 0) > 0 and (DarkPatronDB.LastPactTime or 0) > 0 then
                        if (time() - DarkPatronDB.LastPactTime) >= 1200 then
                            DarkPatronDB.CurrentStreak = 0
                            PatronWhisper("Your momentum wanes. The streak has crumbled to dust.")
                            UpdateTracker()
                        end
                    end

                    -- 2. Board Refresh Check
                    if not DarkPatronDB.LastBoardRefresh or DarkPatronDB.LastBoardRefresh == 0 then 
						DarkPatronDB.LastBoardRefresh = time() 
					end
                    
                    local timeSinceRefresh = time() - DarkPatronDB.LastBoardRefresh
                    local timeUntilNext = 3600 - timeSinceRefresh -- 1 Hour Timer
                    
                    if timeUntilNext <= 0 then
                        DarkPatronDB.PoolOfSix = {}; DarkPatronDB.LastBoardRefresh = time(); RefillMissionPool()
                        if Ledger and Ledger:IsShown() and currentView == "board" then
                            Ledger:GetScript("OnShow")(Ledger); print("|cffffd700[Dark Patron]: Other mortals have claimed the old pacts. The board has been refreshed.|r")
                        end
                        timeUntilNext = 3600
                    end

                    if Ledger and Ledger:IsShown() and currentView == "board" and autoRefreshTimerText then
                        autoRefreshTimerText:SetText(string.format("Auto refresh in: %02d:%02d", math.floor(timeUntilNext / 60), timeUntilNext % 60))
                    end
                end

                -- 3. Active Missions Fallback & Timers
                if DarkPatronDB and DarkPatronDB.ActiveMissions then
                    local needsUpdate = false
                    for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                        local m = DarkPatronDB.ActiveMissions[i]
                        if m and m.current and m.goal and (m.current >= m.goal) and not m.failed then
                            FulfillMission(i, m); needsUpdate = true
                        elseif m and m.isTimed then
                            if not m.expiresAt then m.expiresAt = time() + (m.timeLimit or 900) end
                            if type(m.expiresAt) == "number" and time() >= m.expiresAt and not m.failed then
                                m.failed = true; m.trigger = "FAILED"; DarkPatronDB.CurrentStreak = 0; DarkPatronDB.FailedPactsCount = (DarkPatronDB.FailedPactsCount or 0) + 1
								PatronWhisper("Time is a luxury you do not possess. Another pact wasted.")
                                print(string.format("|cffff0000[Dark Patron]: The timer has expired for '%s'! You must pay the toll to discard this failed pact and free your slot.|r", m.title))
                                if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end
                            end
                            needsUpdate = true
                        end
                    end
                    if needsUpdate then UpdateTracker() end
                end
                
                -- 4. Live update Ledger UI timer counters
                if Ledger and Ledger:IsShown() then
                    local maxSlots = DarkPatronDB.MaxActiveSlots or 3
                    for i = 1, maxSlots do
                        local mData = DarkPatronDB.ActiveMissions[i]
                        if mData and mData.isTimed then
                            if not mData.expiresAt then mData.expiresAt = time() + (mData.timeLimit or 900) end
                            if type(mData.expiresAt) == "number" and not mData.failed then
                                local remain = mData.expiresAt - time()
                                if remain > 0 then activeCards[i].reward:SetText(mData.rewardText .. string.format("\n|cffaaaaaaLeft: %02d:%02d|r", math.floor(remain / 60), remain % 60)) else activeCards[i].reward:SetText(mData.rewardText .. "\n|cffff0000FAILED|r") end
                            end
                        end
                    end
                end
                
                -- 5. Grand Sanctions Aura Stripper (World Buffs & Cheese Pots)
                local RestrictedAuras = {
                    [22888] = "WorldsBoon", [22817] = "WorldsBoon", [22818] = "WorldsBoon", [22820] = "WorldsBoon", 
                    [15366] = "WorldsBoon", [24425] = "WorldsBoon", [16609] = "WorldsBoon", [23768] = "WorldsBoon", 
                    [23735] = "WorldsBoon", [23736] = "WorldsBoon", [23737] = "WorldsBoon", [23738] = "WorldsBoon", 
                    [23766] = "WorldsBoon", [23769] = "WorldsBoon", [23767] = "WorldsBoon",
                    [3169] = "AlchemistSight", [17624] = "AlchemistSight", [13236] = "AlchemistSight", [6615] = "AlchemistSight"
                }
                for i = 1, 40 do
                    local name, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
                    if not name then break end
                    
                    if RestrictedAuras[spellId] == "WorldsBoon" and not DarkPatronDB.HasWorldsBoon then
                        CancelUnitBuff("player", i)
                        print(string.format("|cffff0000[Dark Patron]: The Veil rejects worldly blessings! %s was stripped. Purchase The World's Boon.|r", name))
                    elseif RestrictedAuras[spellId] == "AlchemistSight" and not DarkPatronDB.HasAlchemistSight then
                        CancelUnitBuff("player", i)
                        print(string.format("|cffff0000[Dark Patron]: Forbidden alchemy detected! %s was stripped. Purchase Alchemist's Sight.|r", name))
                    end
                end
            end)
            
        elseif addonName == "Blizzard_TalentUI" then
            local orig_PlayerTalentFrameTalent_OnClick = PlayerTalentFrameTalent_OnClick
            PlayerTalentFrameTalent_OnClick = function(self, button)
                if IsModifiedClick("CHATLINK") then
                    return orig_PlayerTalentFrameTalent_OnClick(self, button)
                end
                
                if GetSpentTalentPoints() >= (DarkPatronDB.MaxTalentsAllowed or 0) then
                    UIErrorsFrame:AddMessage("The Veil blocks your hand. Purchase a Grant of Knowledge.", 1.0, 0.1, 0.1, 1.0)
                    print("|cffff0000[Dark Patron]: The Veil blocks your hand. Purchase a Grant of Knowledge.|r")
                    return
                end
                
                return orig_PlayerTalentFrameTalent_OnClick(self, button)
            end
            
            local orig_LearnTalent = LearnTalent
            LearnTalent = function(tabIndex, talentIndex)
                if GetSpentTalentPoints() >= (DarkPatronDB.MaxTalentsAllowed or 0) then
                    UIErrorsFrame:AddMessage("The Veil blocks your hand. Purchase a Grant of Knowledge.", 1.0, 0.1, 0.1, 1.0)
                    return
                end
                return orig_LearnTalent(tabIndex, talentIndex)
            end

            local dpPointsText = PlayerTalentFrame:CreateFontString(nil, "OVERLAY")
            
            if PlayerTalentFrameTalentPointsText then
                dpPointsText:SetFontObject(PlayerTalentFrameTalentPointsText:GetFontObject())
            else
                dpPointsText:SetFontObject("GameFontNormalSmall")
            end
            
            dpPointsText:SetPoint("BOTTOM", PlayerTalentFrame, "BOTTOM", -95, 86) 

            local function UpdateDPTalentText()
                local maxAllowed = DarkPatronDB.MaxTalentsAllowed or 0
                local spent = GetSpentTalentPoints()
                local available = math.max(0, maxAllowed - spent)
                
                dpPointsText:SetText(string.format("Grants of Knowledge: |cffffffff%d|r", available))
            end

            PlayerTalentFrame:HookScript("OnShow", UpdateDPTalentText)
            
            DP_Core:HookScript("OnEvent", function(self, evt, ...) 
                if evt == "CHARACTER_POINTS_CHANGED" and PlayerTalentFrame and PlayerTalentFrame:IsShown() then 
                    UpdateDPTalentText() 
                end 
            end)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, castGUID, spellID = ...
        if unitTarget == "player" then
            local spellName = GetSpellInfo(spellID)
            if not spellName then return end

            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
                local mission = DarkPatronDB.ActiveMissions[i]
                
                -- CRAFTING
                if mission.trigger == "CRAFT_ITEM" and mission.targetName then
                    if spellName == mission.targetName then
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    end
                    
                -- GATHERING
                elseif mission.trigger == "GATHER_NODE" then
                    -- If the mission asks for a specific profession, enforce it!
                    if mission.targetName and mission.targetName ~= "" then
                        if spellName == mission.targetName then
                            mission.current = mission.current + 1
                            if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                        end
                    -- Fallback for any old, vague contracts still sitting in your active ledger
                    elseif spellName == "Mining" or spellName == "Herb Gathering" or spellName == "Skinning" then
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    end
                end
            end
        end
    elseif event == "BANKFRAME_OPENED" then
        if not DarkPatronDB.HasBank then CloseBankFrame(); print("|cffff0000[Dark Patron]: The Veil seals the vault! You must purchase The Hoarder's Key from the Bazaar to access the Bank.|r") end
    elseif event == "AUCTION_HOUSE_SHOW" then
        if not DarkPatronDB.HasAuction then CloseAuctionHouse(); print("|cffff0000[Dark Patron]: The Veil closes the market! You must purchase The Merchant's Writ from the Bazaar to access the Auction House.|r") end
    elseif event == "MAIL_SHOW" then
        if not DarkPatronDB.HasMail then CloseMail(); print("|cffff0000[Dark Patron]: The Veil blocks your messages! You must purchase The Courier's Seal from the Bazaar to access Mail.|r") end
    elseif event == "PLAYER_ENTERING_WORLD" then
        CheckViolations()
        if not DarkPatronDB.PoolOfSix or #DarkPatronDB.PoolOfSix == 0 then RefillMissionPool() end
        
        DarkPatronAccountDB = DarkPatronAccountDB or {}
        if not DarkPatronAccountDB.TutorialShown then 
            DarkPatronAccountDB.TutorialShown = true
            DarkPatronDB.HasSeenIntro = true

            C_Timer.After(1.5, function()
                currentStep = 1
                UpdateTutorialPage()
                PatronsLedger:Show()
                WelcomeModal:Show()
            end)
        else
            if not DarkPatronDB.HasSeenIntro then
                DarkPatronDB.HasSeenIntro = true
            end
        end

        UpdateTracker(); DP_EvaluateBazaarAlert()
	elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = arg1 or UnitLevel("player")
        
        CheckLevelMilestoneDungeons()
        
        print(string.format("|cffffd700[Dark Patron]: You have reached level %d. The Veil reveals new dungeon trials.|r", newLevel))
        
        if Ledger and Ledger:IsShown() then 
            Ledger:GetScript("OnShow")(Ledger) 
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then CheckViolations()
    elseif event == "PLAYER_REGEN_ENABLED" then if isViolating then CheckViolations() end
    elseif event == "PLAYER_UPDATE_RESTING" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end
	elseif event == "COMPANION_UPDATE" then
        if IsMounted() and DarkPatronDB then
            if IsFlying() and not DarkPatronDB.HasExpertCavalry then
                Dismount(); print("|cffff0000[Dark Patron]: The Veil forbids flying without an Expert's Cavalry Sanction! You are forcefully dismounted.|r")
            elseif not DarkPatronDB.HasJourneymanCavalry then
                Dismount(); print("|cffff0000[Dark Patron]: The Veil forbids riding without a Journeyman's Cavalry Sanction! You are forcefully dismounted.|r")
            end
        end
	elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        
        if prefix == "DP_JUSTICE" then
            local action, data = strsplit(":", text, 2)
            local amount = tonumber(data) or 0
            local cleanSender = strsplit("-", sender)
            
            if action == "DP_REPLY" then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[Developer Inbox] %s|r: %s", cleanSender, data or ""))
                PlaySound(3175)
                ShowPatronToast(string.format("Message from %s!", cleanSender))
                return
            end
            
            if HashIdentity(sender) == SOVEREIGN_HASH and DarkPatronDB then
                if action == "ADD_FAVOR" then
                    DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + amount
                    PlayCinematicSplash(string.format("Restitution: +%d Dark Favor", amount))
                    PatronWhisper("The Veil bends. Your lost Favor has been restored by the Sovereign.")
                elseif action == "ADD_SIGIL" then
                    DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils + amount
                    PlayCinematicSplash(string.format("Restitution: +%d Dark Sigil%s", amount, amount > 1 and "s" or ""))
                    PatronWhisper("Justice is served. The Sigil is yours.")
                elseif action == "ADD_APEX" then
                    DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + amount
                    PlayCinematicSplash("Restitution: +1 Apex Sigil")
                    PatronWhisper("An anomaly corrected. The Apex is restored.")
                elseif action == "REMOVE_FAVOR" then
                    DarkPatronDB.DarkFavor = math.max(0, DarkPatronDB.DarkFavor - amount)
                    PlayCinematicSplash(string.format("Sanction: -%d Dark Favor", amount))
                    PatronWhisper("The Patron has found you wanting. Your Favor is stripped.")
                elseif action == "REMOVE_SIGIL" then
                    DarkPatronDB.DarkSigils = math.max(0, DarkPatronDB.DarkSigils - amount)
                    PlayCinematicSplash(string.format("Sanction: -%d Dark Sigil%s", amount, amount > 1 and "s" or ""))
                    PatronWhisper("You have displeased the Sovereign. Your Sigils are revoked.")
                elseif action == "REMOVE_APEX" then
                    DarkPatronDB.ApexSigils = math.max(0, DarkPatronDB.ApexSigils - amount)
                    PlayCinematicSplash(string.format("Sanction: -%d Apex Sigil%s", amount, amount > 1 and "s" or ""))
                    PatronWhisper("A severe transgression. The Apex is reclaimed by the void.")
                
                elseif action == "GM_WHISPER" then
                    if ChatEdit_SetLastTell then
                        ChatEdit_SetLastTell("HoliestWoW")
                    end
                    
                    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ccffHoliestWoW (Developer)|r: %s", data or ""))
                    PlaySound(8959)
                    ShowPatronToast("New message from Developer. Press 'R' to reply.")
                end
                
                if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end
                UpdateTracker()
                DP_EvaluateBazaarAlert()
            end
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_MONEY" or event == "QUEST_TURNED_IN" or event == "QUEST_LOG_UPDATE" or event == "CHAT_MSG_SYSTEM" or event == "PLAYER_DEAD" then
        CheckCombatProgress(event, ...)
    elseif event == "PLAYER_LOGOUT" then
        if DarkPatronDB and DarkPatronDB.ActiveMissions then
            for _, m in ipairs(DarkPatronDB.ActiveMissions) do
                if m.isTimed and m.expiresAt then
                    local remain = m.expiresAt - time()
                    m.timeRemaining = math.max(remain, 0)
                end
            end
        end
    end
end)