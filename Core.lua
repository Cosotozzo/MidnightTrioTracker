local MTT = LibStub("AceAddon-3.0"):NewAddon("MidnightTrioTracker", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MidnightTrioTracker")

local defaults = {
    profile = {
        modules = {
            stats = { 
                enabled = true, visibility = "ALWAYS", locked = false, 
                opacity = 0.8, scale = 1.0, fontSize = 12, 
                -- FIX: Modificato il punto di ancoraggio base da CENTER a TOPLEFT per prevenire il "wiggle"
                posX = -50, posY = 0, point = "TOPLEFT", relativePoint = "CENTER",
                showBorders = true, format = "BOTH", layout = "VERTICAL", showIcons = true,
                showCrit = true, showMastery = true, showHaste = true,
                showVers = true, showLeech = false, showAvoidance = false, showSpeed = false,
                colors = {
                    Str = {r=1, g=0.2, b=0.2}, Agi = {r=0.2, g=1, b=0.2}, Int = {r=0.2, g=0.8, b=1},
                    Crit = {r=1, g=1, b=0.2}, Mastery = {r=1, g=0.6, b=0.2}, Haste = {r=0.6, g=1, b=0.2},
                    Vers = {r=0.8, g=0.8, b=0.8}, Leech = {r=1, g=0.4, b=0.8}, Speed = {r=0.2, g=1, b=1},
                    Avoidance = {r=1, g=1, b=0.6}
                },
                icons = {
                    Str = "136076", Agi = "132302", Int = "135932",
                    Crit = "132089", Mastery = "135879", Haste = "136012",
                    Vers = "135969", Leech = "136168", Speed = "136093",
                    Avoidance = "136121"
                }
            },
            info = { 
                enabled = true, locked = false, opacity = 0.8, scale = 1.0, fontSize = 12,
                -- FIX: Ancoraggio coerente per il modulo Info
                posX = -50, posY = -100, point = "TOPLEFT", relativePoint = "CENTER",
                showBorders = true, showIcons = true,
                showDurability = true, showGold = true, showDate = true, showTime = true,
                showFPS = true, showLatency = true
            }
        }
    }
}

---@return void
function MTT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MidnightTrioTrackerDB", defaults, true)
    
    -- Routing sicuro Ace3 per il comando /mtt
    self:RegisterChatCommand("mtt", "HandleSlashCmd")
    
    -- Inizializzazione protocollo Agent Eight
    self:RegisterChatCommand("8debug", "DebugSuite") 
    
    self:Print(L["Chat_Loaded"] or "Midnight Trio Tracker Caricato. Digita /mtt per le opzioni.")
end

--- Handler principale per l'instradamento dei comandi Slash
---@param msg string Argomenti testuali passati al comando /mtt
---@return void
function MTT:HandleSlashCmd(msg)
    local input = msg and strtrim(msg:lower()) or ""
    
    if input == "git" then
        print("|cff00ff00[MTT]|r Repository collegato: |cffffff00https://github.com/cosotozzo/midnighttriotracker|r")
    else
        -- Apre l'interfaccia se non viene fornito un argomento o se l'argomento non è riconosciuto
        LibStub("AceConfigDialog-3.0"):Open("MidnightTrioTracker_Options")
    end
end

--- Agent Eight: Monitoraggio stato in tempo reale
---@return void
function MTT:DebugSuite()
    print("|cff00ffff[Agent Eight Debug]|r Analisi ambiente 12.0.5 per:", C_AddOns.GetAddOnMetadata("MidnightTrioTracker", "Title"))
    print(" - Componente DB Inizializzato:", self.db ~= nil and "|cff00ff00OK|r" or "|cffff0000FAIL|r")
    if self.db then
        print(" - Modulo Stats abilitato:", self.db.profile.modules.stats.enabled and "Sì" or "No")
        print(" - Opacità Corrente:", self.db.profile.modules.stats.opacity)
    end
end