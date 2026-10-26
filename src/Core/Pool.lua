local _, PCR = ...

--------------------------------------------------------------------------------
-- Pool — the group's shared battle res charges
--
-- One read of C_Spell.GetSpellCharges on the pool spell gives everything shown:
-- charges, the cap, and the start and length of the recharge in progress.
-- Cooldowns are secret in combat on 12.x, but Blizzard exempted every battle
-- res from that, so these come back as plain numbers even mid-pull. They are
-- still checked: should the exemption ever go, the bar degrades to what the
-- widgets can draw from a secret rather than erroring.
--
-- No widgets here. Core reads, ResBar draws, and this stays testable.
--------------------------------------------------------------------------------

local Pool = {
    active = false,      -- a pool exists: raid encounter or keystone
    secret = false,      -- the numbers came back secret; only `info` is usable
    charges = 0,
    maxCharges = 0,
    recharging = false,  -- a charge is on its way
    start = 0,
    duration = 0,
    info = nil,          -- the raw table, for the secret path
}
PCR.Pool = Pool

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

--- Reads the pool. Returns true if anything a player would see has changed.
function Pool:Read()
    local info = C_Spell.GetSpellCharges(PCR.Spells.POOL)

    if not info then
        local changed = self.active
        self.active, self.secret, self.info = false, false, nil
        return changed
    end

    self.info = info

    -- maxCharges and isActive are never secret; the rest may be.
    if IsSecret(info.currentCharges) or IsSecret(info.cooldownStartTime)
        or IsSecret(info.cooldownDuration) then
        self.active, self.secret = true, true
        self.maxCharges = info.maxCharges
        self.recharging = info.isActive
        return true
    end

    local recharging = info.isActive and info.cooldownDuration > 0
    local changed = not self.active or self.secret
        or self.charges ~= info.currentCharges
        or self.maxCharges ~= info.maxCharges
        or self.recharging ~= recharging
        or self.start ~= info.cooldownStartTime
        or self.duration ~= info.cooldownDuration

    self.active, self.secret = true, false
    self.charges = info.currentCharges
    self.maxCharges = info.maxCharges
    self.recharging = recharging
    self.start = info.cooldownStartTime
    self.duration = info.cooldownDuration

    return changed
end

--- Seconds until the next charge, 0 when none is coming.
function Pool:Remaining(now)
    if self.secret or not self.recharging then return 0 end
    local left = self.start + self.duration - now
    return left > 0 and left or 0
end

--- How far the next charge has come, 0 to 1. Full when nothing is recharging.
function Pool:Progress(now)
    if self.secret or not self.recharging or self.duration <= 0 then return 1 end
    local done = (now - self.start) / self.duration
    if done < 0 then return 0 end
    if done > 1 then return 1 end
    return done
end

--- Stands in a believable pool for Edit Mode and /pcr, so the bar can be placed
--- and styled anywhere: one charge left and the next four minutes away.
function Pool:Preview(now)
    self.active, self.secret, self.info = true, false, nil
    self.charges, self.maxCharges = 1, 5
    self.recharging = true
    self.duration = 600
    self.start = now - 360
end

return Pool
