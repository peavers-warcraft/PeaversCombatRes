local _, PCR = ...
local Config = PCR.Config

local ConfigUI = {}
PCR.ConfigUI = ConfigUI

local PeaversCommons = _G.PeaversCommons
if not PeaversCommons then
    print("|cffff0000Error:|r PeaversCommons not found.")
    return
end

local ConfigUIUtils = PeaversCommons.ConfigUIUtils

--------------------------------------------------------------------------------
-- Where the settings went
--
-- Every setting is in Blizzard's Edit Mode. This page explains what the bar
-- does, and, as importantly, what it cannot do any more.
--------------------------------------------------------------------------------

function ConfigUI:BuildInfoPage(parentFrame)
    ConfigUIUtils.BuildInfoPageWithEditMode(parentFrame, "Combat Res", {
        "Shows the group's shared battle res charges during a raid encounter or a " ..
            "Mythic+ key: how many are left, and how long until the next one. The " ..
            "bar fills as that charge comes back, and turns amber on the last " ..
            "charge and red when there are none.",
        { command = "/pcr", desc = "preview the bar, to see it outside a fight" },
        { command = "/pcr probe", desc = "print what this client reports about battle res" },

        { header = "When it shows" },
        "The pool only exists during a raid boss fight or a keystone, so that is " ..
            "the only time the bar appears. Between raid pulls it hides itself. " ..
            "Edit Mode shows a made-up pool so you can place it anywhere.",

        { header = "Who can res" },
        "The optional line under the bar lists the players who can battle res, " ..
            "greyed when dead or offline. It cannot say whose res has been used: " ..
            "since Midnight, addons cannot see other players' casts in an " ..
            "instance, or talk to each other during a key or a boss fight.",
    }, {
        title = "the combat res bar",
        select = "the bar",
        reset = function()
            PCR.Config:Reset()
            if PCR.Core and PCR.Core.Rebuild then PCR.Core:Rebuild() end
            if PeaversCommons.EditModePanel then
                PeaversCommons.EditModePanel:Refresh()
            end
        end,
    })
end

function ConfigUI:GetPages()
    return {
        { key = "info", label = "Information", builder = function(f) ConfigUI:BuildInfoPage(f) end },
    }
end

function ConfigUI:BuildIntoFrame(parentFrame)
    self:BuildInfoPage(parentFrame)
    return parentFrame
end

function ConfigUI:InitializeOptions()
    local panel = ConfigUIUtils.CreateSettingsPanel(
        "Combat Res",
        "The bar is configured in Blizzard's Edit Mode"
    )
    local content = panel.content
    self:BuildIntoFrame(content)
    panel:UpdateContentHeight(content:GetHeight())
    return panel
end

function ConfigUI:OpenOptions()
    Config:Save()

    if _G.PeaversConfig and _G.PeaversConfig.MainFrame then
        _G.PeaversConfig.MainFrame:Show()
        _G.PeaversConfig.MainFrame:SelectAddon("PeaversCombatRes")
        return
    end

    if Settings and Settings.OpenToCategory then
        if PCR.directSettingsCategoryID then
            local ok = pcall(Settings.OpenToCategory, PCR.directSettingsCategoryID)
            if ok then return end
        end
        if PCR.directCategoryID then
            local ok = pcall(Settings.OpenToCategory, PCR.directCategoryID)
            if ok then return end
        end
    end

    if SettingsPanel then
        ShowUIPanel(SettingsPanel)
    end
end

Config.OpenOptionsCommand = function()
    ConfigUI:OpenOptions()
end

function ConfigUI:Initialize()
    self.panel = self:InitializeOptions()
end

return ConfigUI
