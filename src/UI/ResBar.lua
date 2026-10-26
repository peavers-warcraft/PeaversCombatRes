local _, PCR = ...

--------------------------------------------------------------------------------
-- ResBar — the one bar, its icon and the roster line under it
--
--   [icon] [ Battle Res  1 ··········· 4:00 ]
--          Druid  Death Knight  Warlock
--
-- The bar fills as the next charge comes back and is coloured by how many are
-- left. Every draw is diffed against the last, so a tick that changes nothing
-- touches no widget, which is what keeps this inside the Ultra Performance
-- budget while a pool is up.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons
local AnimatedStatusBar = PeaversCommons.AnimatedStatusBar
local BarTextManager = PeaversCommons.BarTextManager

local ResBar = {}
PCR.ResBar = ResBar

local ROSTER_GAP = 2
local ICON_GAP = 2

local LABEL = "Battle Res"

local function FormatTime(seconds)
    seconds = math.ceil(seconds)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function RosterHeight(config)
    return (config.fontSize or 9) + 6
end

--------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------

function ResBar:Destroy()
    if self.statusBar then self.statusBar:Destroy() end
    if self.textManager then self.textManager:Destroy() end
    if self.row then self.row:Hide() end
    if self.icon then self.icon:Hide() end
    if self.roster then self.roster:Hide() end
    self.statusBar, self.textManager, self.row, self.icon, self.roster = nil, nil, nil, nil, nil
end

function ResBar:Build(contentFrame)
    self:Destroy()
    self.last = {}

    local config = PCR.Config
    local height = config.barHeight

    local row = CreateFrame("Frame", nil, contentFrame)
    row:SetHeight(height)
    row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, 0)
    self.row = row

    local barLeft = 0
    if config.showIcon then
        local icon = CreateFrame("Frame", nil, row)
        icon:SetSize(height, height)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)

        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints()
        icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints()
        icon.cooldown:SetDrawEdge(false)
        icon.cooldown:SetHideCountdownNumbers(not config.showIconCountdown)

        icon.count = icon:CreateFontString(nil, "OVERLAY")
        icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 1)
        BarTextManager.SafeSetFont(icon.count, config.fontFace, config.fontSize + 1, "OUTLINE")

        self.icon = icon
        barLeft = height + ICON_GAP
    end

    local statusBar = AnimatedStatusBar:New(row, {
        texture = config.barTexture,
        bgAlpha = config.barBgAlpha,
        barAlpha = config.barAlpha,
        color = config.colorReady,
        minValue = 0,
        maxValue = 1,
        showBackground = true,
    })
    statusBar:SetPoint("TOPLEFT", row, "TOPLEFT", barLeft, 0)
    statusBar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    -- A recharge moves a sliver a second; gliding each one is wasted work.
    statusBar:SetSmoothing(false)
    self.statusBar = statusBar

    if config.showLabel or config.showTimer then
        self.textManager = BarTextManager:New(statusBar:GetStatusBar(), {
            showName = config.showLabel,
            showValue = config.showTimer,
            fontFace = config.fontFace,
            fontSize = config.fontSize,
            fontOutline = config.fontOutline,
            fontShadow = config.fontShadow,
            textAlpha = config.textAlpha,
            name = LABEL,
        })
    end

    if config.showRoster then
        local roster = contentFrame:CreateFontString(nil, "OVERLAY")
        roster:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 2, -ROSTER_GAP)
        roster:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", -2, -ROSTER_GAP)
        roster:SetHeight(RosterHeight(config))
        roster:SetJustifyH("LEFT")
        roster:SetWordWrap(false)
        BarTextManager.SafeSetFont(roster, config.fontFace, config.fontSize,
            config.fontOutline and "OUTLINE" or "")
        roster:SetAlpha(config.textAlpha or 1)
        self.roster = roster
    end
end

function ResBar:GetHeight()
    local config = PCR.Config
    local height = config.barHeight
    if config.showRoster then
        height = height + ROSTER_GAP + RosterHeight(config)
    end
    return height
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------

-- True, and remembered, when value differs from the last one drawn under key.
function ResBar:Changed(key, value)
    if self.last[key] == value then return false end
    self.last[key] = value
    return true
end

function ResBar:ColourFor(charges)
    local config = PCR.Config
    if charges <= 0 then return config.colorEmpty end
    if charges == 1 then return config.colorLast end
    return config.colorReady
end

function ResBar:IconSpell()
    local choice = PCR.Config.iconSpell
    if choice == "DYNAMIC" or not tonumber(choice) then
        return PCR.Roster:SharedSpell() or PCR.Spells.DEFAULT
    end
    return tonumber(choice)
end

-- The numbers came back secret. Only widgets that take a secret are touched:
-- text, and the cooldown swipe through a duration object. No colour, no fill,
-- no countdown, because each of those needs arithmetic on the value.
function ResBar:DrawSecret(pool)
    -- Forget what the readable path drew, so it redraws in full if the numbers
    -- ever come back plain.
    self.last.charges, self.last.progress, self.last.timer = nil, nil, nil
    self.last.cdStart, self.last.cdDuration = nil, nil
    local info = pool.info
    if self.textManager and self.textManager.nameElement then
        self.textManager.nameElement:SetFormattedText("%s  %s", LABEL, info.currentCharges)
    end
    if self.textManager then self.textManager:SetValue("") end
    self.statusBar:SetValue(1, true)
    if self.icon then
        self.icon.count:SetText(info.currentCharges)
        local duration = C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(PCR.Spells.POOL)
        if duration then
            self.icon.cooldown:SetCooldownFromDurationObject(duration)
        end
    end
end

function ResBar:Draw(pool, now)
    if not self.statusBar then return end

    if pool.secret then
        self:DrawSecret(pool)
    else
        local charges = pool.charges

        if self:Changed("charges", charges) then
            local c = self:ColourFor(charges)
            self.statusBar:SetColor(c.r, c.g, c.b, PCR.Config.barAlpha or 1)
            if self.textManager then
                self.textManager:SetName(("%s  %d"):format(LABEL, charges))
            end
            if self.icon then
                self.icon.count:SetText(charges)
                self.icon.texture:SetDesaturated(charges <= 0)
            end
        end

        -- Whole percent steps: finer than a pixel on any bar this size.
        local progress = math.floor(pool:Progress(now) * 100 + 0.5) / 100
        if self:Changed("progress", progress) then
            self.statusBar:SetValue(progress, true)
        end

        if self.textManager then
            local timer = pool.recharging and FormatTime(pool:Remaining(now)) or ""
            if self:Changed("timer", timer) then
                self.textManager:SetValue(timer)
            end
        end

        if self.icon then
            local start = pool.recharging and pool.start or 0
            local startChanged = self:Changed("cdStart", start)
            local durationChanged = self:Changed("cdDuration", pool.duration)
            if startChanged or durationChanged then
                if pool.recharging then
                    self.icon.cooldown:SetCooldown(pool.start, pool.duration)
                else
                    self.icon.cooldown:Clear()
                end
            end
        end
    end

    if self.icon then
        local spellID = self:IconSpell()
        if self:Changed("iconSpell", spellID) then
            self.icon.texture:SetTexture(PCR.Spells:Icon(spellID))
        end
    end

    if self.roster then
        local text = PCR.Roster:Text()
        if self:Changed("roster", text) then
            self.roster:SetText(text)
        end
    end
end

return ResBar
