local MTT = LibStub("AceAddon-3.0"):GetAddon("MidnightTrioTracker")
local StatsMod = MTT:NewModule("Stats", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MidnightTrioTracker")

-- FIX CRITICO 1: Silenzia la libreria AceLocale per i tool di Debug di WoW
rawset(L, "ToDebugString", false)

-- Localizzazione API Globali per Massime Performance e Sicurezza (Pulite dalle ridondanze)
local UnitAffectingCombat = UnitAffectingCombat
local InCombatLockdown = InCombatLockdown
local C_PlayerInfo = C_PlayerInfo
local GetCombatRating = GetCombatRating
local GetCritChance = GetCritChance
local GetMasteryEffect = GetMasteryEffect
local UnitSpellHaste = UnitSpellHaste
local GetCombatRatingBonus = GetCombatRatingBonus
local GetVersatilityBonus = GetVersatilityBonus
local GetLifesteal = GetLifesteal
local GetAvoidance = GetAvoidance
local GetSpeed = GetSpeed
local GetUnitSpeed = GetUnitSpeed
local IsSwimming = IsSwimming
local IsFlying = IsFlying
local UnitStat = UnitStat
local select = select
local string_format = string.format
local math_max = math.max
local tostring = tostring
local type = type
local ipairs = ipairs
local pairs = pairs
local pcall = pcall

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
-- FIX CRITICO 2: GESTIONE SICURA STATISTICHE (MIDNIGHT 12.0.5)
-- Bypass completo per le restrizioni API di Midnight in Combat
-- ==========================================
---@type table<string, number>
local statCache = {}

--- Esegue il fetch della statistica solo se fuori combattimento per evitare i Secret Numbers
---@param key string Identificativo in cache
---@param fetchFunc function Callback di lettura dal namespace C_ o API globale consentita
---@return number Valore numerico pulito
local function GetSafeStat(key, fetchFunc)
    if not InCombatLockdown() then
        local val = fetchFunc()
        -- [12.0.5] Midnight Secret Number Bypass: type() ritorna "number", forziamo math evaluation via pcall
        -- per testare se è un vero numero o un Secret Number protetto
        local isSafe, safeVal = pcall(function() return val + 0 end)
        if isSafe and type(safeVal) == "number" then
            statCache[key] = safeVal
        end
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

--- Formatta le statistiche primarie secondo le preferenze del DB
---@param icon string L'icona escape text
---@param name string Nome localizzato
---@param color string Hex color code escape
---@param absVal number Valore assoluto
---@return string
local function FormatCoreStat(icon, name, color, absVal)
    local db = MTT.db.profile.modules.stats
    local iconStr = db.showIcons and (icon .. " ") or ""
    return string_format("%s%s%s: |r%d", iconStr, color, name, absVal or 0)
end

--- Formatta le statistiche secondarie in base al layout
---@param icon string L'icona escape text
---@param name string Nome localizzato
---@param color string Hex color code escape
---@param absVal number Valore del Combat Rating
---@param pctVal number Percentuale calcolata
---@return string
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
    
    -- Statistiche Primarie (Midnight 12.0.5 API Strict C_Namespace)
    local str = GetSafeStat("str", function() return (C_PlayerInfo and C_PlayerInfo.GetStat and C_PlayerInfo.GetStat(1)) or select(2, UnitStat("player", 1)) or 0 end)
    local agi = GetSafeStat("agi", function() return (C_PlayerInfo and C_PlayerInfo.GetStat and C_PlayerInfo.GetStat(2)) or select(2, UnitStat("player", 2)) or 0 end)
    local int = GetSafeStat("int", function() return (C_PlayerInfo and C_PlayerInfo.GetStat and C_PlayerInfo.GetStat(4)) or select(2, UnitStat("player", 4)) or 0 end)
    
    local maxStat = math_max(str, agi, int)
    
    if maxStat == str then activeStats[#activeStats + 1] = FormatCoreStat(currentIcons.Str, L["Stat_Strength"] or "Str", currentColors.Str, str)
    elseif maxStat == agi then activeStats[#activeStats + 1] = FormatCoreStat(currentIcons.Agi, L["Stat_Agility"] or "Agi", currentColors.Agi, agi)
    else activeStats[#activeStats + 1] = FormatCoreStat(currentIcons.Int, L["Stat_Intellect"] or "Int", currentColors.Int, int) end
    
    -- Statistiche Secondarie
    if db.showCrit then 
        local cr_crit = GetSafeStat("cr_crit", function() return type(GetCombatRating) == "function" and GetCombatRating(R_CRIT) or 0 end)
        local pct_crit = GetSafeStat("pct_crit", function() return type(GetCritChance) == "function" and GetCritChance() or 0 end)
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Crit, L["Stat_Crit"] or "Crit", currentColors.Crit, cr_crit, pct_crit) 
    end
    
    if db.showMastery then 
        local cr_mast = GetSafeStat("cr_mast", function() return type(GetCombatRating) == "function" and GetCombatRating(R_MASTERY) or 0 end)
        local pct_mast = GetSafeStat("pct_mast", function() return type(GetMasteryEffect) == "function" and GetMasteryEffect() or 0 end)
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Mastery, L["Stat_Mastery"] or "Mastery", currentColors.Mastery, cr_mast, pct_mast) 
    end
    
    if db.showHaste then 
        local cr_haste = GetSafeStat("cr_haste", function() return type(GetCombatRating) == "function" and GetCombatRating(R_HASTE) or 0 end)
        local pct_haste = GetSafeStat("pct_haste", function() 
            if type(UnitSpellHaste) == "function" then return UnitSpellHaste("player") end
            if C_PaperDollInfo and type(C_PaperDollInfo.GetSpellHaste) == "function" then return C_PaperDollInfo.GetSpellHaste() end
            return 0 
        end)
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Haste, L["Stat_Haste"] or "Haste", currentColors.Haste, cr_haste, pct_haste) 
    end
    
    if db.showVers then 
        local cr_vers = GetSafeStat("cr_vers", function() return (type(GetCombatRating) == "function") and GetCombatRating(R_VERS) or 0 end)
        local pct_vers = GetSafeStat("pct_vers", function() 
            local rawVersFlat = (type(GetVersatilityBonus) == "function") and GetVersatilityBonus(R_VERS) or 0
            local rawVersBase = 0
            
            if type(GetCombatRatingBonus) == "function" then
                rawVersBase = GetCombatRatingBonus(R_VERS)
            elseif C_PlayerInfo and type(C_PlayerInfo.GetVersatility) == "function" then
                rawVersBase = C_PlayerInfo.GetVersatility()
            end
            
            -- FIX CRITICO 12.0.5: Disinnesco del Secret Number tramite Type Safety
            local versBase = (type(rawVersBase) == "number") and rawVersBase or 0
            local versFlat = (type(rawVersFlat) == "number") and rawVersFlat or 0
            
            return versBase + versFlat
        end)
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Vers, L["Stat_Versatility"] or "Vers", currentColors.Vers, cr_vers, pct_vers) 
    end
    
    -- Statistiche Terziarie
    if db.showLeech then 
        local cr_leech = GetSafeStat("cr_leech", function() return type(GetCombatRating) == "function" and GetCombatRating(R_LEECH) or 0 end)
        local pct_leech = GetSafeStat("pct_leech", function() return type(GetLifesteal) == "function" and GetLifesteal() or 0 end)
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Leech, L["Stat_Leech"] or "Leech", currentColors.Leech, cr_leech, pct_leech) 
    end
    
    if db.showAvoidance then 
        local cr_avoid = GetSafeStat("cr_avoid", function() return type(GetCombatRating) == "function" and GetCombatRating(R_AVOID) or 0 end)
        local pct_avoid = GetSafeStat("pct_avoid", function() return type(GetAvoidance) == "function" and GetAvoidance() or 0 end)
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Avoidance, L["Stat_Avoidance"] or "Avoidance", currentColors.Avoidance, cr_avoid, pct_avoid) 
    end
    
    if db.showSpeed then 
        local speedPct = 0
        local currentSpeed, runSpeed, flightSpeed, swimSpeed = 0, 0, 0, 0
        
        if type(GetUnitSpeed) == "function" then 
            currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player") 
        end
        
        if type(currentSpeed) == "number" and type(runSpeed) == "number" then
            local displaySpeed = runSpeed
            if type(IsSwimming) == "function" and IsSwimming() and type(swimSpeed) == "number" then 
                displaySpeed = swimSpeed
            elseif type(IsFlying) == "function" and IsFlying() and type(flightSpeed) == "number" then 
                displaySpeed = flightSpeed 
            end
            displaySpeed = math_max(displaySpeed, currentSpeed)
            speedPct = (displaySpeed / 7.0) * 100 
            statCache["pct_speed"] = speedPct
        else
            speedPct = statCache["pct_speed"] or GetSafeStat("fallback_speed", function() return type(GetSpeed) == "function" and GetSpeed() or 0 end)
        end
        
        local cr_speed = GetSafeStat("cr_speed", function() return type(GetCombatRating) == "function" and GetCombatRating(R_SPEED) or 0 end)
        activeStats[#activeStats + 1] = FormatSecondaryStat(currentIcons.Speed, L["Stat_Speed"] or "Speed", currentColors.Speed, cr_speed, speedPct) 
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

--- Mixin Architecture per evitare Global Leakage ed errori Taint (12.0.5)
---@class StatsFrameMixin : Frame
local StatsFrameMixin = {}

function StatsFrameMixin:OnDragStart()
    if not MTT.db.profile.modules.stats.locked then self:StartMoving() end 
end

function StatsFrameMixin:OnDragStop()
    self:StopMovingOrSizing()
    local left, top = self:GetLeft(), self:GetTop()
    
    local db = MTT.db.profile.modules.stats
    db.point, db.relativePoint = "TOPLEFT", "BOTTOMLEFT"
    db.posX, db.posY = left, top
    
    self:ClearAllPoints()
    self:SetPoint(db.point, UIParent, db.relativePoint, left, top)
    
    LibStub("AceConfigRegistry-3.0"):NotifyChange("MidnightTrioTracker_Options")
end

local function CreateStatsFrame()
    -- Creazione anonima con incapsulamento Mixin
    statsFrame = Mixin(CreateFrame("Frame", nil, UIParent, "BackdropTemplate"), StatsFrameMixin)
    
    statsFrame:SetMovable(true)
    statsFrame:EnableMouse(true)
    statsFrame:RegisterForDrag("LeftButton")
    statsFrame:SetScript("OnDragStart", statsFrame.OnDragStart)
    statsFrame:SetScript("OnDragStop", statsFrame.OnDragStop)
    
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

-- ==========================================
-- Agent Eight (12.0.5): Implementazione sicura del Debug Mixin.
-- ==========================================
---@class AgentEightDebugMixin
local AgentEight = {}

--- Metodo di ispezione del frame protetto e del pool variabili
function AgentEight:Debug()
    local colorHeader = "|cFF00FFFF[Agent Eight Debug 12.0.5]|r"
    local combatState = InCombatLockdown() and "|cFFFF0000[IN COMBAT]|r" or "|cFF00FF00[OOC]|r"
    
    print(colorHeader .. " Stato Sicurezza Midnight:")
    print("  - Combat Lockdown:", combatState)
    print("  - Forza in Cache (SafeVal):", statCache["str"] or "N/A")
    print("  - Agilità in Cache (SafeVal):", statCache["agi"] or "N/A")
    print("  - Critico in Cache (SafeVal):", statCache["pct_crit"] or "N/A")
    
    if statsFrame then
        local isTainted, taintReason = issecurevariable(statsFrame, "SetPoint")
        if isTainted then
            print("  - Integrità Frame: |cFFFF0000[TAINTED]|r (Causato da: " .. tostring(taintReason) .. ")")
        else
            print("  - Integrità Frame: |cFF00FF00[SECURE]|r")
        end
    else
        print("  - Integrità Frame: Non ancora inizializzato")
    end
end

-- Registrazione sicura nel namespace globale per i comandi di slash
_G.SLASH_MTTAGENTEIGHTDEBUG1 = "/8debug"
_G.SlashCmdList["MTTAGENTEIGHTDEBUG"] = function()
    AgentEight:Debug()
end