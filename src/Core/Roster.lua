local _, PCR = ...

--------------------------------------------------------------------------------
-- Roster — who in the group could battle res
--
-- Capability only, never availability. Under 12.x nobody can see another
-- player's casts in an instance, and addon messages are blocked for the whole of
-- a key and during raid fights, so whose res has gone is unknowable. What can be
-- read is each member's class, and whether they are dead or offline, which is
-- what the line under the bar says.
--------------------------------------------------------------------------------

local Roster = {
    members = {},  -- { unit, name, classFile, spellID }, in group order
}
PCR.Roster = Roster

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    else
        units[1] = "player"
        for i = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. i
        end
    end
    return units
end

--- Rebuilds the list from the group. Class and name are not secret for group
--- members; anything that comes back secret anyway is left out, not guessed.
function Roster:Rebuild()
    local members = {}

    for _, unit in ipairs(GroupUnits()) do
        if UnitExists(unit) then
            local _, classFile = UnitClass(unit)
            local name = UnitName(unit)
            if classFile and name and not IsSecret(classFile) and not IsSecret(name) then
                local spellID = PCR.Spells:ForClass(classFile)
                if spellID then
                    members[#members + 1] = {
                        unit = unit, name = name, classFile = classFile, spellID = spellID,
                    }
                end
            end
        end
    end

    self.members = members
end

--- Whether a member is alive and online. A secret answer counts as yes: the
--- line is a hint, and greying out somebody who can res would be worse.
function Roster:IsUp(member)
    local dead = UnitIsDeadOrGhost(member.unit)
    local connected = UnitIsConnected(member.unit)
    if IsSecret(dead) or IsSecret(connected) then return true end
    return connected and not dead
end

local GREY = "|cff808080%s|r"

local function Coloured(member)
    local color = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(member.classFile)
    if color then
        return color:WrapTextInColorCode(member.name)
    end
    return member.name
end

--- The line under the bar: class-coloured names, greyed when dead or offline.
--- Empty when nobody in the group can res.
function Roster:Text()
    local parts = {}
    for i, member in ipairs(self.members) do
        if self:IsUp(member) then
            parts[i] = Coloured(member)
        else
            parts[i] = GREY:format(member.name)
        end
    end
    return table.concat(parts, "  ")
end

--- The one spell every capable member shares, or nil when there is a mix or
--- nobody, or this is a raid. Drives the dynamic icon: a party with a single
--- druid shows Rebirth, a party with a druid and a warlock falls back.
function Roster:SharedSpell()
    if IsInRaid() then return nil end
    local shared
    for _, member in ipairs(self.members) do
        if shared and shared ~= member.spellID then return nil end
        shared = member.spellID
    end
    return shared
end

--- Stand-in members for the preview, one of each class, so the line shows how
--- it will look in a group even when you are on your own.
function Roster:Preview()
    local names = LOCALIZED_CLASS_NAMES_MALE or {}
    self.members = {}
    for _, classFile in ipairs({ "DRUID", "DEATHKNIGHT", "WARLOCK" }) do
        self.members[#self.members + 1] = {
            unit = "player", name = names[classFile] or classFile,
            classFile = classFile, spellID = PCR.Spells:ForClass(classFile),
        }
    end
end

return Roster
