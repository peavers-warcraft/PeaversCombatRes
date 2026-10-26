local addonName, PCR = ...

-- Check for PeaversCommons
local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r " .. addonName .. " requires PeaversCommons to work properly.")
    return
end

local AddonInit = PeaversCommons.AddonInit

-- Setup addon using AddonInit helper. A bare /pcr shows a preview rather than
-- toggling the frame: outside a key or a raid fight there is nothing to show, so
-- a toggle would look like it did nothing.
local success = AddonInit:Setup(PCR, addonName, {
    modules = {"Core", "Utils", "Config"},
    slashCommand = "pcr",
    extraSlashCommands = {
        default = function() PCR.Core:TogglePreview() end,
        probe = function() PCR.Probe:Run() end,
    },
})

if not success then return end

-- Expose addon namespace globally for PeaversUISetup integration
_G.PeaversCombatRes = PCR

PeaversCommons.Events:Init(addonName, function()
    if PCR.Config and PCR.Config.Initialize then
        PCR.Config:Initialize()
    end

    if PCR.Config.useGlobalAppearance and PeaversCommons.GlobalAppearance then
        PeaversCommons.GlobalAppearance:RegisterAddon("PeaversCombatRes", PCR.Config, function()
            if PCR.ApplySetting then PCR.ApplySetting("barTexture") end
        end)
    end

    if PCR.ConfigUI and PCR.ConfigUI.Initialize then
        PCR.ConfigUI:Initialize()
    end

    PCR.Core:Initialize()

    -- After Core, because it registers the frame Core builds.
    if PCR.EditMode then
        PCR.EditMode:Register()
    end

    -- Logout save, combat state and group changes, which all end in
    -- Core:UpdateFrameVisibility.
    AddonInit:RegisterCommonEvents(PCR)

    C_Timer.After(0.5, function()
        PeaversCommons.SettingsUI:CreateRedirectPage(PCR, "PeaversCombatRes", "Peavers Combat Res")
    end)

    if PeaversCommons.ConfigRegistry then
        PeaversCommons.ConfigRegistry:Register({
            name = "PeaversCombatRes",
            displayName = "Combat Res",
            description = "The group's shared battle res charges",
            addonRef = PCR,
            config = PCR.Config,
            pages = PCR.ConfigUI:GetPages(),
            order = 6,
        })
    end
end, {
    suppressAnnouncement = true
})
