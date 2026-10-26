local _, PCR = ...

--------------------------------------------------------------------------------
-- Core — the frame, when it shows, and what keeps it current
--
-- The bar is shown only while a pool exists (a raid encounter or a keystone)
-- and the visibility settings allow it, or while it is being previewed or
-- placed in Edit Mode.
--
-- Nothing runs per frame. Events say when the pool may have changed, and a one
-- second ticker runs only while the bar is on screen, for the countdown and
-- for the roster line noticing a death. Hidden, it costs nothing at all.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons

local Core = {}
PCR.Core = Core

local TICK = 1

-- Anything that can start, end or change the pool. SPELL_UPDATE_CHARGES fires
-- for every charge spell the player has, so it is cheap to handle by design:
-- one read, and widgets only if something moved.
local POOL_EVENTS = {
    "SPELL_UPDATE_CHARGES",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
}

-- The pool is not always there the instant a fight or a key begins.
local START_EVENTS = {
    ENCOUNTER_START = true,
    CHALLENGE_MODE_START = true,
    PLAYER_ENTERING_WORLD = true,
}

--------------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------------

function Core:Initialize()
    local config = PCR.Config

    self.frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    self.frame:SetSize(config.frameWidth, 40)

    self.titleBar = PeaversCommons.TitleBar:Create(self.frame, config, {
        title = "PCR",
        version = PCR.version or "1.0.0",
        leftPadding = 5,
    })

    self.contentFrame = CreateFrame("Frame", nil, self.frame)

    self:UpdateFrameBackground()
    self:UpdateTitleBarVisibility()
    self:ApplyFramePosition()
    self:UpdateFrameLock()

    PCR.Roster:Rebuild()
    PCR.Pool:Read()
    self:Rebuild()

    for _, event in ipairs(POOL_EVENTS) do
        PeaversCommons.Events:RegisterEvent(event, function() self:OnPoolEvent(event) end)
    end
    PeaversCommons.Events:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        PCR.Roster:Rebuild()
        self:Draw()
    end)

    self:UpdateFrameVisibility()
end

-- Rebuilds the bar after a setting that changes its shape.
function Core:Rebuild()
    if not self.contentFrame then return end
    self.frame:SetWidth(PCR.Config.frameWidth)
    PCR.ResBar:Build(self.contentFrame)
    self:AdjustFrameHeight()
    self:Draw()
end

function Core:AdjustFrameHeight()
    local titleBarHeight = PCR.Config.showTitleBar and 20 or 0
    self.frame:SetHeight(PCR.ResBar:GetHeight() + titleBarHeight)
end

function Core:UpdateFrameLock()
    PeaversCommons.FrameLock:ApplyFromConfig(
        self.frame,
        self.contentFrame,
        PCR.Config,
        function() PCR.Config:Save() end
    )
end

function Core:UpdateTitleBarVisibility()
    if not self.titleBar then return end
    local showTitleBar = PCR.Config.showTitleBar
    self.titleBar:SetShown(showTitleBar)

    local titleBarHeight = showTitleBar and 20 or 0
    self.contentFrame:ClearAllPoints()
    self.contentFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -titleBarHeight)
    self.contentFrame:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 0, 0)

    self:AdjustFrameHeight()
    self:UpdateFrameLock()
end

function Core:UpdateFrameBackground()
    local config = PCR.Config
    if config.showFrameBackground then
        self.frame:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\BUTTONS\\WHITE8X8",
            tile = true, tileSize = 16, edgeSize = 1,
        })
        self.frame:SetBackdropColor(config.bgColor.r, config.bgColor.g, config.bgColor.b, config.bgAlpha)
        self.frame:SetBackdropBorderColor(0, 0, 0, config.bgAlpha)
    else
        self.frame:SetBackdrop(nil)
    end
end

function Core:ApplyFramePosition()
    if not self.frame then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint(PCR.Config.framePoint or "CENTER", PCR.Config.frameX or 0, PCR.Config.frameY or 0)
end

--------------------------------------------------------------------------------
-- Pool
--------------------------------------------------------------------------------

function Core:Refresh()
    if self:IsPreviewing() then return end
    local wasActive = PCR.Pool.active
    if PCR.Pool:Read() then
        if wasActive ~= PCR.Pool.active then
            self:UpdateFrameVisibility()
        end
        self:Draw()
    end
end

function Core:OnPoolEvent(event)
    -- A real pool replaces the preview: the moment it matters, it is the truth.
    if self.preview and START_EVENTS[event] and event ~= "PLAYER_ENTERING_WORLD" then
        self:SetPreview(false)
    end

    self:Refresh()

    if START_EVENTS[event] then
        C_Timer.After(1, function() self:Refresh() end)
    end
end

function Core:Draw()
    if self.frame and self.frame:IsShown() then
        PCR.ResBar:Draw(PCR.Pool, GetTime())
    end
end

-- Runs only while the bar is on screen.
function Core:SyncTicker(shown)
    if shown and not self.ticker then
        self.ticker = C_Timer.NewTicker(TICK, function()
            self:Refresh()
            self:Draw()
        end)
    elseif not shown and self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

--------------------------------------------------------------------------------
-- Preview and Edit Mode
--------------------------------------------------------------------------------

function Core:IsPreviewing()
    return self.preview or self.editMode
end

local function EnterPreview()
    PCR.Pool:Preview(GetTime())
    -- A real group says more about how the line will look than stand-ins do.
    if #PCR.Roster.members == 0 then
        PCR.Roster:Preview()
    end
end

local function LeavePreview()
    PCR.Roster:Rebuild()
    PCR.Pool:Read()
end

local function SetPreviewFlag(self, key, on)
    local before = self:IsPreviewing()
    self[key] = on and true or nil
    local after = self:IsPreviewing()

    if after and not before then
        EnterPreview()
    elseif before and not after then
        LeavePreview()
    end
    self:UpdateFrameVisibility()
end

function Core:SetPreview(on)
    SetPreviewFlag(self, "preview", on)
end

function Core:TogglePreview()
    self:SetPreview(not self.preview)
    PeaversCommons.Utils.Print(PCR, self.preview
        and "Preview on. /pcr again to hide it; Edit Mode moves and styles it."
        or "Preview off. The bar shows itself in a key or a raid encounter.")
end

function Core:SetEditMode(on)
    SetPreviewFlag(self, "editMode", on)
end

--------------------------------------------------------------------------------
-- Visibility
--------------------------------------------------------------------------------

-- Called by Edit Mode, the profile switch and PeaversCommons' combat, group and
-- zone handlers (AddonInit:RegisterCommonEvents).
function Core:UpdateFrameVisibility()
    if not self.frame then return false end

    local shown
    if self:IsPreviewing() then
        self.frame:Show()
        shown = true
    elseif not PCR.Pool.active then
        self.frame:Hide()
        shown = false
    else
        shown = PeaversCommons.VisibilityManager:UpdateVisibility(self.frame, PCR.Config, self.inCombat)
    end

    if shown then self:Draw() end
    self:SyncTicker(shown)
    return shown
end

return Core
