local _, PCR = ...

--------------------------------------------------------------------------------
-- The battle res spells
--
-- In a raid encounter or a keystone every battle res draws on one shared pool,
-- and the game reports that pool through Rebirth whatever class you are. Outside
-- those it does not exist and the call returns nothing.
--------------------------------------------------------------------------------

local Spells = {}
PCR.Spells = Spells

Spells.POOL = 20484

-- One spell per class that can battle res, in the order they are offered as a
-- fixed icon. Engineering items are left out: which engineer has one equipped
-- needs an inspect of every player, and the pool counts their uses all the same.
Spells.BY_CLASS = {
    DRUID = 20484,       -- Rebirth
    DEATHKNIGHT = 61999, -- Raise Ally
    WARLOCK = 20707,     -- Soulstone
    PALADIN = 391054,    -- Intercession
}

Spells.ORDER = { "DRUID", "DEATHKNIGHT", "WARLOCK", "PALADIN" }

-- Used wherever an icon is wanted and nothing better is known.
Spells.DEFAULT = 20484

function Spells:ForClass(classFile)
    return self.BY_CLASS[classFile]
end

-- Texture for a spell, or the question mark if the client does not know it.
function Spells:Icon(spellID)
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    return icon or 134400
end

function Spells:Name(spellID)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    return name or tostring(spellID)
end

return Spells
