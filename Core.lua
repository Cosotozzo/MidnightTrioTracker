local MTT = LibStub("AceAddon-3.0"):NewAddon("MidnightTrioTracker", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MidnightTrioTracker")

local defaults = {
    profile = {
        modules = {
            stats = { 
                enabled = true, visibility = "ALWAYS", locked = false, 
                opacity = 0.8, scale = 1.0, fontSize = 12, 
                -- POSIZIONE INIZIALE MODIFICATA
                posX = 0, posY = 0, point = "CENTER", relativePoint = "CENTER",
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
                -- POSIZIONE INIZIALE MODIFICATA
                posX = 0, posY = 0, point = "CENTER", relativePoint = "CENTER",
                showBorders = true, showIcons = true,
                showDurability = true, showGold = true, showDate = true, showTime = true,
                showFPS = true, showLatency = true
            }
        }
    }
}

function MTT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MidnightTrioTrackerDB", defaults, true)
    self:RegisterChatCommand("mtt", "OpenConfig")
    self:Print(L["Chat_Loaded"] or "Midnight Stats Tracker Caricato. Digita /mtt per le opzioni.")
end

function MTT:OpenConfig()
    LibStub("AceConfigDialog-3.0"):Open("MidnightTrioTracker_Options")
end