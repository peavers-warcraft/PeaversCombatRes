--------------------------------------------------------------------------------
-- The addon, driven end to end against tests/env.lua.
--
--   Run: lua tests/test_core.lua        (from the addon root)
--
-- Covers the rules a player would notice going wrong: the bar shows only while
-- a pool exists, says the right number in the right colour, counts down, never
-- errors on a secret, and costs nothing while hidden.
---@diagnostic disable: undefined-global, missing-fields
--------------------------------------------------------------------------------

local failures, current = 0, ""
local function check(label, got, want)
    if got ~= want then
        failures = failures + 1
        print(("FAIL [%s] %s: got %s, want %s"):format(current, label, tostring(got), tostring(want)))
    end
end
local function test(name, fn)
    current = name
    package.loaded["tests.env"] = nil
    local env = dofile("tests/env.lua")
    local ok, err = pcall(fn, env)
    if not ok then
        failures = failures + 1
        print(("ERROR [%s] %s"):format(name, tostring(err)))
    end
end

local function Boot(env)
    local PCR = env.Load()
    PCR.Core:Initialize()
    return PCR
end

test("hidden with no pool, and no ticker running", function(env)
    local PCR = Boot(env)
    check("shown", PCR.Core.frame:IsShown(), false)
    check("ticker", env.LiveTicker(), nil)
    env.ResetCalls()
    env.Fire("SPELL_UPDATE_CHARGES")
    check("widget calls on a charge event with no pool", env.calls.total, nil)
end)

test("a key starting shows the bar", function(env)
    local PCR = Boot(env)
    env.world.pool = env.Pool(1, env.world.now - 60, 600)
    env.Fire("CHALLENGE_MODE_START")
    check("shown", PCR.Core.frame:IsShown(), true)
    check("ticker", env.LiveTicker() ~= nil, true)
    check("label", PCR.ResBar.textManager.nameElement._text, "Battle Res  1")
    check("timer", PCR.ResBar.textManager.valueElement._text, "9:00")
    check("colour is the last-charge colour", PCR.ResBar.statusBar.color.g, 0.5)
    check("fill", PCR.ResBar.statusBar.value, 0.1)
    check("icon cooldown start", PCR.ResBar.icon.cooldown._cooldown[1], env.world.now - 60)
end)

test("the timer counts down on the ticker", function(env)
    local PCR = Boot(env)
    env.world.pool = env.Pool(2, env.world.now, 600)
    env.Fire("ENCOUNTER_START")
    env.Tick(1)
    check("timer after a second", PCR.ResBar.textManager.valueElement._text, "9:59")
    env.Tick(119)
    check("timer after two minutes", PCR.ResBar.textManager.valueElement._text, "8:00")
    check("colour with two charges", PCR.ResBar.statusBar.color.g, 1)
end)

test("a tick that changes nothing visible touches no widget", function(env)
    local PCR = Boot(env)
    env.world.pool = env.Pool(3)  -- full, nothing recharging
    env.Fire("ENCOUNTER_START")
    check("no timer when nothing is recharging", PCR.ResBar.textManager.valueElement._text, "")
    check("full bar", PCR.ResBar.statusBar.value, 1)
    env.ResetCalls()
    for _ = 1, 10 do env.Tick(1) end
    env.Fire("SPELL_UPDATE_CHARGES")
    check("widget calls", env.calls.total, nil)
end)

test("spending the last charge turns the bar red and greys the icon", function(env)
    local PCR = Boot(env)
    env.world.pool = env.Pool(1, env.world.now, 600)
    env.Fire("ENCOUNTER_START")
    env.world.pool = env.Pool(0, env.world.now, 600)
    env.Fire("SPELL_UPDATE_CHARGES")
    check("label", PCR.ResBar.textManager.nameElement._text, "Battle Res  0")
    check("red", PCR.ResBar.statusBar.color.r == 1 and PCR.ResBar.statusBar.color.g == 0, true)
    check("icon greyed", PCR.ResBar.icon.texture._desaturated, true)
end)

test("the fight ending hides the bar and stops the ticker", function(env)
    local PCR = Boot(env)
    env.world.pool = env.Pool(1, env.world.now, 600)
    env.Fire("ENCOUNTER_START")
    env.world.pool = nil
    env.Fire("ENCOUNTER_END")
    check("shown", PCR.Core.frame:IsShown(), false)
    check("ticker", env.LiveTicker(), nil)
end)

test("content settings still hide a live pool", function(env)
    local PCR = Boot(env)
    PCR.Config.showInMythicPlus = false
    env.world.pool = env.Pool(1)
    env.Fire("CHALLENGE_MODE_START")
    check("shown", PCR.Core.frame:IsShown(), false)
    check("ticker", env.LiveTicker(), nil)
end)

test("a pool that arrives a moment late is still picked up", function(env)
    local PCR = Boot(env)
    env.Fire("ENCOUNTER_START")
    check("shown before the pool exists", PCR.Core.frame:IsShown(), false)
    env.world.pool = env.Pool(1)
    env.Flush()
    check("shown after the delayed read", PCR.Core.frame:IsShown(), true)
end)

test("secret numbers are drawn without arithmetic", function(env)
    local PCR = Boot(env)
    local pool = env.Pool(2, env.world.now, 600)
    env.world.secret[pool.currentCharges] = true
    env.world.pool = pool
    env.Fire("ENCOUNTER_START")
    env.Tick(1)
    check("shown", PCR.Core.frame:IsShown(), true)
    check("secret flagged", PCR.Pool.secret, true)
    check("label passes the secret through", PCR.ResBar.textManager.nameElement._text, "Battle Res  2")
    check("no timer", PCR.ResBar.textManager.valueElement._text, "")
end)

test("roster lists who can res, greying the dead", function(env)
    env.world.party = {
        { "Tree", "DRUID" }, { "Tank", "WARRIOR" }, { "Lock", "WARLOCK", dead = true },
    }
    local PCR = Boot(env)
    env.world.pool = env.Pool(1)
    env.Fire("CHALLENGE_MODE_START")
    check("roster", PCR.ResBar.roster._text, "<DRUID>Tree  |cff808080Lock|r")
end)

test("dynamic icon follows a party with one kind of res", function(env)
    env.world.party = { { "Tree", "DRUID" }, { "Tank", "WARRIOR" } }
    local PCR = Boot(env)
    env.world.pool = env.Pool(1)
    env.Fire("CHALLENGE_MODE_START")
    check("druid only", PCR.ResBar.icon.texture._texture, "icon:20484")

    env.world.party = { { "Tank", "WARRIOR" }, { "Lock", "WARLOCK" } }
    env.Fire("GROUP_ROSTER_UPDATE")
    check("warlock only", PCR.ResBar.icon.texture._texture, "icon:20707")

    env.world.party = { { "Tree", "DRUID" }, { "Lock", "WARLOCK" } }
    env.Fire("GROUP_ROSTER_UPDATE")
    check("a mix falls back to Rebirth", PCR.ResBar.icon.texture._texture, "icon:20484")

    PCR.Config.iconSpell = "61999"
    PCR.Core:Rebuild()
    check("a fixed choice wins", PCR.ResBar.icon.texture._texture, "icon:61999")
end)

test("preview shows a made-up pool and gives way to a real one", function(env)
    local PCR = Boot(env)
    PCR.Core:TogglePreview()
    check("shown", PCR.Core.frame:IsShown(), true)
    check("preview label", PCR.ResBar.textManager.nameElement._text, "Battle Res  1")
    check("preview timer", PCR.ResBar.textManager.valueElement._text, "4:00")
    check("stand-in roster when alone", #PCR.Roster.members, 3)

    env.world.pool = env.Pool(2)
    env.Fire("ENCOUNTER_START")
    check("preview off", PCR.Core.preview, nil)
    check("real label", PCR.ResBar.textManager.nameElement._text, "Battle Res  2")
    check("real roster", #PCR.Roster.members, 0)
end)

test("edit mode shows the bar and leaving it hides it again", function(env)
    local PCR = Boot(env)
    PCR.Core:SetEditMode(true)
    check("shown in edit mode", PCR.Core.frame:IsShown(), true)
    PCR.Core:SetEditMode(false)
    check("hidden after", PCR.Core.frame:IsShown(), false)
    check("ticker", env.LiveTicker(), nil)
end)

if failures > 0 then
    print(failures .. " failure(s)")
    os.exit(1)
end
print("core: all passed")
