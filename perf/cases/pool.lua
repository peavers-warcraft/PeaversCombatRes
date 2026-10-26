--------------------------------------------------------------------------------
-- Ultra Performance case: what keeping the bar current costs.
--
-- There is no OnUpdate anywhere in src/. The bar is kept current by events and
-- by a one second ticker that exists only while it is on screen, so the honest
-- questions are what a tick costs while a charge recharges, what it costs when
-- nothing is moving, and what the rest of the time costs. This loads the real
-- Spells, Pool, Roster, ResBar and Core files and drives Core's own ticker.
--------------------------------------------------------------------------------

local Stubs = dofile(HARNESS_LIB .. "/wow-stubs.lua").Install()

local pool = nil
local handlers = {}
local ticker = nil

_G.C_Spell = {
    GetSpellCharges = function() return pool end,
    GetSpellTexture = function() return 136080 end,
    GetSpellName = function() return "Rebirth" end,
}
_G.C_Timer = {
    After = function() end,
    NewTicker = function(_, fn)
        ticker = { fn = fn, Cancel = function() ticker = nil end }
        return ticker
    end,
}

-- A five-player key with a druid and a warlock in it.
local party = {
    player = { "Tree", "DRUID" }, party1 = { "Lock", "WARLOCK" }, party2 = { "Tank", "WARRIOR" },
    party3 = { "Rogue", "ROGUE" }, party4 = { "Priest", "PRIEST" },
}
_G.IsInRaid = function() return false end
_G.GetNumSubgroupMembers = function() return 4 end
_G.UnitExists = function(unit) return party[unit] ~= nil end
_G.UnitClass = function(unit) return party[unit][2], party[unit][2] end
_G.UnitName = function(unit) return party[unit][1] end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitIsConnected = function() return true end
_G.C_ClassColor = {
    GetClassColor = function() return { WrapTextInColorCode = function(_, t) return t end } end,
}

local function Bar()
    local frame = Stubs.NewFrame()
    local bar = {}
    function bar:SetValue(v) if self.value ~= v then self.value = v; frame:SetValue(v) end end
    function bar:SetColor(r, g, b) frame:SetStatusBarColor(r, g, b) end
    function bar:SetSmoothing() end
    function bar:SetPoint() end
    function bar:Destroy() end
    function bar:GetStatusBar() return frame end
    return bar
end

---@diagnostic disable-next-line: missing-fields
_G.PeaversCommons = {
    Utils = { Print = function() end },
    Events = {
        RegisterEvent = function(_, event, fn)
            handlers[event] = handlers[event] or {}
            table.insert(handlers[event], fn)
            return true
        end,
    },
    TitleBar = { Create = function() return Stubs.NewFrame() end },
    FrameLock = { ApplyFromConfig = function() end },
    VisibilityManager = {
        UpdateVisibility = function(_, frame) frame:Show() return true end,
    },
    AnimatedStatusBar = { New = function() return Bar() end },
    BarTextManager = {
        SafeSetFont = function() end,
        New = function()
            local tm = { nameElement = Stubs.NewTexture(), valueElement = Stubs.NewTexture() }
            function tm:SetName(t) self.nameElement:SetText(t) end
            function tm:SetValue(t) self.valueElement:SetText(t) end
            function tm:Destroy() end
            return tm
        end,
    },
}

local PCR = { version = "perf" }
for _, file in ipairs({ "src/Data/Spells.lua", "src/Core/Pool.lua", "src/Core/Roster.lua",
    "src/UI/ResBar.lua", "src/Core/Core.lua" }) do
    assert(loadfile(ADDON_DIR .. "/" .. file))("PeaversCombatRes", PCR)
end

-- Shipped defaults, with everything that draws switched on.
PCR.Config = {
    frameWidth = 200, barHeight = 20, barAlpha = 1, barBgAlpha = 0.7, fontSize = 9, textAlpha = 1,
    bgColor = { r = 0, g = 0, b = 0 }, bgAlpha = 0.8, showFrameBackground = true, showTitleBar = false,
    showIcon = true, iconSpell = "DYNAMIC", showLabel = true, showTimer = true, showRoster = true,
    colorReady = { r = 0, g = 1, b = 0 }, colorLast = { r = 1, g = 0.7, b = 0 }, colorEmpty = { r = 1, g = 0, b = 0 },
    Save = function() end,
}

local function Fire(event)
    for _, fn in ipairs(handlers[event] or {}) do fn() end
end

local function ChargePool(charges, recharging)
    return {
        currentCharges = charges, maxCharges = 5,
        cooldownStartTime = recharging and Stubs.time or 0,
        cooldownDuration = recharging and 600 or 0,
        chargeModRate = 1, isActive = recharging,
    }
end

-- Ticks the bar the way the client would: once a second, while a ticker exists.
local TICKS = 300
local function DriveTicker()
    Stubs.ResetCounts()
    for _ = 1, TICKS do
        Stubs.time = Stubs.time + 1
        if ticker then ticker.fn() end
    end
    return Stubs.TotalCalls() / TICKS
end

PCR.Core:Initialize()

-- 1. No pool: open world, between raid pulls. Nothing is on screen.
Stubs.ResetCounts()
for _ = 1, 50 do Fire("SPELL_UPDATE_CHARGES") end
local idleEventCalls = Stubs.TotalCalls() / 50
local idleTicker = ticker
local idleRate = DriveTicker()

-- 2. A key, one charge, the next one recharging.
pool = ChargePool(1, true)
Fire("CHALLENGE_MODE_START")
local rechargingRate = DriveTicker()

-- 3. A pool at its cap: nothing moves.
pool = ChargePool(5, false)
Fire("SPELL_UPDATE_CHARGES")
local fullRate = DriveTicker()

-- 4. A rotation that spends charges of its own fires SPELL_UPDATE_CHARGES
--    constantly; the pool has not changed, so nothing should be drawn.
Stubs.ResetCounts()
for _ = 1, 100 do Fire("SPELL_UPDATE_CHARGES") end
local stormCalls = Stubs.TotalCalls() / 100

assert(idleTicker == nil, "a ticker ran with no pool")
assert(idleEventCalls == 0, "charge events drew with no pool")
assert(stormCalls == 0, "an unchanged pool was redrawn")

return {
    {
        name = "key, next charge recharging, 1s ticker",
        callsPerFrame = 0,
        callsPerSecond = rechargingRate,
        notes = ("%d ticks driven; bar fill and timer text"):format(TICKS),
    },
    {
        name = "key, pool at its cap",
        callsPerFrame = 0,
        callsPerSecond = fullRate,
        notes = "every draw is diffed; nothing moved",
    },
    {
        name = "no pool (open world, between pulls)",
        callsPerFrame = 0,
        idleCallsPerSecond = idleRate,
        notes = "hidden, no ticker exists",
    },
    {
        name = "100 SPELL_UPDATE_CHARGES, pool unchanged",
        callsPerFrame = 0,
        notes = ("%.2f widget calls per event"):format(stormCalls),
    },
}
