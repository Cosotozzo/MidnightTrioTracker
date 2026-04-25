local MTT = LibStub("AceAddon-3.0"):GetAddon("MidnightTrioTracker")
local StatsMod = MTT:NewModule("Stats", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MidnightTrioTracker")

-- FIX CRITICO 1: Silenzia la libreria AceLocale per i tool di Debug di WoW
rawset(L, "ToDebugString", false)

-- Localizzazione API Globali per Massime Performance
local UnitStat = UnitStat
local UnitAffectingCombat = UnitAffectingCombat
local GetCombatRating = GetCombatRating
local GetCritChance = GetCritChance
local GetMasteryEffect = GetMasteryEffect
local UnitSpellHaste = UnitSpellHaste
local GetCombatRatingBonus = GetCombatRatingBonus
local GetVersatilityBonus = GetVersatilityBonus
local GetLifesteal = GetLifesteal
local GetSpeed = GetSpeed
local GetAvoidance = GetAvoidance
local GetUnitSpeed = GetUnitSpeed
local IsSwimming = IsSwimming
local IsFlying = IsFlying
local string_format = string.format
local math_max = math.max
local tostring = tostring
local type = type
local ipairs = ipairs
local pairs = pairs

-- Setup Costanti Combat Rating
local CR = Enum.CombatRating or {}
local R_CRIT = CR.CritMelee or 9
local R_MASTERY = CR.Mastery or 26
local R_HASTE = CR.HasteMelee or 18
local R_VERS = CR.VersatilityDamageDone or 29
local R_LEECH = CR.Lifesteal or 17
local R_AVOID = CR.Avoidance or 21
local R_SPEED = CR.Speed or 14

local statsFrame
local fontStringsPool = {}

local THROTTLE_TIME = 0.15
local updatePending = false

local currentColors = {}
local currentIcons = {}

-- ==========================================
-- FIX CRITICO 2: SISTEMA CACHE "ANTI SECRET-NUMBER"
-- Bypass completo per le restrizioni API di Midnight in Combat
-- ==========================================
local statCache = {}
local function GetSafeNumber(val, key)
    if type(val) == "number" then
        statCache[key] = val
        return val
    end
    return statCache[key] or 0
end
-- ==========================================

local function UpdateColorCache()
    local dbColors = MTT.db.profile.modules.stats.colors
    for statKey, colorData in pairs(dbColors) do
        currentColors[statKey] = string_format("|cFF%02x%02x%02x", colorData.r * 255, colorData.g * 255, colorData.b * 255)
    end
end

local function UpdateIconCache()
    local dbIcons = MTT.db.profile.modules.stats.icons
    for statKey, iconID in pairs(dbIcons) do
        currentIcons[statKey] = string_format("|T%s:14:14:0:-1:64:64:4:60:4:60|t", tostring(iconID))
    end
end

local function FormatCoreStat(icon, name, color, absVal)
    local db = MTT.db.profile.modules.stats
    local iconStr = db.showIcons and (icon .. " ") or ""
    return string_format("%s%s%s: |r%d", iconStr, color, name, absVal or 0)
end

local function FormatSecondaryStat(icon, name, color, absVal, pctVal)
    local db = MTT.db.profile.modules.stats
    local formatPref = db.format or "BOTH"
    local iconStr = db.showIcons and (icon .. " ") or ""
    local baseText = string_format("%s%s%s: |r", iconStr, color, name)
    
    if formatPref == "ABS" then 
        return baseText .. string_format("%d", absVal or 0)
    elseif formatPref == "PCT" then 
        return baseText .. string_format("%.2f%%", pctVal or 0)
    else 
        return baseText .. string_format("%d (%.2f%%)", absVal or 0, pctVal or 0)
    end
end

local function ApplyStyle()
    if not statsFrame then return end
    local db = MTT.db.profile.modules.stats
    
    if db.showBorders then
        statsFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, 
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    else
        statsFrame:SetBackdrop({ 
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
            edgeFile = nil, 
            insets = { left=0, right=0, top=0, bottom=0 } 
        })
    end
    statsFrame:SetBackdropColor(0, 0, 0, db.opacity or 0.8)
    statsFrame:SetScale(db.scale or 1.0)
    
    statsFrame:ClearAllPoints()
    statsFrame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.posX or 0, db.posY or 0)
end

local function UpdateDynamicEvents(self)
    local db = MTT.db.profile.modules.stats
    if db.showSpeed then
        self:RegisterEvent("PLAYER_STARTED_MOVING", "TriggerUpdate")
        self:RegisterEvent("PLAYER_STOPPED_MOVING", "TriggerUpdate")
    else
        self:UnregisterEvent("PLAYER_STARTED_MOVING")
        self:UnregisterEvent("PLAYER_STOPPED_MOVING")
    end
end

local function UpdateStats()
    local db = MTT.db.profile.modules.stats
    if not db.enabled then 
        statsFrame:Hide()
        return 
    end

    local inCombat = UnitAffectingCombat("player")
    if (db.visibility == "COMBAT" and not inCombat) or (db.visibility == "OOC" and inCombat) then 
        statsFrame:Hide()
        return 
    else 
        statsFrame:Show() 
    end

    local activeStats = {}
    
    -- Statistiche Primarie Protette da Secret Number
    local str = GetSafeNumber(UnitStat("player", 1), "str")
    local agi = GetSafeNumber(UnitStat("player", 2), "agi")
    local int = GetSafeNumber(UnitStat("player", 4), "int")
    
    local maxStat = math_max(str, agi, int)
    
    if maxStat == str then activeStats[#activeStats + 1] = FormatCoreStat(currentIcons.Str, L["Stat_Strength"] or "Str", currentColors.Str, str)
    elseif maxStat == agi then activeStats[#activeStats + 1] = FormatCoreStat(currentIcons.Agi, L["Stat_Agility"] or "Agi", currentColors.Agi, agi)
    else activeStats[#activeStats + 1] = FormatCoreStat(currentIcons.Int, L["Stat_Intellect"] or "Int", currentColors.Int, int) end
    
    -- Statistiche Secondarie Protette da Secret Number
    if db.showCrit then 
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Crit, L["Stat_Crit"] or "Crit", currentColors.Crit, GetSafeNumber(GetCombatRating(R_CRIT), "cr_crit"), GetSafeNumber(GetCritChance(), "pct_crit")) 
    end
    if db.showMastery then 
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Mastery, L["Stat_Mastery"] or "Mastery", currentColors.Mastery, GetSafeNumber(GetCombatRating(R_MASTERY), "cr_mast"), GetSafeNumber(GetMasteryEffect(), "pct_mast")) 
    end
    if db.showHaste then 
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Haste, L["Stat_Haste"] or "Haste", currentColors.Haste, GetSafeNumber(GetCombatRating(R_HASTE), "cr_haste"), GetSafeNumber(UnitSpellHaste("player"), "pct_haste")) 
    end
    
    if db.showVers then 
        local versFlat = (GetVersatilityBonus and type(GetVersatilityBonus) == "function") and GetVersatilityBonus(R_VERS) or 0
        local totalVersPct = GetSafeNumber(GetCombatRatingBonus(R_VERS), "pct_vers_base") + GetSafeNumber(versFlat, "pct_vers_flat")
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Vers, L["Stat_Versatility"] or "Vers", currentColors.Vers, GetSafeNumber(GetCombatRating(R_VERS), "cr_vers"), totalVersPct) 
    end
    
    -- Statistiche Terziarie Protette da Secret Number
    if db.showLeech then 
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Leech, L["Stat_Leech"] or "Leech", currentColors.Leech, GetSafeNumber(GetCombatRating(R_LEECH), "cr_leech"), GetSafeNumber(GetLifesteal(), "pct_leech")) 
    end
    if db.showAvoidance then 
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Avoidance, L["Stat_Avoidance"] or "Avoidance", currentColors.Avoidance, GetSafeNumber(GetCombatRating(R_AVOID), "cr_avoid"), GetSafeNumber(GetAvoidance(), "pct_avoid")) 
    end
    
    if db.showSpeed then 
        local speedPct = 0
        local currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")
        
        if type(currentSpeed) == "number" and type(runSpeed) == "number" then
            local displaySpeed = runSpeed
            if IsSwimming() and type(swimSpeed) == "number" then 
                displaySpeed = swimSpeed
            elseif IsFlying() and type(flightSpeed) == "number" then 
                displaySpeed = flightSpeed 
            end
            displaySpeed = math_max(displaySpeed, currentSpeed)
            speedPct = (displaySpeed / 7.0) * 100 
            statCache["pct_speed"] = speedPct
        else
            speedPct = statCache["pct_speed"] or GetSafeNumber(GetSpeed(), "fallback_speed")
        end
        
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Speed, L["Stat_Speed"] or "Speed", currentColors.Speed, GetSafeNumber(GetCombatRating(R_SPEED), "cr_speed"), speedPct) 
    end

    local isVertical = (db.layout == "VERTICAL")
    local fontSize = db.fontSize or 12
    local maxWidth = 0
    local totalHeight = 0 
    local needsResize = false

    for i = #activeStats + 1, #fontStringsPool do
        fontStringsPool[i]:Hide()
    end

    for i, statText in ipairs(activeStats) do
        local fs = fontStringsPool[i]
        if not fs then
            fs = statsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fontStringsPool[i] = fs
            needsResize = true
        end
        
        fs:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        
        if fs:GetText() ~= statText then
            fs:SetText(statText)
            needsResize = true 
        end
        
        fs:ClearAllPoints()
        
        if i == 1 then 
            fs:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 10, -10)
        else
            if isVertical then 
                fs:SetPoint("TOPLEFT", fontStringsPool[i-1], "BOTTOMLEFT", 0, -5)
            else 
                fs:SetPoint("LEFT", fontStringsPool[i-1], "RIGHT", 15, 0) 
            end
        end
        fs:Show()
        
        if needsResize then
            local strWidth = fs:GetStringWidth()
            local strHeight = fs:GetStringHeight()
            if isVertical then
                maxWidth = math_max(maxWidth, strWidth)
                totalHeight = totalHeight + strHeight + (i > 1 and 5 or 0)
            else
                maxWidth = maxWidth + strWidth + (i > 1 and 15 or 0)
                totalHeight = math_max(totalHeight, strHeight)
            end
        end
    end
    
    if needsResize and #activeStats > 0 then
        statsFrame:SetSize(maxWidth + 20, totalHeight + 20)
    end
end

function StatsMod:TriggerUpdate()
    if not statsFrame or not statsFrame:IsShown() then 
        UpdateStats()
    else
        if updatePending then return end 
        updatePending = true
        C_Timer.After(THROTTLE_TIME, function()
            UpdateStats()
            updatePending = false
        end)
    end
end

local function CreateStatsFrame()
    statsFrame = CreateFrame("Frame", "MTT_StatsFrame", UIParent, "BackdropTemplate")
    
    statsFrame:SetMovable(true)
    statsFrame:EnableMouse(true)
    statsFrame:RegisterForDrag("LeftButton")
    statsFrame:SetScript("OnDragStart", function(self) 
        if not MTT.db.profile.modules.stats.locked then self:StartMoving() end 
    end)
    statsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        
        local db = MTT.db.profile.modules.stats
        db.point, db.relativePoint = "TOPLEFT", "BOTTOMLEFT"
        db.posX, db.posY = left, top
        
        self:ClearAllPoints()
        self:SetPoint(db.point, UIParent, db.relativePoint, left, top)
        
        LibStub("AceConfigRegistry-3.0"):NotifyChange("MidnightTrioTracker_Options")
    end)
    
    ApplyStyle()
end

function StatsMod:OnConfigChanged()
    UpdateColorCache()
    UpdateIconCache()
    UpdateDynamicEvents(self)
    ApplyStyle()
    UpdateStats()
end

function StatsMod:OnEnable()
    UpdateColorCache()
    UpdateIconCache() 
    if not statsFrame then CreateStatsFrame() end
    
    self:RegisterEvent("UNIT_STATS", function(e, unit) if unit == "player" then self:TriggerUpdate() end end)
    self:RegisterEvent("UNIT_AURA", function(e, unit) if unit == "player" then self:TriggerUpdate() end end)
    
    self:RegisterEvent("PLAYER_CONTROL_GAINED", "TriggerUpdate")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "TriggerUpdate")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "TriggerUpdate")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "TriggerUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "TriggerUpdate")
    
    UpdateDynamicEvents(self)
    self:RegisterMessage("MTT_CONFIG_UPDATED", "OnConfigChanged")
    
    UpdateStats()
end

function StatsMod:OnDisable()
    if statsFrame then statsFrame:Hide() end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end

SLASH_MTTSTATSDEBUG1 = "/mttdebug"
SlashCmdList["MTTSTATSDEBUG"] = function()
    local colorHeader = "|cFF00FFFF[MTT Debug]|r"
    local ok = "|cFF00FF00[OK]|r"
    local err = "|cFFFF0000[ERRORE]|r"
    
    print(colorHeader .. " Stato Modulo Statistiche (Midnight 12.0.1):")
    print("  - Modulo Abilitato:", MTT.db.profile.modules.stats.enabled and ok or err)
    print("  - Frame UI Visibile:", (statsFrame and statsFrame:IsShown()) and ok or "|cFFFFFF00[NASCOSTO]|r")
    print("  - Throttle (C_Timer):", updatePending and "|cFFFFFF00[In Attesa]|r" or ok)
    
    local isTainted, taintReason = issecurevariable(_G, "MTT_StatsFrame")
    if isTainted then
        print("  - Sicurezza Frame:", err .. " Tainted da: " .. tostring(taintReason))
    else
        print("  - Sicurezza Frame:", ok .. " Nessun Taint rilevato.")
    end
end