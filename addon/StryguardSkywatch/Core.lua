local ADDON, ns = ...

-- Saved settings, the slash command, and the flight hooks: open when a flight starts,
-- pause on landing, hide in combat.

local Core = {}
ns.Core = Core

local DEFAULT_OPTS = { autoOpen = true, autoPause = true, auto = true, scale = 1 }

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, ...)
    if Core[event] then Core[event](...) end
end)

function Core.ADDON_LOADED(name)
    if name ~= ADDON then return end
    SkywatchDB = SkywatchDB or {}
    local db = SkywatchDB
    db.best = db.best or {}
    db.opts = db.opts or {}
    db.campaign = db.campaign or {}
    db.shop = db.shop or {}
    db.marks = db.marks or 0
    db.deeds = db.deeds or {}
    db.stats = db.stats or {}
    for k, v in pairs(DEFAULT_OPTS) do
        if db.opts[k] == nil then db.opts[k] = v end
    end
    -- Runs saved by the first version were on the old, smaller maps.
    if type(db.run) == "table" and db.run.v ~= 2 then db.run = nil end
    ns.db = db
    local gift = ns.Meta.Migrate()
    if gift then
        C_Timer.After(5, function()
            print(("|cffffd100Skywatch|r has a campaign now! You get %d marks for your old records: spend them in the shop."):format(gift))
        end)
    end
    events:UnregisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_CONTROL_LOST")
    events:RegisterEvent("PLAYER_CONTROL_GAINED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_LOGOUT")
end

-- A run is saved only between waves; see Game.Snapshot. A won or lost run is let go.
function Core.SaveRun()
    local s = ns.Game.s
    if not s or not ns.db then return end
    if s.over or (s.won and not s.endless) then
        ns.db.run = nil
    elseif s.idle then
        ns.db.run = ns.Game.Snapshot()
    end
end

function Core.FlightTime()
    if Core.flightStart and UnitOnTaxi("player") then return GetTime() - Core.flightStart end
end

function Core.PLAYER_ENTERING_WORLD()
    -- After a reload in the air, keep counting but don't pop the window open again.
    if UnitOnTaxi("player") then
        Core.flying, Core.flightStart = true, Core.flightStart or GetTime()
    end
end

function Core.PLAYER_CONTROL_LOST()
    C_Timer.After(0.6, function()
        if UnitOnTaxi("player") and not Core.flying then
            Core.flying, Core.flightStart = true, GetTime()
            ns.Meta.Count("flights")
            ns.Meta.CheckDeeds("stats")
            if ns.db.opts.autoOpen and not InCombatLockdown() then ns.UI.Show() end
        end
    end)
end

function Core.PLAYER_CONTROL_GAINED()
    C_Timer.After(0.3, function()
        if Core.flying and not UnitOnTaxi("player") then
            Core.flying, Core.flightStart = false, nil
            if ns.db.opts.autoPause then ns.UI.Landed() end
        end
    end)
end

function Core.PLAYER_REGEN_DISABLED()
    ns.UI.Combat()
end

function Core.PLAYER_LOGOUT()
    Core.SaveRun()
end

local function say(msg)
    print("|cffffd100Skywatch|r " .. msg)
end

SLASH_STRYGUARDSKYWATCH1 = "/skywatch"
SLASH_STRYGUARDSKYWATCH2 = "/td"
SlashCmdList.STRYGUARDSKYWATCH = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" then
        ns.UI.Toggle()
    elseif cmd == "scale" and tonumber(arg) then
        local v = math.max(0.5, math.min(2, tonumber(arg)))
        ns.UI.SetScale(v)
        say(("window scale set to %.2f."):format(v))
    elseif cmd == "reset" then
        ns.UI.ResetPosition()
        say("window moved back to the middle of the screen.")
    elseif cmd == "flights" then
        ns.db.opts.autoOpen = arg ~= "off"
        say("opening when a flight starts is " .. (ns.db.opts.autoOpen and "on." or "off."))
    else
        say("commands: /skywatch (open or close), /skywatch scale 0.8, /skywatch reset, /skywatch flights on|off")
    end
end

-- The minimap's addon menu, on clients that have one.
function StryguardSkywatch_OnAddonCompartmentClick()
    ns.UI.Toggle()
end
