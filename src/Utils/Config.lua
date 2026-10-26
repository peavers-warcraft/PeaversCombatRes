--------------------------------------------------------------------------------
-- PeaversCombatRes Configuration
-- Uses PeaversCommons.ConfigManager with AceDB-3.0 for profile management
--------------------------------------------------------------------------------

local _, PCR = ...

local PeaversCommons = _G.PeaversCommons
local ConfigManager = PeaversCommons.ConfigManager

-- PCR-specific defaults (these extend the common defaults from ConfigManager)
local PCR_DEFAULTS = {
    framePoint = "CENTER",
    frameX = 0,
    frameY = -180,
    frameWidth = 200,

    -- One bar does not need a title to say what it is.
    showTitleBar = false,
    showFrameBackground = true,

    -- Icon: "DYNAMIC" or a spell ID as a string.
    showIcon = true,
    iconSpell = "DYNAMIC",
    showIconCountdown = false,

    showLabel = true,
    showTimer = true,
    showRoster = false,

    -- Bar colour by charges left.
    colorReady = { r = 0.20, g = 0.78, b = 0.35 },
    colorLast = { r = 1.00, g = 0.68, b = 0.10 },
    colorEmpty = { r = 0.86, g = 0.20, b = 0.20 },

    -- The pool only exists in a raid encounter or a keystone, so in practice
    -- these choose between the two. The rest are offered because the usual
    -- Peavers set has them and delves are not yet known either way.
    showInMythicPlus = true,
    showInRaid = true,
    showInDungeon = false,
    showInDelve = false,
    showInScenario = false,
    showInPvP = false,
    showInOpenWorld = false,
}

PCR.Config = ConfigManager:NewWithAceDB(
    PCR,
    PCR_DEFAULTS,
    {
        savedVariablesName = "PeaversCombatResDB",
        profileType = "character",
        onProfileChanged = function()
            if not PCR.Core or not PCR.Core.frame then return end
            PCR.Core:Rebuild()
            PCR.Core:ApplyFramePosition()
            PCR.Core:UpdateFrameLock()
            PCR.Core:UpdateFrameVisibility()
        end,
    }
)

return PCR.Config
