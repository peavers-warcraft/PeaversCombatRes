--------------------------------------------------------------------------------
-- A stand-in client for the tests: just enough of WoW and PeaversCommons to
-- load the real addon files and drive them. Everything a test wants to steer
-- lives in `env.world`; every widget call is recorded in `env.calls`.
--
-- Not addon code, and not packaged (see .pkgmeta).
---@diagnostic disable: undefined-global, duplicate-set-field, lowercase-global, missing-fields
--------------------------------------------------------------------------------

local env = { calls = {}, handlers = {}, tickers = {} }

env.world = {
    now = 1000,
    pool = nil,             -- what C_Spell.GetSpellCharges(20484) returns
    raid = false,
    party = {},             -- { { name, classFile, dead, offline } }, player first
    content = "MYTHIC_PLUS",
    secret = {},            -- values issecretvalue should call secret
}

local function Count(name)
    env.calls[name] = (env.calls[name] or 0) + 1
    env.calls.total = (env.calls.total or 0) + 1
end

function env.ResetCalls() env.calls = {} end

-- A widget: setters are counted and remembered, getters read them back.
local Widget = {}
Widget.__index = function(_, key)
    if type(key) == "string" and key:sub(1, 1) == "_" then return nil end
    return function(self, ...)
        if key:find("^Get") or key:find("^Is") then
            if key == "IsShown" then return self._shown end
            if key == "GetText" then return self._text end
            if key == "GetFrameLevel" then return 1 end
            if key == "GetWidth" then return 200 end
            if key == "GetHeight" then return self._height or 20 end
            return nil
        end
        Count(key)
        if key == "Show" then self._shown = true
        elseif key == "Hide" then self._shown = false
        elseif key == "SetShown" then self._shown = (...) and true or false
        elseif key == "SetText" then self._text = ...
        elseif key == "SetFormattedText" then self._text = string.format(...)
        elseif key == "SetHeight" then self._height = ...
        elseif key == "SetTexture" then self._texture = ...
        elseif key == "SetDesaturated" then self._desaturated = ...
        elseif key == "SetCooldown" then self._cooldown = { ... }
        elseif key == "Clear" then self._cooldown = nil
        end
    end
end

local function NewWidget()
    return setmetatable({ _shown = true }, Widget)
end
env.NewWidget = NewWidget

-- Frames
_G.CreateFrame = function(_, _, _, template)
    local w = NewWidget()
    if template == "BackdropTemplate" then w._shown = true end
    w.CreateTexture = function() return NewWidget() end
    w.CreateFontString = function() return NewWidget() end
    return w
end
_G.UIParent = NewWidget()

-- Clock and timers
_G.GetTime = function() return env.world.now end
_G.C_Timer = {
    After = function(_, fn) env.after = env.after or {}; table.insert(env.after, fn) end,
    NewTicker = function(_, fn)
        local t = { fn = fn }
        t.Cancel = function(self) self.cancelled = true end
        table.insert(env.tickers, t)
        return t
    end,
}

function env.LiveTicker()
    for _, t in ipairs(env.tickers) do
        if not t.cancelled then return t end
    end
end

function env.Tick(seconds)
    env.world.now = env.world.now + (seconds or 1)
    local t = env.LiveTicker()
    if t then t.fn() end
end

-- Secrets
_G.issecretvalue = function(v)
    return env.world.secret[v] == true
end

-- Spells
_G.C_Spell = {
    GetSpellCharges = function(id)
        assert(id == 20484, "pool is read through Rebirth")
        return env.world.pool
    end,
    GetSpellTexture = function(id) return "icon:" .. id end,
    GetSpellName = function(id) return "spell:" .. id end,
    GetSpellChargeDuration = function() return "duration-object" end,
}

-- Group
local function Member(unit)
    local party = env.world.party
    if env.world.raid then
        return party[tonumber(unit:match("raid(%d+)"))]
    end
    if unit == "player" then return party[1] end
    local i = tonumber(unit:match("party(%d+)"))
    return i and party[i + 1]
end

_G.IsInRaid = function() return env.world.raid end
_G.IsInGroup = function() return #env.world.party > 1 end
_G.GetNumGroupMembers = function() return #env.world.party end
_G.GetNumSubgroupMembers = function() return math.max(0, #env.world.party - 1) end
_G.UnitExists = function(unit) return Member(unit) ~= nil end
_G.UnitClass = function(unit) local m = Member(unit); return m and m[2], m and m[2] end
_G.UnitName = function(unit) local m = Member(unit); return m and m[1] end
_G.UnitIsDeadOrGhost = function(unit) local m = Member(unit); return m and m.dead or false end
_G.UnitIsConnected = function(unit) local m = Member(unit); return not (m and m.offline) end
_G.InCombatLockdown = function() return false end
_G.C_ClassColor = {
    GetClassColor = function(classFile)
        return { WrapTextInColorCode = function(_, text) return "<" .. classFile .. ">" .. text end }
    end,
}

-- PeaversCommons, as much as the addon touches
local commons = {}
_G.PeaversCommons = commons

commons.Utils = { Print = function(_, text) env.printed = text end }
commons.Events = {
    RegisterEvent = function(_, event, fn)
        env.handlers[event] = env.handlers[event] or {}
        table.insert(env.handlers[event], fn)
        return true
    end,
}
commons.TitleBar = { Create = function() return NewWidget() end }
commons.FrameLock = { ApplyFromConfig = function() end }
commons.VisibilityManager = {
    UpdateVisibility = function(_, frame, config)
        local key = ({ MYTHIC_PLUS = "showInMythicPlus", RAID = "showInRaid", DELVE = "showInDelve",
            OPEN_WORLD = "showInOpenWorld" })[env.world.content]
        local shown = not key or config[key] ~= false
        if shown then frame:Show() else frame:Hide() end
        return shown
    end,
    GetContentType = function() return env.world.content end,
}
commons.BarTextManager = {
    SafeSetFont = function() end,
    New = function(_, _, options)
        local tm = { nameElement = NewWidget(), valueElement = NewWidget() }
        function tm:SetName(text) self.nameElement:SetText(text) end
        function tm:SetValue(text) self.valueElement:SetText(text) end
        function tm:Destroy() end
        tm.options = options
        return tm
    end,
}
commons.AnimatedStatusBar = {
    New = function(_, _, options)
        local bar = { widget = NewWidget(), value = nil, color = options.color }
        function bar:SetValue(v) if self.value ~= v then self.value = v; self.widget:SetValue(v) end end
        function bar:SetColor(r, g, b) self.color = { r = r, g = g, b = b }; self.widget:SetStatusBarColor(r, g, b) end
        function bar:SetSmoothing() end
        function bar:SetPoint() end
        function bar:Destroy() end
        function bar:GetStatusBar() return self.widget end
        return bar
    end,
}

-- Loads the addon in TOC order.
function env.Load(dir)
    dir = dir or "."
    local PCR = { version = "test" }
    local files = {
        "src/Data/Spells.lua", "src/Core/Pool.lua", "src/Core/Roster.lua",
        "src/UI/ResBar.lua", "src/Core/Core.lua",
    }
    for _, file in ipairs(files) do
        assert(loadfile(dir .. "/" .. file))("PeaversCombatRes", PCR)
    end
    PCR.Config = {
        frameWidth = 200, barHeight = 20, barAlpha = 1, barBgAlpha = 0.7, fontSize = 9,
        textAlpha = 1, bgColor = { r = 0, g = 0, b = 0 }, bgAlpha = 0.8,
        showFrameBackground = true, showTitleBar = false,
        showIcon = true, iconSpell = "DYNAMIC", showIconCountdown = false,
        showLabel = true, showTimer = true, showRoster = true,
        colorReady = { r = 0, g = 1, b = 0 }, colorLast = { r = 1, g = 0.5, b = 0 },
        colorEmpty = { r = 1, g = 0, b = 0 },
        showInMythicPlus = true, showInRaid = true, showInOpenWorld = false,
        Save = function() end,
    }
    env.PCR = PCR
    return PCR
end

function env.Fire(event)
    for _, fn in ipairs(env.handlers[event] or {}) do fn() end
end

-- Runs whatever C_Timer.After queued.
function env.Flush()
    local queued = env.after or {}
    env.after = {}
    for _, fn in ipairs(queued) do fn() end
end

function env.Pool(charges, start, duration, max)
    return {
        currentCharges = charges, maxCharges = max or 5,
        cooldownStartTime = start or 0, cooldownDuration = duration or 0,
        chargeModRate = 1, isActive = (duration or 0) > 0,
    }
end

return env
