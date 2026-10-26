local _, PCR = ...

--------------------------------------------------------------------------------
-- Edit Mode
--
-- The bar is placed and configured in Blizzard's Edit Mode. All of the
-- machinery lives in PeaversCommons; what is here is the list of settings and
-- how to apply one after it changes. While Edit Mode is open the bar shows a
-- made-up pool, because the real one only exists mid-fight.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons

local EditMode = {}
PCR.EditMode = EditMode

--------------------------------------------------------------------------------
-- Applying a change
--------------------------------------------------------------------------------

local VISIBILITY_KEYS = {
    displayMode = true, hideOutOfCombat = true, showOnLogin = true,
    showInMythicPlus = true, showInRaid = true, showInDungeon = true, showInDelve = true,
    showInScenario = true, showInPvP = true, showInOpenWorld = true,
}

function PCR.ApplySetting(key)
    local Core = PCR.Core
    if not (Core and Core.frame) then return end

    if key == "frameX" or key == "frameY" then
        Core:ApplyFramePosition()
    elseif key == "bgAlpha" or key == "bgColor" or key == "showFrameBackground" then
        Core:UpdateFrameBackground()
    elseif key == "lockPosition" then
        Core:UpdateFrameLock()
    elseif key == "showTitleBar" then
        Core:UpdateTitleBarVisibility()
    elseif VISIBILITY_KEYS[key] then
        Core:UpdateFrameVisibility()
    else
        -- Everything else changes what the bar shows or how it is drawn.
        Core:Rebuild()
    end
end

--------------------------------------------------------------------------------
-- The settings
--------------------------------------------------------------------------------

EditMode.SECTIONS = {
    { key = "frame", label = "Frame" },
    { key = "position", label = "Position" },
    { key = "bars", label = "Bar" },
    { key = "icon", label = "Icon" },
    { key = "text", label = "Text" },
    { key = "colors", label = "Colours" },
    { key = "visibility", label = "Visibility" },
}

local function IconChoices()
    local out = { { value = "DYNAMIC", label = "Dynamic" } }
    for _, classFile in ipairs(PCR.Spells.ORDER) do
        local spellID = PCR.Spells:ForClass(classFile)
        out[#out + 1] = { value = tostring(spellID), label = PCR.Spells:Name(spellID) }
    end
    return out
end

EditMode.ENTRIES = {
    -- Frame
    { key = "frameWidth", section = "frame" },
    { key = "showTitleBar", section = "frame" },
    {
        key = "showFrameBackground", section = "frame",
        label = "Show Frame Background", kind = "checkbox", default = true,
    },
    { key = "bgColor", section = "frame" },
    { key = "bgAlpha", section = "frame" },
    { key = "lockPosition", section = "frame" },

    -- Position
    { key = "frameX", section = "position", kind = "number" },
    { key = "frameY", section = "position", kind = "number" },

    -- Bar
    { key = "barHeight", section = "bars" },
    { key = "barAlpha", section = "bars" },
    { key = "barBgAlpha", section = "bars" },
    { key = "barTexture", section = "bars", height = 300 },

    -- Icon
    {
        key = "showIcon", section = "icon",
        label = "Show Icon", kind = "checkbox", default = true,
    },
    {
        key = "iconSpell", section = "icon",
        label = "Icon", kind = "dropdown", default = "DYNAMIC", values = IconChoices,
        desc = "Dynamic shows the res spell of whoever in your party can res, " ..
            "when they all share one; otherwise Rebirth.",
    },
    {
        key = "showIconCountdown", section = "icon",
        label = "Countdown on Icon", kind = "checkbox", default = false,
        desc = "Blizzard's cooldown numbers on the icon, as well as the timer on the bar.",
    },

    -- Text
    {
        key = "showLabel", section = "text",
        label = "Show Charges", kind = "checkbox", default = true,
    },
    {
        key = "showTimer", section = "text",
        label = "Show Recharge Timer", kind = "checkbox", default = true,
    },
    {
        key = "showRoster", section = "text",
        label = "Show Who Can Res", kind = "checkbox", default = false,
        desc = "A line of the players who can battle res, greyed when dead or offline. " ..
            "It shows who could res, not whose res is spent: the game no longer lets " ..
            "addons see that.",
    },
    { key = "fontSize", section = "text" },
    { key = "textAlpha", section = "text" },
    { key = "fontFace", section = "text", height = 300 },
    { key = "fontOutline", section = "text" },
    { key = "fontShadow", section = "text" },

    -- Colours
    { key = "colorReady", section = "colors", label = "Two or More Charges", kind = "color" },
    { key = "colorLast", section = "colors", label = "Last Charge", kind = "color" },
    { key = "colorEmpty", section = "colors", label = "No Charges", kind = "color" },

    -- Visibility
    { key = "showInMythicPlus", section = "visibility" },
    { key = "showInRaid", section = "visibility" },
    { key = "showInDelve", section = "visibility" },
    { key = "showInDungeon", section = "visibility" },
    { key = "showInScenario", section = "visibility" },
    { key = "showInPvP", section = "visibility" },
    { key = "showInOpenWorld", section = "visibility" },
    { key = "hideOutOfCombat", section = "visibility" },
    { key = "displayMode", section = "visibility" },
    { key = "showOnLogin", section = "visibility" },
}

function EditMode:BuildSchema()
    if self.schema then return self.schema end

    self.schema = PeaversCommons.SettingsSchema:New({
        config = PCR.Config,
        sections = self.SECTIONS,
        entries = self.ENTRIES,
        apply = function(entry, _, value) PCR.ApplySetting(entry.key, value) end,
    })

    return self.schema
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local function SavePosition(_, point, x, y)
    PCR.Config.framePoint = point
    PCR.Config.frameX = x
    PCR.Config.frameY = y
    PCR.Config:Save()
end

-- The frame drags itself when unlocked, and Edit Mode drags it through its own
-- overlay. Both at once means two systems answering one drag.
local function ReleaseDragging(frame)
    for _, target in ipairs({ frame, PCR.Core.contentFrame }) do
        if target then
            target:RegisterForDrag()
            target:SetScript("OnDragStart", nil)
            target:SetScript("OnDragStop", nil)
        end
    end
end

function EditMode:Register()
    if not PeaversCommons.EditMode or not PeaversCommons.EditMode.available then
        return false
    end
    if not PCR.Core or not PCR.Core.frame then return false end

    local defaults = PCR.Config.defaults or {}

    PeaversCommons.EditMode:Register({
        frame = PCR.Core.frame,
        name = "Peavers Combat Res",
        schema = self:BuildSchema(),
        default = {
            point = defaults.framePoint or "CENTER",
            x = defaults.frameX or 0,
            y = defaults.frameY or -180,
        },
        onPositionChanged = SavePosition,
        onEnter = function(frame)
            ReleaseDragging(frame)
            PCR.Core:SetEditMode(true)
        end,
        onExit = function()
            PCR.Core:SetEditMode(false)
            PCR.Core:UpdateFrameLock()
        end,
    })

    return true
end

return EditMode
