local _, PCR = ...

--------------------------------------------------------------------------------
-- /pcr probe — what this client will tell us, printed
--
-- Some of what decides this addon can only be answered by a live client:
-- whether each battle res is exempt from cooldown secrecy, whether anybody
-- else's cast of one can be seen, whether a Soulstone sitting on a player can
-- be. Run it in a key or on a raid boss and paste the output into an issue.
--------------------------------------------------------------------------------

local PeaversCommons = _G.PeaversCommons

local Probe = {}
PCR.Probe = Probe

-- Every battle res worth asking about, engineering items included: the probe
-- is the cheapest way to learn whether a future version could use them.
local SPELLS = {
    { 20484, "Rebirth" },
    { 61999, "Raise Ally" },
    { 20707, "Soulstone" },
    { 95750, "Soulstone Resurrection" },
    { 391054, "Intercession" },
    { 345130, "Spectrophasic Reanimator" },
    { 385403, "Arclight Vital Correctors" },
    { 384893, "Jumper Cables" },
}

local function Say(text)
    PeaversCommons.Utils.Print(PCR, text)
end

-- Enum.SecrecyLevel values by number, for printing.
local function SecrecyName(value)
    if value == nil then return "n/a" end
    for name, v in pairs(Enum.SecrecyLevel or {}) do
        if v == value then return name end
    end
    return tostring(value)
end

local function Ask(fn, spellID)
    if not (C_Secrets and C_Secrets[fn]) then return "n/a" end
    local ok, value = pcall(C_Secrets[fn], spellID)
    return ok and SecrecyName(value) or "error"
end

local function Show(value)
    if issecretvalue and issecretvalue(value) then return "SECRET" end
    return tostring(value)
end

function Probe:Run()
    Say(("probe, %s, content %s"):format(
        GetBuildInfo and select(4, GetBuildInfo()) or "?",
        PeaversCommons.VisibilityManager.GetContentType and PeaversCommons.VisibilityManager:GetContentType() or "?"))

    local info = C_Spell.GetSpellCharges(PCR.Spells.POOL)
    if info then
        Say(("pool: charges %s/%s, start %s, duration %s, active %s"):format(
            Show(info.currentCharges), Show(info.maxCharges),
            Show(info.cooldownStartTime), Show(info.cooldownDuration), Show(info.isActive)))
    else
        Say("pool: none (only exists in a raid encounter or a keystone)")
    end

    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum.AddOnRestrictionType then
        local active = {}
        for name, value in pairs(Enum.AddOnRestrictionType) do
            if C_RestrictedActions.IsAddOnRestrictionActive(value) then
                active[#active + 1] = name
            end
        end
        Say("restrictions: " .. (#active > 0 and table.concat(active, ", ") or "none"))
    end

    Say("spell: cooldown / cast / aura secrecy")
    for _, spell in ipairs(SPELLS) do
        local id = spell[1]
        Say(("  %s %d: %s / %s / %s"):format(spell[2], id,
            Ask("GetSpellCooldownSecrecy", id), Ask("GetSpellCastSecrecy", id), Ask("GetSpellAuraSecrecy", id)))
    end
end

return Probe
