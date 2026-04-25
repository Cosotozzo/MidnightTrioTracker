local MTT = LibStub("AceAddon-3.0"):GetAddon("MidnightTrioTracker")
local L = LibStub("AceLocale-3.0"):GetLocale("MidnightTrioTracker")

local function GetOption(info)
    return MTT.db.profile.modules[info[#info-1]][info[#info]]
end

local function SetOption(info, value)
    MTT.db.profile.modules[info[#info-1]][info[#info]] = value
    MTT:SendMessage("MTT_CONFIG_UPDATED")
end

local function GetColorOption(info)
    local key = info[#info]
    local c = MTT.db.profile.modules.stats.colors[key]
    return c.r, c.g, c.b, 1.0
end

local function SetColorOption(info, r, g, b, a)
    local key = info[#info]
    local c = MTT.db.profile.modules.stats.colors[key]
    c.r, c.g, c.b = r, g, b
    MTT:SendMessage("MTT_CONFIG_UPDATED")
end

local function GetIconOption(info)
    local key = info[#info]
    return tostring(MTT.db.profile.modules.stats.icons[key] or "")
end

local function SetIconOption(info, value)
    local key = info[#info]
    MTT.db.profile.modules.stats.icons[key] = value
    MTT:SendMessage("MTT_CONFIG_UPDATED")
end

local options = {
    name = "Midnight Stats Tracker",
    handler = MTT,
    type = "group",
    args = {
        stats = {
            name = L["Tab_Stats"] or "Statistiche",
            type = "group",
            order = 1,
            get = GetOption,
            set = SetOption,
            args = {
                header_general = { type = "header", name = L["General_Settings"] or "Impostazioni Generali", order = 1 },
                enabled = { type = "toggle", name = L["Enable_Module"] or "Abilita Modulo", order = 2 },
                locked = { type = "toggle", name = L["Lock_Unlock"] or "Blocca Finestra", order = 3 },
                visibility = {
                    type = "select", name = L["Visibility"] or "Visibilità", order = 4,
                    values = { ALWAYS = L["Show_Always"] or "Sempre", COMBAT = L["Show_Combat"] or "In Combattimento", OOC = L["Show_OOC"] or "Fuori Combattimento" }
                },
                opacity = {
                    type = "range", name = L["Opacity"] or "Opacità Sfondo", order = 5,
                    min = 0, max = 1, step = 0.05, isPercent = true
                },
                showBorders = { type = "toggle", name = L["Show_Borders"] or "Mostra Bordi", order = 6 },
                
                header_stats = { type = "header", name = L["Stats_To_Show"] or "Statistiche da Mostrare", order = 7 },
                showCrit = { type = "toggle", name = L["Stat_Crit"] or "Critico", order = 8 },
                showMastery = { type = "toggle", name = L["Stat_Mastery"] or "Maestria", order = 9 },
                showHaste = { type = "toggle", name = L["Stat_Haste"] or "Celerità", order = 10 },
                showVers = { type = "toggle", name = L["Stat_Versatility"] or "Versatilità", order = 11 },
                showLeech = { type = "toggle", name = L["Stat_Leech"] or "Sanguisuga", order = 12 },
                showAvoidance = { type = "toggle", name = L["Stat_Avoidance"] or "Elusione", order = 13 },
                showSpeed = { type = "toggle", name = L["Stat_Speed"] or "Velocità", order = 14 },
                showIcons = { type = "toggle", name = L["Show_Icons"] or "Mostra Icone", order = 15 },
                
                header_layout_format = { type = "header", name = L["Layout_Format"] or "Formato Layout", order = 16 },
                format = {
                    type = "select", name = L["Value_Format"] or "Formato Valori", order = 17,
                    values = { ABS = L["Format_Abs"] or "Assoluto", PCT = L["Format_Pct"] or "Percentuale", BOTH = L["Format_Both"] or "Entrambi" }
                },
                layout = {
                    type = "select", name = L["Layout_Direction"] or "Direzione Layout", order = 18,
                    values = { VERTICAL = L["Layout_Vertical"] or "Verticale", HORIZONTAL = L["Layout_Horizontal"] or "Orizzontale" }
                },

                header_pos = { type = "header", name = L["Layout_Position"] or "Layout & Posizione", order = 19 },
                scale = {
                    type = "range", name = L["Module_Scale"] or "Scala Modulo", order = 20,
                    min = 0.5, max = 2.0, step = 0.05, isPercent = true
                },
                fontSize = {
                    type = "range", name = L["Font_Size"] or "Dimensione Font", order = 21,
                    min = 8, max = 32, step = 1
                },
                posX = {
                    type = "range", name = L["Position_X"] or "Posizione X", order = 22,
                    min = -2500, max = 2500, step = 1
                },
                posY = {
                    type = "range", name = L["Position_Y"] or "Posizione Y", order = 23,
                    min = -2500, max = 2500, step = 1
                },
                
                header_colors = { type = "header", name = L["Stat_Colors"] or "Colori Statistiche", order = 24 },
                colorsConfig = {
                    name = L["Stat_Colors"] or "Personalizza Colori",
                    type = "group",
                    inline = true,
                    order = 25,
                    get = GetColorOption,
                    set = SetColorOption,
                    args = {
                        Str = { type = "color", name = L["Stat_Strength"] or "Forza", order = 1 },
                        Agi = { type = "color", name = L["Stat_Agility"] or "Agilità", order = 2 },
                        Int = { type = "color", name = L["Stat_Intellect"] or "Intelletto", order = 3 },
                        Crit = { type = "color", name = L["Stat_Crit"] or "Critico", order = 4 },
                        Mastery = { type = "color", name = L["Stat_Mastery"] or "Maestria", order = 5 },
                        Haste = { type = "color", name = L["Stat_Haste"] or "Celerità", order = 6 },
                        Vers = { type = "color", name = L["Stat_Versatility"] or "Versatilità", order = 7 },
                        Leech = { type = "color", name = L["Stat_Leech"] or "Sanguisuga", order = 8 },
                        Avoidance = { type = "color", name = L["Stat_Avoidance"] or "Elusione", order = 9 },
                        Speed = { type = "color", name = L["Stat_Speed"] or "Velocità", order = 10 },
                    }
                },

                header_icons = { type = "header", name = L["Stat_Icons"] or "Icone Statistiche (FileID)", order = 26 },
                iconsConfig = {
                    name = L["Stat_Icons_Desc"] or "Inserisci il FileID dell'icona",
                    type = "group",
                    inline = true,
                    order = 27,
                    get = GetIconOption,
                    set = SetIconOption,
                    args = {
                        Str = { type = "input", name = L["Stat_Strength"] or "Forza", order = 1 },
                        Agi = { type = "input", name = L["Stat_Agility"] or "Agilità", order = 2 },
                        Int = { type = "input", name = L["Stat_Intellect"] or "Intelletto", order = 3 },
                        Crit = { type = "input", name = L["Stat_Crit"] or "Critico", order = 4 },
                        Mastery = { type = "input", name = L["Stat_Mastery"] or "Maestria", order = 5 },
                        Haste = { type = "input", name = L["Stat_Haste"] or "Celerità", order = 6 },
                        Vers = { type = "input", name = L["Stat_Versatility"] or "Versatilità", order = 7 },
                        Leech = { type = "input", name = L["Stat_Leech"] or "Sanguisuga", order = 8 },
                        Avoidance = { type = "input", name = L["Stat_Avoidance"] or "Elusione", order = 9 },
                        Speed = { type = "input", name = L["Stat_Speed"] or "Velocità", order = 10 },
                    }
                }
            }
        },
        info = {
            name = L["Tab_Info"] or "Info (Oro/Durabilità)",
            type = "group",
            order = 2,
            get = GetOption,
            set = SetOption,
            args = {
                header_general = { type = "header", name = L["General_Settings"] or "Impostazioni Generali", order = 1 },
                enabled = { type = "toggle", name = L["Enable_Module"] or "Abilita Modulo", order = 2 },
                locked = { type = "toggle", name = L["Lock_Unlock"] or "Blocca Finestra", order = 3 },
                opacity = {
                    type = "range", name = L["Opacity"] or "Opacità Sfondo", order = 4,
                    min = 0, max = 1, step = 0.05, isPercent = true
                },
                showBorders = { type = "toggle", name = L["Show_Borders"] or "Mostra Bordi", order = 5 },
                showIcons = { type = "toggle", name = L["Show_Icons"] or "Mostra Icone Denaro", order = 6 },
                
                header_elements = { type = "header", name = L["Elements_To_Show"] or "Elementi da Mostrare", order = 7 },
                showDurability = { type = "toggle", name = L["Show_Durability"] or "Durabilità", order = 8 },
                showGold = { type = "toggle", name = L["Show_Gold"] or "Oro", order = 9 },
                showDate = { type = "toggle", name = L["Show_Date"] or "Data", order = 10 },
                showTime = { type = "toggle", name = L["Show_Time"] or "Ora", order = 11 },
                showFPS = { type = "toggle", name = L["Show_FPS"] or "FPS", order = 12 },
                showLatency = { type = "toggle", name = L["Show_Latency"] or "Latenza (Ping)", order = 13 },

                header_pos = { type = "header", name = L["Layout_Position"] or "Layout & Posizione", order = 14 },
                scale = {
                    type = "range", name = L["Module_Scale"] or "Scala Modulo", order = 15,
                    min = 0.5, max = 2.0, step = 0.05, isPercent = true
                },
                fontSize = {
                    type = "range", name = L["Font_Size"] or "Dimensione Font", order = 16,
                    min = 8, max = 32, step = 1
                }
            }
        }
    }
}

function MTT:SetupOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("MidnightTrioTracker_Options", options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("MidnightTrioTracker_Options", "Midnight Stats Tracker")
end

hooksecurefunc(MTT, "OnInitialize", function(self)
    self:SetupOptions()
end)