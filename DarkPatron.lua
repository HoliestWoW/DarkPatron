-- =====================================================================
-- 1. DATABASE & INITIALIZATION
-- =====================================================================
local _, core = ...
local DP = CreateFrame("Frame", "DarkPatronCore")

local defaults = {
    DarkFavor = 0,
    DarkSigils = 0,
    ApexSigils = 0,
    MaxTalentsAllowed = 0,
    MaxGearQuality = 1, 
    MaxActiveSlots = 3, 
    HasJourneymanCavalry = false,
    HasMasterCavalry = false,
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
    CurrentStreak = 0,
    LastPactTime = 0,
    LastBoardRefresh = 0,
    HasInitializedAwakening = false, 
    HasSeenIntro = false,
    IsDead = false,
    DeathEpitaph = nil,
}

DP:RegisterEvent("ADDON_LOADED")
DP:RegisterEvent("PLAYER_ENTERING_WORLD")
DP:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
DP:RegisterEvent("CHARACTER_POINTS_CHANGED")
DP:RegisterEvent("PLAYER_REGEN_ENABLED")
DP:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
DP:RegisterEvent("CHAT_MSG_LOOT")
DP:RegisterEvent("CHAT_MSG_MONEY")
DP:RegisterEvent("CHAT_MSG_SYSTEM") 
DP:RegisterEvent("QUEST_TURNED_IN")
DP:RegisterEvent("QUEST_LOG_UPDATE")
DP:RegisterEvent("PLAYER_UPDATE_RESTING")
DP:RegisterEvent("ZONE_CHANGED_NEW_AREA")
DP:RegisterEvent("ZONE_CHANGED")
DP:RegisterEvent("BANKFRAME_OPENED")
DP:RegisterEvent("AUCTION_HOUSE_SHOW")
DP:RegisterEvent("MAIL_SHOW")
DP:RegisterEvent("PLAYER_LOGOUT")
DP:RegisterEvent("COMPANION_UPDATE")

local devMode = false

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

-- =====================================================================
-- 2. PROCEDURAL GRAMMAR, INTERNAL MAPPINGS & ROSTERS
-- =====================================================================

local RawEliteNames = {"Broken Tooth", "Princess Theradras", "Herod", "High Inquisitor Whitemane", "Humar the Pridelord", "Emperor Dagran Thaurissan", "Onyxia", "Edwin VanCleef", "Azuregos", "Qiaga the Keeper", "Lord Kazzak", "Ragnaros", "Baron Rivendare", "General Drakkisath", "Archmage Arugal", "Stitches", "Scarlet Commander Mograine", "Bhag'thera", "Prince Nazjak", "The Rake", "Hakkar", "Archaedas", "Arcanist Doan", "Blackmoss the Fetid", "Keyl Swiftclaw", "King Bangalash", "Nefarian", "Roogug", "Kel'Thuzad", "Plugger Spazzring", "Mekgineer Thermaplugg", "Amnennar the Coldbringer", "Rexxar", "Ursius", "Warchief Rend Blackhand", "Golem Lord Argelmach", "Shade of Eranikus", "Fozruk", "Varimathras", "Aku'mai", "Rin'wosho the Trader", "Teremus the Devourer", "Mok'rash", "Fineous Darkvire", "C'Thun", "Magistrate Barthilas", "Mutanus the Devourer", "Gri'lek", "Devilsaur", "Moam", "Houndmaster Loksey", "Sewer Beast", "Cavindra", "Darkmaster Gandling", "Buliwyf Stonehand", "Duke Hydraxis", "Pusillin", "Urok Doomhowl", "Anachronos", "Jandice Barov", "Overlord Wyrmthalak", "Lord Valthalak", "Tethis", "Ironspine", "General Angerforge", "King Mosh", "Chief Ukorz Sandscalp", "Bloodmage Thalnos", "Hogger", "Lorekeeper Lydros", "Woo Ping", "Grel'borg the Miser", "Balnazzar", "Nathanos Blightcaller", "Gorosh the Dervish", "Pyromancer Loregrain", "Ysondre", "Lupos", "Charlga Razorflank", "Rok'Alim the Pounder", "Zanza the Restless", "Sapphiron", "Ghost Howl", "Vultros", "Azshir the Sleepless", "Zaricotl", "Narillasanz", "Gahz'ranka", "Bael'Gar", "Princess Moira Bronzebeard", "Bloodlord Mandokir", "Ossirian the Unscarred", "Princess Tempestria", "Silithid Harvester", "Chromaggus", "Tirion Fordring", "Brumeran", "Guard Mol'dar", "Majordomo Executus", "Fallen Champion", "Illiyana Moonblaze", "Sever", "Dagun the Ravenous", "Scarshield Infiltrator", "Interrogator Vishas", "Haleh", "Rattlegore", "Taerar", "Lord Roccor", "Hazza'rah", "Immol'thar", "Kirtonos the Herald", "Highlord Taelan Fordring", "High Inquisitor Fairbanks", "Lethon", "Prince Tortheldrin", "Shadow Hunter Vosh'gajin", "Emeriss", "Olm the Wise", "Ras Frostwhisper", "Crowd Pummeler 9-60", "Loatheb", "General Marcus Jonathan", "Baelog", "Thaddius", "Jed Runewatcher", "Antu'sul", "Celebras the Redeemed", "Ambassador Flamelash", "Mad Magglish", "Viscidus", "Avalanchion", "Lorgus Jett", "Tendris Warpwood", "Alzzin the Wildshaper", "Pyroguard Emberseer", "Ol' Sooty", "Gahz'rilla", "Lady Anacondra", "Lord Cobrahn", "Rak'shiri", "Baron Geddon", "High Interrogator Gerstahn", "Patchwerk", "Blind Hunter", "Fallen Hero", "Lord Incendius", "The Duke of Cynders", "Thrall", "High Chief Winterfall", "High Priest Venoxis", "Garr", "Bjarn", "Gryan Stoutmantle", "Scarshield Quartermaster", "Ragglesnout", "Volchan", "Vaelastrasz the Corrupt", "Mazzranache", "The Beast", "Cobalt Mageweaver", "Scorn", "Broodlord Lashlayer", "Lord Serpentis", "Leprithus", "Highlord Omokk", "Shadra", "The Windreaver", "Vilebranch Raiding Wolf", "Ribbly Screwspigot", "War Master Voone", "Archmage Angela Dosantos", "Ansekhwa", "Nimar the Slayer", "Overlord Ramtusk", "Baron Charr", "Lord Pythas", "The Nameless Prophet", "Mr. Smite", "Isalien", "Razorgore the Untamed", "Magmus", "Deathmaw", "Marez Cowl", "Avatar of Hakkar", "Archibald", "Mogh the Undying", "Morphaz", "Verdan the Everliving", "Stone Guardian", "Death Flayer", "Kelm Hargunth", "Mor Grayhoof", "Captain Ironhill", "Rotgrip", "Warder Stilgiss", "Myzrael", "Vile Sting", "Phalanx", "Keeper Remulos", "Lo'Grosh", "Golemagg the Incinerator", "High Priest Thekal", "Andorgos", "Bazzalan", "Bazil Thredd", "Balgaras the Foul", "Tinkerer Gizlock", "Araj the Summoner", "Solakar Flamewreath", "Twilight Lord Kelris", "Kresh", "Meshlok the Harvester", "Hydrospawn", "Overmaster Pyron", "Crimson Hammersmith", "Atal'alarion", "Deathsworn Captain", "Ramstein the Gorger", "General Fangferror", "Zevrim Thornhoof", "Lothos Riftwaker", "Grand Crusader Dathrohan", "King Gordok", "Ghamoo-ra", "Magmadar", "Noxxion", "Gammerita", "Kandrostrasz", "Lady Falther'ess", "Highlord Bolvar Fordragon", "Timber", "Hydromancer Velratha", "Cookie", "Gorlash", "Takk the Leaper", "Jammal'an the Prophet", "Kurinnaxx", "Captain Greenskin", "Doctor Theolen Krastinov", "Gothik the Harvester", "Agathelos the Raging", "Bruegal Ironknuckle", "Margol the Rager", "Velarok Windblade", "Timmy the Cruel", "Baron Aquanis", "Duskstalker", "Dark Iron Ambassador", "Digmaster Shovelphlange", "Maleki the Pallid", "Mor'Ladim", "Ressan the Needler", "Baroness Anastari", "Aean Swiftriver", "Emberstrife", "Fenrus the Devourer", "Cyclonian", "Ilyenia Moonfire", "Ironeye the Invincible", "Marshal Windsor", "Celebras the Cursed", "Deviate Faerie Dragon", "Obsidian Sentinel", "The Unforgiven", "Glutton", "Somnus", "Wolf Master Nandos", "Old Serra'kis", "Miner Johnson", "Nekrum Gutchewer", "Shadow of Doom", "Archivist Galford", "Cannon Master Willey", "Jin'do the Hexxer", "Shadowclaw", "Baron Silverlaine", "Instructor Razuvious", "Ok'thor the Breaker", "Arch Druid Fandral Staghelm", "Leech Widow", "Qiraji Officer Zod", "Galgann Firehammer", "Firemaw", "Plaguemaw the Rotting", "Rhahk'Zor", "Grimlok", "Black Guard Swordsmith", "Electrocutioner 6000", "Battleguard Sartura", "Razorclaw the Butcher", "Anub'Rekhan", "Dreamscythe", "Heigan the Unclean", "Houndmaster Grebmar", "Maexxna", "Anathemus", "King Mukla", "Quartermaster Zigris", "The Prophet Skeram", "Witch Doctor Zum'rah", "Lord Vyletongue", "Noth the Plaguebringer", "Skum", "Duskwing", "Snarler", "Vaelan", "Foe Reaper 4000", "Mist Howler", "Taragaman the Hungerer", "Zerillis", "Gath'Ilzogg", "High Priestess Mar'li", "Mizzle the Crafty", "Vilebranch Shadowcaster", "Fankriss the Unyielding", "Flamegor", "Revelosh", "Gyth", "Vectus", "Chok'sul", "Cyrus Therepentous", "Slavering Worg", "Tuten'kash", "Tyrande Whisperwind", "Magregan Deepshadow", "Goraluk Anvilcrack", "Gruff Swiftbite", "Grunter", "Grand Widow Faerlina", "Landslide", "Lucifron", "Viscous Fallout", "Gehennas", "Hearthsinger Forresten", "Deviate Dreadfang", "Haren Swifthoof", "Spiteflayer", "Hurley Blackbreath", "Elder Saltwater Crocolisk", "Ironaya", "Prince Thunderaan", "Setis", "Ayamiss the Hunter", "Ouro", "Panzor the Invincible", "Skul", "Ambassador Malcin", "Atiesh", "Blazerunner", "Razorlash", "Gesharahan", "Grobbulus", "Rohan the Assassin", "Simone the Inconspicuous", "Shazzrah", "Lady Sarevess", "Overseer Maltorius", "Emperor Vek'lor", "Gilnid", "Swiftmane", "Zaetar's Spirit", "Guard Slip'kik", "High Priestess Arlokk", "Stomper Kreeg", "Nancy Vishas", "Ebonroc", "Shadowpriest Sezz'ziz", "Death Knight Darkreaver", "Cho'Rush the Observer", "Nerub'enkan", "Earthcaller Halmgar", "Korfax, Champion of the Light", "Scarlet Champion", "Vagash", "Sulfuron Harbinger", "Axtroz", "Boulderheart", "Corporal Keeshan", "Fedfennel", "Shen'dralar Ancient", "High Priestess Jeklik", "Princess Huhuran", "Agam'ar", "Chieftain Nek'rosh", "Mordresh Fire Eye", "Commander Springvale", "Gluth", "Dishu", "Goggeroc", "Kormok", "Muckrake", "Old Cliff Jumper", "Grubbis", "Odo the Blindwatcher", "Postmaster Malown", "Rethilgore", "Son of Hakkar", "Magister Kalendris", "Commander Eligor Dawnbringer", "General Rajaxx", "Theka the Martyr", "Cairne Bloodhoof", "Dextren Ward", "Negolash", "Taskmaster Fizzule", "Twilight Prophet", "Vile Priestess Hexx", "Vinchaxa", "Gloom'rel", "Aggem Thorncurse", "Hetaera", "Lady Sylvanas Windrunner", "Uhk'loc", "Dun Garok Rifleman", "High Justice Grimstone", "Xandivious", "Azurous", "Baron Kazum", "Crimson Courier", "Lorekeeper Mykos", "Qiraji Captain Ka'ark", "Slark", "Captain Kromcrush", "Felweaver Scornn", "Jergosh the Invoker", "King Magni Bronzebeard", "Emperor Vek'nilash", "Brack", "Lady Vespira", "Lord Skwol", "Lorekeeper Polkelt", "The Cleaner", "Arash-ethis", "Gelihast", "Huntsman Leopold", "Lord Azrethoc", "Lord Condar", "Morgaine the Sly", "Qiraji Lieutenant Jo-rel", "Samuel Hawke", "Deathclasp", "Eliza", "Gasher", "Techbot", "Azure Templar", "Borelgore", "Scorched Guardian", "Thanthaldis Snowgleam", "Lethtendris", "Fenros", "Kam Deepfury", "Mistress Natalia Mar'alith", "Ambassador Infernus", "Azzere the Skyblade", "Coral Shark", "Lord Alexei Barov", "Naraxis", "Rathorian", "Thuros Lightfingers", "Ancient Stone Keeper", "Illyanna Ravenoak", "Nerubian Overseer", "Alexi Barov", "Archbishop Benedictus", "Lady Jaina Proudmoore", "Overlord Mok'Morokk", "Foreman Thistlenettle", "Blackfathom Tide Priestess", "Blood Steward of Kirtonos", "Death Speaker Jargba", "Eris Havenfire", "Frostmaul Giant", "Instructor Malicia", "Master Elemental Shaper Krixix", "Morbent Fel", "Buru the Gorger", "Gizrul the Slavener", "Halycon", "Earthen Templar", "Scryer", "Sian-Rotam", "Sandarr Dunereaver", "Stonespine", "Boahn", "Cenarion Hold Infantry", "Fel Steed", "Hederine Slayer", "Highlord Demitrian", "Ironback", "Rayne", "Rotting Agam'ar", "Sneed's Shredder", "Spirit of Magra", "Ezra Grimm", "Grizzle", "Hazzas", "Besseleth", "Lord Malathrom", "Lord Kri", "Vem", "Ironhide Devilsaur", "Lord Lakmaeran", "Targorr the Dread", "Terrowulf Packlord", "Bijou", "Kharan Mighthammer", "Renataki", "Stone Fury", "The Duke of Shards", "Mushgog", "The Razza", "Theldren", "Edana Hatetalon", "Elder Mystic Razorsnout", "Lieutenant Valorcall", "Mother Fang", "Rimblat Earthshatter", "Rohh the Silent", "Shanda the Spinner", "Shy-Rotam", "Vol'jin", "Eroded Anubisath Warbringer", "Lord Blackwood", "Dustwraith", "Archmage Tarsis Kir-Moldir", "Son of Arkkoroc", "Lady Blaumeux", "Black Drake", "Crushridge Warmonger", "Jekyll Flandring", "Master Craftsman Omarion", "Vethsera", "Grizlak", "Hammerspine", "Krethis Shadowspinner", "Revanchion", "Scarlet High Clerist", "Sergeant Brashclaw", "Tharil'zun", "Wushoolay", "Hedrum the Creeper", "Artorius the Amiable", "Awbee", "Great Father Arctikus", "Large Loch Crocolisk", "Maws", "Scarlet Enchanter", "Dark Keeper Pelver", "Lord Hel'nurath", "Marisa du'Paige", "Mother Smolderweb", "Balzaphon", "Black Dragonspawn", "Bloodfury Ripper", "Dark Iron Dwarf", "Firebrand Pyromancer", "Lord Banehollow", "Dark Keeper Ofgut", "Colossus of Ashi", "Commander Mar'alith", "Crimson Templar", "Dalaran Spellscribe", "Edan the Howler", "Foreman Rigger", "Immolatus", "Obsidion", "Prince Skaldrenox", "The Husk", "The Threshwackonator 4100", "Willix the Importer", "Eric \"The Swift\"", "Guard Fengus", "Chimaerok", "High Marshal Whirlaxis", "Hoary Templar", "Mistress Nagmara", "Nelson the Nice", "Highlord Mograine", "Verek", "Watchman Doomgrip", "Death Howl", "Goblin Woodcarver", "Grand Foreman Puzik Gallywix", "Kovork", "Mug'thol", "Old Icebeard", "Rocklance", "Sayoc", "Son of Arugal", "Eviscerator", "Malor the Zealous", "Princess Yauj", "Blacklash", "Captain Flat Tusk", "Chatter", "Gorefang", "Lady Vespia", "Mataus the Wrathcaster", "Molthor", "Narg the Taskmaster", "Old Grizzlegut", "Ghok Bashguud", "Ogom the Wretched", "Doctor Weavil", "Lord Arkkoroc", "Sergeant Bly", "Strider Clutchmother", "Anub'shiah", "Dark Keeper Uggel", "Farmer Solliden", "Garneg Charskull", "Grol the Destroyer", "Hakkari Frostwing", "Hematus", "Klaven Mortwake", "Zul'Farrak Zombie", "Dreadlord", "Dungar Longdrink", "Lieutenant General Andorov", "Qiraji Officer", "Reginald Windsor", "Taskmaster Whipfang", "Sir Zeliek", "Skarr the Unbreakable", "Tsu'zee", "Ancient Core Hound", "Colonel Kurzen", "Master Digger", "Prince Raze", "Spirit of Kolk", "Stonearm", "Twilight Corrupter", "Crimson Inquisitor", "Franklin the Friendly", "Heartrazor", "High Tinker Mekkatorque", "Rekk'tilac", "Rutherford Twing", "Sand Shark", "Tyrant Devilsaur", "Weaver", "Boulderfist Shaman", "Chimaerok Devourer", "Demetria", "Duggan Wildhammer", "Gibblewilt", "Omgorn the Lost", "Snarlmane", "Spectral Researcher", "The Duke of Fathoms", "Bannok Grimaxe", "Ruuzlu", "Arcane Chimaerok", "Emissary Roman'khan", "Hematos", "Lorekeeper Javon", "Marduk Blackpool", "Qiraji Major He'al-ie", "Vartrus the Ancient", "Thane Korth'azz", "Al'tabim the All-Seeing", "Deviate Coiler", "Lady Hederine", "Raging Agam'ar", "The Duke of Zephyrs", "The Ravenian", "Weldon Barov", "Dark Keeper Bethek", "Anubisath Warbringer", "Foreman Marcrid", "Kirith the Damned", "Rage Talon Fire Tongue", "Sneed", "Spirestone Butcher", "Trigore the Lasher", "Cobalt Scalebane", "Flamescale Wyrmkin", "Kazon", "Lieutenant General Nokhor", "Ravage", "Snort the Heckler", "Jarien", "Felguard Elite", "Frenzied Black Drake", "Hayoc", "Klinfran the Crazed", "Lady Illucia Barov", "Scarlet Archmage", "Cliff Breaker", "Commander Felstrom", "Deepstrider Giant", "Father Inigo Montoy", "Lord Victor Nefarius", "Lumbering Horror", "Magosh", "Mo'grosh Ogre", "Hederine Initiate", "Lord Falconcrest", "Lost Soul", "Mai'Zoth", "Or'Kalar", "Spirit of Azuregos", "Squiddic", "The Behemoth", "Archmage Allistarj", "Brontus", "Gringer", "Magistrate Henry Maleb", "Oakenscowl", "Scholomance Necromancer", "Sergra Darkthorn", "Achellios the Banished", "Arygos", "Dark Iron Demolitionist", "Death Talon Wyrmguard", "Eldreth Sorcerer", "Grizzle Snowpaw", "Lady Sevine", "Lord Darkscythe", "Pyrewood Watcher", "Ripscale", "Solenor the Slayer", "Targ", "Dark Keeper Vorfalk", "7:XT", "Clunk", "Frostmaul Preserver", "High General Abbendis", "Qiraji Lieutenant", "Sister Riven", "Skhowl", "Brainwashed Noble", "Disciple of Naralex", "Gryfe", "Nightmare Phantasm", "Oggleflint", "Sorrow Wing", "Thenan", "Elfarran", "High Overlord Saurfang", "Manaclaw", "Pyrewood Armorer", "Scarlet Warder", "Spellmaw", "Araga", "Arikara", "Bone Witch", "Dessecus", "Emogg the Crusher", "Flamescale Dragonspawn", "Gibblesnik", "Hamhock", "Lorekeeper Kildrath", "Marcus Bel", "Seeker Aqualon", "Sludge Beast", "Thule Ravenclaw", "Withered Mistress", "Xorothian Dreadsteed", "Doom'rel", "Dirk Thunderwood", "Emeraldon Tree Warder", "Lord Tirion Fordring", "Ma'ruk Wyrmscale", "Mith'rethis the Enchanter", "Rage Talon Dragonspawn", "Razelikh the Defiler", "Razormaw Matriarch", "Zul'arek Hatefowler", "Spirestone Battle Lord", "Akkrilus", "Artorius the Doombringer", "Black Wyrmkin", "Blackhand Assassin", "Brimgore", "Jonathan the Revelator", "Retherokk the Berserker", "Shadow Charger", "Warpwood Guardian", "Magra", "Bayne", "Blue Dragonspawn", "Cranky Benj", "Kraul Bat", "Malfurion Stormrage", "Minor Anubisath Warbringer", "Scarlet Diviner", "Threggil", "Olaf", "Bixi Wobblebonk", "Blastmaster Emi Shortfuse", "Boss Galgosh", "Cliff Walker", "Deepstrider Searcher", "Demon of the Orb", "Gruff", "Helcular's Remains", "Raene Wolfrunner", "Risen Bonewarder", "Shadowfang Darksoul", "Shen'dralar Provisioner", "Warlord Krom'zar", "Core Hound", "Fellicent's Shade", "Geopriest Gukk'rok", "Grand Inquisitor Isillien", "Old Vicejaw", "Risen Construct", "Rynthariel the Keymaster", "Sister Rathtalon", "Sandfury Executioner", "Druid of the Fang", "Firewalker", "Foreman Grills", "Fury Shelda", "Grark Lorkrub", "Jade", "Kroshius", "Lake Thresher", "Qiraji Major", "Stonevault Brawler", "Watch Commander Zalaphil", "Crystal Fang", "Colossus of Regal", "Crushridge Mauler", "Dreamstalker", "Dun Garok Mountaineer", "Lord Maldazzar", "Mo'grosh Enforcer", "Overlord Runthak", "Scale Belly", "Shadowforge Surveyor", "Singer", "Sister Hatelash", "Spirit of the Damned", "Tormented Spirit", "Warlord Kolkanis", "Zulian Tiger", "Deeb", "Defias Convict", "Drek'Thar", "Grandpa Vishas", "Hakkari Bloodkeeper", "Korrak the Bloodrager", "Kurmokk", "Patchwork Horror", "Pridewing Patriarch", "Ravasaur Matriarch", "Roloch", "Scarlet Sentinel", "Shrike Bat", "Verifonix", "Anvilrage Warden", "Blackrock Shadowcaster", "Clack the Reaver", "Enforcer Emilgund", "Rippa", "Scarlet Praetorian", "Crushridge Enforcer", "Firelord", "Foreman Jerris", "Greater Firebird", "Lupine Horror", "Mo'grosh Shaman", "Molten Giant", "Mongress", "Muad", "Nal'taszar", "Red Scalebane", "Spirit of Veng", "Blackfathom Oracle", "Cliff Thunderer", "Doomguard Commander", "Foulbelly", "General Colbatann", "Living Monstrosity", "Omen", "Razzashi Raptor", "Scarlet Monk", "Sludginn", "Thalon", "Twilight Fire Guard", "Twilight Lord Everun", "Ursol'lok", "Vilebranch Soul Eater", "Young Arikara", "Dark Keeper Zimrel", "Veng", "Big Samras", "Commander Gor'shak", "Earthcaller Franzahl", "Firebrand Invoker", "Merithra of the Dream", "Molten Destroyer", "Number Two", "Scarlet Centurion", "Searscale Drake", "Silithid Ravager", "Snagglespear", "Spirit of Gelk", "Sri'skulk", "Stromgarde Vindicator", "Vilebranch Berserker", "Spirestone Lord Magus", "Colossus of Zora", "Crimson Defender", "Darbel Montrose", "Deviate Stinglash", "Deviate Venomwing", "Giggler", "Lady Moongazer", "Mo'grosh Brute", "Nessy", "Obsidian Destroyer", "Otto", "Ragefire Trogg", "Razorfen Servitor", "Razorfen Spearhide", "Scarlet Guardsman", "Venom Belcher", "Anvilrage Captain", "Blackwing Technician", "Crimson Elite", "Deviate Creeper", "Grunnda Wolfheart", "Hagg Taurenbane", "Krellack", "Lefty", "Lord Captain Wyrmak", "Mirelow", "Putridius", "Saltscale Forager", "Scarshield Legionnaire", "Shadowforge Commander", "Twilight Marauder Morna", "Vesprystus", "Gelk", "Stratholme Courier", "Ambassador Bloodrage", "Captain Balinda Stonehearth", "Kael'thas Sunstrider", "Illidan Stormrage", "G'eras", "Fedryen Swiftspear", "Mother Shahraz", "Okuno", "Lady Vashj", "Magtheridon", "Gruul the Dragonkiller", "Doom Lord Kazzak", "Prince Malchezaar", "Doomwalker", "Quartermaster Urgronn", "Archimonde", "Murmur", "Rage Winterchill", "Warchief Kargath Bladefist", "Skar'this the Heretic", "Arrond", "Nightbane", "Terokk", "Anzu", "Fathom-Lord Karathress", "Void Reaver", "Kil'jaeden", "Teron Gorefiend", "High King Maulgar", "Pathaleon the Calculator", "Yor", "Coren Direbrew", "Fel Reaver", "Soridormi", "Morogrim Tidewalker", "Shartuul", "Warlord Kalithresh", "Plugger Spazzring", "Pandemonius", "Al'ar", "Leotheras the Blind", "Hydross the Unstable", "The Lurker Below", "Keli'dan the Breaker", "Quagmirran", "Congealed Void Horror", "Herod", "The Black Stalker", "Time-Lost Shadowmage", "Anetheron", "Warp Splinter", "Aeonus", "Nexus-Prince Shaffar", "Talon King Ikiss", "Talonsworn Forest-Rager", "Harbinger Skyriss", "Durn the Hungerer", "High Warlord Naj'entus", "High Astromancer Solarian", "Supremus", "Epoch Hunter", "Netherspite", "Bash'ir", "Exarch Maladaar", "Omor the Unscarred", "Akama", "Arcanist Doan", "Zul'jin", "Chief Engineer Lorthander", "Blackheart the Inciter", "Shade of Aran", "Shirrak the Dead Watcher", "Kaz'rogal", "Force Commander Danath Trollbane", "The Grand Collector", "Scarlet Commander Mograine", "Azgalor", "High Inquisitor Whitemane", "Wravien", "Khadgar", "Gurtogg Bloodboil", "Grand Warlock Nethekurse", "Altruis the Sufferer", "Essence of Anger", "Kael'thas Sunstrider", "The Maker", "Mordenai", "Temporus", "Ancient Shadowmoon Spirit", "Commander Sarannis", "Arcanist Thelis", "Eredar Deathbringer", "A'dal", "Humar the Pridelord", "Watchkeeper Gargolmar", "King Bangalash", "Ruul the Darkener", "Shade of Akama", "Hex Lord Malacrass", "Wildlord Antelarion", "Mekgineer Thermaplugg", "Vazruden", "Rokad the Ravager", "The Curator", "Bloodmage Thalnos", "Darkweaver Syth", "Moroes", "Grandmaster Vorpil", "Raging Skeleton", "Rokmar the Crackler", "Terestian Illhoof", "Tavarok", "Avatar of the Martyred", "The Illidari Council", "Lantresor of the Blade", "Mennu the Betrayer", "Adyen the Lightwarden", "Ambassador Hellmaw", "Emperor Dagran Thaurissan", "Rin'wosho the Trader", "Mechano-Lord Capacitus", "Frost Wyrm", "Shadowlord Deathwail", "Warbringer O'mrogg", "Mok'rash", "Ythyar", "Broggok", "Sa'at", "Maiden of Virtue", "Attumen the Huntsman", "Vhel'kur", "High Nethermancer Zerevor", "Princess Theradras", "Baron Sablemane", "David Wayne", "Interrogator Vishas", "Tethyr", "Grand Astromancer Capernian", "Speaker Mar'grom", "Magistrate Barthilas", "Gutripper", "Arazmodu", "Archmage Arugal", "Mekgineer Steamrigger", "Magistrix Fyalenn", "Laj", "Arazzius the Cruel", "Apexis Guardian", "Auchenai Monk", "Knucklerot", "Archaedas", "Houndmaster Loksey", "Mataus the Wrathcaster", "Windcaller Claw", "Sal'salabim", "Ethereal Priest", "Cenarion Hold Infantry", "Goc", "Zephyr", "Deathskitter", "Phantom Stagehand", "Shattered Hand Centurion", "Gezzarak the Huntress", "High Botanist Freywinn", "Hungarfen", "Broken Tooth", "Flame of Azzinoth", "Kayri", "Val'zareq the Conqueror", "M'uru", "Edwin VanCleef", "Hamanar", "Brutallus", "Nazan", "Shadikith the Glider", "Andormu", "High Inquisitor Fairbanks", "Koren", "Netherock", "Teribus the Cursed", "Scarlet Archmage", "Tagar Spinebreaker", "Reliquary of the Lost", "Kalecgos", "Amnennar the Coldbringer", "Cryo-Engineer Sha'heen", "Medivh", "Morthis Whisperwing", "Shattered Hand Executioner", "Ghaz'an", "Pyromancer Loregrain", "Gorkan Bloodfist", "Silithid Harvester", "Spymaster Thalodien", "Chief Ukorz Sandscalp", "Zereketh the Unbound", "Kraator", "Don Carlos", "Kiggler the Crazed", "Captain Skarloc", "Dar'Khan Drathir", "Chrono Lord Deja", "Coreiel", "Fathom-Guard Caribdis", "Morphaz", "Shade of Eranikus", "Ambassador Jerrikar", "Grel'borg the Miser", "Ahune", "Cho'war the Pillager", "Avatar of Hakkar", "Aku'mai", "Socrethar", "Battleguard Sartura", "Hyakiss the Lurker", "Crypt Fiend", "Levixus", "Priestess Delrissa", "Baron Rivendare", "Ishanah", "Krosh Firehand", "Reth'hedron the Subduer", "Gathios the Shatterer", "Alluvion", "Azshir the Sleepless", "Baelog", "Kel'Thuzad", "Agathelos the Raging", "Cavindra", "Quartermaster Jaffrey Noreliqe", "Varimathras", "Woo Ping", "Swamplord Musel'ek", "Bash'ir's Harbinger", "Floon", "Lord Roccor", "Dimensius the All-Devouring", "Dalliah the Doomsayer", "Cyrukh the Firelord", "Maggoc", "Overlord Ramtusk", "Grimlok", "Thorngrin the Tender", "Vexallus", "Attumen the Huntsman", "Azaloth", "Charlga Razorflank", "Highlord Kruul", "Ironspine", "Quartermaster Davian Vaclav", "Rak'shiri", "Coosh'coosh", "Erozion", "Olm the Wise", "Stitches", "Zorus the Judicator", "Aldraan", "Bladespire Ravager", "Fallen Champion", "Furywing", "Garrosh", "Mo'arg Incinerator", "Roogug", "Vile Sting", "Fineous Darkvire", "Hydromancer Thespia", "Rotgrip", "The Crone", "Anachronos", "Arash-ethis", "Coilfang Oracle", "Obsidia", "Digmaster Shovelphlange", "Revelosh", "Baron Aquanis", "Shadra", "Blacktalon the Savage", "Windroc Matriarch", "Felmyst", "Nethermancer Sepethrea", "Tinkerer Gizlock", "Coilfang Myrmidon", "Echo of Medivh", "Ever-Core the Punisher", "Mountain Gronn", "Gahz'rilla", "Lady Sacrolash", "Lord Serpentis", "Sapphiron", "Ethereum Wave-Caster", "Ghoul", "Insidion", "Lorgus Jett", "Underbog Colossus", "Vindicator Boros", "Wing Commander Dabir'ee", "Arcatraz Sentinel", "Death Speaker Jargba", "Giant Infernal", "Gnarl", "Kamsis", "Sunseeker Astromage", "Hydromancer Velratha", "Lady Anacondra", "Blackmoss the Fetid", "Gurok the Usurper", "Volchan", "Barnes", "Fathom-Guard Tidalvess", "Ilyenia Moonfire", "Naberius", "Vakkiz the Windrager", "Akil'zon", "General Angerforge", "Nalorakk", "Overlord Wyrmthalak", "Arcane Annihilator", "Blindeye the Seer", "Grunter", "Lady Falther'ess", "Lo'Grosh", "Warden Bullrok", "Crowd Pummeler 9-60", "Grubbis", "Halazzi", "Lord Vyletongue", "Lord Banehollow", "Neltharaku", "Prince Nazjak", "Stonegazer", "Teron Gorefiend", "Thaladred the Darkener", "Torgos", "Zaricotl", "Baroness Anastari", "Celebras the Cursed", "Mutanus the Devourer", "Apex", "Darkscreecher Akkarai", "Mogh the Undying", "Myzrael", "Nexus Terror", "Rexxar", "Rift Lord", "Golem Lord Argelmach", "Maleki the Pallid", "Galvanoth", "Rivendark", "Voren'thal the Seer", "Razorlash", "Shadowpriest Sezz'ziz", "Braxxus", "Glutton", "Ripscale", "Slaag", "Varedis", "Antu'sul", "Gahz'ranka", "Drillmaster Zurok", "Harbinger Skyriss", "Lady Sarevess", "Millhouse Manastorm", "Nutral", "Rajah Haghazed", "Yrma", "Deathsworn Captain", "Lieutenant Drake", "Atal'alarion", "Bazzalan", "Blue Scalebane", "Chief Apothecary Hildagard", "Steward of Time", "Tusker", "Tuten'kash", "Warchief Rend Blackhand", "Xi'ri", "Lady Malande", "Obsidian Sentinel", "Cyrus Therepentous", "Darkmaster Gandling", "Illiyana Moonblaze", "King Mosh", "Master Engineer Telonicus", "Old Serra'kis", "Sewer Beast", "Uvuros", "Wind Trader Zhareem", "Essence of Suffering", "Julianne", "Aggem Thorncurse", "Celebras the Redeemed", "Mal'druk the Soulrender", "Mr. Smite", "Sever", "Thrall", "Zelemar the Wrathful", "Essence of Desire", "Jan'alai", "Kresh", "Dagun the Ravenous", "Gelihast", "Gorlash", "Headless Horseman", "Marticar", "Mordresh Fire Eye", "Grand Warlock Alythess", "Meshlok the Harvester", "Ribbly Screwspigot", "Collidus the Warp-Watcher", "Ethereum Slayer", "Ghost Howl", "Glordrum Steelbeard", "Qiraji Major He'al-ie", "Raging Colossus", "Rhahk'Zor", "Scholomance Necromancer", "Fankriss the Unyielding", "Landslide", "Noxxion", "Arvoar the Rapacious", "Cobalt Serpent", "Earthcaller Halmgar", "Nexus-King Salhadaar", "Shattered Hand Legionnaire", "Spirit of Magra", "Supply Officer Shandria", "Theremis", "Tobias the Filth Gorger", "Ancient Stone Keeper", "Balnazzar", "Ironaya", "Onyxia", "Princess Moira Bronzebeard", "Quartermaster Zigris", "Shadow Hunter Vosh'gajin", "Andormu", "Blind Hunter", "Boglash", "Chief Researcher Kartos", "Jekyll Flandring", "Karynaku", "Raliq the Drunk", "Twilight Lord Kelris", "Ambassador Flamelash", "Galgann Firehammer", "Nekrum Gutchewer", "Arator the Redeemer", "Banthar", "Coilfang Priestess", "Jergosh the Invoker", "Lady Illucia Barov", "Lupos", "Oakun", "Olm the Summoner", "Rotting Agam'ar", "Blood Guard Porung", "C'Thun", "High Interrogator Gerstahn", "Hurley Blackbreath", "Lord Incendius", "Abomination", "Ansekhwa", "Duskstalker", "Warder Corpse", "Zuluhed the Whacked", "Phalanx", "Tendris Warpwood", "Theka the Martyr", "Wrath-Scryer Soccothrates", "Cookie", "Cyclonian", "Death Flayer", "Ghamoo-ra", "Grulloc", "Nuramoc", "Rohan the Assassin", "Sunblade Blood Knight", "Teremus the Devourer", "Trelopades", "Fenrus the Devourer", "High Priest Thekal", "Pusillin", "Viscous Fallout", "Bloodwarder Legionnaire", "Fathom-Guard Sharkkis", "Leech Widow", "Narillasanz", "Scarlet Champion", "Eric The Swift", "Firemaw", "Immol'thar", "Lord Pythas", "Veras Darkshadow", "Aean Swiftriver", "Araj the Summoner", "Banshee", "Kor'kron Wind Rider", "Rajis Fyashe", "Rattlegore", "Shadowy Necromancer", "Yarzill the Merc", "Eviscerator", "Highlord Omokk", "Midnight", "Alandien", "Azuregos", "Gargantuan Abyssal", "General Drakkisath", "Lady Sylvanas Windrunner", "Nether-Stalker Mah'duun", "Prophet Velen", "Ressan the Needler", "Terokkarantula", "Vindicator Haylen", "Rethilgore", "Witch Doctor Zum'rah", "Culuthas", "Garul", "Kam Deepfury", "Magtheridon", "Ragglesnout", "Taerar", "The Rake", "Electrocutioner 6000", "Vaelastrasz the Corrupt", "Baelmon the Hound-Master", "Baron Kazum", "Geopriest Gukk'rok", "Gilnid", "Gradav", "Nimar the Slayer", "Thanthaldis Snowgleam", "Unbound Devastator", "Bael'Gar", "Deviate Faerie Dragon", "Gorosh the Dervish", "Magmus", "The Big Bad Wolf", "Colossus of Ashi", "D'ore", "Ember of Al'ar", "Fel Stalker", "Greater Firebird", "Lorekeeper Lydros", "Coilfang Strider", "Death's Head Acolyte", "Gasher", "Karsius the Ancient Watcher", "The Behemoth", "Agam'ar", "Crimson Inquisitor", "Devilsaur", "Doomcryer", "Ethereal Spellfilcher", "Fulgorge", "Hellfire Channeler", "Lord Kazzak", "Nathanos Blightcaller", "Overlord Or'barokh", "Scorn", "Second Fragment Guardian", "Sneed's Shredder", "Spiteflayer", "Tempest-Forge Destroyer", "The Windreaver", "Alzzin the Wildshaper", "Astromancer", "Bjarn", "Lethon", "Phoenix-Hawk", "Plague Ghoul", "Sathrovarr the Corruptor", "Spawn of Hakkar", "Tirion Fordring", "Velarok Windblade", "Vorakem Doomspeaker", "Warden Moi'bff Jill", "Gatewatcher Gyro-Kill", "Hazzas", "Hedrum the Creeper", "Hydrospawn", "Wolf Master Nandos", "Bach'lor", "Crippler", "High Justice Grimstone", "Kraul Bat", "Matis the Cruel", "Shadow Demon", "Snarler", "Star Scryer", "Unchained Doombringer", "Dreamscythe", "Entropius", "Lord Kri", "Ruuzlu", "The Nameless Prophet", "Dirty Larry", "Coilfang Serpentguard", "Karrog", "Lord Sanguinar", "Maiev Shadowsong", "Mekthorg the Wild", "Scarshield Infiltrator", "Shade of Hakkar", "Zaetar's Spirit", "Anub'shiah", "Bloodlord Mandokir", "Commander Springvale", "Mother Smolderweb", "Ok'thor the Breaker", "Patchwerk", "Atiesh", "Coilskar General", "Ethereal Sorcerer", "Mazzranache", "Overmaster Pyron", "Ras Frostwhisper", "Seer Kanai", "Tempest-Smith", "V'eru", "Vazruden the Herald", "Veraku", "Archivist Galford", "Romulo", "Selin Fireheart", "Stomper Kreeg", "The Prophet Skeram", "Warder Stilgiss", "Cobalt Mageweaver", "Corporal Keeshan", "Dextren Ward", "Force-Commander Gorax", "Garm Wolfbrother", "Grand Crusader Dathrohan", "Hand of Kargath", "Luzran", "Naraxis", "Occulus", "Overlord Mor'ghor", "Ravage", "Chromaggus", "Lord Cobrahn", "Odo the Blindwatcher", "Razorclaw the Butcher", "Zerillis", "Akkiris Lightning-Waker", "Alexi Barov", "Ashtongue Battlelord", "Baron Charr", "Bergrisst", "Bog Giant", "Bro'Gaz the Clanless", "Chok'sul", "Gul'dan", "Illidari Boneslicer", "Lakka", "Nexus Stalker", "Nexus-Prince Haramad", "Plaguemaw the Rotting", "Shadowfang Ragetooth", "Silvermoon Dragonhawk", "Sneed", "Sorcerer Ashcrombe", "Baron Geddon", "Dark Iron Ambassador", "Viscidus", "Ashtongue Channeler", "Bazil Thredd", "Bloodwarder Squire", "Boahn", "Coilskar Soothsayer", "Dart", "First Fragment Guardian", "Kelm Hargunth", "Misha", "Pyroguard Emberseer", "Scarlet Commander Marjhan", "Sister Rathtalon", "Tarren Mill Protector", "Third Fragment Guardian", "Crimson Hammersmith", "Gatewatcher Iron-Hand", "Hearthsinger Forresten", "Lethtendris", "Moam", "Archibald", "Banro", "Captain Greenskin", "Coldmist Widow", "Greater Kraul Bat", "Greatmother Geyah", "Helcular's Remains", "Infinity Blades", "Keeper Remulos", "Magistrix Larynna", "Nihil the Banished", "Qiraji Captain Ka'ark", "Razzashi Broodwidow", "Scale Belly", "Sunblade Magister", "Thrall", "Thysta", "Twilight Prophet", "Zarcsin", "Flamegor", "Noth the Plaguebringer", "Urok Doomhowl", "Arcane Watchman", "Blazerunner", "Bog Overlord", "Cabal Deathsworn", "Dungar Longdrink", "Morcrush", "Shrike Bat", "Ursol'lok", "Voidhunter Yar", "Vultros", "Grizzle", "Jammal'an the Prophet", "Magister Kalendris", "Majordomo Executus", "Ogom the Wretched", "Tito", "Weaver", "Anveena", "Araga", "Arcane Protector", "Ashtongue Primalist", "Coilfang Emissary", "Druid of the Fang", "Elder Mystic Razorsnout", "Farahlon Breaker", "General Colbatann", "General Marcus Jonathan", "Makazradon", "Or'kaos the Insane", "Qiraji Lieutenant Jo-rel", "Razormaw", "Rekk'tilac", "Takk the Leaper", "Thane Yoregar", "The Beast", "Wildhammer Gryphon Rider", "Houndmaster Grebmar", "Nefarian", "Warden Mellichar", "Aqueous Spawn", "Buliwyf Stonehand", "Demos, Overseer of Hate", "Ethereal Spellbinder", "Goretooth", "Grark Lorkrub", "Hederine Slayer", "Malfurion Stormrage", "Scryer", "Splinterbone Captain", "Taragaman the Hungerer", "Taskmaster Varkule Dragonbreath", "Wildspawn Betrayer", "Xorothian Dreadsteed", "Mor Grayhoof", "Stratholme Courier", "Zevrim Thornhoof", "Bloodwarder Marshal", "Cairne Bloodhoof", "Coilfang Guardian", "Coilfang Soothsayer", "Coilfang Warrior", "Crimson Courier", "Crimson Sorcerer", "Crystalcore Mechanic", "Darkened Spirit", "Emberstrife", "Ethereal Crypt Raider", "Farahlon Giant", "Gryan Stoutmantle", "Instructor Malicia", "Kael'thas Sunstrider", "Rift Keeper", "Shattered Hand Assassin", "Stephanos", "Stoma the Ancient", "Supply Officer Isabel", "Targorr the Dread", "Timber", "Towering Infernal", "Vashj'ir Honor Guard", "Watch Commander Relthorn Netherwane", "Hakkar", "Mushgog", "Bash'ir Reckoner", "Bloodfalcon", "Cabal Spellbinder", "Cliff Giant", "Crazed Colossus", "Deviate Moccasin", "Dr. Whitherlimb", "Dreghood Slave", "Gesharahan", "Greyheart Nether-Mage", "Hemathion", "Hogger", "Illidan Stormrage", "Immolatus", "Ironeye the Invincible", "Jandice Barov", "Kerna", "Leviathan", "Lord Malathrom", "Mo'arg Master Planner", "Overlord Mok'Morokk", "Overseer Tidewrath", "Prince Thunderaan", "Raven", "Rohh the Silent", "Sentinel Farsong", "Sergeant Altumus", "Shadowbat", "Shattered Hand Heathen", "Son of Arugal", "Tasaldan", "Underbat", "Baron Silverlaine", "Captain Kromcrush", "Ebonroc", "Emperor Vek'lor", "Malor the Zealous", "Prince Tortheldrin", "The Razza", "Veng", "Ambassador Infernus", "Avalanchion", "Azzere the Skyblade", "Behemothon, King of the Colossi", "Brokentoe", "Coilfang Champion", "Crimson Hand Blood Knight", "Deathclasp", "Deathstalker Adamant", "Deviate Dreadfang", "Dishu", "Draconic Mageweaver", "Fallen Hero", "G'eras Vindicator", "Gath'Ilzogg", "Great Father Arctikus", "Hakkari Frostwing", "Hamhock", "Huntsman Leopold", "Lady Liadrin", "Lair Brute", "Lieutenant General Andorov", "Lord Valthalak", "Nerubian Overseer", "Promenade Sentinel", "Scarlet Praetorian", "Scorched Guardian", "Shadowfang Darksoul", "Sister of Torment", "Skhowl", "Sulfuron Magma-Thrower", "Tidewalker Lurker", "Uhk'loc", "Vindicator Aeus", "Warlord Dar'toon", "Ysondre", "Dark Keeper Bethek", "Highlord Mograine", "King Gordok", "Miner Johnson", "Princess Yauj", "Skum", "Timmy the Cruel", "Astromancer Lord", "Barnabus", "Blackwing Drakonaar", "Blazing Trickster", "Cabal Acolyte", "Captain Blackanvil", "Coilfang Frenzy", "Crusty", "Crystalcore Devastator", "Deviate Adder", "Durnholde Warden", "Emeriss", "Foe Reaper 4000", "Franklin the Friendly", "Frostwolf Explosives Expert", "Goblin Woodcarver", "Hastat the Ancient", "Hydross the Unstable", "Larissa Sunstrike", "Lobo", "Lord Skwol", "Raging Agam'ar", "Rokaro", "Skittering Crustacean", "Spectral Performer", "Sunseeker Botanist", "Supreme Anubisath Warbringer", "War Golem", "Warmaul Chef Bufferlo", "Zanza the Restless", "Garr", "Thaddius", "Altar of Sha'tar Vindicator", "Amani'shi Beast Tamer", "Aqueous", "Bijou", "Bonechewer Ravener", "Cabal Fanatic", "Caylee Dak", "Coilfang Ambusher", "Dalaran Spellscribe", "Dame Twinbraid", "Darbel Montrose", "Forward Commander To'arch", "General Tiras'alan", "Gordunni Soulreaper", "Greyheart Skulker", "High Tinker Mekkatorque", "Illidari Defiler", "Kalecgos", "Kel'gash the Wicked", "Kharan Mighthammer", "Lesser Doomguard", "Lord Alexei Barov", "Marshal Isildor", "Mo'arg Engineer", "Negaton Warp-Master", "Netharel", "Phantom Attendant", "Phoenix-Hawk Hatchling", "Pridewing Patriarch", "Princess Tempestria", "Saurfang the Younger", "Sayoc", "Shadowclaw", "The Husk", "Twilight Reaver", "Water Globule", "Gelk", "Isalien", "Maexxna", "Ouro", "Ramstein the Gorger", "The Unforgiven", "Tinhead", "Verdan the Everliving", "Amani'shi Tempest", "Apprentice Star Scryer", "Arch Druid Fandral Staghelm", "Bash'ir Controller", "Blood Lord Zarath", "Coilfang Siren", "Cragskaar", "Durnholde Tracking Hound", "Ethereal Darkcaster", "Fel Overseer", "Fenissa the Assassin", "Fenros", "Fenstalker", "Fingrom", "Ghostly Baker", "Greater Bogstrok", "Highlord Taelan Fordring", "Illidari Centurion", "Illidari Heartseeker", "Illidari Highlord", "King Llane UNUSED", "Large Loch Crocolisk", "Living Monstrosity", "Molten Giant", "Qiraji Brigadier General Pax-lish", "Razorfen Totemic", "Remote-Controlled Golem", "Rhonin", "Sargeron Hellcaller", "Scholomance Dark Summoner", "Shadowmoon Soldier", "Shill Dinger", "Sig Nicious", "Son of Hakkar", "Soulflayer", "Staff of Disintegration", "Stalagg", "Stone Guardian", "Stonevault Mauler", "Tarren Mill Lookout", "Tarren Mill Protector", "Tick", "Time Keeper", "Twilight Drakonaar", "Warp Slicer", "Zulian Stalker", "Dark Keeper Ofgut", "Nerub'enkan", "Ragnaros", "Ancient Core Hound", "Barbed Crustacean", "Blackhand Veteran", "Blastmaster Emi Shortfuse" }
local RawEliteIDs = {2850, 12201, 3975, 3977, 5828, 9019, 10184, 639, 6109, 7996, 12397, 11502, 10440, 10363, 4275, 412, 3976, 728, 2779, 5807, 14834, 2748, 6487, 3535, 15500, 731, 11583, 6168, 15990, 9499, 7800, 7358, 10182, 10806, 10429, 8983, 5709, 2611, 2425, 4829, 14921, 7846, 1493, 9056, 15727, 10435, 3654, 15082, 6498, 15340, 3974, 3581, 13697, 1853, 11865, 13278, 14354, 10584, 15192, 10503, 9568, 16042, 730, 6489, 9033, 6584, 7267, 4543, 448, 14368, 11867, 2417, 10813, 11878, 9027, 9024, 14887, 521, 4421, 4499, 15042, 15989, 3056, 462, 6490, 2931, 2447, 15114, 9016, 8929, 11382, 15339, 14457, 3253, 14020, 1855, 10807, 14326, 12018, 6488, 14753, 14682, 2937, 10299, 3983, 10929, 11622, 14890, 9025, 15083, 11496, 10506, 1842, 4542, 14888, 11486, 9236, 14889, 14343, 10508, 6229, 16011, 466, 6906, 15928, 10509, 8127, 13716, 9156, 3655, 15299, 14464, 12902, 11489, 11492, 9816, 1225, 7273, 3671, 3669, 10200, 12056, 9018, 16028, 4425, 10996, 9017, 15206, 4949, 10738, 14507, 12057, 1130, 234, 9046, 7354, 10119, 13020, 3068, 10430, 7437, 14693, 12017, 3673, 572, 9196, 2707, 14454, 2681, 9543, 9237, 16116, 11869, 2606, 4420, 14461, 3670, 13718, 646, 16097, 12435, 9938, 10077, 2783, 8443, 11870, 1060, 5719, 5775, 6560, 5823, 14754, 16080, 2304, 13596, 9041, 2755, 5937, 9502, 11832, 2453, 11988, 14509, 15502, 11519, 1716, 1364, 13601, 1852, 10264, 4832, 3653, 12237, 13280, 9026, 11120, 8580, 3872, 10439, 6650, 11490, 14387, 10812, 11501, 4887, 11982, 13282, 7977, 15503, 14686, 1748, 1132, 7795, 645, 1492, 5842, 5710, 15348, 647, 11261, 16060, 4422, 1720, 5833, 8479, 10808, 12876, 14430, 6228, 7057, 10438, 522, 10357, 10436, 5797, 10321, 4274, 6239, 11866, 5935, 9023, 12225, 5912, 7023, 10516, 8567, 12900, 3927, 4830, 3586, 7796, 16143, 10811, 10997, 11380, 2175, 3887, 16061, 9030, 3516, 1112, 15813, 7291, 11983, 7356, 644, 4854, 11121, 6235, 15516, 3886, 15956, 5721, 15936, 9319, 15952, 2754, 1559, 9736, 15263, 7271, 12236, 15954, 3674, 11897, 5356, 10296, 573, 10644, 11520, 10082, 334, 14510, 14353, 2642, 15510, 11981, 6910, 10339, 10432, 1210, 9459, 3862, 7355, 7999, 2932, 10899, 100, 8303, 15953, 12203, 12118, 7079, 12259, 10558, 5056, 2478, 8299, 9537, 2635, 7228, 14435, 14471, 15369, 15517, 8923, 10393, 12865, 16387, 9376, 12258, 3398, 15931, 16131, 14527, 12264, 4831, 14621, 15276, 1763, 5831, 12238, 14323, 14515, 14322, 3984, 14601, 7275, 14516, 14324, 10437, 4842, 16112, 4302, 1388, 12098, 12899, 14273, 349, 472, 14358, 14517, 15509, 4511, 2091, 7357, 4278, 15932, 5865, 11920, 16118, 2421, 8211, 7361, 4279, 11143, 3914, 11357, 11487, 16115, 15341, 7272, 3057, 1663, 1494, 7233, 15308, 7995, 15070, 9037, 4424, 6140, 10181, 6585, 2345, 10096, 15623, 10202, 15205, 12337, 14382, 15815, 519, 14325, 5822, 11518, 2784, 15275, 520, 7016, 15305, 10901, 14503, 5349, 6243, 16132, 5760, 14268, 99, 15814, 15127, 15196, 314, 5713, 6231, 15211, 11896, 2726, 13217, 14327, 507, 1666, 15215, 2745, 5834, 5434, 10504, 574, 3470, 61, 7206, 11488, 16184, 11022, 1284, 4968, 4500, 626, 4802, 14861, 4428, 14494, 7428, 10505, 14401, 1200, 15370, 10268, 10220, 15307, 10664, 10741, 10080, 10809, 3672, 15184, 3864, 7463, 14347, 8213, 16135, 4512, 642, 12241, 11058, 9028, 5722, 11921, 503, 15511, 15544, 6499, 12803, 1696, 3792, 10257, 9021, 15084, 2258, 15208, 11447, 11497, 16059, 8075, 3270, 2612, 471, 16134, 947, 14266, 10737, 10540, 15810, 14695, 10081, 16381, 6144, 16065, 7044, 2287, 13219, 16365, 15504, 1425, 1119, 12433, 14690, 1839, 506, 486, 15085, 9032, 14531, 10740, 1260, 2476, 15571, 9452, 9443, 14506, 599, 10596, 14684, 7040, 12579, 1051, 9264, 9516, 9442, 15742, 15181, 15209, 1920, 1137, 5931, 7137, 8400, 15203, 1851, 6669, 4508, 6907, 14321, 12800, 15204, 15212, 9500, 14536, 16062, 9042, 9476, 14339, 641, 7288, 2603, 2257, 1271, 5841, 11868, 2529, 9029, 11032, 15543, 2757, 5824, 616, 12431, 10559, 16133, 14875, 79, 5352, 9718, 5711, 15552, 6134, 7604, 2172, 9031, 9439, 1936, 2108, 7665, 5291, 2759, 7053, 7286, 8716, 352, 15471, 15812, 12580, 5932, 16063, 11498, 11467, 11673, 813, 1424, 10647, 12240, 5837, 15625, 10426, 14529, 5934, 7937, 8277, 15126, 5435, 6500, 5720, 2570, 12802, 12339, 10817, 8503, 8201, 1948, 10499, 15207, 9596, 7797, 12801, 14862, 8976, 14381, 10433, 15816, 14524, 16064, 14903, 3630, 10201, 4514, 15220, 10507, 11023, 9438, 15751, 1844, 7728, 10372, 643, 9219, 3652, 7436, 7043, 584, 15818, 8300, 5829, 16101, 8717, 9461, 14234, 14534, 10502, 9451, 6146, 771, 4686, 16113, 10162, 14697, 1399, 1178, 7461, 2597, 1531, 818, 2773, 15481, 14270, 8924, 7666, 5827, 2858, 2276, 2166, 10477, 3338, 5933, 15380, 1054, 12460, 11470, 10199, 7667, 10826, 1891, 14233, 14530, 2420, 9437, 14224, 8447, 7429, 10828, 15806, 5930, 2452, 596, 3678, 10583, 15629, 11517, 5928, 2763, 14981, 14720, 10663, 3528, 9447, 10662, 14222, 10882, 16380, 7104, 14267, 7042, 14427, 1717, 14383, 5800, 14269, 3295, 1947, 14825, 14502, 9039, 16091, 12475, 12126, 2090, 8217, 9096, 7664, 1140, 8219, 9218, 3773, 14535, 7041, 10318, 4339, 15693, 8216, 3865, 11461, 13740, 10356, 193, 14223, 4538, 15362, 15807, 4291, 14432, 6908, 13084, 7998, 1398, 6148, 4687, 6549, 6583, 2433, 3691, 10491, 3855, 14371, 9456, 11671, 10358, 5863, 1840, 12432, 10488, 8518, 5830, 7274, 3840, 11666, 5835, 14431, 9520, 1063, 14467, 14357, 15750, 4855, 5809, 10376, 15741, 2254, 12498, 2344, 1848, 1179, 14392, 1552, 4844, 2600, 5785, 16379, 1533, 5808, 11361, 1911, 1711, 11946, 3985, 8438, 12159, 14491, 10414, 4015, 6581, 14488, 1827, 4861, 14492, 8890, 436, 8301, 5787, 14490, 9448, 2256, 11668, 1843, 8207, 3863, 1181, 11658, 14344, 1910, 4066, 1047, 12243, 4803, 6147, 12396, 2601, 10196, 16021, 15467, 14821, 4540, 14433, 6726, 5861, 14479, 12037, 2647, 10581, 9441, 13738, 14280, 9020, 14348, 9262, 15378, 11659, 15554, 4301, 7046, 4132, 5786, 12239, 10359, 2585, 2643, 9217, 15740, 10421, 2598, 3631, 5756, 14228, 2184, 1180, 10942, 15338, 2599, 11318, 6132, 4438, 4290, 10417, 8903, 13996, 12128, 3632, 13218, 5859, 14476, 16049, 14445, 14424, 1850, 877, 9097, 2744, 15541, 3838, 13741, 11082, 7895, 11949, 19622, 22917, 18525, 17904, 22947, 23159, 21212, 17257, 19044, 18728, 15690, 17711, 17585, 17968, 18708, 17767, 16808, 22421, 19521, 17225, 21838, 23035, 21214, 19516, 25315, 22871, 18831, 19220, 22930, 23872, 18733, 19935, 21213, 23230, 17798, 9499, 18341, 19514, 21215, 21216, 21217, 17377, 17942, 20779, 3975, 17882, 18320, 17808, 17977, 17881, 18344, 18473, 23029, 20912, 18411, 22887, 18805, 22898, 18096, 15689, 23391, 18373, 17308, 21700, 6487, 23863, 18697, 18667, 16524, 18371, 17888, 16819, 23333, 3976, 17842, 3977, 16813, 18166, 22948, 16807, 18417, 23420, 24664, 17381, 22113, 17880, 21797, 17976, 21955, 20880, 18481, 5828, 17306, 731, 21315, 22841, 24239, 22127, 7800, 17537, 16181, 15691, 4543, 18472, 15687, 18732, 18521, 17991, 15688, 18343, 18478, 23426, 18261, 17941, 18537, 18731, 9019, 14921, 19219, 17907, 22006, 16809, 1493, 17518, 17380, 20201, 16457, 16152, 21801, 22950, 12201, 22103, 21465, 3983, 23899, 20062, 18693, 10435, 18257, 19936, 4275, 17796, 18531, 17980, 19191, 22275, 18497, 16246, 2748, 3974, 16133, 17894, 18584, 18317, 15184, 20555, 25967, 18647, 16472, 17465, 23163, 17975, 17770, 2850, 22997, 26089, 21979, 25741, 639, 19063, 24882, 17536, 16180, 20130, 4542, 16388, 20772, 22441, 9451, 19443, 22856, 24850, 7358, 19671, 15608, 22832, 17301, 18105, 9024, 16845, 3253, 19468, 7267, 20870, 18696, 28132, 18835, 17862, 16329, 17879, 21474, 21964, 5719, 5709, 18695, 2417, 25740, 18423, 8443, 4829, 20132, 15516, 16179, 17897, 19847, 24560, 10440, 18538, 18832, 22357, 22949, 21730, 6490, 6906, 15990, 4422, 13697, 18821, 2425, 11867, 17826, 23390, 18588, 9025, 19554, 20885, 21181, 20600, 4420, 4854, 17978, 24744, 15550, 21506, 4421, 18338, 6489, 18822, 10200, 18586, 18723, 14343, 412, 21774, 21485, 20729, 6488, 23261, 18063, 23354, 6168, 5937, 9056, 17797, 13596, 18168, 15192, 5349, 17803, 23282, 7057, 6910, 12876, 2707, 17057, 19055, 25038, 19221, 13601, 17800, 16816, 18698, 19201, 7273, 25165, 3673, 15989, 20897, 17895, 23281, 12902, 21251, 17684, 19409, 20869, 4428, 17908, 17310, 16815, 19168, 7795, 3671, 3535, 18182, 10119, 16812, 21965, 11866, 20483, 23162, 23574, 9033, 23576, 9568, 18856, 18836, 8303, 14686, 2453, 18407, 6229, 7361, 23577, 12236, 9516, 21657, 2779, 18648, 21867, 20064, 18707, 2931, 10436, 12225, 3654, 19940, 23161, 1060, 2755, 19307, 21984, 17839, 8983, 10438, 22281, 23061, 18530, 12258, 7275, 23353, 8567, 14233, 22199, 21178, 8127, 15114, 19312, 21466, 4831, 20977, 18940, 18046, 25977, 3872, 17848, 8580, 11519, 6130, 21772, 20142, 18290, 7355, 10429, 18528, 22951, 7023, 9459, 1853, 14753, 6584, 20063, 4830, 3581, 21102, 24369, 23418, 17534, 4424, 13716, 20445, 646, 14682, 4949, 17830, 23419, 23578, 3653, 2937, 6243, 1492, 23682, 18680, 7357, 25166, 12237, 9543, 18694, 20896, 3056, 12197, 15816, 19188, 644, 10477, 15510, 12203, 13282, 23267, 19428, 4842, 20454, 16700, 12241, 19314, 25976, 21411, 7206, 10813, 7228, 10184, 8929, 9736, 9236, 19932, 4425, 18281, 18817, 13219, 22112, 18585, 4832, 9156, 7291, 7796, 16886, 18259, 21220, 11518, 10502, 521, 22456, 18834, 4512, 20923, 15727, 9018, 9537, 9017, 17898, 11869, 14430, 21304, 11980, 9502, 11489, 7272, 20886, 645, 6239, 5823, 4887, 20216, 20932, 16131, 24684, 7846, 22828, 4274, 14509, 14354, 7079, 20031, 21966, 1112, 2447, 4302, 6907, 11983, 11496, 3670, 22952, 5797, 1852, 17905, 21998, 18044, 11622, 17899, 23141, 9029, 9196, 16151, 21171, 6109, 20898, 10363, 10181, 24370, 17468, 10357, 20682, 22462, 3914, 7271, 20138, 19050, 1666, 21174, 7354, 14890, 5807, 6235, 13020, 19747, 15205, 5863, 1763, 16814, 2606, 13217, 20881, 9016, 5912, 9027, 9938, 17521, 15742, 19412, 19551, 17916, 8207, 14368, 22056, 4515, 5713, 21877, 8924, 4511, 10426, 6498, 19963, 16545, 18678, 17256, 12397, 11878, 21769, 14693, 22891, 642, 8299, 19735, 14454, 11492, 20033, 1130, 14888, 20039, 10405, 24892, 5708, 1855, 8479, 18679, 18408, 19218, 5722, 9032, 13280, 3927, 18258, 18689, 10096, 4538, 17664, 23375, 5356, 20034, 20900, 5721, 25840, 15511, 7797, 13718, 19720, 21298, 23165, 20060, 21699, 18677, 10299, 8440, 12238, 9031, 11382, 4278, 10596, 9030, 16028, 16387, 22873, 18313, 3068, 9026, 10508, 23158, 20042, 22497, 17307, 18544, 10811, 17533, 24723, 14322, 15263, 9041, 7437, 349, 1663, 19264, 21950, 10812, 22374, 16245, 574, 8196, 23139, 8300, 14020, 3669, 4279, 3886, 10082, 20908, 11022, 22844, 14461, 23619, 17723, 18684, 1210, 17008, 22869, 18956, 18314, 19674, 7356, 3859, 27946, 643, 3850, 12056, 6228, 15299, 23421, 1716, 20036, 3672, 22876, 14232, 22890, 14754, 10204, 9816, 16114, 5830, 23180, 22892, 11120, 19710, 10558, 14327, 15340, 11870, 21488, 647, 16171, 4539, 18141, 2433, 21271, 11832, 19469, 21823, 15815, 11370, 1552, 24685, 17876, 1387, 15308, 23355, 11981, 15954, 10584, 16485, 9376, 21694, 18635, 352, 18690, 4861, 12037, 18683, 462, 9028, 5710, 11487, 12018, 5711, 17548, 5720, 26046, 14222, 16504, 22847, 18681, 3840, 3270, 18886, 10196, 466, 21501, 23168, 15814, 17592, 8277, 5842, 21773, 10430, 22059, 9319, 11583, 20904, 22883, 11865, 18535, 18312, 17144, 9520, 7463, 15362, 10664, 7345, 11520, 23140, 11454, 14502, 16080, 11082, 11490, 20035, 3057, 21873, 17960, 17802, 12337, 10422, 20052, 19480, 10321, 18311, 18885, 234, 10505, 23054, 21104, 17695, 17555, 14525, 19315, 1696, 1132, 17818, 21218, 16841, 14834, 11447, 23332, 18155, 18639, 5358, 19823, 5762, 22062, 17799, 3398, 21230, 18692, 448, 23467, 7137, 5935, 10503, 18807, 22884, 503, 18567, 4500, 18107, 14435, 7605, 947, 14733, 19309, 16173, 17420, 2529, 21483, 17724, 3887, 14325, 14601, 15276, 11032, 11486, 11497, 13738, 2745, 14464, 5834, 22054, 18398, 17957, 20049, 15196, 3849, 5056, 5865, 6131, 10996, 20331, 334, 1260, 5291, 1717, 16132, 17076, 19389, 15471, 16042, 16184, 23394, 9448, 2726, 3855, 24697, 2452, 20909, 21920, 6585, 23270, 19254, 14887, 9438, 16062, 11501, 3586, 15543, 3674, 10808, 20046, 2753, 20911, 20905, 18633, 15440, 21508, 18241, 20040, 5048, 17833, 14889, 573, 14529, 13597, 641, 14526, 21932, 21954, 21952, 15305, 4514, 10182, 4821, 16473, 18422, 15758, 2751, 18440, 15042, 12057, 15928, 21986, 24059, 17275, 10257, 17264, 18830, 24727, 21865, 1920, 15432, 2598, 19273, 25167, 23022, 21232, 7937, 22853, 24848, 16358, 9021, 17864, 10504, 19308, 16945, 20873, 21164, 16406, 20038, 4015, 14457, 18229, 11868, 2175, 1851, 4810, 21913, 13741, 16097, 15952, 15517, 10439, 10516, 17547, 5775, 24549, 20043, 3516, 23368, 21410, 17801, 20202, 17840, 18331, 18796, 22060, 507, 24245, 20757, 16412, 17817, 1842, 23337, 23339, 19797, 16581, 2476, 16021, 11658, 15817, 4440, 2520, 16128, 20902, 11582, 23047, 9678, 23626, 11357, 11359, 21274, 15929, 6560, 7320, 23177, 18093, 8198, 17918, 20910, 21272, 15067, 9442, 10437, 11502, 11673, 4823, 9819, 7998}
local RawEliteData = {"Rare 37", "Elite 51", "Elite 40", "Elite 42", "Rare Elite 23", "Elite 59", "Boss ??", "Rare Elite 21", "Boss ??", "Elite 50", "Boss ??", "Boss ??", "Elite 62", "Boss ??", "Elite 26", "Elite 35", "Elite 42", "Elite 40", "Rare 41", "Rare 10", "Boss ??", "Elite 47", "Elite 37", "Rare 13", "Elite 60", "Elite 43", "Boss ??", "Elite 28", "Boss ??", "Elite 55", "Elite 34", "Elite 41", "Elite ??", "Elite 56", "Boss ??", "Elite 57", "Elite 55", "Elite 42", "Boss ??", "Elite 28", "Elite 56", "Boss ??", "Elite 50", "Elite 54", "Boss ??", "Elite 58", "Elite 22", "Boss ??", "Elite 54 - 55", "Boss ??", "Elite 34", "Rare 50", "Elite 45", "Elite 61", "Elite 50", "Elite 60", "Elite 57", "Rare Elite 60", "Boss ??", "Elite 61", "Elite 60", "Boss ??", "Elite 43", "Rare Elite 33", "Elite 57", "Rare Elite 60", "Elite 48", "Elite 34", "Elite 11", "Elite 60", "Elite 50", "Elite 39", "Elite 60", "Elite 62", "Elite 56", "Rare Elite 52", "Boss ??", "Rare 23", "Elite 33", "Elite 30", "Elite 60", "Boss ??", "Rare 12", "Rare 26", "Rare Elite 33", "Rare Elite 55", "Rare Elite 44", "Boss ??", "Elite 54", "Elite 58", "Boss ??", "Boss ??", "Elite 60", "Rare 24", "Boss ??", "Elite 61", "Elite 58", "Elite 59", "Boss ??", "Rare Elite 33", "Elite 55", "Elite 25", "Elite 43", "Elite 54 - 55", "Elite 32", "Elite 62", "Elite 61", "Boss ??", "Rare Elite 51", "Boss ??", "Elite 61", "Elite 60", "Elite 60", "Elite 40", "Boss ??", "Elite 61", "Elite 58", "Boss ??", "Rare 52", "Elite 62", "Elite 32", "Boss ??", "Elite 62", "Elite 41", "Boss ??", "Rare Elite 59", "Elite 48", "Elite 49", "Elite 57", "Elite 18", "Boss ??", "Elite 58", "Elite 26", "Elite 60", "Elite 58", "Boss ??", "Elite 20", "Elite 46", "Elite 20", "Elite 20", "Rare 57", "Boss ??", "Elite 52", "Boss ??", "Rare Elite 32", "Elite 58 - 60", "Elite 55", "Elite 62", "Boss ??", "Elite 59", "Boss ??", "Boss ??", "Rare 12", "Elite 35", "Rare Elite 55", "Elite 40", "Rare Elite 60", "Boss ??", "Rare 9", "Boss ??", "Elite 57 - 58", "Elite 34", "Boss ??", "Elite 21", "Rare 19", "Elite 59", "Elite 55", "Elite 60", "Elite 50 - 51", "Elite 53", "Elite 59", "Elite 60", "Elite 50", "Rare 37", "Elite 32", "Elite 58", "Elite 21", "Elite 41", "Elite 20", "Elite 60", "Boss ??", "Elite 57", "Rare 53", "Elite 40", "Elite 60", "Elite 50", "Elite 44", "Elite 52", "Elite 21", "Elite 60 - 61", "Rare 11", "Elite 55", "Elite 60", "Elite 32", "Elite 50", "Rare Elite 56", "Elite 44", "Rare Elite 35", "Elite 55", "Elite 62", "Rare 39", "Boss ??", "Boss ??", "Elite 60", "Elite 16", "Elite 29", "Elite 34", "Elite 50", "Elite 61", "Elite 60", "Elite 27", "Elite 20", "Rare Elite 48", "Elite 57", "Elite 52", "Elite 60", "Elite 50", "Rare Elite 25", "Elite 61", "Rare 50 - 51", "Elite 57", "Elite 60", "Elite 62", "Elite 62", "Elite 25", "Boss ??", "Elite 48", "Elite 48", "Elite 60", "Elite 40", "Boss ??", "Rare 10", "Elite 46", "Elite 20", "Elite 47", "Rare Elite 19", "Elite 54", "Boss ??", "Elite 20", "Elite 60", "Boss ??", "Elite 33", "Rare Elite 26", "Elite 48", "Elite 55", "Rare Elite 58", "Elite 28", "Rare 9", "Rare Elite 33 - 41", "Rare Elite 38", "Elite 61", "Elite 35", "Rare 11", "Elite 59", "Rare Elite 25", "Elite 61", "Elite 25", "Elite 40", "Elite 50", "Rare Elite 37", "Elite 52", "Elite 49", "Rare Elite 20", "Elite 42", "Elite 57", "Elite 40", "Elite 62", "Elite 25", "Elite 26", "Rare Elite 19", "Elite 45 - 46", "Elite 60", "Elite 60", "Elite 60", "Boss ??", "Rare 13", "Elite 24", "Boss ??", "Elite 53", "Boss ??", "Rare 24", "Elite 20", "Elite 45", "Boss ??", "Elite 40", "Elite 19", "Elite 45", "Elite 61 - 62", "Elite 32", "Boss ??", "Elite 22", "Boss ??", "Elite 53", "Boss ??", "Elite 52", "Boss ??", "Rare Elite 45", "Elite 50 - 51", "Rare Elite 59", "Boss ??", "Elite 46", "Elite 47", "Boss ??", "Elite 21", "Elite 60", "Rare 42", "Elite 60", "Rare 20", "Rare 22", "Elite 16", "Rare Elite 45", "Elite 26", "Boss ??", "Elite 60", "Elite 47 - 48", "Boss ??", "Boss ??", "Elite 40", "Elite 62", "Elite 60", "Elite 22", "Elite 55", "Elite 18 - 25", "Elite 40", "Boss ??", "Elite 38", "Elite 61", "Rare 12", "Rare 50", "Boss ??", "Elite 50", "Boss ??", "Elite 30", "Boss ??", "Rare Elite 57", "Elite 20 - 21", "Elite 19 - 21", "Rare 52", "Elite 55", "Elite 38", "Elite 40", "Boss ??", "Rare Elite 61", "Boss ??", "Boss ??", "Rare Elite 57", "Rare Elite 58", "Elite 36", "Boss ??", "Elite 56", "Elite 48", "Rare Elite 20", "Boss ??", "Elite 60", "Elite 60", "Boss ??", "Elite 25", "Elite 49 - 50", "Boss ??", "Elite 20", "Rare Elite 21", "Elite 60", "Elite 59", "Boss ??", "Elite 59", "Elite 33", "Boss ??", "Elite 47", "Elite 62", "Elite 60", "Elite 60", "Rare Elite 32", "Elite 60", "Elite 39 - 40", "Elite 11", "Boss ??", "Elite 62", "Rare 25", "Elite 25", "Rare 12", "Elite 60", "Boss ??", "Boss ??", "Elite 24 - 25", "Elite 32", "Elite 39", "Elite 24", "Boss ??", "Rare 13", "Elite 20", "Elite 60", "Elite 40", "Rare 42", "Elite 32", "Elite 24", "Elite 60", "Elite 20", "Elite 60", "Elite 60", "Elite 60", "Boss ??", "Elite 45 - 46", "Boss ??", "Elite 26", "Elite 52", "Elite 30", "Elite 60", "Elite 51", "Elite 60", "Elite 56", "Elite 30", "Elite 55", "Boss ??", "Rare 52 - 53", "Elite 29 - 30", "Elite 52", "Elite 62", "Rare Elite 59", "Boss ??", "Elite 60", "Elite 60", "Elite 40", "Rare 15", "Elite 61", "Rare Elite 11", "Elite 16", "Boss ??", "Boss ??", "Rare 19", "Rare 22", "Boss ??", "Elite 60", "Elite 63", "Rare 49", "Elite 26", "Elite 60", "Elite 40", "Rare 15 - 16", "Rare 10", "Elite 28", "Elite 55", "Elite 59", "Elite 31", "Elite 51", "Elite 26", "Elite 60", "Elite 61", "Elite 43 - 45", "Elite 58", "Elite 57", "Rare 32", "Elite 27", "Elite 62", "Elite 42", "Rare 25", "Elite 46 - 47", "Elite 60", "Rare 27", "Rare 15", "Rare 11", "Elite 44", "Elite 60", "Elite 60", "Elite 60", "Boss ??", "Boss ??", "Elite 45", "Elite 20", "Elite 20 - 21", "Elite 61", "Elite 30", "Elite 60", "Elite 59 - 60", "Elite 60", "Elite 60", "Elite 32", "Boss ??", "Elite 60", "Elite 59", "Elite 60", "Elite 60", "Elite 60", "Rare Elite 45", "Rare Elite 60", "Rare Elite 20", "Elite 60", "Elite 19 - 20", "Elite 59 - 60", "Elite 62", "Rare 51", "Elite 60", "Elite 28", "Elite 20", "Elite 43", "Elite 61", "Elite 54", "Elite 53", "Elite 21", "Rare 31", "Boss ??", "Boss ??", "Elite 54 - 56", "Elite 62", "Elite 24", "Rare 31 - 32", "Elite 58", "Elite 52", "Boss ??", "Rare 37", "Elite 62", "Rare Elite 60", "Rare Elite 60", "Elite 60", "Elite 50", "Rare Elite 15", "Elite 38", "Rare 10", "Elite 60", "Rare 26", "Rare 19", "Elite 60", "Boss ??", "Elite 16 - 18", "Elite 60", "Rare Elite 45", "Elite 60", "Elite 54 - 55", "Boss ??", "Elite 50 - 52", "Elite 39 - 40", "Elite 58", "Elite 60", "Elite 60", "Rare 15", "Rare 12", "Rare 15", "Elite 60", "Rare Elite 63", "Rare 18", "Elite 24", "Boss ??", "Elite 53", "Elite 60", "Elite 57", "Rare 11", "Rare 22", "Boss ??", "Elite 53 - 55", "Elite 55", "Elite 62", "Rare Elite 18", "Elite 59", "Elite 60", "Elite 52 - 53", "Elite 26", "Elite 27 - 28", "Elite 57 - 58", "Elite 59", "Elite 55", "Boss ??", "Elite 62", "Elite 60", "Rare 21", "Rare 9", "Rare Elite 24", "Rare Elite 56", "Elite 52", "Boss ??", "Rare 62", "Elite 20", "Elite 27", "Elite 40", "Elite 58 - 59", "Elite 60 - 61", "Boss ??", "Elite 60", "Elite 54", "Elite 60", "Boss ??", "Rare Elite 55", "Elite 55", "Rare 49", "Elite 18 - 19", "Elite 23", "Rare 36", "Elite 43", "Elite 11", "Rare Elite 17", "Elite 50", "Elite 24 - 25", "Elite 54", "Elite 60", "Boss ??", "Elite 50", "Rare Elite 11", "Rare 23", "Rare 13", "Rare 22", "Elite 60", "Elite 60", "Rare 10", "Rare 43", "Rare Elite 59", "Elite 53", "Elite 63", "Elite 60", "Elite 45", "Rare 20", "Elite 54", "Elite 55", "Rare 8", "Rare 29", "Elite 58", "Elite 49 - 50", "Elite 50", "Elite 23", "Elite 43 - 44", "Elite 62", "Elite 55", "Elite 61", "Elite 18 - 20", "Elite ??", "Rare Elite 22", "Boss ??", "Rare Elite 58", "Elite 59", "Elite 61 - 62", "Elite 40", "Rare 15", "Rare 32", "Elite 43", "Rare 15", "Boss ??", "Elite 59 - 60", "Elite 60", "Rare Elite 32", "Boss ??", "Rare 48", "Elite 55", "Elite 12 - 13", "Elite 54 - 55", "Elite 51", "Elite 38 - 39", "Elite 61 - 62", "Elite 61", "Rare 55", "Rare 11", "Rare 50", "Rare 23", "Elite 58 - 60", "Elite 62", "Rare Elite 59", "Elite 46", "Elite 60 - 62", "Boss ??", "Rare Elite 60", "Elite 60", "Elite 58", "Elite 50", "Elite 63", "Boss ??", "Elite 60", "Elite 15 - 16", "Rare Elite 61", "Elite 25 - 26", "Elite 62", "Elite 60", "Elite 60", "Elite 55", "Elite 43 - 45", "Rare 58", "Elite 55", "Elite 60 - 61", "Elite 20", "Rare Elite 57", "Rare Elite 19", "Elite 56 - 57", "Elite 57 - 58", "Rare 27", "Boss ??", "Rare 51", "Rare 17", "Elite ??", "Elite 61", "Elite 54", "Rare 41", "Elite", "Elite 60", "Elite 55 - 57", "Elite 54 - 62", "Rare 32", "Elite 38 - 39", "Elite 60", "Boss ??", "Rare 61", "Rare 21", "Elite 18 - 19", "Elite 59 - 60", "Elite 40", "Rare 6 - 7", "Elite 47", "Elite 40", "Boss ??", "Rare 19", "Rare Elite 50", "Elite 58", "Rare Elite 27", "Elite 55", "Elite 60", "Elite 9", "Elite 58 - 59", "Elite 60", "Rare 31", "Boss ??", "Elite 30 - 31", "Elite 62 - 63", "Elite 58 - 59", "Rare 59", "Elite 59", "Rare 57", "Elite 13 - 14", "Rare 39", "Elite", "Elite 41", "Elite 55", "Rare 41", "Elite 48", "Elite 59 - 60", "Rare Elite 59", "Elite 28", "Rare Elite 28", "Rare 36", "Rare Elite 18", "Elite 20", "Elite 55", "Elite 62", "Elite 16", "Rare Elite 27", "Elite 42", "Elite 61", "Elite 62", "Elite 58", "Elite 14 - 15", "Elite 53 - 54", "Elite 56", "Rare 35", "Elite 28", "Rare 61", "Rare Elite 56", "Rare Elite 19", "Elite 56 - 57", "Rare 28", "Elite 28", "Elite 58", "Rare Elite 24", "Rare 21", "Rare 19", "Elite 24", "Elite 56 - 60", "Elite 62", "Elite 57", "Elite 60", "Elite 60", "Elite ??", "Rare 23", "Rare Elite 52", "Elite 58 - 59", "Elite 60", "Rare 31", "Rare 43", "Rare Elite 58", "Rare 26", "Elite", "Elite 53 - 54", "Elite 60 - 61", "Rare Elite 45", "Elite 61", "Rare 48", "Elite 20 - 21", "Elite 57 - 58", "Elite", "Rare 10", "Elite 50 - 51", "Rare 32", "Elite 30 - 31", "Boss ??", "Elite 25", "Elite 34 - 35", "Rare 6", "Elite 40", "Elite 50", "Elite 27", "Rare 22", "Elite 52 - 62", "Elite 39 - 40", "Elite 40", "Rare Elite 57", "Elite 44", "Elite 60", "Elite 58 - 59", "Elite 20 - 21", "Elite 52", "Elite 20", "Elite 61", "Rare 12", "Rare 19", "Elite ??", "Rare 14", "Elite 58 - 61", "Elite 29", "Rare Elite 19", "Elite 46", "Elite 19 - 20", "Elite 60 - 62", "Rare 19", "Rare 8", "Elite 56", "Rare Elite 47", "Elite 55", "Elite 25", "Elite 45 - 48", "Elite 43 - 44", "Rare 9", "Rare Elite 60", "Boss ??", "Elite 36 - 37", "Elite 62", "Elite 28 - 29", "Rare 56", "Elite 18 - 19", "Elite 60", "Rare 45", "Elite 35 - 36", "Rare 34", "Rare Elite 11", "Rare 61", "Rare 8 - 9", "Rare 9", "Elite 60", "Rare 12", "Elite 24 - 25", "Elite ??", "Elite 34", "Elite 49 - 50", "Elite", "Rare 42", "Elite 57 - 58", "Rare 25", "Rare 50", "Rare 38", "Elite 55 - 56", "Elite 38 - 39", "Rare 42", "Elite 49 - 50", "Elite 22 - 23", "Rare 53", "Rare 11", "Rare 44", "Elite 56 - 57", "Elite 38 - 39", "Elite 60 - 62", "Rare Elite 62", "Rare 46", "Elite 24 - 25", "Elite 18 - 19", "Elite 61 - 62", "Rare 50", "Rare 10", "Rare Elite 30", "Elite 59 - 60", "Elite 47", "Elite 21 - 22", "Elite 53 - 62", "Elite 61", "Rare Elite 42", "Rare Elite 56 - 57", "Elite 62", "Boss ??", "Elite 60", "Elite 35 - 36", "Rare 30", "Elite 55", "Elite 48 - 49", "Rare 60", "Rare 31", "Elite 49 - 50", "Elite 20", "Elite 55", "Elite", "Rare 27", "Elite 54", "Elite 62", "Elite 56 - 57", "Boss ??", "Elite 62 - 63", "Elite 61", "Elite 38 - 39", "Elite 56 - 58", "Rare 36", "Rare 9", "Elite 42", "Rare 13", "Elite 39 - 40", "Elite 47 - 48", "Rare Elite 58", "Boss ??", "Elite 58 - 59", "Rare Elite 39", "Elite 16 - 17", "Elite 20 - 21", "Rare 34", "Rare 17", "Elite 19 - 20", "Boss ??", "Elite 61", "Elite 38", "Elite 13 - 15", "Elite 23 - 24", "Rare Elite 29 - 30", "Elite 36 - 37", "Elite 60 - 61", "Elite 55 - 56", "Elite 59 - 60", "Elite 60", "Elite 15 - 16", "Elite 58", "Rare Elite 26", "Rare 56", "Elite 60", "Rare Elite 45", "Rare 25", "Rare Elite 58", "Elite 35 - 36", "Elite 54 - 55", "Rare 40", "Elite 60", "Elite 55", "Elite", "Elite 57", "Rare Elite 36", "Elite 61", "Boss", "Boss", "Elite 72", "Elite 60", "Boss", "Elite", "Boss", "Boss ??", "Boss ??", "Boss ??", "Boss ??", "Boss ??", "Elite 62", "Boss", "Elite 72", "Boss", "Elite 72", "Elite 70", "Elite 70", "Boss ??", "Elite", "Elite", "Boss", "Boss", "Boss", "Boss", "Boss ??", "Elite 72", "Elite", "Elite", "Elite 70", "Elite 73", "Boss", "Boss", "Elite 72", "Elite 55", "Elite 66 - 72", "Boss", "Boss", "Boss", "Boss", "Elite 63 - 72", "Elite 64 - 72", "Elite 70", "Elite 37", "Elite 65 - 72", "Elite 69 - 72", "Boss", "Elite 72", "Elite 72", "Elite 66 - 72", "Elite 69 - 72", "Elite", "Elite 72", "Elite 67", "Boss", "Boss", "Boss", "Elite 68 - 72", "Boss ??", "Elite", "Elite 67 - 72", "Elite 62 - 72", "Elite 70", "Elite 35", "Boss", "Rare 69", "Elite 72", "Boss ??", "Elite 66 - 71", "Boss", "Elite 65", "Elite", "Elite 40", "Boss", "Elite 40", "Elite 70", "Elite 71", "Boss", "Elite 71 - 72", "Elite 70", "Boss", "Elite", "Elite 62 - 71", "Elite 71", "Elite 72", "Elite 72", "Elite 72", "Elite 68", "Elite 70", "Elite 73", "Rare Elite 23", "Elite 62 - 72", "Elite 43", "Elite 71", "Boss", "Boss", "Elite 72", "Elite 28", "Elite 62 - 72", "Rare Elite 73", "Boss ??", "Elite 32", "Elite 69 - 72", "Boss ??", "Elite 72", "Elite 67 - 72", "Elite 64 - 72", "Boss ??", "Elite 66 - 72", "Elite 67 - 72", "Boss", "Elite 70", "Elite 64 - 72", "Elite 71", "Elite 72", "Elite 56", "Elite 56", "Elite 72", "Elite", "Elite 70", "Elite 72", "Elite 46", "Elite 70", "Elite 63 - 72", "Elite 73", "Boss ??", "Boss ??", "Elite 70", "Boss", "Elite 48", "Elite 72", "Elite 70", "Elite 32", "Boss ??", "Elite", "Rare 68", "Elite 58", "Elite 67", "Elite 71", "Elite 21", "Elite 72", "Elite 73", "Elite 72", "Elite 63", "Elite", "Elite 65 - 71", "Elite 21", "Elite 40", "Elite 34", "Elite 60", "Elite", "Elite 68", "Elite 64 - 71", "Elite 70", "Elite 70", "Elite", "Elite 64", "Elite 71", "Elite 70 - 71", "Elite", "Elite 72", "Elite 65 - 72", "Rare 37", "Elite", "Elite", "Elite 70", "Boss", "Elite 20", "Elite 70", "Boss", "Elite", "Rare Elite 73", "Elite 66", "Elite 40", "Elite 70", "Elite 68", "Elite 65", "Elite 55 - 57", "Elite 61", "Boss", "Boss", "Elite 37", "Elite 66", "Boss ??", "Elite 71", "Elite 70", "Elite 65 - 72", "Rare Elite 52", "Elite 68", "Rare 24", "Elite 68", "Elite 46", "Elite 72", "Rare", "Elite 68 - 72", "Boss ??", "Elite 68 - 72", "Elite 21", "Elite 72", "Elite 70", "Elite", "Elite 50", "Elite 50", "Rare 69", "Elite 39", "Elite", "Elite 67", "Elite", "Elite 24", "Elite 72", "Boss ??", "Rare Elite 73", "Elite", "Elite 66", "Elite", "Elite 62", "Elite 72", "Boss ??", "Elite 73", "Boss", "Elite 72", "Rare Elite 32", "Elite 39", "Boss ??", "Elite 27", "Elite 45", "Elite 65", "Boss ??", "Elite 50", "Elite 65 - 72", "Elite", "Elite 68", "Elite 51", "Elite 70", "Elite 72", "Elite 72", "Elite 70", "Elite 27", "Elite 40", "Elite 72", "Elite", "Boss ??", "Elite 70", "Elite 27", "Boss ??", "Rare Elite 32", "Elite 65", "Rare 57", "Elite 68", "Elite 70", "Rare 52", "Elite 35", "Elite 70", "Elite 70", "Elite 67", "Rare Elite 32", "Elite 72", "Boss ??", "Elite", "Elite 26", "Rare Elite 35", "Elite 53", "Elite 72", "Elite 48", "Boss ??", "Boss ??", "Rare", "Elite 70", "Elite 72", "Rare Elite 38", "Elite 39", "Elite 24", "Elite 55", "Elite 63", "Elite 66", "Boss", "Elite 72", "Elite 48", "Elite 70", "Boss ??", "Rare 68", "Elite 66 - 67", "Elite 46", "Boss", "Elite 20", "Boss ??", "Elite 70", "Elite", "Elite 72", "Elite 24", "Elite", "Elite 33", "Elite 65", "Elite 70", "Elite 27", "Elite", "Elite 40", "Elite 70", "Elite 69 - 70", "Elite 46", "Elite 20", "Rare 13", "Elite 67", "Rare Elite 60", "Elite 70", "Elite", "Elite 50", "Elite 69", "Elite", "Boss", "Elite 55", "Boss", "Elite 60", "Elite 68", "Boss ??", "Rare", "Elite", "Rare", "Elite 70", "Elite 28", "Elite 28", "Boss", "Elite 44", "Elite 59", "Elite 72", "Rare 41", "Elite 64", "Elite 72", "Elite", "Elite 65", "Rare Elite 55", "Elite 59", "Elite 46", "Elite 20", "Elite 67 - 68", "Elite", "Elite 44", "Elite 44", "Elite 64 - 70", "Elite ??", "Elite 71", "Elite 55", "Elite 61", "Elite", "Elite 72", "Elite 72", "Elite 46", "Elite 46", "Elite", "Elite 37", "Rare 37", "Elite 70", "Elite 70", "Elite 46", "Boss ??", "Elite 62", "Elite 72", "Elite 23", "Elite 70", "Elite 65", "Elite 63", "Elite", "Rare Elite 21", "Elite 68 - 72", "Elite 49", "Elite 16", "Elite 52 - 53", "Elite 69", "Elite 70", "Elite 68", "Elite 37", "Boss ??", "Elite 70", "Boss", "Elite 40", "Elite 55", "Elite 61", "Elite 55", "Rare Elite 60", "Elite", "Elite 24", "Rare 50", "Elite 70", "Elite 70", "Boss", "Boss ??", "Elite 27", "Elite 46", "Elite 64", "Elite 20", "Elite", "Boss ??", "Elite 20", "Boss", "Boss", "Elite 20", "Elite 43", "Elite 24", "Elite 42", "Elite", "Rare", "Elite 37", "Boss", "Rare Elite 46", "Elite 53", "Rare 68", "Elite 70", "Rare 12", "Elite 61", "Elite", "Elite 63", "Elite 19", "Elite 58 - 59", "Boss ??", "Elite 48", "Elite 46", "Elite", "Elite 68 - 71", "Rare Elite 27", "Elite 72", "Elite 70", "Elite 43", "Elite 62", "Elite", "Elite 62", "Elite 40", "Elite", "Elite 39", "Boss ??", "Elite 55", "Elite 59", "Elite 58", "Elite 70", "Rare Elite 27", "Elite 61", "Elite 69", "Elite 58", "Elite 72", "Elite 68", "Elite 24", "Elite 55", "Elite 40", "Elite 45", "Elite 61", "Elite 67", "Elite", "Elite 16", "Elite 60", "Rare 23", "Elite 70", "Boss ??", "Elite 26", "Elite 72", "Boss ??", "Elite 52", "Elite 55", "Elite 53", "Elite", "Elite 50", "Rare 9", "Elite 68 - 69", "Elite 72", "Elite 55", "Elite 60", "Elite 46", "Elite 72", "Elite 20", "Elite 40", "Rare 11", "Elite 23", "Elite 70", "Rare", "Elite 60", "Elite", "Boss ??", "Elite", "Elite 21", "Boss ??", "Elite 57", "Elite 28", "Elite", "Elite", "Rare 24", "Rare Elite 44", "Elite 39", "Elite 39", "Boss ??", "Elite 61", "Elite 20", "Boss", "Rare Elite 22", "Elite 61", "Elite", "Elite 70", "Elite 63", "Elite 61", "Elite", "Elite", "Elite 52", "Elite 57", "Boss ??", "Elite 70", "Boss ??", "Elite 71", "Boss ??", "Boss ??", "Elite 70", "Boss ??", "Rare", "Elite 65", "Elite 62", "Elite 20", "Elite 46", "Elite 70", "Elite 70", "Elite 25", "Boss", "Elite 37", "Boss ??", "Rare 10", "Elite 28", "Boss ??", "Elite 68", "Boss", "Rare 19", "Elite 20", "Elite 70", "Rare 37", "Elite 58", "Elite 70", "Elite 52", "Rare Elite 19", "Elite 52", "Elite 56", "Boss ??", "Boss", "Elite 73", "Elite", "Elite", "Rare", "Elite 60", "Elite", "Elite 25 - 26", "Elite 49", "Elite 72", "Rare 50", "Elite 24 - 25", "Elite 59 - 60", "Elite 54 - 55", "Elite 68", "Elite 72", "Rare 62", "Boss ??", "Boss ??", "Elite 62", "Elite 70", "Elite", "Elite 70", "Elite 20", "Rare", "Elite 71", "Elite", "Elite 58", "Elite", "Rare 12", "Boss", "Elite", "Elite 57 - 58", "Boss", "Elite 49", "Elite 61", "Elite 55", "Rare 62", "Elite 70", "Elite 72", "Elite 50", "Elite 52", "Elite 57", "Elite 21", "Elite 67", "Rare 65", "Elite 52", "Elite 26", "Elite 18", "Elite", "Rare 42", "Elite", "Elite 71", "Elite 50", "Boss", "Boss ??", "Elite 45", "Elite 41", "Elite 66", "Elite", "Elite", "Elite", "Elite 72", "Rare 61", "Elite 54 - 55", "Elite 48 - 49", "Elite 60", "Elite 52", "Boss ??", "Elite 20", "Elite 59", "Elite 52", "Boss ??", "Boss", "Elite", "Elite 65 - 71", "Rare 9", "Elite 51", "Elite 62", "Elite", "Elite", "Elite 72", "Elite 62 - 72", "Elite 70", "Elite 60", "Boss ??", "Elite", "Elite 59", "Boss ??", "Rare Elite 54", "Elite 57 - 58", "Elite 25", "Elite 25", "Elite 63", "Elite 70", "Elite 62", "Elite 63", "Elite 21", "Rare", "Elite 50", "Elite", "Rare", "Boss ??", "Elite 20", "Elite 21", "Elite 20", "Rare Elite 45", "Elite 72", "Elite 60", "Elite", "Elite 58", "Elite", "Elite 63 - 70", "Rare", "Elite 22", "Boss ??", "Elite", "Elite 67", "Elite 65 - 72", "Elite 73", "Elite 37", "Elite 20", "Elite 65", "Elite 20", "Elite 18", "Boss ??", "Rare Elite 28", "Boss ??", "Elite", "Elite 25", "Elite", "Rare 17", "Elite", "Rare 38", "Elite 70", "Elite 55", "Elite 72", "Boss ??", "Elite 60", "Rare Elite 19", "Elite 67 - 72", "Elite 70", "Elite 60", "Elite 72", "Rare Elite 57", "Elite 57", "Boss ??", "Elite 50", "Elite 70", "Elite 20", "Elite 71", "Elite 26", "Boss ??", "Elite 44", "Elite", "Elite 72", "Elite 69", "Boss", "Elite", "Elite 61", "Rare", "Elite", "Elite 67 - 71", "Elite 65", "Elite 60", "Elite", "Boss ??", "Boss ??", "Elite 60", "Elite 72", "Elite 56", "Elite 70", "Elite 69 - 71", "Elite 65", "Rare", "Elite 37 - 38", "Rare 31", "Rare", "Rare", "Elite 52", "Elite 50", "Elite 60", "Boss ??", "Elite 49", "Elite 70", "Elite 50", "Boss", "Rare 35", "Elite 72", "Elite", "Rare", "Elite 19", "Rare Elite 15", "Elite 69 - 70", "Rare Elite 57", "Elite 72", "Elite 68 - 69", "Elite", "Elite", "Elite 20", "Rare", "Rare Elite", "Elite 70", "Boss ??", "Elite 70", "Elite 52", "Boss ??", "Elite 72", "Elite", "Elite 50", "Elite 68", "Elite 65 - 72", "Rare", "Elite 56", "Elite 59 - 60", "Boss", "Elite 60", "Elite 36", "Elite 16", "Elite", "Elite 55 - 56", "Elite 62", "Elite", "Elite 57", "Elite 57", "Elite", "Boss ??", "Elite", "Elite 62 - 70", "Elite 70", "Elite 60", "Elite 58 - 59", "Elite", "Elite 67 - 68", "Elite 61", "Elite 64 - 70", "Elite 67 - 68", "Elite 35", "Elite 60", "Boss", "Elite 71", "Elite 70 - 71", "Elite 65", "Elite 63", "Elite 62", "Elite 24", "Rare 10", "Elite", "Elite", "Elite 62", "Boss ??", "Rare Elite", "Elite", "Elite 69 - 70", "Elite 70 - 71", "Elite 49 - 50", "Elite 69 - 70", "Elite 19", "Rare 18", "Elite 70", "Rare Elite 20", "Elite", "Rare", "Elite 11", "Boss", "Rare Elite", "Rare Elite", "Elite 61", "Elite 65", "Elite", "Rare 31", "Elite 68", "Elite 45", "Elite", "Boss", "Elite 44", "Rare", "Elite 55", "Elite 64", "Elite 69 - 70", "Elite 69 - 70", "Elite 20", "Elite 70", "Elite 62 - 70", "Elite 20", "Elite 61", "Boss ??", "Boss ??", "Elite 60", "Elite 61", "Rare Elite 60", "Elite", "Elite 42", "Elite 58", "Rare 25", "Elite", "Elite 65 - 66", "Elite 63 - 71", "Elite", "Elite 59", "Elite 18", "Elite 19", "Rare 13", "Elite 51 - 52", "Elite 58 - 60", "Elite 70", "Elite 26", "Rare 11", "Elite 48 - 49", "Elite 25", "Elite 60", "Boss ??", "Elite 72", "Elite 61", "Boss ??", "Rare Elite 60", "Elite", "Elite 56 - 57", "Elite 43 - 45", "Elite 19", "Elite", "Rare 36", "Elite 72", "Elite", "Rare 52", "Elite 70", "Elite 70", "Boss ??", "Elite 53", "Boss ??", "Elite 62", "Rare Elite 19", "Boss ??", "Elite 20", "Elite 58", "Elite", "Rare", "Elite 72", "Elite 70", "Elite 69 - 70", "Elite 60", "Elite", "Rare 32", "Elite", "Elite 18 - 19", "Elite 67 - 71", "Boss ??", "Rare 20", "Elite 60", "Elite", "Elite 18 - 19", "Elite 63", "Boss", "Elite 69", "Elite 70", "Boss", "Elite 25", "Elite ??", "Elite 22", "Elite 71", "Elite 70 - 71", "Elite", "Rare", "Elite 65 - 66", "Elite 60", "Boss ??", "Boss ??", "Elite 70", "Elite", "Elite 70", "Elite 58", "Elite 60 - 71", "Elite 70", "Elite 70", "Elite", "Rare", "Elite", "Rare Elite 39", "Elite 65", "Elite", "Elite 70 - 71", "Elite", "Boss ??", "Elite", "Elite", "Elite 20", "Elite 52", "Elite", "Elite 60", "Elite 71", "Elite 67 - 68", "Elite 70", "Elite 70", "Elite 71", "Elite", "Rare 25", "Elite", "Elite ??", "Elite 50", "Rare 13", "Rare 62", "Elite 23", "Elite", "Elite", "Elite", "Boss ??", "Boss ??", "Elite 61", "Elite 57", "Elite 72", "Elite 20", "Elite", "Elite", "Boss ??", "Elite", "Elite 71", "Elite 70", "Elite 69", "Elite 65 - 69", "Elite 65 - 71", "Elite 70", "Rare 18", "Rare 32", "Elite", "Elite 67", "Elite 71", "Elite 62 - 70", "Elite ??", "Elite", "Elite", "Elite 71", "Boss", "Rare 22", "Elite 62", "Elite 62", "Elite", "Elite 25 - 26", "Elite 18", "Boss", "Elite 70", "Elite 58 - 59", "Elite", "Elite 53", "Elite", "Elite 60", "Elite 61", "Elite", "Boss ??", "Elite 60 - 61", "Elite 38 - 39", "Elite 67 - 72", "Elite 67 - 72", "Elite 52", "Elite 70", "Elite 72", "Elite", "Elite 61", "Elite", "Elite 60", "Boss ??", "Elite 62", "Elite 23", "Elite 59 - 60", "Elite 26" }
local RawEliteZones = {"Badlands", "Maraudon", "Scarlet Monastery", "Scarlet Monastery", "The Barrens", "Blackrock Depths", "an Unknown Location", "The Deadmines", "Azshara Storm Cliffs", "The Hinterlands", "Blasted Lands", "Molten Core", "Stratholme", "Blackrock Spire", "Shadowfang Keep", "Duskwood", "Scarlet Monastery", "Stranglethorn Vale", "Arathi Highlands", "Mulgore", "Zul'Gurub", "Uldaman", "Scarlet Monastery", "Teldrassil", "Silithus", "Stranglethorn Vale", "Blackwing Lair", "Razorfen Kraul", "Naxxramas", "Blackrock Depths", "Gnomeregan", "Razorfen Downs", "Feralas Desolace Stonetalon Mountains", "Winterspring", "Blackrock Spire", "Blackrock Depths", "The Temple of Atal'Hakkar", "Arathi Highlands", "Undercity", "Blackfathom Deeps", "Stranglethorn Vale", "Blasted Lands Swamp of Sorrows Elwynn Forest Stormwind City", "Stranglethorn Vale", "Blackrock Depths", "Ahn'Qiraj", "Stratholme", "Wailing Caverns", "Zul'Gurub", "Un'Goro Crater", "Ruins of Ahn'Qiraj", "Scarlet Monastery", "Stormwind City", "an Unknown Location", "Scholomance", "Ironforge", "Azshara", "Dire Maul", "Blackrock Spire", "Tanaris", "Scholomance", "Blackrock Spire", "Blackrock Spire", "Stranglethorn Vale", "Scarlet Monastery", "Blackrock Depths", "Un'Goro Crater", "Zul'Farrak", "Scarlet Monastery", "Dun Morogh Elwynn Forest Durotar Westfall Tirisfal Glades Stormwind City", "Dire Maul", "Stormwind City", "Alterac Mountains", "Stratholme", "Eastern Plaguelands", "Blackrock Depths", "Blackrock Depths", "Duskwood The Hinterlands Ashenvale Feralas", "Duskwood", "Razorfen Kraul", "Thousand Needles", "Zul'Gurub", "Naxxramas", "Mulgore Thunder Bluff", "Westfall", "Scarlet Monastery", "Badlands", "Alterac Mountains Hillsbrad Foothills", "Zul'Gurub", "Blackrock Depths", "Blackrock Depths", "Zul'Gurub", "Ruins of Ahn'Qiraj", "Winterspring", "The Barrens", "Blackwing Lair", "Eastern Plaguelands", "Winterspring", "Dire Maul", "Molten Core", "Scarlet Monastery", "Ashenvale", "Shadowfang Keep", "Dustwallow Marsh", "Blackrock Spire", "Scarlet Monastery", "Winterspring", "Scholomance", "Duskwood The Hinterlands Ashenvale Feralas", "Blackrock Depths", "Zul'Gurub", "Dire Maul", "Scholomance", "Western Plaguelands", "Scarlet Monastery", "Duskwood The Hinterlands Ashenvale Feralas", "Dire Maul", "Blackrock Spire", "Duskwood The Hinterlands Ashenvale Feralas", "Felwood", "Scholomance", "Gnomeregan", "Naxxramas", "Stormwind City", "Uldaman", "Naxxramas", "Blackrock Spire", "Zul'Farrak", "Maraudon", "Blackrock Depths", "The Barrens", "Ahn'Qiraj", "Azshara", "Blackfathom Deeps", "Dire Maul", "Dire Maul", "Blackrock Spire", "Loch Modan", "Zul'Farrak", "Wailing Caverns", "Wailing Caverns", "Winterspring", "Molten Core", "Blackrock Depths", "Naxxramas", "Razorfen Kraul", "Western Plaguelands Tirisfal Glades Eastern Plaguelands", "Blackrock Depths", "Silithus", "Orgrimmar", "Winterspring", "Zul'Gurub", "Molten Core", "Dun Morogh", "Westfall", "Stranglethorn Vale", "Razorfen Downs", "Redridge Mountains Burning Steppes", "Blackwing Lair", "Mulgore", "Blackrock Spire", "Winterspring", "Scarlet Monastery", "Blackwing Lair", "Wailing Caverns", "Westfall", "Blackrock Spire", "The Hinterlands", "Silithus", "The Hinterlands", "Blackrock Depths", "Blackrock Spire", "Eastern Plaguelands", "Thunder Bluff", "Arathi Highlands", "Razorfen Kraul", "Un'Goro Crater", "Wailing Caverns", "Desolace", "The Deadmines", "Dire Maul", "Blackwing Lair", "Blackrock Depths", "Burning Steppes", "Arathi Highlands", "The Temple of Atal'Hakkar", "Undercity", "Stranglethorn Vale", "The Temple of Atal'Hakkar", "Wailing Caverns", "Un'Goro Crater", "Durotar", "The Barrens", "Blackrock Spire", "Hillsbrad Foothills", "Maraudon", "Blackrock Depths", "Arathi Highlands", "Thousand Needles", "Blackrock Depths", "Moonglade", "Alterac Mountains", "Molten Core", "Zul'Gurub", "Ahn'Qiraj", "Ragefire Chasm", "The Stockade", "Wetlands", "Maraudon", "Western Plaguelands", "Blackrock Spire", "Blackfathom Deeps", "Wailing Caverns", "Maraudon", "Dire Maul", "an Unknown Location", "Stratholme", "The Temple of Atal'Hakkar", "Shadowfang Keep", "Stratholme", "Azshara", "Dire Maul", "an Unknown Location", "Stratholme", "Dire Maul", "Blackfathom Deeps", "Molten Core", "Maraudon", "The Hinterlands", "Ahn'Qiraj", "Razorfen Downs", "Stormwind City", "Dun Morogh", "Zul'Farrak", "The Deadmines", "Stranglethorn Vale", "The Barrens", "The Temple of Atal'Hakkar", "Ruins of Ahn'Qiraj", "The Deadmines", "Scholomance", "Naxxramas", "Razorfen Kraul", "The Stockade", "Searing Gorge", "Searing Gorge", "Stratholme", "Blackfathom Deeps", "Teldrassil", "Gnomeregan", "an Unknown Location", "Stratholme", "Duskwood", "Tirisfal Glades", "Stratholme", "The Barrens", "Dustwallow Marsh", "Shadowfang Keep", "Alterac Mountains", "Darnassus", "Thousand Needles", "Blackrock Depths", "Maraudon", "Wailing Caverns", "Uldaman", "Stratholme", "Razorfen Downs", "Swamp of Sorrows", "Shadowfang Keep", "Blackfathom Deeps", "The Deadmines", "Zul'Farrak", "Blasted Lands Azshara Burning Steppes Eastern Plaguelands Tanaris Winterspring", "Stratholme", "Stratholme", "Zul'Gurub", "Darkshore", "Shadowfang Keep", "Naxxramas", "Blackrock Depths", "Darnassus", "Wetlands", "The Barrens Darkshore", "Uldaman", "Blackwing Lair", "Razorfen Downs", "The Deadmines", "Uldaman", "Stratholme", "Gnomeregan", "Ahn'Qiraj", "Shadowfang Keep", "Naxxramas", "The Temple of Atal'Hakkar", "Naxxramas", "Blackrock Depths", "Naxxramas", "Badlands", "Stranglethorn Vale", "Blackrock Spire", "Ahn'Qiraj", "Zul'Farrak", "Maraudon", "Naxxramas", "Wailing Caverns", "Eastern Plaguelands", "Feralas", "an Unknown Location", "Westfall", "Ashenvale", "Ragefire Chasm", "Zul'Farrak", "Redridge Mountains", "Zul'Gurub", "Dire Maul", "The Hinterlands", "Ahn'Qiraj", "Blackwing Lair", "Uldaman", "Blackrock Spire", "Scholomance", "Loch Modan", "Burning Steppes", "Shadowfang Keep", "Razorfen Downs", "Darnassus", "an Unknown Location", "Blackrock Spire", "Elwynn Forest", "Blasted Lands", "Naxxramas", "Maraudon", "Molten Core", "Gnomeregan", "Molten Core", "Stratholme", "Wailing Caverns", "Loch Modan", "Blasted Lands", "Blackrock Depths", "Stranglethorn Vale", "Uldaman", "Silithus", "Silithus", "Ruins of Ahn'Qiraj", "Ahn'Qiraj", "Blackrock Depths", "Stratholme", "The Barrens", "Stratholme", "Un'Goro Crater", "Maraudon", "The Barrens", "Naxxramas", "Eastern Plaguelands", "Un'Goro Crater", "Molten Core", "Blackfathom Deeps", "Searing Gorge", "Ahn'Qiraj", "The Deadmines", "The Barrens", "Maraudon", "Dire Maul", "Zul'Gurub", "Dire Maul", "Alterac Mountains", "Blackwing Lair", "Zul'Farrak", "Scholomance", "Dire Maul", "Stratholme", "Razorfen Kraul", "Eastern Plaguelands", "Scarlet Monastery", "Dun Morogh", "Molten Core", "Wetlands", "Redridge Mountains", "Redridge Mountains", "Elwynn Forest", "Dire Maul", "Zul'Gurub", "Ahn'Qiraj", "Razorfen Kraul", "Wetlands", "Razorfen Downs", "Shadowfang Keep", "Naxxramas", "The Barrens", "Stonetalon Mountains", "Scholomance", "Alterac Mountains", "The Hinterlands", "Gnomeregan", "Shadowfang Keep", "Stratholme", "Shadowfang Keep", "Zul'Gurub", "Dire Maul", "Eastern Plaguelands", "Ruins of Ahn'Qiraj", "Zul'Farrak", "Thunder Bluff", "The Stockade", "Stranglethorn Vale", "The Barrens", "Silithus", "The Hinterlands", "Stranglethorn Vale", "Blackrock Depths", "Razorfen Kraul", "Azshara", "Undercity", "Un'Goro Crater", "Hillsbrad Foothills", "Blackrock Depths", "Winterspring", "Winterspring", "Silithus", "Eastern Plaguelands", "Dire Maul", "Thousand Needles", "Westfall", "Dire Maul", "Durotar", "Ragefire Chasm", "Ironforge", "Ahn'Qiraj", "Westfall", "Darkshore", "Silithus", "Scholomance", "Eastern Plaguelands", "Feralas", "Blackfathom Deeps", "Eastern Plaguelands", "Desolace", "Loch Modan", "Elwynn Forest", "The Barrens", "Arathi Highlands", "Silithus", "Duskwood", "The Temple of Atal'Hakkar", "an Unknown Location", "Silithus", "Eastern Plaguelands", "Badlands", "Alterac Mountains", "Dire Maul", "Duskwood", "The Stockade", "Silithus", "Badlands", "The Barrens", "Dustwallow Marsh", "Scholomance", "Duskwood", "The Barrens", "Elwynn Forest", "Uldaman", "Dire Maul", "Eastern Plaguelands", "Tirisfal Glades", "Stormwind City", "Dustwallow Marsh", "Dustwallow Marsh", "an Unknown Location", "Ashenvale", "Scholomance", "Razorfen Kraul", "Eastern Plaguelands", "Winterspring", "Scholomance", "Blackwing Lair", "Duskwood", "Ruins of Ahn'Qiraj", "Blackrock Spire", "Blackrock Spire", "Silithus", "Winterspring", "Winterspring", "Zul'Farrak", "Stratholme", "an Unknown Location", "Silithus", "Shadowfang Keep", "Winterspring", "Silithus", "The Hinterlands", "Eastern Plaguelands", "Razorfen Kraul", "The Deadmines", "an Unknown Location", "Stratholme", "Blackrock Depths", "The Temple of Atal'Hakkar", "Stonetalon Mountains", "Duskwood", "Ahn'Qiraj", "Ahn'Qiraj", "Un'Goro Crater", "Feralas", "The Stockade", "Ashenvale", "Blackrock Spire", "Blackrock Depths", "Zul'Gurub", "Alterac Mountains", "Silithus", "Feralas", "Feralas", "Blackrock Depths", "Feralas", "The Barrens", "Arathi Highlands", "Elwynn Forest", "Eastern Plaguelands", "Redridge Mountains", "Loch Modan", "Winterspring", "Orgrimmar", "The Barrens Darkshore", "Scholomance", "Zul'Farrak", "Naxxramas", "Azshara", "Naxxramas", "Burning Steppes", "Alterac Mountains", "Alterac Mountains", "Naxxramas", "Ahn'Qiraj", "Loch Modan", "Dun Morogh", "Silverpine Forest", "Dire Maul", "Western Plaguelands", "Westfall", "Redridge Mountains", "Zul'Gurub", "Blackrock Depths", "Winterspring", "Blackrock Spire", "Dun Morogh", "Loch Modan", "Azshara", "Eastern Plaguelands", "Blackrock Depths", "Dire Maul", "an Unknown Location", "Blackrock Spire", "Stratholme", "Burning Steppes", "Stonetalon Mountains", "Wetlands", "Blackrock Spire", "Felwood", "Blackrock Depths", "Silithus", "Silithus", "Silithus", "Silverpine Forest", "Dun Morogh", "Stonetalon Mountains", "Felwood", "Searing Gorge", "Silithus", "Western Plaguelands", "Darkshore", "Razorfen Kraul", "Uldaman", "Dire Maul", "Feralas", "Silithus", "Silithus", "Blackrock Depths", "Silithus", "Naxxramas", "Blackrock Depths", "Blackrock Depths", "Felwood", "The Deadmines", "The Barrens", "Arathi Highlands", "Alterac Mountains", "Dun Morogh", "The Barrens", "Orgrimmar", "Shadowfang Keep", "Blackrock Depths", "Stratholme", "Ahn'Qiraj", "Badlands Loch Modan", "Durotar", "Redridge Mountains", "Silverpine Forest", "Ashenvale", "Eastern Plaguelands", "Stranglethorn Vale", "Elwynn Forest", "Feralas", "Blackrock Spire", "The Temple of Atal'Hakkar", "Dustwallow Marsh Winterspring", "Azshara", "Zul'Farrak", "Darkshore", "Blackrock Depths", "Blackrock Depths", "Tirisfal Glades", "Wetlands", "Blasted Lands", "The Temple of Atal'Hakkar", "Badlands Loch Modan", "Westfall", "Zul'Farrak", "Blasted Lands The Tainted Scar", "Stormwind City", "Ruins of Ahn'Qiraj", "The Barrens Darkshore", "Elwynn Forest Stormwind City", "Stonetalon Mountains", "Naxxramas", "Feralas", "Dire Maul", "Molten Core", "Stranglethorn Vale", "Westfall", "Ashenvale", "Desolace", "The Barrens", "Duskwood", "Stratholme", "Burning Steppes", "Thousand Needles", "Ironforge", "Searing Gorge", "Arathi Highlands", "Durotar The Barrens Tirisfal Glades", "Un'Goro Crater", "The Temple of Atal'Hakkar", "Arathi Highlands", "Feralas", "Eastern Plaguelands", "Eastern Plaguelands", "Dun Morogh", "Tanaris", "Silverpine Forest", "Scholomance", "Silithus", "Blackrock Spire", "Zul'Farrak", "Feralas", "Silithus", "Burning Steppes", "Dire Maul", "Scholomance", "Thousand Needles", "Felwood", "Naxxramas", "Stranglethorn Vale", "The Barrens", "Winterspring", "Razorfen Kraul", "Silithus", "Scholomance", "Western Plaguelands", "Blackrock Depths", "Thousand Needles", "Western Plaguelands", "Blasted Lands", "Blackrock Spire", "The Deadmines", "Blackrock Spire", "an Unknown Location", "Winterspring", "Burning Steppes", "Redridge Mountains", "Tanaris Silithus", "Blasted Lands", "The Barrens", "Stratholme", "Blasted Lands The Tainted Scar", "Burning Steppes", "Dustwallow Marsh", "an Unknown Location", "Scholomance", "Eastern Plaguelands", "Azshara Storm Cliffs", "Duskwood", "Desolace", "Eastern Plaguelands", "Blackrock Spire Blackwing Lair", "Blasted Lands Azshara Burning Steppes Eastern Plaguelands Tanaris Winterspring", "Loch Modan", "Loch Modan", "Winterspring", "Arathi Highlands", "Tirisfal Glades", "Stranglethorn Vale", "Arathi Highlands", "Azshara", "Redridge Mountains", "an Unknown Location", "Blasted Lands", "The Barrens", "Stranglethorn Vale", "Hillsbrad Foothills", "Teldrassil", "Scholomance", "The Barrens", "Thousand Needles", "Silithus Ahn'Qiraj", "Wetlands", "Blackwing Lair", "Dire Maul", "Winterspring", "Blasted Lands", "Eastern Plaguelands", "Silverpine Forest", "Dustwallow Marsh", "an Unknown Location", "Alterac Mountains", "Blackrock Depths", "Badlands", "Searing Gorge", "Winterspring", "Eastern Plaguelands", "The Barrens", "Stonetalon Mountains", "Alterac Mountains", "an Unknown Location", "Wailing Caverns", "Un'Goro Crater", "Moonglade", "Ragefire Chasm", "Stonetalon Mountains", "Arathi Highlands", "Stormwind City", "Silithus Orgrimmar", "Winterspring", "Silverpine Forest", "Eastern Plaguelands", "Winterspring", "Alterac Mountains", "Thousand Needles", "Blasted Lands Azshara Burning Steppes Eastern Plaguelands Tanaris Winterspring", "Felwood", "Loch Modan", "Burning Steppes", "Thousand Needles", "The Stockade", "Dire Maul", "The Barrens", "Redridge Mountains", "The Barrens", "Silverpine Forest", "Zul'Gurub", "Dire Maul", "Blackrock Depths", "Silithus", "Ashenvale Orgrimmar Ashenvale", "Western Plaguelands", "Wetlands", "The Hinterlands", "Blackrock Spire", "Blasted Lands", "Wetlands", "The Hinterlands", "Blackrock Spire", "Ashenvale", "an Unknown Location", "Burning Steppes", "Blackrock Spire", "Dustwallow Marsh", "Silithus", "The Hinterlands", "Shadowfang Keep", "Dire Maul", "an Unknown Location", "Tirisfal Glades", "Azshara", "Alterac Mountains", "Razorfen Kraul", "The Temple of Atal'Hakkar", "The Barrens", "Scarlet Monastery", "Teldrassil", "Uldaman", "Ironforge", "Gnomeregan", "Loch Modan", "Azshara Storm Cliffs", "Desolace", "Dustwallow Marsh", "Un'Goro Crater", "Hillsbrad Foothills", "Ashenvale", "Scholomance", "Shadowfang Keep", "Dire Maul", "The Barrens", "Molten Core", "Tirisfal Glades", "The Barrens", "Western Plaguelands", "Silverpine Forest", "Scholomance", "Stonetalon Mountains", "The Barrens", "Zul'Farrak", "Wailing Caverns", "Molten Core", "The Barrens", "Teldrassil", "Burning Steppes", "an Unknown Location", "Felwood", "Redridge Mountains", "Thousand Needles", "Uldaman", "Durotar", "Blackrock Spire", "Silithus", "Alterac Mountains", "Ashenvale Ashenvale", "Hillsbrad Foothills", "Western Plaguelands", "Loch Modan", "Orgrimmar", "Stranglethorn Vale", "Badlands", "Arathi Highlands", "Mulgore", "Blasted Lands Azshara Burning Steppes Eastern Plaguelands Tanaris Winterspring", "Tirisfal Glades", "Durotar", "Zul'Gurub", "Tirisfal Glades", "The Stockade", "Alterac Valley", "Alterac Mountains", "The Temple of Atal'Hakkar", "an Unknown Location", "Stranglethorn Vale", "Stratholme", "Stonetalon Mountains", "Un'Goro Crater", "Stranglethorn Vale", "Western Plaguelands", "Uldaman", "Stranglethorn Vale", "Blackrock Depths", "Redridge Mountains", "Blasted Lands", "Mulgore", "Stranglethorn Vale", "Eastern Plaguelands", "Alterac Mountains", "Molten Core", "Western Plaguelands", "Tanaris", "Shadowfang Keep", "Loch Modan", "Molten Core", "Felwood", "Tirisfal Glades", "Stonetalon Mountains", "Wetlands", "Maraudon", "Ashenvale", "Azshara Storm Cliffs", "Blasted Lands The Tainted Scar", "Arathi Highlands", "Winterspring", "Naxxramas", "The Barrens Moonglade Orgrimmar", "Zul'Gurub", "Scarlet Monastery", "Wetlands", "Desolace", "Searing Gorge", "Silithus", "Ashenvale", "The Hinterlands", "Thousand Needles", "Blackrock Depths", "an Unknown Location", "Hillsbrad Foothills", "Blackrock Depths", "Winterspring", "Blackrock Spire", "Silithus Ahn'Qiraj", "Molten Core", "Winterspring", "Scarlet Monastery", "Burning Steppes", "Thousand Needles", "Mulgore", "Desolace", "Tirisfal Glades", "Arathi Highlands", "The Hinterlands", "Blackrock Spire", "Silithus", "Stratholme", "Arathi Highlands", "an Unknown Location", "Wailing Caverns", "Desolace", "Darkshore", "Loch Modan", "an Unknown Location", "Ruins of Ahn'Qiraj", "Arathi Highlands", "Ragefire Chasm", "The Barrens", "Razorfen Kraul", "Scarlet Monastery", "Stratholme", "Blackrock Depths", "Blackwing Lair", "Western Plaguelands", "The Barrens", "Alterac Valley", "The Barrens", "Silithus", "Blackrock Depths", "Swamp of Sorrows", "Wetlands", "Western Plaguelands", "Stranglethorn Vale", "Blackrock Spire", "Badlands", "Silithus", "Teldrassil", "an Unknown Location", "Stratholme", "The Barrens", "Alterac Valley", "Tempest Keep", "Black Temple", "Shattrath City", "Zangarmarsh", "Black Temple", "Black Temple", "Serpentshrine Cavern", "Magtheridon's Lair", "Gruul's Lair", "Hellfire Peninsula", "Karazhan", "Shadowmoon Valley", "Hellfire Peninsula", "Hyjal Summit", "Shadow Labyrinth", "Hyjal Summit", "The Shattered Halls", "The Slave Pens", "Shadowmoon Valley", "Karazhan", "Terokkar Forest", "Sethekk Halls", "Serpentshrine Cavern", "Tempest Keep", "Sunwell Plateau", "Black Temple", "Gruul's Lair", "The Mechanar", "Mana-Tombs", "Blackrock Depths", "Hellfire Peninsula", "Tanaris", "Serpentshrine Cavern", "Blade's Edge Mountains", "The Steamvault", "Blackrock Depths", "Mana-Tombs", "Tempest Keep", "Serpentshrine Cavern", "Serpentshrine Cavern", "Serpentshrine Cavern", "The Blood Furnace", "The Slave Pens", "Netherstorm", "Scarlet Monastery", "The Underbog", "Sethekk Halls", "Hyjal Summit", "The Botanica", "The Black Morass", "Mana-Tombs", "Sethekk Halls", "Terokkar Forest", "The Arcatraz", "Nagrand", "Black Temple", "Tempest Keep", "Black Temple", "Old Hillsbrad Foothills", "Karazhan", "Blade's Edge Mountains", "Auchenai Crypts", "Hellfire Ramparts", "Shadowmoon Valley", "Scarlet Monastery", "Zul'Aman", "Netherstorm", "Shadow Labyrinth", "Karazhan", "Auchenai Crypts", "Hyjal Summit", "Hellfire Peninsula", "Blade's Edge Mountains", "Scarlet Monastery", "Hyjal Summit", "Scarlet Monastery", "Karazhan", "Shattrath City", "Black Temple", "The Shattered Halls", "Nagrand", "Black Temple", "Magisters' Terrace", "The Blood Furnace", "Shadowmoon Valley", "The Black Morass", "Shadowmoon Valley", "The Botanica", "Shadowmoon Valley", "The Arcatraz", "Shattrath City", "The Barrens", "Hellfire Ramparts", "Stranglethorn Vale", "Shadowmoon Valley", "Black Temple", "Zul'Aman", "Blade's Edge Mountains", "Gnomeregan", "Hellfire Ramparts", "Karazhan", "Karazhan", "Scarlet Monastery", "Sethekk Halls", "Karazhan", "Shadow Labyrinth", "Auchenai Crypts", "The Slave Pens", "Karazhan", "Mana-Tombs", "Auchenai Crypts", "Black Temple", "Nagrand", "The Slave Pens", "Netherstorm Shattrath City", "Shadow Labyrinth", "Blackrock Depths", "Stranglethorn Vale", "The Mechanar", "-", "Shadowmoon Valley", "The Shattered Halls", "Stranglethorn Vale", "Karazhan", "The Blood Furnace", "The Black Morass", "Karazhan", "Karazhan", "Shadowmoon Valley", "Black Temple", "Maraudon", "Blade's Edge Mountains", "Terokkar Forest", "Scarlet Monastery", "Dustwallow Marsh", "Tempest Keep", "Blade's Edge Mountains", "Stratholme", "Nagrand", "Tanaris", "Shadowfang Keep", "The Steamvault", "Shattrath City", "The Botanica", "Hellfire Peninsula", "Blade's Edge Mountains", "Auchenai Crypts", "Ghostlands", "Uldaman", "Scarlet Monastery", "Eastern Plaguelands", "-", "Shattrath City", "Mana-Tombs", "Silithus", "Blade's Edge Mountains", "Shattrath City", "Terokkar Forest", "Karazhan", "The Shattered Halls", "Terokkar Forest", "The Botanica", "The Underbog", "Badlands", "Black Temple", "Isle of Quel'Danas", "Shadowmoon Valley", "Sunwell Plateau", "The Deadmines", "Shattrath City", "Sunwell Plateau", "-", "Karazhan", "Tanaris", "Scarlet Monastery", "Karazhan", "Netherstorm", "Terokkar Forest", "Eastern Plaguelands", "Hellfire Peninsula", "-", "Sunwell Plateau", "Razorfen Downs", "Mana-Tombs", "The Black Morass", "Zangarmarsh", "The Shattered Halls", "The Underbog", "Blackrock Depths", "Hellfire Peninsula", "The Barrens", "Netherstorm", "Zul'Farrak", "The Arcatraz", "Shadowmoon Valley", "-", "Gruul's Lair", "Old Hillsbrad Foothills", "Ghostlands", "The Black Morass", "Nagrand", "Serpentshrine Cavern", "The Temple of Atal'Hakkar", "The Temple of Atal'Hakkar", "Shadowmoon Valley", "Alterac Mountains", "The Slave Pens", "Nagrand", "The Temple of Atal'Hakkar", "Blackfathom Deeps", "Netherstorm", "Ahn'Qiraj", "Karazhan", "-", "Terokkar Forest", "Magisters' Terrace", "Stratholme", "Netherstorm Shattrath City", "Gruul's Lair", "Nagrand", "Black Temple", "Terokkar Forest", "Scarlet Monastery", "Uldaman", "Naxxramas", "Razorfen Kraul", "Kalimdor", "Nagrand", "Undercity", "Stormwind City", "The Underbog", "Blade's Edge Mountains", "Terokkar Forest", "Blackrock Depths", "Netherstorm", "The Arcatraz", "Shadowmoon Valley", "Blade's Edge Mountains", "Razorfen Kraul", "Uldaman", "The Botanica", "Magisters' Terrace", "Karazhan", "Shadowmoon Valley", "Razorfen Kraul", "Dun Morogh Elwynn Forest Durotar Azshara Stranglethorn Vale The Hinterlands Searing Gorge Tirisfal Glades Eastern Plaguelands Winterspring Silithus Undercity Stormwind City Ironforge Orgrimmar", "Scarlet Monastery", "Nagrand", "Winterspring", "Zangarmarsh", "-", "Felwood", "Duskwood Elwynn Forest", "Shadowmoon Valley", "Nagrand", "Blade's Edge Mountains", "Scarlet Monastery", "Blade's Edge Mountains", "Nagrand", "Blade's Edge Mountains", "Razorfen Kraul", "Thousand Needles", "Blackrock Depths", "The Steamvault", "Maraudon", "Karazhan", "Tanaris", "Feralas", "The Steamvault", "Blade's Edge Mountains", "Badlands", "Uldaman", "Blackfathom Deeps", "The Hinterlands", "Hellfire Peninsula", "Nagrand", "Sunwell Plateau", "The Mechanar", "Maraudon", "The Steamvault", "Karazhan", "Netherstorm", "Nagrand", "Zul'Farrak", "Sunwell Plateau", "Wailing Caverns", "Naxxramas", "The Arcatraz", "-", "Blade's Edge Mountains", "Blackfathom Deeps", "Serpentshrine Cavern", "Bloodmyst Isle", "Hellfire Peninsula", "The Arcatraz", "Razorfen Kraul", "-", "Ashenvale", "Karazhan", "The Mechanar", "Zul'Farrak", "Wailing Caverns", "Teldrassil", "Nagrand", "Redridge Mountains Burning Steppes", "Karazhan", "Serpentshrine Cavern", "Darnassus", "Netherstorm", "Terokkar Forest", "Zul'Aman", "Blackrock Depths", "Zul'Aman", "Blackrock Spire", "Netherstorm", "Gruul's Lair", "Blasted Lands", "Razorfen Downs", "Alterac Mountains", "Nagrand", "Gnomeregan", "Gnomeregan", "Zul'Aman", "Maraudon", "Felwood", "Shadowmoon Valley", "Arathi Highlands", "Terokkar Forest", "Shadowmoon Valley", "Tempest Keep", "Terokkar Forest", "Badlands", "Stratholme", "Maraudon", "Wailing Caverns", "Netherstorm", "Terokkar Forest", "Stranglethorn Vale", "Arathi Highlands", "Mana-Tombs", "Blade's Edge Mountains", "The Black Morass", "Blackrock Depths", "Stratholme", "Blade's Edge Mountains", "Blade's Edge Mountains", "Shattrath City", "Maraudon", "Zul'Farrak", "Blade's Edge Mountains", "Razorfen Downs", "Dustwallow Marsh", "Terokkar Forest", "Shadowmoon Valley", "Zul'Farrak", "Zul'Gurub", "Hellfire Peninsula", "The Arcatraz", "Blackfathom Deeps", "The Arcatraz", "Shattrath City", "Zangarmarsh", "Isle of Quel'Danas", "Shadowfang Keep", "Old Hillsbrad Foothills", "The Temple of Atal'Hakkar", "Ragefire Chasm", "Azshara", "Shadowmoon Valley", "Tanaris", "Nagrand", "Razorfen Downs", "Blackrock Spire", "Shadowmoon Valley", "Black Temple", "Uldaman", "Burning Steppes", "Scholomance", "Ashenvale", "Un'Goro Crater", "Tempest Keep", "Blackfathom Deeps", "Stormwind City", "Shadowmoon Valley", "Shattrath City", "Black Temple", "Karazhan", "Razorfen Kraul", "Maraudon", "Zangarmarsh", "The Deadmines", "Shadowfang Keep", "Orgrimmar", "Ragefire Chasm", "Black Temple", "Zul'Aman", "Wailing Caverns", "Dustwallow Marsh", "Blackfathom Deeps", "Stranglethorn Vale", "Scarlet Monastery", "Zangarmarsh", "Razorfen Downs", "Sunwell Plateau", "Maraudon", "Blackrock Depths", "Shadowmoon Valley", "The Arcatraz", "Mulgore Thunder Bluff", "Ironforge", "Thousand Needles", "Hellfire Peninsula", "The Deadmines", "Scholomance", "Ahn'Qiraj", "Maraudon", "Maraudon", "Shadowmoon Valley", "Sethekk Halls", "Razorfen Kraul", "Netherstorm", "The Shattered Halls", "Kalimdor", "Hellfire Peninsula", "Isle of Quel'Danas", "Shattrath City", "Uldaman", "Stratholme", "Uldaman", "-", "Blackrock Depths", "Blackrock Spire", "Blackrock Spire", "Tanaris", "Razorfen Kraul", "Zangarmarsh", "Nagrand", "Alterac Mountains", "Shadowmoon Valley", "Shattrath City", "Blackfathom Deeps", "Blackrock Depths", "Uldaman", "Zul'Farrak", "Hellfire Peninsula", "Nagrand", "Serpentshrine Cavern", "Ragefire Chasm", "Scholomance", "Duskwood", "Terokkar Forest", "Gruul's Lair", "Razorfen Kraul", "The Shattered Halls", "Ahn'Qiraj", "Blackrock Depths", "Blackrock Depths", "Blackrock Depths", "-", "Thunder Bluff", "Teldrassil", "The Arcatraz", "Shadowmoon Valley", "Blackrock Depths", "Dire Maul", "Zul'Farrak", "The Arcatraz", "The Deadmines", "Alterac Mountains Hillsbrad Foothills", "Durotar", "Blackfathom Deeps", "Blade's Edge Mountains", "Netherstorm", "Eastern Plaguelands", "Alterac Valley Arathi Basin Eye of the Storm", "Blasted Lands Swamp of Sorrows Elwynn Forest Stormwind City", "-", "Shadowfang Keep", "Zul'Gurub", "Dire Maul", "Gnomeregan", "Tempest Keep", "Serpentshrine Cavern", "Wetlands", "Alterac Mountains Hillsbrad Foothills", "Scarlet Monastery", "Uldaman", "Blackwing Lair", "Dire Maul", "Wailing Caverns", "Black Temple", "The Barrens", "Western Plaguelands", "-", "Shadowmoon Valley", "Zangarmarsh", "Scholomance", "-", "Shadowmoon Valley", "Blackrock Depths", "Blackrock Spire", "Karazhan", "Shadowmoon Valley", "Azshara", "The Arcatraz", "Blackrock Spire", "Undercity", "Shattrath City", "Bloodmyst Isle The Exodar", "Tirisfal Glades", "Terokkar Forest", "Terokkar Forest", "Shadowfang Keep", "Zul'Farrak", "Netherstorm", "Shattrath City", "The Stockade", "-", "Razorfen Downs", "Duskwood The Hinterlands Ashenvale Feralas", "Mulgore", "Gnomeregan", "Blackwing Lair", "Blade's Edge Mountains", "Silithus", "The Barrens", "The Deadmines", "Karazhan", "Arathi Highlands", "Alterac Mountains", "The Arcatraz", "Blackrock Depths", "Wailing Caverns", "Blackrock Depths", "Blackrock Depths", "Karazhan", "Silithus", "Auchenai Crypts", "Tempest Keep", "-", "Tanaris", "Dire Maul", "Serpentshrine Cavern", "Razorfen Kraul", "The Temple of Atal'Hakkar", "Shadowmoon Valley", "-", "Razorfen Kraul", "Stratholme", "Un'Goro Crater", "Blade's Edge Mountains", "Karazhan", "Hellfire Peninsula", "Magtheridon's Lair", "Blasted Lands", "Eastern Plaguelands", "Shadowmoon Valley", "Scarlet Monastery", "The Steamvault", "The Deadmines", "Blasted Lands", "The Mechanar", "Silithus", "Dire Maul", "Tempest Keep", "Dun Morogh", "Duskwood The Hinterlands Ashenvale Feralas", "Tempest Keep", "Stratholme", "Sunwell Plateau", "The Temple of Atal'Hakkar", "Eastern Plaguelands", "Searing Gorge", "Hellfire Peninsula", "Nagrand", "The Mechanar", "The Temple of Atal'Hakkar", "Blackrock Depths", "Dire Maul", "Shadowfang Keep", "Nagrand", "Terokkar Forest", "Blackrock Depths", "Razorfen Kraul", "Bloodmyst Isle", "Black Temple", "Feralas", "Tempest Keep", "The Arcatraz", "The Temple of Atal'Hakkar", "Sunwell Plateau", "Ahn'Qiraj", "Zul'Farrak", "Desolace", "Shattrath City", "Serpentshrine Cavern", "Terokkar Forest", "Tempest Keep", "Shadowmoon Valley", "Hellfire Peninsula", "Blackrock Spire", "The Temple of Atal'Hakkar", "Maraudon", "Blackrock Depths", "Zul'Gurub", "Shadowfang Keep", "Blackrock Spire", "Blackrock Depths", "Naxxramas", "Stratholme", "Black Temple", "Mana-Tombs", "Mulgore", "Eastern Kingdoms", "Scholomance", "Black Temple", "Tempest Keep", "Shattrath City", "Hellfire Ramparts", "Netherstorm", "Stratholme", "Karazhan", "Magisters' Terrace", "Dire Maul", "Ahn'Qiraj", "Blackrock Depths", "Winterspring", "Redridge Mountains", "The Stockade", "Hellfire Peninsula", "Blade's Edge Mountains", "Stratholme", "Hellfire Peninsula", "Ghostlands", "Duskwood", "Tanaris", "Shadowmoon Valley", "Blasted Lands", "Blackwing Lair", "Wailing Caverns", "Shadowfang Keep", "Shadowfang Keep", "Zul'Farrak", "The Arcatraz", "Tirisfal Glades", "Black Temple", "Un'Goro Crater", "Blackrock Depths Shattrath City", "The Underbog", "Nagrand", "Loch Modan", "Shadowmoon Valley", "Black Temple", "Sethekk Halls", "Mana-Tombs", "Terokkar Forest", "Razorfen Downs", "Shadowfang Keep", "Eversong Woods Ghostlands", "The Deadmines", "Shadowfang Keep", "Molten Core", "Gnomeregan", "Ahn'Qiraj", "Black Temple", "The Stockade", "Tempest Keep", "Kalimdor", "Black Temple", "Dustwallow Marsh", "Shadow Labyrinth", "The Barrens", "Feralas Desolace Stonetalon Mountains Blade's Edge Mountains", "Blackrock Spire", "Eastern Plaguelands", "The Barrens", "-", "The Arcatraz", "Stratholme", "The Mechanar", "Stratholme", "Dire Maul", "Ruins of Ahn'Qiraj", "Undercity", "Nagrand", "The Deadmines", "Karazhan", "Razorfen Kraul", "Nagrand", "Hillsbrad Foothills", "Tempest Keep", "Moonglade", "Netherstorm", "-", "Thousand Needles", "Zul'Gurub", "Stranglethorn Vale", "Alterac Valley Arathi Basin Eye of the Storm", "-", "Stranglethorn Vale", "Silithus", "Blade's Edge Mountains", "Blackwing Lair", "Naxxramas", "Blackrock Spire", "Karazhan", "Un'Goro Crater", "The Steamvault", "Shadow Labyrinth", "Stormwind City", "Blade's Edge Mountains", "Uldaman", "Ashenvale", "Nagrand", "Westfall", "Blackrock Depths", "The Temple of Atal'Hakkar", "Dire Maul", "Molten Core", "The Temple of Atal'Hakkar", "Karazhan", "The Temple of Atal'Hakkar", "-", "Alterac Mountains", "Karazhan", "Black Temple", "Zangarmarsh", "Wailing Caverns", "The Barrens", "Netherstorm", "Winterspring", "Stormwind City", "Shadowmoon Valley", "Shadowmoon Valley", "The Barrens", "Bloodmyst Isle", "Searing Gorge", "The Barrens", "Shadowmoon Valley", "Blackrock Spire", "Shadowmoon Valley", "Blackrock Depths", "Blackwing Lair", "The Arcatraz", "Black Temple", "Ironforge", "Nagrand", "Mana-Tombs", "Nagrand", "Burning Steppes", "Winterspring", "The Temple of Atal'Hakkar", "Winterspring", "Razorfen Downs", "Ragefire Chasm", "Shadowmoon Valley", "Dire Maul", "Dire Maul", "Blackrock Spire", "Stratholme", "Dire Maul", "Tempest Keep", "Thunder Bluff", "Serpentshrine Cavern", "The Slave Pens", "The Steamvault", "Eastern Plaguelands", "Stratholme", "Tempest Keep", "Nagrand", "Dustwallow Marsh", "Mana-Tombs", "Netherstorm", "Westfall", "Scholomance", "Shattrath City", "The Black Morass", "The Shattered Halls", "The Exodar", "Felwood", "Hellfire Peninsula", "The Stockade", "Dun Morogh", "-", "Serpentshrine Cavern", "Blasted Lands", "Zul'Gurub", "-", "Blade's Edge Mountains", "The Botanica", "Shadow Labyrinth", "Feralas", "Shadowmoon Valley", "Wailing Caverns", "Ghostlands", "The Steamvault", "The Barrens", "Serpentshrine Cavern", "Blade's Edge Mountains", "Dun Morogh Duskwood Elwynn Forest Durotar Westfall Tirisfal Glades Teldrassil Stormwind City", "Shadowmoon Valley", "Felwood", "Thousand Needles", "Scholomance", "Terokkar Forest", "Black Temple", "Duskwood", "Nagrand", "Dustwallow Marsh", "-", "Silithus", "Zul'Farrak", "Redridge Mountains", "Ashenvale", "Hellfire Peninsula", "Karazhan", "The Shattered Halls", "Silverpine Forest Shadowfang Keep", "Nagrand", "The Underbog", "Shadowfang Keep", "Dire Maul", "Blackwing Lair", "Ahn'Qiraj", "Stratholme", "Dire Maul", "Kalimdor", "-", "Badlands", "Azshara", "The Barrens", "-", "Nagrand", "The Slave Pens", "Tempest Keep", "Silithus", "Shadowfang Keep", "Wailing Caverns", "The Barrens", "Azshara", "Western Plaguelands Tirisfal Glades Eastern Plaguelands", "Shattrath City", "Redridge Mountains", "Dun Morogh", "The Temple of Atal'Hakkar", "The Stockade", "Eastern Plaguelands", "Silvermoon City Shattrath City", "Gruul's Lair", "Ruins of Ahn'Qiraj", "Blackrock Spire", "Eastern Plaguelands", "Black Temple", "Eastern Plaguelands", "Badlands", "Shadowfang Keep", "Arathi Basin Eye of the Storm", "Alterac Mountains", "The Arcatraz", "Serpentshrine Cavern", "Un'Goro Crater", "Shattrath City", "Blasted Lands", "Duskwood The Hinterlands Ashenvale Feralas", "Blackrock Depths", "Naxxramas", "Dire Maul", "The Deadmines", "Ahn'Qiraj", "Wailing Caverns", "Stratholme", "Tempest Keep", "Badlands", "The Arcatraz", "The Arcatraz", "Shadow Labyrinth", "Silithus", "Serpentshrine Cavern", "Desolace", "Tempest Keep", "Wailing Caverns", "-", "Duskwood The Hinterlands Ashenvale Feralas", "Westfall", "Burning Steppes", "-", "The Deadmines", "Felwood", "-", "Shadowmoon Valley", "Blade's Edge Mountains", "Silithus", "Razorfen Kraul", "Feralas Desolace Stonetalon Mountains", "Blackfathom Deeps", "Karazhan", "The Botanica", "Tanaris Silithus", "Badlands", "Nagrand", "Zul'Gurub", "Molten Core", "Naxxramas", "Shadowmoon Valley", "Zul'Aman", "Bloodmyst Isle", "Blackrock Spire", "Hellfire Ramparts", "Shadow Labyrinth", "Shattrath City", "Serpentshrine Cavern", "Silverpine Forest", "Ironforge", "Arathi Highlands", "Hellfire Peninsula", "Shattrath City", "Terokkar Forest", "Serpentshrine Cavern", "Ironforge", "Black Temple", "Arathi Basin", "Ghostlands", "Blackrock Depths", "-", "Scholomance", "Hellfire Peninsula", "Nagrand", "The Arcatraz", "Shadowmoon Valley", "Karazhan", "Tempest Keep", "Stonetalon Mountains", "Winterspring", "Nagrand", "Orgrimmar", "Darkshore", "Western Plaguelands", "Blackfathom Deeps", "-", "-", "Dire Maul", "Naxxramas", "Ahn'Qiraj", "Stratholme", "Stratholme", "Karazhan", "Wailing Caverns", "Zul'Aman", "Tempest Keep", "Darnassus", "Blade's Edge Mountains", "Shadowmoon Valley", "The Steamvault", "Netherstorm", "-", "Mana-Tombs", "Shadow Labyrinth", "Bloodmyst Isle", "Duskwood", "Zul'Aman", "Blade's Edge Mountains", "Karazhan", "The Slave Pens", "Western Plaguelands", "Black Temple", "Black Temple", "Shadowmoon Valley", "-", "Loch Modan", "Naxxramas", "Molten Core", "Tanaris Silithus", "Razorfen Kraul", "The Deadmines", "-", "The Arcatraz", "Scholomance", "Black Temple", "Blackrock Depths", "Blackrock Depths Shattrath City", "Zul'Gurub", "Zul'Gurub", "Tempest Keep", "Naxxramas", "Un'Goro Crater", "Uldaman", "-", "-", "Tanaris", "The Black Morass", "The Arcatraz", "Tempest Keep", "Zul'Gurub", "Blackrock Depths", "Stratholme", "Molten Core", "Molten Core", "Blackfathom Deeps", "Blackrock Spire", "Gnomeregan" }

local Adjectives = { "Bloody", "Iron", "Relentless", "Shadowy", "Sorrowful", "Abyssal", "Ruthless", "Crimson", "Forsaken", "Savage", "Grim", "Vengeful", "Silent", "Zealous", "Reckless", "Foolish", "Mad" }
local Nouns = { "Blood", "Iron", "Carnage", "Sorrow", "Malice", "Shadows", "Dominance", "Restitution", "the Abyss", "Ruin", "Despair", "Ashes", "Dust", "Gluttony", "Pride" }

local ZoneLoadingScreens = {
    ["The Deadmines"] = "LoadScreenDeadmines", ["Wailing Caverns"] = "LoadScreenWailingCaverns", ["Shadowfang Keep"] = "LoadScreenShadowFang", ["Blackfathom Deeps"] = "LoadScreenBlackfathom", ["Razorfen Kraul"] = "LoadScreenRazorfenKraul", ["Gnomeregan"] = "LoadScreenGnomeregan", ["Scarlet Monastery"] = "LoadScreenMonastery", ["Uldaman"] = "LoadScreenUldaman", ["Razorfen Downs"] = "LoadScreenRazorfenDowns", ["Zul'Farrak"] = "LoadScreenZulFarrak", ["Maraudon"] = "LoadScreenMaraudon", ["The Temple of Atal'Hakkar"] = "LoadScreenSunkenTemple", ["Blackrock Depths"] = "LoadScreenBlackrockDepths", ["Scholomance"] = "LoadScreenScholomance", ["Stratholme"] = "LoadScreenStratholme", ["Dire Maul"] = "LoadScreenDireMaul", ["Blackrock Spire"] = "LoadScreenBlackrockSpire", ["Ragefire Chasm"] = "LoadScreenOrc", ["The Stockade"] = "LoadScreenStormwind"
}

local ActionTemplates = {
    { trigger = "SWING_DAMAGE", baseDesc = "Land %s successful physical attacks.", baseGoal = 35, baseFavor = 1, reqMelee = true, patterns = { "The [Adj] Striker", "Striker of [Noun]" } },
    { trigger = "DAMAGE_TAKEN", baseDesc = "Survive taking %s total damage in combat.", baseGoal = 200, baseFavor = 1, isStat = true, patterns = { "The [Adj] Martyr", "Trial of the Martyr" } },
    { trigger = "ANY_DAMAGE", baseDesc = "Inflict %s total damage across all combat.", baseGoal = 350, baseFavor = 1, isStat = true, patterns = { "The [Adj] Annihilator", "Path of the Annihilator" } },
    { trigger = "PARTY_KILL", baseDesc = "Strike the killing blow on %s hostile targets.", baseGoal = 15, baseFavor = 2, patterns = { "The [Adj] Executioner", "Decree of the Executioner" } },
    { trigger = "DEFENSE_ROLL", baseDesc = "Parry, Dodge, or Block %s incoming attacks.", baseGoal = 15, baseFavor = 1, reqDefense = true, patterns = { "The [Adj] Bulwark", "Trial of the Bulwark" } },
    { trigger = "SPELL_DAMAGE", baseDesc = "Deal %s magical damage to enemies.", baseGoal = 300, baseFavor = 1, isStat = true, reqCaster = true, patterns = { "The [Adj] Evoker", "Rite of the Evoker" } },
    { trigger = "INTERRUPT_SPELL", baseDesc = "Successfully interrupt enemy spellcasts %s times.", baseGoal = 5, baseFavor = 2, reqInterrupt = true, patterns = { "The [Adj] Silencer", "Vow of the Silencer" } },
    { trigger = "FETCH_ITEM", baseDesc = "Acquire and stockpile %s %s.", baseGoal = 10, baseFavor = 2, patterns = { "The Hoarder's Tribute", "Tribute of [Noun]" } },
    { trigger = "DUEL_WIN", baseDesc = "Emerge victorious in %s non-lethal duels.", baseGoal = 2, baseFavor = 2, isPvP = true, patterns = { "The [Adj] Duelist", "Contract: The Duelist" } },
    { trigger = "MAKGORA_WIN", baseDesc = "Emerge victorious from a Mak'gora duel to the death.", baseGoal = 1, baseFavor = 35, isPvP = true, isLegendary = true, minLvl = 19, reqHardcore = true, patterns = { "The Blood Debt", "Trial of the True [Noun]" } },
    { trigger = "MONEY_LOOT", baseDesc = "Loot %s copper coins from the world.", baseGoal = 50, baseFavor = 1, isStat = true, patterns = { "The [Adj] Mercenary", "Greed of the [Adj] Mercenary" } },
    { trigger = "QUEST_COMPLETE", baseDesc = "Successfully complete and turn in %s quests.", baseGoal = 3, baseFavor = 2, patterns = { "The [Adj] Adventurer", "Path of the Adventurer" } },
    { trigger = "FALLING_DAMAGE", baseDesc = "Survive taking %s falling damage.", baseGoal = 100, baseFavor = 1, isStat = true, patterns = { "The [Adj] Plunge", "Gravity's [Noun]" } },
}

local TradeGoodsDB = {
    { name = "Linen Cloth", minLvl = 1, maxLvl = 20 }, { name = "Copper Ore", minLvl = 1, maxLvl = 20, reqProf = "Mining" }, { name = "Peacebloom", minLvl = 1, maxLvl = 15, reqProf = "Herbalism" }, { name = "Light Leather", minLvl = 1, maxLvl = 20, reqProf = "Skinning" }, { name = "Wool Cloth", minLvl = 16, maxLvl = 30 }, { name = "Tin Ore", minLvl = 16, maxLvl = 30, reqProf = "Mining" }, { name = "Medium Leather", minLvl = 16, maxLvl = 35, reqProf = "Skinning" }, { name = "Briarthorn", minLvl = 15, maxLvl = 30, reqProf = "Herbalism" }, { name = "Silk Cloth", minLvl = 28, maxLvl = 40 }, { name = "Iron Ore", minLvl = 28, maxLvl = 40, reqProf = "Mining" }, { name = "Heavy Leather", minLvl = 25, maxLvl = 45, reqProf = "Skinning" }, { name = "Kingsblood", minLvl = 25, maxLvl = 40, reqProf = "Herbalism" }, { name = "Mageweave Cloth", minLvl = 38, maxLvl = 50 }, { name = "Mithril Ore", minLvl = 38, maxLvl = 50, reqProf = "Mining" }, { name = "Thick Leather", minLvl = 36, maxLvl = 50, reqProf = "Skinning" }, { name = "Fadeleaf", minLvl = 35, maxLvl = 50, reqProf = "Herbalism" }, { name = "Runecloth", minLvl = 50, maxLvl = 60 }, { name = "Thorium Ore", minLvl = 50, maxLvl = 60, reqProf = "Mining" }, { name = "Rugged Leather", minLvl = 46, maxLvl = 60, reqProf = "Skinning" }, { name = "Dreamfoil", minLvl = 50, maxLvl = 60, reqProf = "Herbalism" }, { name = "Felcloth", minLvl = 50, maxLvl = 60 }, { name = "Essence of Earth", minLvl = 55, maxLvl = 60 }
}

local DungeonDB = {
    { name = "Ragefire Chasm", minLvl = 13, maxLvl = 20, faction = "Horde" }, { name = "Wailing Caverns", minLvl = 15, maxLvl = 25 }, { name = "The Deadmines", minLvl = 15, maxLvl = 25, faction = "Alliance" }, { name = "Shadowfang Keep", minLvl = 18, maxLvl = 28 }, { name = "Blackfathom Deeps", minLvl = 20, maxLvl = 30 }, { name = "The Stockade", minLvl = 22, maxLvl = 30, faction = "Alliance" }, { name = "Razorfen Kraul", minLvl = 28, maxLvl = 38 }, { name = "Gnomeregan", minLvl = 28, maxLvl = 38 }, { name = "Scarlet Monastery", minLvl = 30, maxLvl = 42 }, { name = "Uldaman", minLvl = 40, maxLvl = 50 }, { name = "Razorfen Downs", minLvl = 38, maxLvl = 48 }, { name = "Zul'Farrak", minLvl = 42, maxLvl = 52 }, { name = "Maraudon", minLvl = 45, maxLvl = 55 }, { name = "The Temple of Atal'Hakkar", minLvl = 50, maxLvl = 58 }, { name = "Blackrock Depths", minLvl = 52, maxLvl = 60 }, { name = "Scholomance", minLvl = 58, maxLvl = 60 }, { name = "Stratholme", minLvl = 58, maxLvl = 60 }, { name = "Dire Maul", minLvl = 56, maxLvl = 60 }, { name = "Blackrock Spire", minLvl = 56, maxLvl = 60 }, { name = "Hellfire Ramparts", minLvl = 59, maxLvl = 67 },
    { name = "The Blood Furnace", minLvl = 61, maxLvl = 68 },
    { name = "The Slave Pens", minLvl = 62, maxLvl = 69 },
    { name = "Underbog", minLvl = 63, maxLvl = 70 },
    { name = "Mana-Tombs", minLvl = 64, maxLvl = 70 },
    { name = "Auchenai Crypts", minLvl = 65, maxLvl = 70 },
    { name = "Sethekk Halls", minLvl = 67, maxLvl = 70 },
    { name = "Shadow Labyrinth", minLvl = 67, maxLvl = 70 },
    { name = "Old Hillsbrad Foothills", minLvl = 66, maxLvl = 70 },
    { name = "The Black Morass", minLvl = 68, maxLvl = 70 },
    { name = "The Shattered Halls", minLvl = 69, maxLvl = 70 },
    { name = "The Botanica", minLvl = 69, maxLvl = 70 }, 
    { name = "The Mechanar", minLvl = 69, maxLvl = 70 },
    { name = "The Arcatraz", minLvl = 70, maxLvl = 70 },
    { name = "Magisters' Terrace", minLvl = 70, maxLvl = 70 }
}

local RaidDB = {
    { name = "Zul'Gurub", minLvl = 60, bossGoal = 5 }, { name = "Molten Core", minLvl = 60, bossGoal = 8 }, { name = "Onyxia's Lair", minLvl = 60, bossGoal = 1 }, { name = "Blackwing Lair", minLvl = 60, bossGoal = 6 }, { name = "Ruins of Ahn'Qiraj", minLvl = 60, bossGoal = 4 }, { name = "Ahn'Qiraj", minLvl = 60, bossGoal = 7 }, { name = "Naxxramas", minLvl = 60, bossGoal = 10 }, { name = "Karazhan", minLvl = 70, bossGoal = 10 },
    { name = "Gruul's Lair", minLvl = 70, bossGoal = 2 },
    { name = "Magtheridon's Lair", minLvl = 70, bossGoal = 1 },
    { name = "Serpentshrine Cavern", minLvl = 70, bossGoal = 6 },
    { name = "Tempest Keep", minLvl = 70, bossGoal = 4 },
    { name = "Hyjal Summit", minLvl = 70, bossGoal = 5 },
    { name = "Black Temple", minLvl = 70, bossGoal = 9 },
    { name = "Sunwell Plateau", minLvl = 70, bossGoal = 6 }
}

local EliteRoster = {}
for i = 1, #RawEliteNames do
    local lvlStr = RawEliteData[i]
    local rarity = lvlStr:match("([A-Za-z%s]+)") or "Elite"
    rarity = rarity:gsub("%s+$", "") 
    local lvlMatch = lvlStr:match("(%d+)")
    local level = lvlMatch and tonumber(lvlMatch) or 63
    local zone = RawEliteZones[i]
    if zone == "-" then zone = "an Unknown Location" end
    table.insert(EliteRoster, { id = RawEliteIDs[i], name = RawEliteNames[i], rarity = rarity, level = level, zone = zone })
end

local function GetDeterministicHash(trigger, goal, offset)
    local hash = 0
    local str = trigger .. tostring(goal) .. tostring(offset)
    for i = 1, #str do hash = (hash * 31 + string.byte(str, i)) % 1000000 end
    return hash
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
    if template.reqDefense and not (pClass == "WARRIOR" or pClass == "PALADIN" or pClass == "ROGUE" or pClass == "HUNTER" or pClass == "SHAMAN") then return false end
    if template.reqInterrupt then
        if pClass == "SHAMAN" and pLvl < 4 then return false end
        if (pClass == "WARRIOR" or pClass == "ROGUE") and pLvl < 12 then return false end
        if pClass == "MAGE" and pLvl < 24 then return false end
        if pClass == "PALADIN" or pClass == "DRUID" or pClass == "HUNTER" or pClass == "PRIEST" or pClass == "WARLOCK" then return false end
    end 
    if template.reqGatherer then
        local hasGathering = false
        for i = 1, GetNumSkillLines() do
            local name = select(1, GetSkillLineInfo(i))
            if name == "Mining" or name == "Herbalism" or name == "Skinning" then hasGathering = true break end
        end
        if not hasGathering then return false end
    end
    if template.trigger == "DUNGEON_CLEAR" then
        local hasValidDung = false
        for _, d in ipairs(DungeonDB) do
            if pLvl >= d.minLvl and (not d.faction or d.faction == pFaction) then hasValidDung = true break end
        end
        if not hasValidDung then return false end
    end
    if template.trigger == "FETCH_ITEM" then
        local hasValidItem = false
        for _, item in ipairs(TradeGoodsDB) do
            if pLvl >= item.minLvl and pLvl <= (item.maxLvl + 10) then
                if not item.reqProf or PlayerHasSkill(item.reqProf) then hasValidItem = true break end
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
            -- Exponential scaling for Damage/Health/Money (~80x multiplier at lvl 60)
            local statScale = 1 + ((pLvl * pLvl) * 0.022)
            finalGoal = math.floor(template.baseGoal * statScale)
        else
            -- Gentle linear scaling for kills/items (3.4x multiplier at lvl 60)
            local countScale = 1 + (pLvl * 0.04)
            finalGoal = math.floor(template.baseGoal * countScale)
        end
    end
    
    local patternIdx = (GetDeterministicHash(template.trigger, finalGoal, "Pattern") % #template.patterns) + 1
    local adjIdx = (GetDeterministicHash(template.trigger, finalGoal, "Adj") % #Adjectives) + 1
    local nounIdx = (GetDeterministicHash(template.trigger, finalGoal, "Noun") % #Nouns) + 1

    local pattern = template.patterns[patternIdx]
    local baseTitle = pattern:gsub("%[Adj%]", Adjectives[adjIdx]):gsub("%[Noun%]", Nouns[nounIdx])
    
    local targetNameStr = ""
    local targetZoneStr = ""
    
    if template.trigger == "FETCH_ITEM" then
        local validItems = {}
        for _, item in ipairs(TradeGoodsDB) do
            if pLvl >= item.minLvl and pLvl <= (item.maxLvl + 10) then 
                if not item.reqProf or PlayerHasSkill(item.reqProf) then table.insert(validItems, item) end
            end
        end
        local chosenItem = (#validItems > 0) and validItems[math.random(#validItems)] or TradeGoodsDB[1]
        targetNameStr = chosenItem.name
    elseif template.trigger == "DUNGEON_CLEAR" then
        local validDungeons = {}
        local pFaction = UnitFactionGroup("player")
        for _, dungeon in ipairs(DungeonDB) do
            if pLvl >= dungeon.minLvl and (not dungeon.faction or dungeon.faction == pFaction) then table.insert(validDungeons, dungeon) end
        end
        local chosenDung = (#validDungeons > 0) and validDungeons[math.random(#validDungeons)] or DungeonDB[1]
        targetNameStr = chosenDung.name
        targetZoneStr = chosenDung.name
    end
    
    local finalDesc = template.baseDesc
    local formattedGoal = DP_FormatNumber(finalGoal)
    if targetNameStr ~= "" then finalDesc = string.format(template.baseDesc, formattedGoal, targetNameStr) else finalDesc = string.format(template.baseDesc, formattedGoal) end
    
    local isTimed = (math.random(1, 100) <= 15) and not template.isLegendary
    local timeLimit = 0
    if isTimed then timeLimit = math.random(15, 30) * 60 end
    
    -- WoW Quest Scaling: Base favor + an extra point every 5 levels
    local favorPayout = template.baseFavor + math.floor(pLvl / 5)
    if isTimed then favorPayout = favorPayout + 1 end
    
    local rarity = "Standard"
    local baseRewardText = ""
	
	-- If Mak'gora is selected, give it a 5% chance to actually remain, otherwise re-roll
	if template.trigger == "MAKGORA_WIN" and math.random(1, 100) > 5 then
		-- Re-roll to a standard action template so Mak'gora stays extremely rare
		template = validActions[math.random(#validActions)]
	end
    
    if template.isLegendary then
        rarity = "Rare Elite"
        baseRewardText = "Reward: +1 Apex Sigil, +35 Favor"
    else
        if allowRare and not isTimed and math.random(1, 100) <= 5 then
            rarity = "Rare"
            favorPayout = favorPayout + 1
            finalGoal = math.ceil(finalGoal * 1.25) -- Bump difficulty slightly for a rare spawn
        end
        baseRewardText = string.format("Reward: +%d Dark Favor", favorPayout)
    end
    
    return { id = GetDeterministicHash(template.trigger, finalGoal, "ID"), title = baseTitle, desc = finalDesc, rarity = rarity, rewardText = baseRewardText, favor = favorPayout, goal = finalGoal, current = 0, trigger = template.trigger, targetName = targetNameStr, zone = targetZoneStr, isPvP = template.isPvP or false, isLegendary = template.isLegendary or false, isTimed = isTimed, timeLimit = timeLimit, expiresAt = 0 }
end

local function GenerateAllDungeonContracts(pLvl)
    local validContracts = {}
    local pFaction = UnitFactionGroup("player")
    for _, dungeon in ipairs(DungeonDB) do
        if pLvl >= dungeon.minLvl and (not dungeon.faction or dungeon.faction == pFaction) then 
            table.insert(validContracts, { id = GetDeterministicHash("DUNGEON_CLEAR", 25, dungeon.name .. GetTime()), title = "Purge of " .. dungeon.name, desc = string.format("Slay 25 enemies inside %s.", dungeon.name), rarity = "Elite", rewardText = "Reward: +1 Dark Sigil", favor = 0, goal = 25, current = 0, trigger = "DUNGEON_CLEAR", targetName = dungeon.name, zone = dungeon.name, isPvP = false, isLegendary = false, isTimed = false })
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
            table.insert(validContracts, { id = GetDeterministicHash("RAID_CLEAR", raid.bossGoal, raid.name .. GetTime()), title = "The Apex Hunt: " .. raid.name, desc = string.format("Slay %d raid bosses inside %s.", raid.bossGoal, raid.name), rarity = "Rare Elite", rewardText = "Reward: +2 Apex Sigils, +50 Favor", favor = 50, goal = raid.bossGoal, current = 0, trigger = "DUNGEON_CLEAR", targetName = raid.name, zone = raid.name, isPvP = false, isLegendary = true, isTimed = true, timeLimit = 604800 })
        end
    end
    return validContracts
end

-- =====================================================================
-- 3. THE PATRON'S VEIL & VOID DEBT AUDIT LOGIC
-- =====================================================================
local Veil = CreateFrame("Frame", "PatronsVeil", UIParent)
Veil:SetAllPoints(UIParent)
Veil:SetFrameStrata("TOOLTIP")
Veil:Hide()
local veilBg = Veil:CreateTexture(nil, "BACKGROUND")
veilBg:SetAllPoints(Veil)
veilBg:SetTexture("Interface\\Buttons\\WHITE8X8")
veilBg:SetVertexColor(0.02, 0.02, 0.05, 0.92)
local veilText = Veil:CreateFontString(nil, "OVERLAY", "QuestFont_Enormous")
veilText:SetPoint("CENTER", 0, 50)
veilText:SetTextColor(1, 0, 0)

local isViolating = false
local lastTalentExcess = 0

local function CheckViolations()
    if not DarkPatronDB then return end
    isViolating = false
    local violationReason = ""

    local totalTalentsSpent = 0
    for tab = 1, GetNumTalentTabs() do
        for i = 1, GetNumTalents(tab) do
            local _, _, _, _, rank = GetTalentInfo(tab, i)
            totalTalentsSpent = totalTalentsSpent + rank
        end
    end
    
    local talentExcess = totalTalentsSpent - DarkPatronDB.MaxTalentsAllowed
    if talentExcess > 0 then
        if talentExcess > lastTalentExcess then
            local penalty = (talentExcess - lastTalentExcess) * 50
            DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - penalty
            print(string.format("|cffff0000[Dark Patron]: Unearned knowledge detected! Your soul is cast into debt (-%d Dark Favor). Revert your talents or work off the debt.|r", penalty))
            if PatronsLedger and PatronsLedger:IsShown() then PatronsLedger:GetScript("OnShow")(PatronsLedger) end
        end
        lastTalentExcess = talentExcess
    else
        lastTalentExcess = 0
    end

    for slot = 1, 19 do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local _, _, itemQuality = GetItemInfo(itemLink)
            if itemQuality and itemQuality > DarkPatronDB.MaxGearQuality then
                isViolating = true
                violationReason = "FORBIDDEN ARTIFACT (Unequip illegal gear)"
                if not InCombatLockdown() then PickupInventoryItem(slot) PutItemInBackpack() end
            end
        end
    end

    if isViolating then Veil:Show() veilText:SetText(violationReason) else Veil:Hide() end
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
pulseGlow:SetSize(40, 40)
pulseGlow:SetPoint("CENTER", 0, 0)
pulseGlow:SetVertexColor(0.64, 0.21, 0.93) 
pulseGlow:Hide()

local pulseAnimGroup = pulseGlow:CreateAnimationGroup()
local alpha1 = pulseAnimGroup:CreateAnimation("Alpha")
alpha1:SetFromAlpha(0.2); alpha1:SetToAlpha(0.8); alpha1:SetDuration(1.2); alpha1:SetOrder(1)
local alpha2 = pulseAnimGroup:CreateAnimation("Alpha")
alpha2:SetFromAlpha(0.8); alpha2:SetToAlpha(0.2); alpha2:SetDuration(1.2); alpha2:SetOrder(2)
pulseAnimGroup:SetLooping("REPEAT")

DP_EvaluateBazaarAlert = function()
    if not DarkPatronDB then return end
    local shouldPulse = false
    if not DarkPatronDB.HasAlchemistGrace and DarkPatronDB.DarkFavor >= 35 then shouldPulse = true end
    if DarkPatronDB.MaxGearQuality == 1 and DarkPatronDB.DarkFavor >= 18 then shouldPulse = true end
    if not DarkPatronDB.HasBank and DarkPatronDB.DarkFavor >= 25 then shouldPulse = true end
    if DarkPatronDB.DungeonBounties and #DarkPatronDB.DungeonBounties > 0 then shouldPulse = true end
    if shouldPulse then pulseGlow:Show() pulseAnimGroup:Play() else pulseGlow:Hide() pulseAnimGroup:Stop() end
end

local border = MinimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT", 0, 0)

MinimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
MinimapBtn:SetScript("OnClick", function() if PatronsLedger and PatronsLedger:IsShown() then PatronsLedger:Hide() else PatronsLedger:Show() end end)

local Tracker = CreateFrame("Frame", "DarkPatronTracker", UIParent, "BackdropTemplate")
Tracker:SetSize(260, 20)
Tracker:SetPoint("RIGHT", UIParent, "RIGHT", -80, 0)
Tracker:SetMovable(true)
Tracker:EnableMouse(true)
Tracker:RegisterForDrag("LeftButton")
Tracker:SetScript("OnDragStart", function(self) if IsShiftKeyDown() then self:StartMoving() end end)
Tracker:SetScript("OnDragStop", Tracker.StopMovingOrSizing)
Tracker:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
Tracker:SetBackdropColor(0.05, 0.05, 0.1, 0.85)

Tracker.Header = Tracker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
Tracker.Header:SetPoint("TOPLEFT", 10, -10)
Tracker.Header:SetText("Active Pacts")

Tracker.Rows = {}
for i = 1, 4 do
    local row = Tracker:CreateFontString(nil, "OVERLAY", "GameFontWhiteSmall")
    row:SetWidth(230)
    row:SetJustifyH("LEFT")
    row:SetJustifyV("TOP")
    Tracker.Rows[i] = row
end

local function UpdateTracker()
    if not DarkPatronDB or not DarkPatronDB.ActiveMissions or #DarkPatronDB.ActiveMissions == 0 then Tracker:Hide() return end
    Tracker:Show()
    local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    local currentY = -30
    for i = 1, 4 do
        if i <= maxSlots then
            Tracker.Rows[i]:SetPoint("TOPLEFT", 15, currentY)
            local m = DarkPatronDB.ActiveMissions[i]
            if m then
                local progressText = (m.goal and m.goal > 1) and string.format("\nProgress: %d / %d", m.current or 0, m.goal) or ""
                local timeText = ""
                if m.isTimed and m.expiresAt then
                    local remain = m.expiresAt - time()
                    if remain > 0 then timeText = string.format("\n|cffaaaaaaTime Remaining: %02d:%02d|r", math.floor(remain / 60), remain % 60) else timeText = "\n|cffff0000FAILED|r" end
                end
                local rarityLabel = ""
                if m.rarity == "Rare Elite" or m.rarity == "Boss" then rarityLabel = "["..m.rarity.."]\n" elseif m.rarity == "Elite" then rarityLabel = "[Elite]\n" elseif m.rarity == "Rare" then rarityLabel = "[Rare]\n" end
                Tracker.Rows[i]:SetText(string.format("%s%s\n%s%s%s", rarityLabel, m.title, m.desc, progressText, timeText))
                if m.rarity == "Rare Elite" or m.rarity == "Boss" then Tracker.Rows[i]:SetTextColor(1, 0.5, 0) elseif m.rarity == "Elite" then Tracker.Rows[i]:SetTextColor(0.64, 0.21, 0.93) elseif m.rarity == "Rare" then Tracker.Rows[i]:SetTextColor(0, 0.44, 0.87) else Tracker.Rows[i]:SetTextColor(1, 1, 1) end
                Tracker.Rows[i]:Show()
                currentY = currentY - Tracker.Rows[i]:GetStringHeight() - 12
            else
                Tracker.Rows[i]:SetText(string.format("Slot %d: Empty", i))
                Tracker.Rows[i]:SetTextColor(0.5, 0.5, 0.5)
                Tracker.Rows[i]:Show()
                currentY = currentY - Tracker.Rows[i]:GetStringHeight() - 12
            end
        else
            Tracker.Rows[i]:Hide()
        end
    end
    Tracker:SetHeight(math.abs(currentY) + 15)
end

local DragGhost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
DragGhost:SetSize(180, 45)
DragGhost:SetFrameStrata("TOOLTIP")
DragGhost:Hide()
DragGhost:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
DragGhost.title = DragGhost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
DragGhost.title:SetPoint("CENTER")

local function StartDragging(sourceType, index, titleText)
    DragGhost.sourceType = sourceType; DragGhost.sourceIndex = index; DragGhost.title:SetText(titleText); DragGhost:Show()
    DragGhost:SetScript("OnUpdate", function(self) local x, y = GetCursorPosition(); local s = self:GetEffectiveScale(); self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x/s, y/s) end)
end
local function StopDragging() DragGhost:Hide(); DragGhost:SetScript("OnUpdate", nil) end

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

local closeBtn = _G["PatronsLedgerCloseButton"]
if closeBtn then closeBtn:ClearAllPoints(); closeBtn:SetPoint("TOPRIGHT", Ledger, "TOPRIGHT", -4, -4) end

local HelpBtn = CreateFrame("Button", nil, Ledger, "UIPanelButtonTemplate")
HelpBtn:SetSize(24, 24)
if closeBtn then HelpBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0) else HelpBtn:SetPoint("TOPRIGHT", Ledger, "TOPRIGHT", -32, -4) end
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
    
    if not DarkPatronDB or (DarkPatronDB.TotalPactsAccepted or 0) == 0 then
        return {"The parchment is cold and blank. Your story has yet to be written in blood.\n\nFulfill your first pact to begin."}
    end

    local archetype, archeDesc = GetPlayerArchetype()
    local p1 = string.format("The Ledger recognizes %s, a %s of the %s archetype. They navigated the Veil by %s.\n\n", pName, string.lower(pClass), archetype, archeDesc)
    p1 = p1 .. string.format("To date, they have sealed and fulfilled %d pacts, surviving trials that would break lesser souls.\n\n", DarkPatronDB.TotalPactsAccepted)

    if DarkPatronDB.FirstEliteKilled then p1 = p1 .. string.format("The Patron's eye was truly drawn to them on the day they executed %s. That first major kill proved they were not merely prey, but a predator in their own right.\n\n", DarkPatronDB.FirstEliteKilled) else p1 = p1 .. "Though they have survived the board, they have yet to claim the head of a true Elite. The Patron watches, waiting for them to prove their mettle.\n\n" end
    table.insert(pages, p1)

    local p2 = ""
    local fails = DarkPatronDB.FailedPactsCount or 0
    if fails == 0 and DarkPatronDB.TotalPactsAccepted > 10 then p2 = p2 .. "Remarkably, their resolve has never fractured. Every pact signed has been fulfilled. The Veil honors their flawless execution.\n\n"
    elseif fails > 0 and fails < 5 then p2 = p2 .. string.format("But the path to power is paved with broken promises. They failed the Patron %d times, paying the blood tax to survive their own hubris.\n\n", fails)
    elseif fails >= 5 then p2 = p2 .. string.format("Their ambition often outpaced their ability. With %d broken pacts, they bled Dark Favor time and time again, narrowly avoiding the Patron's ultimate wrath.\n\n", fails) end

    if DarkPatronDB.MaxGearQuality >= 3 then p2 = p2 .. "Unwilling to die in peasant's cloth, they secured the rights to formidable armaments from the Bazaar, weaponizing their greed.\n\n" end
    if DarkPatronDB.HasBank or DarkPatronDB.HasAuction then p2 = p2 .. "By securing the Hoarder's Key and the Merchant's Writ, they rooted their influence deep into the economies of Azeroth.\n\n" end
    if p2 ~= "" then table.insert(pages, p2) end

    local p3 = ""
    if DarkPatronDB.ApexSigils > 0 or DarkPatronDB.HasCapstone then
        p3 = p3 .. "Having touched the Void, they claimed their first Apex Sigils. "
        if DarkPatronDB.HasCapstone then p3 = p3 .. "With this forbidden currency, they awakened their ultimate potential, unlocking powers the Light meant to keep hidden.\n\n" else p3 = p3 .. "They hoard this legendary currency, biding their time for a masterstroke.\n\n" end
    end
    
    if DarkPatronDB.HasJourneymanCavalry and not DarkPatronDB.HasMasterCavalry then p3 = p3 .. "When the distances grew vast, they traded Dark Favor for the loyalty of a phantom steed, riding where others walked.\n\n"
    elseif DarkPatronDB.HasMasterCavalry then p3 = p3 .. "Now, they ride upon a Master's mount, a blur of shadow and steel across the continents. The story of " .. pName .. " is etched into the very fabric of the Dark Patron's ledger." end
    
    if pLvl == 60 and not DarkPatronDB.HasMasterCavalry then p3 = p3 .. "Standing at the precipice of mortal limits, the Champion of the Veil gazes into the Abyss. Though they have reached the summit, true power still eludes them. The Patron waits for them to claim their final Sanctions.\n\n" end
    if p3 ~= "" then table.insert(pages, p3) end

    if DarkPatronDB.IsDead and DarkPatronDB.DeathEpitaph then table.insert(pages, DarkPatronDB.DeathEpitaph) end
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
local ParticleFrame = CreateFrame("Frame", nil, BoardContainer)
ParticleFrame:SetAllPoints(); ParticleFrame:SetFrameLevel(100) 
local activeParticles, availableParticles, glowingCards = {}, {}, {}

for i = 1, 60 do 
    local tex = ParticleFrame:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark"); tex:SetBlendMode("ADD"); tex:SetAlpha(0); tex:Hide()
    tex.isActive = false; tex.velX = 0; tex.velY = 0; tex.life = 0
    table.insert(availableParticles, tex)
end

local function SpawnCardParticle(card, rarity)
    local p = table.remove(availableParticles)
    if not p then return end
    local size = math.random(10, 18); p:SetSize(size, size); local width = card:GetWidth()
    p.posX = math.random(-(width / 2.5), (width / 2.5)); p.posY = (size / 2) + 4; p.baseAlpha = 0.8
    p.velX = (math.random() - 0.5) * 15; p.velY = math.random(15, 35)
    if rarity == "Rare" then p:SetVertexColor(0.2, 0.8, 1.0) elseif rarity == "Elite" then p:SetVertexColor(0.6, 0.2, 1.0) else p:SetVertexColor(1.0, 0.6, 0.0) end 
    p.life = math.random(1000, 2000) / 1000; p.parentCard = card; p.isActive = true; p:SetAlpha(p.baseAlpha)
    p:ClearAllPoints(); p:SetPoint("CENTER", card, "BOTTOM", p.posX, p.posY); p:Show()
    table.insert(activeParticles, p)
end

ParticleFrame:SetScript("OnUpdate", function(self, elapsed)
    if #glowingCards == 0 and #activeParticles == 0 then
        return
    end
    local now = GetTime()
    if #glowingCards > 0 and math.random() < 0.3 then
        local targetCard = glowingCards[math.random(#glowingCards)]
        if targetCard:IsShown() and targetCard.missionRarity then SpawnCardParticle(targetCard, targetCard.missionRarity) end
    end
    for i = #activeParticles, 1, -1 do
        local p = activeParticles[i]
        p.posX = p.posX + (p.velX * elapsed); p.posY = p.posY + (p.velY * elapsed); p.life = p.life - elapsed
        if p.life <= 0 or not p.parentCard:IsShown() then
            p.isActive = false; p:Hide(); table.remove(activeParticles, i); table.insert(availableParticles, p)
        else
            local curA = math.min(p.life, 1.0) * p.baseAlpha
            p.posX = p.posX + (math.sin(now * 2 + p.velY) * 0.5); p:SetAlpha(curA); p:SetPoint("CENTER", p.parentCard, "BOTTOM", p.posX, p.posY)
        end
    end
end)

local function ApplyCardTheme(card, mission)
    for i = #glowingCards, 1, -1 do if glowingCards[i] == card then table.remove(glowingCards, i) end end
    card.missionRarity = nil
    if not mission then
        card.rarityText:SetText(""); card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1); card:SetBackdropColor(0.05, 0.05, 0.1, 0.85); if card.bgImage then card.bgImage:Hide() end; return
    end
    if mission.rarity == "Rare Elite" or mission.rarity == "Boss" then
        card.rarityText:SetText("["..mission.rarity.."]"); card.rarityText:SetTextColor(1, 0.5, 0); card:SetBackdropBorderColor(1, 0.5, 0, 1); card.missionRarity = mission.rarity; table.insert(glowingCards, card)
    elseif mission.rarity == "Elite" then
        card.rarityText:SetText("[Elite]"); card.rarityText:SetTextColor(0.64, 0.21, 0.93); card:SetBackdropBorderColor(0.64, 0.21, 0.93, 1); card.missionRarity = mission.rarity; table.insert(glowingCards, card)
    elseif mission.rarity == "Rare" then
        card.rarityText:SetText("[Rare]"); card.rarityText:SetTextColor(0, 0.44, 0.87); card:SetBackdropBorderColor(0, 0.44, 0.87, 1); card.missionRarity = mission.rarity; table.insert(glowingCards, card)
    elseif mission.rarity == "Standard" then
        card.rarityText:SetText(""); card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end
    card.title:SetTextColor(1, 1, 1)

    if not card.bgImage then card.bgImage = card:CreateTexture(nil, "BORDER"); card.bgImage:SetPoint("TOPLEFT", 4, -4); card.bgImage:SetPoint("BOTTOMRIGHT", -4, 4) end
    if card:GetWidth() > 300 then card.bgImage:SetTexCoord(0, 1, 0.3, 0.6) else card.bgImage:SetTexCoord(0, 1, 0.1, 0.8) end
    local loadScreenSuffix = nil
    if (mission.trigger == "DUNGEON_CLEAR" or mission.rarity == "Boss") and mission.zone and ZoneLoadingScreens[mission.zone] then loadScreenSuffix = ZoneLoadingScreens[mission.zone] end

    if loadScreenSuffix then card.bgImage:SetTexture("Interface\\Glues\\LoadingScreens\\" .. loadScreenSuffix); card.bgImage:SetVertexColor(0.35, 0.35, 0.35, 1); card.bgImage:Show(); card:SetBackdropColor(0, 0, 0, 0.7) 
    else card.bgImage:Hide(); card:SetBackdropColor(0.05, 0.05, 0.1, 0.85) end
end

local BoardWarning = BoardContainer:CreateFontString(nil, "OVERLAY", "GameFontRed")
BoardWarning:SetPoint("TOP", BoardContainer, "TOP", 0, -60)
BoardWarning:SetText("You must be in a Sanctuary to Modify Pacts or Reshuffle.")
BoardWarning:Hide()

activeCards = {}
local activeHeader = BoardContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
activeHeader:SetPoint("TOPLEFT", 20, -105)
activeHeader:SetText("Active Pacts (Centered dynamically - Drag to Reorder):")

for i = 1, 4 do
    local card = CreateFrame("Frame", nil, BoardContainer, "BackdropTemplate")
    card:SetSize(170, 110)
    card:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
    card:EnableMouse(true); card:RegisterForDrag("LeftButton")
    
    card:SetScript("OnDragStart", function(self)
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if canEdit and DarkPatronDB.ActiveMissions[i] then StartDragging("active", i, DarkPatronDB.ActiveMissions[i].title) end
    end)
    card:SetScript("OnDragStop", function(self)
        StopDragging(); local maxSlots = DarkPatronDB.MaxActiveSlots or 3
        for j = 1, maxSlots do
            if activeCards[j]:IsMouseOver() and j ~= i and DarkPatronDB.ActiveMissions[i] then
                local movingData = table.remove(DarkPatronDB.ActiveMissions, i)
                local targetIdx = math.min(j, #DarkPatronDB.ActiveMissions + 1)
                table.insert(DarkPatronDB.ActiveMissions, targetIdx, movingData)
                Ledger:GetScript("OnShow")(Ledger); UpdateTracker(); break
            end
        end
    end)
    
    card.rarityText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny"); card.rarityText:SetPoint("TOP", card, "TOP", 0, -6)
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); card.title:SetPoint("TOP", card.rarityText, "BOTTOM", 0, -1); card.title:SetWidth(155); card.title:SetWordWrap(false)
    card.desc = card:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny"); card.desc:SetSize(155, 45); card.desc:SetPoint("TOP", card.title, "BOTTOM", 0, -2); card.desc:SetJustifyH("CENTER"); card.desc:SetJustifyV("TOP")
    card.reward = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); card.reward:SetPoint("BOTTOM", card, "BOTTOM", 0, 28); card.reward:SetTextColor(1, 0.82, 0)
    
    card.btn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate"); card.btn:SetSize(120, 20); card.btn:SetPoint("BOTTOM", card, "BOTTOM", 0, 5)
    card.btn:SetScript("OnClick", function()
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if not canEdit then print("Dark Patron: You must be in a Sanctuary to modify pacts.") return end

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
poolHeader:SetText("Sanctuary Bounty Board (Drag Tile to Active Pacts to Accept):")

poolButtons = {}
for i = 1, 6 do
    local row = math.floor((i - 1) / 3); local col = (i - 1) % 3
    local btnCard = CreateFrame("Frame", nil, BoardContainer, "BackdropTemplate")
    btnCard:SetSize(230, 105); btnCard:SetPoint("TOPLEFT", 20 + (col * 240), -280 - (row * 115))
    btnCard:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
    btnCard:EnableMouse(true); btnCard:RegisterForDrag("LeftButton")
    
    btnCard:SetScript("OnDragStart", function(self)
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if canEdit and DarkPatronDB.PoolOfSix[i] then StartDragging("board", i, DarkPatronDB.PoolOfSix[i].title) end
    end)
    btnCard:SetScript("OnDragStop", function(self)
        StopDragging(); local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if not canEdit then print("Dark Patron: You must be in a Sanctuary to modify pacts.") return end

        local droppedOnActive = false; local maxSlots = DarkPatronDB.MaxActiveSlots or 3
        for j = 1, maxSlots do if activeCards[j]:IsMouseOver() then droppedOnActive = true break end end
        if droppedOnActive then
            if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
            local chosen = table.remove(DarkPatronDB.PoolOfSix, i)
            if chosen.isTimed then chosen.expiresAt = time() + chosen.timeLimit end 
            table.insert(DarkPatronDB.ActiveMissions, chosen)
            
            DarkPatronDB.TotalPactsAccepted = (DarkPatronDB.TotalPactsAccepted or 0) + 1
            if not DarkPatronDB.HasInitializedAwakening and DarkPatronDB.TotalPactsAccepted >= maxSlots then
                DarkPatronDB.HasInitializedAwakening = true
                print("|cffff0000[Dark Patron]: The Veil descends. You must now rest in a Sanctuary to commune with the board.|r")
            end
            RefillMissionPool(); Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
        end
    end)
    
    btnCard.rarityText = btnCard:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny"); btnCard.rarityText:SetPoint("TOP", btnCard, "TOP", 0, -6)
    btnCard.title = btnCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); btnCard.title:SetPoint("TOP", btnCard.rarityText, "BOTTOM", 0, -1); btnCard.title:SetWidth(210); btnCard.title:SetWordWrap(false)
    btnCard.desc = btnCard:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny"); btnCard.desc:SetSize(210, 35); btnCard.desc:SetPoint("TOP", btnCard.title, "BOTTOM", 0, -2); btnCard.desc:SetJustifyH("CENTER"); btnCard.desc:SetJustifyV("TOP")
    btnCard.reward = btnCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); btnCard.reward:SetPoint("BOTTOM", btnCard, "BOTTOM", 0, 27); btnCard.reward:SetTextColor(1, 0.82, 0)
    
    btnCard.acceptBtn = CreateFrame("Button", nil, btnCard, "UIPanelButtonTemplate"); btnCard.acceptBtn:SetSize(90, 18); btnCard.acceptBtn:SetPoint("BOTTOM", btnCard, "BOTTOM", 0, 6); btnCard.acceptBtn:SetText("Accept Pact")
    btnCard.acceptBtn:SetScript("OnClick", function()
        local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
        if not canEdit then print("Dark Patron: You must be in a Sanctuary to modify pacts.") return end

        if DarkPatronDB.PoolOfSix[i] then
            local maxSlots = DarkPatronDB.MaxActiveSlots or 3
            if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
            local chosen = table.remove(DarkPatronDB.PoolOfSix, i)
            if chosen.isTimed then chosen.expiresAt = time() + chosen.timeLimit end 
            table.insert(DarkPatronDB.ActiveMissions, chosen)
            
            DarkPatronDB.TotalPactsAccepted = (DarkPatronDB.TotalPactsAccepted or 0) + 1
            if not DarkPatronDB.HasInitializedAwakening and DarkPatronDB.TotalPactsAccepted >= maxSlots then
                DarkPatronDB.HasInitializedAwakening = true
                print("|cffff0000[Dark Patron]: The Veil descends. You must now rest in a Sanctuary to commune with the board.|r")
            end
            RefillMissionPool(); Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
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
    if canEdit and currentContract then StartDragging("dungeon", 7, currentContract.title) end
end)
DungeonCard:SetScript("OnDragStop", function(self)
    StopDragging(); local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if not canEdit then print("Dark Patron: You must be in a Sanctuary to modify pacts.") return end

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
    if not canEdit then print("Dark Patron: You must be in a Sanctuary to modify pacts.") return end
    local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
    local chosen = table.remove(DarkPatronDB.DungeonBounties, Ledger.CurrentDungeonIndex)
    table.insert(DarkPatronDB.ActiveMissions, chosen)
    if #DarkPatronDB.DungeonBounties == 0 then DarkPatronDB.DungeonBounties = nil Ledger.CurrentDungeonIndex = 1 elseif Ledger.CurrentDungeonIndex > #DarkPatronDB.DungeonBounties then Ledger.CurrentDungeonIndex = #DarkPatronDB.DungeonBounties end
    Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
end)

refreshBtn = CreateFrame("Button", "DarkPatronRefreshBtn", BoardContainer, "UIPanelButtonTemplate"); refreshBtn:SetSize(160, 25); refreshBtn:SetPoint("BOTTOM", BoardContainer, "BOTTOM", 0, 45); refreshBtn:SetText("Reshuffle Board")
local autoRefreshTimerText = BoardContainer:CreateFontString(nil, "OVERLAY", "GameFontWhiteTiny"); autoRefreshTimerText:SetPoint("BOTTOM", refreshBtn, "TOP", 0, -37); autoRefreshTimerText:SetTextColor(0.6, 0.6, 0.6)

refreshBtn:SetScript("OnClick", function()
    local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if not canEdit then print("Dark Patron: You must be in a Sanctuary to reshuffle the board.") return end
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
    if canEdit and currentContract then StartDragging("elite", 8, currentContract.title) end
end)

ECard:SetScript("OnDragStop", function(self)
    StopDragging(); local canEdit = IsResting() or devMode or not DarkPatronDB.HasInitializedAwakening
    if not canEdit then print("Dark Patron: You must be in a Sanctuary to modify pacts.") return end

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
    if not canEdit then print("Dark Patron: You must be in a Sanctuary to modify pacts.") return end
    local maxSlots = DarkPatronDB.MaxActiveSlots or 3
    if #DarkPatronDB.ActiveMissions >= maxSlots then print(string.format("Dark Patron: Active Pacts are full (Max %d). Discard a pact first.", maxSlots)) return end
    
    local chosen = table.remove(DarkPatronDB.EliteBounties, Ledger.CurrentEliteIndex)
    table.insert(DarkPatronDB.ActiveMissions, chosen)
    
    if #DarkPatronDB.EliteBounties == 0 then DarkPatronDB.EliteBounties = nil Ledger.CurrentEliteIndex = 1 elseif Ledger.CurrentEliteIndex > #DarkPatronDB.EliteBounties then Ledger.CurrentEliteIndex = #DarkPatronDB.EliteBounties end
    Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
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

local apexHeader = ApexContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
apexHeader:SetPoint("TOPLEFT", 20, -70)
apexHeader:SetText("The Apex Sanctum (Level 60 Endgame & Conversion):")
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
    btn:SetScript("OnClick", function() if not (IsResting() or devMode) then print("|cffff0000[Dark Patron]: You must be in a Sanctuary to exchange currency.|r") return end onClickFunc() end)
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
        if not (IsResting() or devMode) then print("|cffff0000[Dark Patron]: You must be in a resting Sanctuary to purchase Sanctions.|r") return end
        onBuyClick()
    end)
    
    if isApexTab then table.insert(apexCardsList, card) else table.insert(storeCardsList, card) end
    return card
end

local function GetTalentCost() return math.floor(10 + ((DarkPatronDB.MaxTalentsAllowed or 0) * 2.5)) end

local function UpdateBazaarUI()
    local isPlayerSSF = IsSelfFound(); local bazaarCanEdit = IsResting() or devMode
    if storeCardsList[2] then storeCardsList[2].btn:SetText(GetTalentCost() .. " Favor") end
    
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

-- LEVELING TAB CARDS
CreateStoreCard(false, 1, "Uncommon Armaments", "Unlock the right to equip Uncommon (Green) quality gear permanently.", "18 Favor", function() if DarkPatronDB.DarkFavor >= 18 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 18; DarkPatronDB.MaxGearQuality = 2; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.MaxGearQuality >= 2 end, function() return DarkPatronDB.DarkFavor >= 18 end)
CreateStoreCard(false, 2, "Grant of Knowledge", "Grants the right to allocate 1 additional talent point (Repeatable).", "", function() local cost = GetTalentCost() if DarkPatronDB.DarkFavor >= cost then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - cost; DarkPatronDB.MaxTalentsAllowed = (DarkPatronDB.MaxTalentsAllowed or 0) + 1; PlaySound(8959) CheckViolations(); if Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end end end, nil, function() return DarkPatronDB.DarkFavor >= GetTalentCost() end)
CreateStoreCard(false, 3, "Rare Armaments", "Unlock the right to equip Rare (Blue) quality gear permanently.", "2 Dark Sigils", function() if DarkPatronDB.DarkSigils >= 2 then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - 2; DarkPatronDB.MaxGearQuality = 3; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.MaxGearQuality >= 3 end, function() return DarkPatronDB.DarkSigils >= 2 end)
CreateStoreCard(false, 4, "Journeyman's Cavalry", "Unlock the right to summon and ride your Level 40 (60% speed) mount.", "5 Dark Sigils", function() if DarkPatronDB.DarkSigils >= 5 then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - 5; DarkPatronDB.HasJourneymanCavalry = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasJourneymanCavalry end, function() return DarkPatronDB.DarkSigils >= 5 end)
CreateStoreCard(false, 5, "The Blood Contract", "Trade 30 Favor to hunt a level-appropriate Elite. Prioritizes local zone.", "30 Favor", function()
    if DarkPatronDB.DarkFavor >= 30 then
        local maxSlots = DarkPatronDB.MaxActiveSlots or 3
        if #DarkPatronDB.ActiveMissions >= maxSlots then print("Dark Patron: Your Active Pacts are full. Discard one before signing a Blood Contract.") return end
        
        local pLvl = UnitLevel("player") or 1; local validElites = {}; local localElites = {}; local currentZone = GetRealZoneText() or ""
        for _, elite in ipairs(EliteRoster) do
            if elite.level >= (pLvl - 7) and elite.level <= (pLvl + 4) then
                local isUsed = false
                if DarkPatronDB.CompletedElites then for _, completedId in ipairs(DarkPatronDB.CompletedElites) do if completedId == elite.id then isUsed = true break end end end
                for _, active in ipairs(DarkPatronDB.ActiveMissions) do if active.targetName == elite.name then isUsed = true break end end
                for _, poolItem in ipairs(DarkPatronDB.PoolOfSix) do if poolItem.targetName == elite.name then isUsed = true break end end
                if DarkPatronDB.EliteBounties then for _, eliteItem in ipairs(DarkPatronDB.EliteBounties) do if eliteItem.targetName == elite.name then isUsed = true break end end end
                
                if not isUsed then table.insert(validElites, elite) if string.find(elite.zone, currentZone) then table.insert(localElites, elite) end end
            end
        end
        if #validElites == 0 then print("Dark Patron: The Blood Contract is void. No valid Elite targets remain in your level range.") return end
        
        local chosen = (#localElites > 0) and localElites[math.random(#localElites)] or validElites[math.random(#validElites)]
        DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 30
        local favorReward = (chosen.rarity == "Boss" or chosen.rarity == "Rare Elite") and 5 or 3
        local sigilReward = (chosen.rarity == "Boss" or chosen.rarity == "Rare Elite") and "+1 Apex Sigil" or "+1 Dark Sigil"
        
        DarkPatronDB.EliteBounties = DarkPatronDB.EliteBounties or {}
        table.insert(DarkPatronDB.EliteBounties, { id = chosen.id, title = string.format("%s", chosen.name), baseTitle = chosen.name, desc = string.format("Execute %s. (Located in %s)", chosen.name, chosen.zone), rarity = chosen.rarity, rewardText = "Reward: " .. sigilReward, favor = favorReward, goal = 1, current = 0, trigger = "SPECIFIC_KILL", targetName = chosen.name, zone = chosen.zone })
        
        PlaySound(8959)
        print("DARK PATRON: Blood Contract signed! A specific targeted Hunt has been bound to your ledger.")
        Ledger:GetScript("OnShow")(Ledger)
    else 
        print("Dark Patron: Insufficient Dark Favor (Requires 30).") 
    end
end, nil, function() return DarkPatronDB.DarkFavor >= 30 end)
CreateStoreCard(false, 6, "The Apex Rite", "Sacrifice Elite Dark Sigils to forge 1 forbidden Apex Sigil.", "5 Dark Sigils", function() if DarkPatronDB.DarkSigils >= 5 then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - 5; DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + 1; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) else print("Dark Patron: Insufficient Dark Sigils.") end end, nil, function() return DarkPatronDB.DarkSigils >= 5 end)
CreateStoreCard(false, 7, "The Alchemist's Grace", "Permanently reduce the Coward's Tax for abandoning active pacts down to 1 Favor.", "35 Favor", function() if DarkPatronDB.DarkFavor >= 35 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 35; DarkPatronDB.HasAlchemistGrace = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) else print("Dark Patron: Insufficient Dark Favor (Requires 35).") end end, function() return DarkPatronDB.HasAlchemistGrace end, function() return DarkPatronDB.DarkFavor >= 35 end)
CreateStoreCard(false, 8, "The Pathfinder's Intuition", "Permanently makes board reshuffles completely free (0 Favor cost).", "50 Favor", function() if DarkPatronDB.DarkFavor >= 50 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 50; DarkPatronDB.HasTravelerStep = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) else print("Dark Patron: Insufficient Dark Favor (Requires 50).") end end, function() return DarkPatronDB.HasTravelerStep end, function() return DarkPatronDB.DarkFavor >= 50 end)
CreateStoreCard(false, 9, "The Sovereign Awakening", "Gamble 30 Dark Favor for a 10% chance to forge 1 Apex Sigil. Failure destroys your Favor.", "30 Favor", function() if DarkPatronDB.DarkFavor >= 30 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 30; if math.random(1, 100) <= 10 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + 1; PlaySound(8959); print("DARK PATRON: THE AWAKENING SUCCEEDS! An Apex Sigil has been forged from the void!") else PlaySound(6243); print("DARK PATRON: The Sovereign rejects your offering... Your 30 Dark Favor is lost to the void.") end Ledger:GetScript("OnShow")(Ledger) end end, nil, function() return DarkPatronDB.DarkFavor >= 30 end)
CreateStoreCard(false, 10, "Extended Ledger", "Permanently unlock a 4th simultaneous Active Pact slot.", "50 Favor", function() if DarkPatronDB.DarkFavor >= 50 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 50; DarkPatronDB.MaxActiveSlots = 4; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return (DarkPatronDB.MaxActiveSlots or 3) >= 4 end, function() return DarkPatronDB.DarkFavor >= 50 end)
CreateStoreCard(false, 11, "The Hoarder's Key", "Unlock the right to access and use your Bank.", "25 Favor", function() if DarkPatronDB.DarkFavor >= 25 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 25; DarkPatronDB.HasBank = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasBank end, function() return DarkPatronDB.DarkFavor >= 25 end)
CreateStoreCard(false, 12, "The Merchant's Writ", "Unlock the right to buy and sell on the Auction House.", "40 Favor", function() if DarkPatronDB.DarkFavor >= 40 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 40; DarkPatronDB.HasAuction = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasAuction end, function() return DarkPatronDB.DarkFavor >= 40 end, true)
CreateStoreCard(false, 13, "The Courier's Seal", "Unlock the right to open and send Mail.", "20 Favor", function() if DarkPatronDB.DarkFavor >= 20 then DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 20; DarkPatronDB.HasMail = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasMail end, function() return DarkPatronDB.DarkFavor >= 20 end, true)
CreateStoreCard(false, 14, "Capstone Awakening", "Unlock your 31-point ultimate talent. Required to spend 31st point.", "1 Apex Sigil", function() if DarkPatronDB.ApexSigils >= 1 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 1; DarkPatronDB.HasCapstone = true; DarkPatronDB.MaxTalentsAllowed = DarkPatronDB.MaxTalentsAllowed + 1; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasCapstone end, function() return DarkPatronDB.ApexSigils >= 1 end)

-- === APEX ENDGAME SANCTUM CARDS ===
CreateStoreCard(true, 1, "Master's Cavalry", "Unlock the right to summon and ride your Level 60 Epic (100% speed) mount.", "10 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 10 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 10; DarkPatronDB.HasMasterCavalry = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasMasterCavalry end, function() return DarkPatronDB.ApexSigils >= 10 end)
CreateStoreCard(true, 2, "Epic Armaments", "Unlock the right to equip Epic (Purple) gear permanently.", "5 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 5 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 5; DarkPatronDB.MaxGearQuality = 4; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.MaxGearQuality >= 4 end, function() return DarkPatronDB.ApexSigils >= 5 end)
CreateStoreCard(true, 3, "The Artisan's Sanction", "Unlock the right to equip and use Epic-quality crafted gear.", "3 Dark Sigils", function() if DarkPatronDB.DarkSigils >= 3 then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils - 3; DarkPatronDB.HasArtisanSanction = true; PlaySound(8959) CheckViolations() Ledger:GetScript("OnShow")(Ledger) else print("Dark Patron: Insufficient Dark Sigils.") end end, function() return DarkPatronDB.HasArtisanSanction end, function() return DarkPatronDB.DarkSigils >= 3 end)
CreateStoreCard(true, 4, "Alchemist's Sight", "Unlock the right to use powerful combat alterations (LIPs, Petris, FAPs).", "3 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 3 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 3; DarkPatronDB.HasAlchemistSight = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasAlchemistSight end, function() return DarkPatronDB.ApexSigils >= 3 end)
CreateStoreCard(true, 5, "Enchanter's Writ", "Unlock the right to apply high-tier endgame weapon enchants (Crusader, Spellpower).", "3 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 3 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 3; DarkPatronDB.HasEnchantersWrit = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasEnchantersWrit end, function() return DarkPatronDB.ApexSigils >= 3 end)
CreateStoreCard(true, 6, "The World's Boon", "Unlock the right to retain World Buffs. The Patron strips unsanctioned boons instantly.", "2 Apex Sigils", function() if DarkPatronDB.ApexSigils >= 2 then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils - 2; DarkPatronDB.HasWorldsBoon = true; PlaySound(8959) Ledger:GetScript("OnShow")(Ledger) end end, function() return DarkPatronDB.HasWorldsBoon end, function() return DarkPatronDB.ApexSigils >= 2 end)

tabBoardBtn:SetScript("OnClick", function() if WelcomeModal and WelcomeModal:IsShown() then return end currentView = "board"; BoardContainer:Show(); BazaarContainer:Hide(); BazaarScrollBar:Hide(); ApexContainer:Hide(); ApexScrollBar:Hide(); ChronicleContainer:Hide() end)
tabBazaarBtn:SetScript("OnClick", function() if WelcomeModal and WelcomeModal:IsShown() then return end currentView = "bazaar"; BazaarContainer:Show(); BoardContainer:Hide(); BazaarScrollBar:Show(); ApexContainer:Hide(); ApexScrollBar:Hide(); ChronicleContainer:Hide(); UpdateBazaarScrollStates() end)

tabApexBtn:SetScript("OnClick", function()
    if WelcomeModal and WelcomeModal:IsShown() then return end
    local pLvl = UnitLevel("player") or 1
    if pLvl < 60 and not devMode then
        print("|cffff0000[Dark Patron]: The Apex Sanctum remains sealed until you reach Level 60.|r")
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
    RefillMissionPool(); print("DEV: Wiped & Awakening Reset."); CheckViolations(); Ledger:GetScript("OnShow")(Ledger); UpdateTracker()
end)

Ledger:SetScript("OnShow", function()
    if DarkPatronDB then
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
                
                if mData.isTimed then
                    local remain = mData.expiresAt - time()
                    if remain > 0 then activeCards[i].reward:SetText(mData.rewardText .. string.format("\n|cffaaaaaaLeft: %02d:%02d|r", math.floor(remain / 60), remain % 60)) else activeCards[i].reward:SetText(mData.rewardText .. "\n|cffff0000FAILED|r") end
                else activeCards[i].reward:SetText(mData.rewardText) end
                
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
            if mData.isTimed then poolButtons[i].reward:SetText(mData.rewardText .. string.format("\n|cffff0000Limit: %dm|r", math.floor(mData.timeLimit / 60))) else poolButtons[i].reward:SetText(mData.rewardText) end
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
        if canEdit then DungeonCard.acceptBtn:Enable() else DungeonCard.acceptBtn:Disable() end
        
        local bR, bG, bB = DungeonCard:GetBackdropBorderColor()
        DungeonCard.StackBg1:SetBackdropBorderColor(bR, bG, bB, 1); DungeonCard.StackBg2:SetBackdropBorderColor(bR, bG, bB, 1)
        
        local function SetStackBg(bgFrame, offset)
            local idx = Ledger.CurrentDungeonIndex + offset
            while idx > #dList do idx = idx - #dList end
            local nextDung = dList[idx]
            if not bgFrame.bgImage then bgFrame.bgImage = bgFrame:CreateTexture(nil, "BORDER"); bgFrame.bgImage:SetPoint("TOPLEFT", 4, -4); bgFrame.bgImage:SetPoint("BOTTOMRIGHT", -4, 4); bgFrame.bgImage:SetTexCoord(0, 1, 0.25, 0.65) end
            if nextDung and nextDung.zone and ZoneLoadingScreens[nextDung.zone] then bgFrame.bgImage:SetTexture("Interface\\Glues\\LoadingScreens\\" .. ZoneLoadingScreens[nextDung.zone]); bgFrame.bgImage:SetVertexColor(0.2, 0.2, 0.2, 1); bgFrame.bgImage:Show() else bgFrame.bgImage:Hide() end
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

SLASH_DARKPATRON1 = "/patron"
SlashCmdList["DARKPATRON"] = function(msg)
    if msg == "dev" then devMode = not devMode; print(devMode and "Dark Patron: Dev Mode ENABLED." or "Dark Patron: Dev Mode DISABLED."); if Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end
    elseif msg == "test dungeon" then
        if DarkPatronDB.DungeonBounties and #DarkPatronDB.DungeonBounties > 0 then DarkPatronDB.DungeonBounties = nil; print("DEV: Dungeon Bounties cleared."); if Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end
        else local newStack = GenerateAllDungeonContracts(60) if #newStack > 0 then DarkPatronDB.DungeonBounties = newStack; ShowPatronToast("DEV: A full Elite Dungeon Pact stack was injected!"); print("DEV: Injected Dungeon Bounties."); if Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end end end
    elseif Ledger:IsShown() then Ledger:Hide() else Ledger:Show() end
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
    { title = "2. The Bounty Board", icon = "Interface\\Icons\\INV_Misc_Note_01", header = "Selecting Available Contracts", text = "The Sanctuary Bounty Board generates randomized contracts for you to choose from based on your level.\n\n|cffffd700=> Notice all 6 contract tiles flashing on your Bounty Board below!|r", action = function() if PatronsLedger then PatronsLedger:Show() end currentView = "board" if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end HighlightCards(poolButtons, {1, 2, 3, 4, 5, 6}) end },
    { title = "3. Active Pacts", icon = "Interface\\Icons\\Spell_Holy_BlessingOfStrength", header = "Dragging & Enabling Bounties", text = "To track and complete a bounty, click and drag a contract tile from the Bounty Board up into your |cffffffffActive Pacts|r slots.\n\n|cffffd700=> Notice the flashing Active Pact slots at the top!|r", action = function() if PatronsLedger then PatronsLedger:Show() end currentView = "board" if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end HighlightCards(activeCards, {1, 2, 3, 4}) end },
    { title = "4. Dark Favor Currency", icon = "Interface\\Icons\\INV_Misc_Coin_02", header = "Earning & Stacking Favor", text = "As you play and complete active contracts, you earn |cffffd700Dark Favor|r, which serves as your primary progression currency.\n\n|cffffd700=> Look at your flashing Dark Favor & Sigil tallies in the top-left!|r", action = function() if PatronsLedger then PatronsLedger:Show() end FlashCurrencies() end },
    { title = "5. The Patron's Bazaar", icon = "Interface\\Icons\\INV_Box_01", header = "Purchasing Sanctions", text = "Visit a resting Sanctuary (city or inn) and open the Bazaar tab to spend your accumulated Dark Favor on permanent unlocks.\n\n|cffffd700=> Notice the strobing 'Patron's Bazaar' tab button at the top right!|r", action = function() if PatronsLedger then PatronsLedger:Show() end currentView = "board" if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end FlashButtonStrobe(tabBazaarBtn) end },
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
        table.insert(DarkPatronDB.CompletedElites, mission.id)
    else
        DarkPatronDB.RecentlyCompleted = DarkPatronDB.RecentlyCompleted or {}
        table.insert(DarkPatronDB.RecentlyCompleted, 1, mission.trigger .. (mission.targetName or ""))
        if #DarkPatronDB.RecentlyCompleted > 6 then table.remove(DarkPatronDB.RecentlyCompleted) end
    end
end

RefillMissionPool = function(isRetry)
    DarkPatronDB.PoolOfSix = DarkPatronDB.PoolOfSix or {}
    local safetyBrake = 0
    while #DarkPatronDB.PoolOfSix < 6 and safetyBrake < 100 do
        safetyBrake = safetyBrake + 1
        local rareCount = 0
        for _, m in ipairs(DarkPatronDB.ActiveMissions) do if m.rarity == "Rare" then rareCount = rareCount + 1 end end
        for _, m in ipairs(DarkPatronDB.PoolOfSix) do if m.rarity == "Rare" then rareCount = rareCount + 1 end end
        
        local newContract = GenerateProceduralContract(rareCount == 0)
        local isDup = false
        for _, m in ipairs(DarkPatronDB.ActiveMissions) do if m.trigger == newContract.trigger and m.targetName == newContract.targetName then isDup = true break end end
        for _, m in ipairs(DarkPatronDB.PoolOfSix) do if m.trigger == newContract.trigger and m.targetName == newContract.targetName then isDup = true break end end
        
        DarkPatronDB.RecentlyCompleted = DarkPatronDB.RecentlyCompleted or {}
        for _, t in ipairs(DarkPatronDB.RecentlyCompleted) do if t == (newContract.trigger .. (newContract.targetName or "")) then isDup = true break end end
        
        if not isDup then table.insert(DarkPatronDB.PoolOfSix, newContract) end
    end
    
    local pLvl = UnitLevel("player") or 1
    local maxLvl = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC) and 70 or 60

    if (not DarkPatronDB.DungeonBounties or #DarkPatronDB.DungeonBounties == 0) and not isRetry and DarkPatronDB.HasSeenIntro then
        if pLvl == maxLvl and math.random(1, 100) <= 15 then
            if GenerateAllRaidContracts then
                local raidStack = GenerateAllRaidContracts(pLvl)
                if raidStack and #raidStack > 0 then
                    DarkPatronDB.DungeonBounties = raidStack
                    if ShowPatronToast then ShowPatronToast("A Legendary Raid Stack has appeared in the Ledger!") end
                end
            end
        elseif math.random(1, 100) <= 25 then
            if GenerateAllDungeonContracts then
                local newStack = GenerateAllDungeonContracts(pLvl)
                if newStack and #newStack > 0 then
                    DarkPatronDB.DungeonBounties = newStack
                    if ShowPatronToast then ShowPatronToast("A new Elite Dungeon Pact stack has appeared in the Ledger!") end
                end
            end
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
    local rewardString = ""; local currentTime = time()
    
    -- Safely initialize variables against older saves
    local currentStreak = DarkPatronDB.CurrentStreak or 0
    local lastPactTime = DarkPatronDB.LastPactTime or 0
    
    if currentStreak > 0 and lastPactTime > 0 then
        if (currentTime - lastPactTime) > 1200 then 
            currentStreak = 0
            PatronWhisper("Your momentum wanes. The streak has crumbled to dust.") 
        end
    end

    DarkPatronDB.CurrentStreak = currentStreak + 1
    DarkPatronDB.LastPactTime = currentTime
    
    local streakBonus = 0
    if DarkPatronDB.CurrentStreak > 0 and DarkPatronDB.CurrentStreak % 3 == 0 then 
        streakBonus = 2; PlaySound(565853); 
        PatronWhisper("Three pacts sealed in blood... Your precious Grimoire of Purity forbids the casting of shadow magic, but it cannot stop you from spending it.") 
    end

    if mission.isLegendary then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + 1; DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + 35 + streakBonus; rewardString = string.format("+1 Apex Sigil, +%d Dark Favor", 35 + streakBonus); if streakBonus > 0 then rewardString = rewardString .. " (Combo Bonus!)" end print(string.format("DARK PATRON: Legendary Bounty Fulfilled [%s]!", mission.title))
    elseif mission.rarity == "Rare Elite" or mission.rarity == "Boss" then DarkPatronDB.ApexSigils = DarkPatronDB.ApexSigils + 1; rewardString = "+1 Apex Sigil"; print(string.format("DARK PATRON: Legendary Bounty Fulfilled [%s]!", mission.title))
    elseif mission.rarity == "Elite" then DarkPatronDB.DarkSigils = DarkPatronDB.DarkSigils + 1; rewardString = "+1 Dark Sigil"; print(string.format("DARK PATRON: Elite Bounty Fulfilled [%s]!", mission.title))
    else local favorEarned = (mission.favor or 1) + streakBonus; DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor + favorEarned; rewardString = string.format("+%d Dark Favor", favorEarned); if streakBonus > 0 then rewardString = rewardString .. " (Combo Bonus!)" end print(string.format("DARK PATRON: Contract Fulfilled [%s]!", mission.title)) end
    
    PlayCinematicSplash(rewardString); DP_EvaluateBazaarAlert()

    DarkPatronDB.ContractTypesCompleted = DarkPatronDB.ContractTypesCompleted or {}
    DarkPatronDB.ContractTypesCompleted[mission.trigger] = (DarkPatronDB.ContractTypesCompleted[mission.trigger] or 0) + 1

    if (mission.rarity == "Elite" or mission.rarity == "Rare Elite" or mission.rarity == "Boss") then
        if not DarkPatronDB.FirstEliteKilled then DarkPatronDB.FirstEliteKilled = mission.targetName or "a nameless terror" end
    end
    
    RecordCompletedPact(mission); table.remove(DarkPatronDB.ActiveMissions, index); RefillMissionPool(); if Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end; UpdateTracker()
end

local lastQuestCount = 0

local function CheckCombatProgress(event, ...)
    if not DarkPatronDB or not DarkPatronDB.ActiveMissions then return end

    if event == "PLAYER_DEAD" then
        -- REVERSE LOOP FIX
        for i = #DarkPatronDB.ActiveMissions, 1, -1 do 
            local mission = DarkPatronDB.ActiveMissions[i]
            if mission.trigger == "FLAWLESS_KILL" then 
                mission.current = 0 
                UpdateTracker() 
            end 
        end
        if not DarkPatronDB.IsDead then
            DarkPatronDB.IsDead = true
            local pName = UnitName("player") or "The Wanderer"; local pLvl = UnitLevel("player") or 1; local zone = GetRealZoneText() or "an unforgiving land"; local subZone = GetSubZoneText(); local location = subZone ~= "" and (subZone .. ", " .. zone) or zone
            local epitaph = string.format("But the Veil is an unforgiving master, and all debts are eventually collected.\n\nHere, the Chronicle ends.\n\nAt level %d, %s drew their final breath in %s. The Patron's protection faltered, and the mortal coil was severed. Their remaining pacts are void, their hoarded Favor is scattered to the shadows, and their name becomes but a whisper in the Void.\n\nRequiescat in pace.", pLvl, pName, location)
            DarkPatronDB.DeathEpitaph = epitaph
        end
    end
    
    -- QUEST TRACKING FIX
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
 local mission = DarkPatronDB.ActiveMissions[i] if mission.trigger == "MAKGORA_WIN" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
        elseif msg:find("You have defeated .* in a duel") and not msg:find("to the death") then
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
 local mission = DarkPatronDB.ActiveMissions[i] if mission.trigger == "DUEL_WIN" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
        end
    end

    if event == "CHAT_MSG_MONEY" then
        local msg = ...; local copperEarned = 0
        local g = msg:match("(%d+) Gold") if g then copperEarned = copperEarned + (tonumber(g) * 10000) end
        local s = msg:match("(%d+) Silver") if s then copperEarned = copperEarned + (tonumber(s) * 100) end
        local c = msg:match("(%d+) Copper") if c then copperEarned = copperEarned + tonumber(c) end
        
        if copperEarned > 0 then
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
 local mission = DarkPatronDB.ActiveMissions[i] if mission.trigger == "MONEY_LOOT" then mission.current = mission.current + copperEarned; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
        end
    end

    if event == "CHAT_MSG_LOOT" then
        local msg = ...
        for i = #DarkPatronDB.ActiveMissions, 1, -1 do
 local mission = DarkPatronDB.ActiveMissions[i]
            if mission.trigger == "LOOT_JUNK" and msg:match("|cff9d9d9d.-|r") then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
            elseif mission.trigger == "LOOT_ANY" and (msg:find("You receive loot") or msg:find("You create")) then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
            elseif mission.trigger == "FETCH_ITEM" and mission.targetName then if msg:find(mission.targetName) then local qty = msg:match("x(%d+)%."); mission.current = mission.current + (qty and tonumber(qty) or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
        end
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceFlags2, destGUID, destName, destFlags, destFlags2 = CombatLogGetCurrentEventInfo()
        local amount = 0; local spellSchool = 0; local missType = nil; local spellName = ""

        if subEvent == "SWING_DAMAGE" then amount = select(12, CombatLogGetCurrentEventInfo())
        elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then spellSchool = select(14, CombatLogGetCurrentEventInfo()); amount = select(15, CombatLogGetCurrentEventInfo())
        elseif subEvent == "SWING_MISSED" or subEvent == "RANGE_MISSED" or subEvent == "SPELL_MISSED" then missType = select(12, CombatLogGetCurrentEventInfo())
        elseif subEvent == "SPELL_AURA_APPLIED" then spellName = select(13, CombatLogGetCurrentEventInfo())
        elseif subEvent == "ENVIRONMENTAL_DAMAGE" then local envType, envAmount = select(12, CombatLogGetCurrentEventInfo()); if envType and type(envType) == "string" and string.upper(envType) == "FALLING" then amount = tonumber(envAmount) or 0 end end
        
        if sourceGUID == UnitGUID("player") then
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
 local mission = DarkPatronDB.ActiveMissions[i]
                if mission.trigger == "INTERRUPT_SPELL" and subEvent == "SPELL_INTERRUPT" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "GATHER_NODE" and subEvent == "SPELL_CAST_SUCCESS" then local sName = select(13, CombatLogGetCurrentEventInfo()); if sName == "Mining" or sName == "Herb Gathering" or sName == "Skinning" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "SPELL_CAST_SUCCESS" and subEvent == "SPELL_CAST_SUCCESS" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "AURA_APPLIED" and subEvent == "SPELL_AURA_APPLIED" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "CONSUME_FOOD" and subEvent == "SPELL_AURA_APPLIED" then if spellName == "Food" or spellName == "Drink" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "SWING_DAMAGE" and subEvent == "SWING_DAMAGE" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "UNARMED_DAMAGE" and subEvent == "SWING_DAMAGE" then local mainHandLink = GetInventoryItemLink("player", 16); if not mainHandLink then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "NAKED_COMBAT" and subEvent == "SWING_DAMAGE" then local chestLink = GetInventoryItemLink("player", 5); if not chestLink then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "ANY_DAMAGE" and (subEvent == "SWING_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE") then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "PHYSICAL_DAMAGE" then if subEvent == "SWING_DAMAGE" or (spellSchool == 1 and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE")) then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "SPELL_DAMAGE" and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE") then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "HOLY_FIRE_DAMAGE" and (subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE") then if spellSchool == 2 or spellSchool == 4 or spellSchool == 6 or spellSchool == 36 then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end end
                if mission.trigger == "CRIT_STRIKE" and subEvent:find("DAMAGE") then
                    local isCrit = false
                    if subEvent == "SWING_DAMAGE" then 
                        isCrit = select(18, CombatLogGetCurrentEventInfo())
                    else 
                        isCrit = select(21, CombatLogGetCurrentEventInfo())
                    end
                    if isCrit then 
                        mission.current = mission.current + 1
                        if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end 
                    end
                end

                if subEvent == "PARTY_KILL" then
                    if mission.trigger == "PARTY_KILL" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    elseif mission.trigger == "DUNGEON_CLEAR" then if GetRealZoneText() == mission.targetName then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                    elseif mission.trigger == "HONORABLE_KILL" then local isPlayer = bit.band(destFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) > 0; if isPlayer then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                    elseif mission.trigger == "RISKY_KILL" then local hpMax = UnitHealthMax("player"); if hpMax and hpMax > 0 and (UnitHealth("player") / hpMax) <= 0.33 then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                    elseif mission.trigger == "SPECIFIC_KILL" and destName == mission.targetName then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                end
            end
        end

        if destGUID == UnitGUID("player") then
            for i = #DarkPatronDB.ActiveMissions, 1, -1 do
 local mission = DarkPatronDB.ActiveMissions[i]
                if mission.trigger == "FALLING_DAMAGE" and subEvent == "ENVIRONMENTAL_DAMAGE" and amount > 0 then mission.current = mission.current + amount; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "DAMAGE_TAKEN" and subEvent:find("DAMAGE") then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if mission.trigger == "HEALING_RECEIVED" and (subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL") then mission.current = mission.current + (amount or 1); if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                if (subEvent == "SWING_MISSED" or subEvent == "RANGE_MISSED" or subEvent == "SPELL_MISSED") then
                    if mission.trigger == "DEFENSE_ROLL" and (missType == "PARRY" or missType == "DODGE" or missType == "BLOCK") then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end
                    elseif mission.trigger == "DODGE_ATTACK" and missType == "DODGE" then mission.current = mission.current + 1; if mission.current >= mission.goal then FulfillMission(i, mission) else UpdateTracker() end end
                end
            end
        end
    end
end

-- =====================================================================
-- 8. EVENT REGISTRATION & RESTRICTION HANDLERS
-- =====================================================================
DP:SetScript("OnEvent", function(self, event, ...)
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
            
            if not DarkPatronDB.PoolOfSix or #DarkPatronDB.PoolOfSix == 0 then RefillMissionPool() end
            UpdateTracker()
            
            C_Timer.NewTicker(1, function()
                if DarkPatronDB then
                    if not DarkPatronDB.LastBoardRefresh or DarkPatronDB.LastBoardRefresh == 0 then DarkPatronDB.LastBoardRefresh = time() end
                    
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
                                print(string.format("|cffff0000[Dark Patron]: The timer has expired for '%s'! (-1 Favor). You must discard the failed pact to free your slot.|r", m.title))
                                DarkPatronDB.DarkFavor = DarkPatronDB.DarkFavor - 1
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
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then CheckViolations()
    elseif event == "PLAYER_REGEN_ENABLED" then if isViolating then CheckViolations() end
    elseif event == "PLAYER_UPDATE_RESTING" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then if Ledger and Ledger:IsShown() then Ledger:GetScript("OnShow")(Ledger) end
	elseif event == "COMPANION_UPDATE" then
        if IsMounted() and DarkPatronDB and not DarkPatronDB.HasJourneymanCavalry then
            Dismount()
            print("|cffff0000[Dark Patron]: The Veil forbids riding without a Journeyman's Cavalry Sanction! You are forcefully dismounted.|r")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_MONEY" or event == "QUEST_TURNED_IN" or event == "QUEST_LOG_UPDATE" or event == "CHAT_MSG_SYSTEM" then
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