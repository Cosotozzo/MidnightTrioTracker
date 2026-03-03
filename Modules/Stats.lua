local MTT = LibStub("AceAddon-3.0"):GetAddon("MidnightTrioTracker")
local StatsMod = MTT:NewModule("Stats", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MidnightTrioTracker")

local UnitStat = UnitStat
local UnitAffectingCombat = UnitAffectingCombat
local GetCombatRating = GetCombatRating
local GetCritChance = GetCritChance
local GetMasteryEffect = GetMasteryEffect
local UnitSpellHaste = UnitSpellHaste
local GetCombatRatingBonus = GetCombatRatingBonus
local GetLifesteal = GetLifesteal
local GetSpeed = GetSpeed
local GetAvoidance = GetAvoidance
local GetUnitSpeed = GetUnitSpeed
local IsSwimming = IsSwimming
local IsFlying = IsFlying
local string_format = string.format
local math_max = math.max

local CR = Enum.CombatRating or {}
local R_CRIT = CR.CritMelee or CR_CRIT_MELEE or 9
local R_MASTERY = CR.Mastery or CR_MASTERY or 26
local R_HASTE = CR.HasteMelee or CR_HASTE_MELEE or 18
local R_VERS = CR.VersatilityDamageDone or CR_VERSATILITY_DAMAGE_DONE or 29
local R_LEECH = CR.Lifesteal or CR_LIFESTEAL or 17
local R_AVOID = CR.Avoidance or CR_AVOIDANCE or 21
local R_SPEED = CR.Speed or CR_SPEED or 14

local statsFrame
local fontStringsPool = {}

local THROTTLE_TIME = 0.15
local updateTimer = 0
local updatePending = false

local currentColors = {}
local currentIcons = {}

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
    return string_format("%s%s%s: |r%d", iconStr, color, name, absVal)
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
    local point = db.point or "CENTER"
    local relPoint = db.relativePoint or "CENTER"
    statsFrame:SetPoint(point, UIParent, relPoint, db.posX or 0, db.posY or 0)
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
    
    local str, agi, int = UnitStat("player", 1), UnitStat("player", 2), UnitStat("player", 4)
    local maxStat = math_max(str, agi, int)
    
    if maxStat == str then table.insert(activeStats, FormatCoreStat(currentIcons.Str, L["Stat_Strength"] or "Str", currentColors.Str, str))
    elseif maxStat == agi then table.insert(activeStats, FormatCoreStat(currentIcons.Agi, L["Stat_Agility"] or "Agi", currentColors.Agi, agi))
    else table.insert(activeStats, FormatCoreStat(currentIcons.Int, L["Stat_Intellect"] or "Int", currentColors.Int, int)) end
    
    if db.showCrit then table.insert(activeStats, FormatSecondaryStat(currentIcons.Crit, L["Stat_Crit"] or "Crit", currentColors.Crit, GetCombatRating(R_CRIT), GetCritChance())) end
    if db.showMastery then table.insert(activeStats, FormatSecondaryStat(currentIcons.Mastery, L["Stat_Mastery"] or "Mastery", currentColors.Mastery, GetCombatRating(R_MASTERY), GetMasteryEffect())) end
    if db.showHaste then table.insert(activeStats, FormatSecondaryStat(currentIcons.Haste, L["Stat_Haste"] or "Haste", currentColors.Haste, GetCombatRating(R_HASTE), UnitSpellHaste("player"))) end
    if db.showVers then table.insert(activeStats, FormatSecondaryStat(currentIcons.Vers, L["Stat_Versatility"] or "Vers", currentColors.Vers, GetCombatRating(R_VERS), GetCombatRatingBonus(R_VERS))) end
    
    if db.showLeech then table.insert(activeStats, FormatSecondaryStat(currentIcons.Leech, L["Stat_Leech"] or "Leech", currentColors.Leech, GetCombatRating(R_LEECH), GetLifesteal())) end
    if db.showAvoidance then table.insert(activeStats, FormatSecondaryStat(currentIcons.Avoidance, L["Stat_Avoidance"] or "Avoidance", currentColors.Avoidance, GetCombatRating(R_AVOID), GetAvoidance())) end
    
    if db.showSpeed then 
        local currentSpeed, runSpeed, flightSpeed, swimSpeed = GetUnitSpeed("player")
        local displaySpeed = runSpeed
        if IsSwimming() then displaySpeed = swimSpeed
        elseif IsFlying() then displaySpeed = flightSpeed end
        displaySpeed = math_max(displaySpeed, currentSpeed)
        
        local speedPct = (displaySpeed / 7.0) * 100 
        table.insert(activeStats, FormatSecondaryStat(currentIcons.Speed, L["Stat_Speed"] or "Speed", currentColors.Speed, GetCombatRating(R_SPEED), speedPct)) 
    end

    local isVertical = (db.layout == "VERTICAL")
    local fontSize = db.fontSize or 12
    local maxWidth = 0
    local totalHeight = 0 
    local needsResize = false

    for _, fs in ipairs(fontStringsPool) do fs:Hide() end

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
        local paddingX = 20
        local paddingY = 20
        statsFrame:SetSize(maxWidth + paddingX, totalHeight + paddingY)
    end
end

function StatsMod:TriggerUpdate()
    -- Se il frame è nascosto, il suo OnUpdate è congelato.
    -- Forziamo un UpdateStats() immediato per rivalutare la visibilità (Show/Hide)
    if statsFrame and not statsFrame:IsShown() then
        UpdateStats()
    else
        updatePending = true
    end
end

local function CreateStatsFrame()
    statsFrame = CreateFrame("Frame", "MTT_StatsFrame", UIParent, "BackdropTemplate")
    
    statsFrame:SetScript("OnUpdate", function(self, elapsed)
        if updatePending then
            updateTimer = updateTimer + elapsed
            if updateTimer >= THROTTLE_TIME then
                UpdateStats()
                updatePending = false
                updateTimer = 0
            end
        end
    end)
    
    statsFrame:SetMovable(true)
    statsFrame:EnableMouse(true)
    statsFrame:RegisterForDrag("LeftButton")
    statsFrame:SetScript("OnDragStart", function(self) 
        if not MTT.db.profile.modules.stats.locked then self:StartMoving() end 
    end)
    statsFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        
        -- ANCORAGGIO TOPLEFT PER PREVENIRE WIGGLE
        local left = self:GetLeft()
        local top = self:GetTop()
        
        MTT.db.profile.modules.stats.point = "TOPLEFT"
        MTT.db.profile.modules.stats.relativePoint = "BOTTOMLEFT"
        MTT.db.profile.modules.stats.posX = left
        MTT.db.profile.modules.stats.posY = top
        
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        
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
    
    UpdateDynamicEvents(self)
    
    self:RegisterMessage("MTT_CONFIG_UPDATED", "OnConfigChanged")
    
    UpdateStats()
end

function StatsMod:OnDisable()
    if statsFrame then statsFrame:Hide() end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end