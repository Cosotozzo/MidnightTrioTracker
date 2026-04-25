local MTT = LibStub("AceAddon-3.0"):GetAddon("MidnightTrioTracker")
local InfoMod = MTT:NewModule("Info", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("MidnightTrioTracker")

local infoFrame
local ticker
local buttons = {} 
local separators = {}

local function GetDurabilityColor(percent)
    if percent > 80 then return "|cFF33FF33"
    elseif percent > 30 then return "|cFFFFFF33"
    else return "|cFFFF3333" end
end

local function GetFPSColor(fps)
    if fps >= 60 then return "|cFF33FF33"
    elseif fps >= 30 then return "|cFFFFFF33"
    else return "|cFFFF3333" end
end

local function GetLatencyColor(latency)
    if latency < 60 then return "|cFF33FF33"
    elseif latency < 150 then return "|cFFFFFF33"
    else return "|cFFFF3333" end
end

local function GetAverageDurability()
    local totalCurrent, totalMax = 0, 0
    for i = 1, 18 do
        local current, max = GetInventoryItemDurability(i)
        if current and max and max > 0 then
            totalCurrent = totalCurrent + current
            totalMax = totalMax + max
        end
    end
    if totalMax == 0 then return 100 end
    return (totalCurrent / totalMax) * 100
end

local function FormatThousands(number)
    local _, _, minus, int, fraction = tostring(number):find('^([^%d]*%d)(%d*)(.-)$')
    return minus .. int:reverse():gsub("(%d%d%d)", "%1."):reverse() .. fraction
end

local function GetFormattedMoney(money, showIcons)
    local gold = math.floor(money / 10000)
    local goldStr = FormatThousands(gold)
    
    if showIcons then
        return string.format("%s|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t", goldStr)
    else
        return string.format("%sg", goldStr)
    end
end

local function StartDrag()
    if not MTT.db.profile.modules.info.locked then
        infoFrame.isMoving = true
        infoFrame:StartMoving()
    end
end

local function StopDrag()
    infoFrame:StopMovingOrSizing()
    infoFrame.isMoving = false
    
    -- ANCORAGGIO TOPLEFT PER PREVENIRE WIGGLE
    local left = infoFrame:GetLeft()
    local top = infoFrame:GetTop()
    
    MTT.db.profile.modules.info.point = "TOPLEFT"
    MTT.db.profile.modules.info.relativePoint = "BOTTOMLEFT"
    MTT.db.profile.modules.info.posX = left
    MTT.db.profile.modules.info.posY = top
    
    infoFrame:ClearAllPoints()
    infoFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    
    LibStub("AceConfigRegistry-3.0"):NotifyChange("MidnightTrioTracker_Options")
end

local function CreateInfoButton(key, onClick, tooltipTitle, tooltipText)
    local btn = CreateFrame("Button", nil, infoFrame)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("CENTER")
    
    if onClick then
        btn:SetScript("OnClick", function()
            if infoFrame.isMoving then return end
            onClick()
        end)
    end
    
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", StartDrag)
    btn:SetScript("OnDragStop", StopDrag)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltipTitle or "Info", 1, 0.82, 0)
        if tooltipText then GameTooltip:AddLine(tooltipText, 1, 1, 1) end
        if not MTT.db.profile.modules.info.locked then
            GameTooltip:AddLine(L["Tooltip_Drag"] or "Trascina per spostare l'intera barra", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    buttons[key] = btn
end

local function ApplyStyle()
    if not infoFrame then return end
    local db = MTT.db.profile.modules.info
    
    if db.showBorders then
        infoFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    else
        infoFrame:SetBackdrop({ 
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
            edgeFile = nil, 
            insets = { left=0, right=0, top=0, bottom=0 } 
        })
    end
    infoFrame:SetBackdropColor(0, 0, 0, db.opacity or 0.8)
    infoFrame:SetScale(db.scale or 1.0)
    
    infoFrame:ClearAllPoints()
    infoFrame:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER", db.posX or 0, db.posY or 0)
end

local function UpdateLayout()
    local db = MTT.db.profile.modules.info
    if not db.enabled then
        infoFrame:Hide()
        return
    else
        infoFrame:Show()
    end

    for _, sep in ipairs(separators) do sep:Hide() end

    local activeElements = {}
    local fontSize = db.fontSize or 12

    if db.showDurability then
        buttons.durability.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        table.insert(activeElements, buttons.durability)
    else buttons.durability:Hide() end

    if db.showGold then
        buttons.gold.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        table.insert(activeElements, buttons.gold)
    else buttons.gold:Hide() end

    if db.showDate then
        buttons.date.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        table.insert(activeElements, buttons.date)
    else buttons.date:Hide() end

    if db.showTime then
        buttons.time.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        table.insert(activeElements, buttons.time)
    else buttons.time:Hide() end

    if db.showFPS then
        buttons.fps.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        table.insert(activeElements, buttons.fps)
    else buttons.fps:Hide() end

    if db.showLatency then
        buttons.ping.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
        table.insert(activeElements, buttons.ping)
    else buttons.ping:Hide() end

    local totalWidth = 15
    local prevObj = nil
    local sepCount = 0

    for i, btn in ipairs(activeElements) do
        btn:SetWidth(btn.text:GetStringWidth() + 20) 
        btn:SetHeight(fontSize + 8)
        btn:ClearAllPoints()
        
        if i == 1 then
            btn:SetPoint("LEFT", infoFrame, "LEFT", totalWidth, 0)
        else
            sepCount = sepCount + 1
            local sep = separators[sepCount]
            if not sep then
                sep = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                table.insert(separators, sep)
            end
            
            sep:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
            sep:SetText("|")
            sep:ClearAllPoints()
            sep:SetPoint("LEFT", prevObj, "RIGHT", 8, 0)
            sep:Show()
            
            totalWidth = totalWidth + 8 + sep:GetStringWidth() + 8
            btn:SetPoint("LEFT", sep, "RIGHT", 8, 0)
        end
        
        btn:Show()
        totalWidth = totalWidth + btn:GetWidth()
        prevObj = btn
    end
    
    totalWidth = totalWidth + 15
    if totalWidth == 30 then totalWidth = 100 end 
    
    infoFrame:SetWidth(totalWidth)
    infoFrame:SetHeight(math.max(30, fontSize + 16))
end

local function UpdateGold()
    if not infoFrame then return end
    if MTT.db.profile.modules.info.showGold then
        buttons.gold.text:SetText(GetFormattedMoney(GetMoney(), MTT.db.profile.modules.info.showIcons))
    end
end

local function UpdateDurability()
    if not infoFrame then return end
    if MTT.db.profile.modules.info.showDurability then
        local p = GetAverageDurability()
        buttons.durability.text:SetText(string.format("Durability: %s%d%%|r", GetDurabilityColor(p), p))
    end
end

local lastMin, lastDate, lastFPS, lastPingHome, lastPingWorld = -1, "", -1, -1, -1

local function UpdateDynamicInfoData()
    if not infoFrame then return end
    local db = MTT.db.profile.modules.info

    if db.showDate then
        local curDate = date("%d/%m/%Y")
        if curDate ~= lastDate then
            buttons.date.text:SetText(curDate)
            lastDate = curDate
        end
    end

    if db.showTime then
        local curMin = tonumber(date("%M"))
        if curMin ~= lastMin then
            buttons.time.text:SetText(date("%H:%M"))
            lastMin = curMin
        end
    end

    if db.showFPS then
        local fps = math.floor(GetFramerate())
        if fps ~= lastFPS then
            buttons.fps.text:SetText(string.format("FPS: %s%d|r", GetFPSColor(fps), fps))
            lastFPS = fps
        end
    end

    if db.showLatency then
        local _, _, latencyHome, latencyWorld = GetNetStats()
        if latencyHome ~= lastPingHome or latencyWorld ~= lastPingWorld then
            buttons.ping.text:SetText(string.format("Ping: %s%d|r/%s%d|r ms", GetLatencyColor(latencyHome), latencyHome, GetLatencyColor(latencyWorld), latencyWorld))
            lastPingHome = latencyHome
            lastPingWorld = latencyWorld
        end
    end
end

function InfoMod:OnConfigChanged()
    ApplyStyle()
    
    lastMin, lastDate, lastFPS, lastPingHome, lastPingWorld = -1, "", -1, -1, -1 
    UpdateGold()
    UpdateDurability()
    UpdateDynamicInfoData()
    UpdateLayout()
end

function InfoMod:OnEnable()
    if not infoFrame then
        infoFrame = CreateFrame("Frame", "MTT_InfoFrame", UIParent, "BackdropTemplate")
        infoFrame:SetMovable(true)
        infoFrame:EnableMouse(true)
        infoFrame:RegisterForDrag("LeftButton")
        infoFrame:SetScript("OnDragStart", StartDrag)
        infoFrame:SetScript("OnDragStop", StopDrag)
        
        CreateInfoButton("durability", function() ToggleCharacter("PaperDollFrame") end, L["Show_Durability"] or "Durabilità", L["Tooltip_CharPanel"] or "Clicca per aprire il Pannello Personaggio")
        CreateInfoButton("gold", function() ToggleAllBags() end, L["Show_Gold"] or "Oro", L["Tooltip_Bags"] or "Clicca per aprire le Borse")
        CreateInfoButton("date", function() ToggleCalendar() end, L["Show_Date"] or "Data", L["Tooltip_Calendar"] or "Clicca per aprire il Calendario")
        CreateInfoButton("time", function() ToggleCalendar() end, L["Show_Time"] or "Ora", L["Tooltip_Calendar"] or "Clicca per aprire il Calendario")
        CreateInfoButton("fps", nil, L["Show_FPS"] or "FPS", L["Tooltip_FPS"] or "Fotogrammi per secondo")
        CreateInfoButton("ping", nil, L["Show_Latency"] or "Latenza (Ping)", L["Tooltip_Ping"] or "Ping (Locale / Mondiale)")
    end
    
    self:RegisterMessage("MTT_CONFIG_UPDATED", "OnConfigChanged")
    
    self:RegisterEvent("PLAYER_MONEY", function() UpdateGold() end)
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", function() UpdateDurability() end)
    
    ApplyStyle()
    
    UpdateGold()
    UpdateDurability()
    UpdateDynamicInfoData()
    UpdateLayout()
    
    if not ticker then
        ticker = C_Timer.NewTicker(1.0, UpdateDynamicInfoData)
    end
end

function InfoMod:OnDisable()
    if infoFrame then infoFrame:Hide() end
    if ticker then ticker:Cancel(); ticker = nil end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end