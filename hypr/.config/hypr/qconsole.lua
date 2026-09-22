-- The scratchpad as a Quake console (ported from Omarchy's default/hypr/qconsole.lua):
-- a dimmed panel that drops down over the current workspace. SUPER + S toggles it;
-- the first time it opens empty it starts Claude Code (scripts/agent) in ~/Work.

-- How much of the usable screen height the console covers, from the top
local share = 0.5

-- A single window is boxed into a centered panel this many times wider than tall;
-- a second tiled window gets the full width back
local box = 2

local SCRATCHPAD = "special:scratchpad"

-- Seed on first open rather than at boot, so nothing runs until it's wanted. The exec
-- rule pins the workspace itself, since the spawn isn't tagged with where it came from.
local seed = "[workspace special:scratchpad silent] ~/.config/hypr/scripts/agent"

-- Dimming only applies while a special workspace is open
hl.config({
    decoration = {
        dim_special = 0.6,
    },
})

-- The panel is flush with the top and centered, so it's described by the gap down each
-- side and the gap underneath. Only rewrite the rule when those actually change.
local beside, below = nil, nil

local function cover(side, bottom)
    if beside == side and below == bottom then
        return false
    end
    beside, below = side, bottom

    hl.workspace_rule({
        workspace = SCRATCHPAD,
        gaps_in   = 0,
        gaps_out  = { top = 0, right = side, bottom = bottom, left = side },
        no_border = true,

        on_created_empty = seed,
    })

    return true
end

-- Only tiled windows count: the gaps size the panel, floating windows aren't laid out by them
local function alone()
    local tiled = 0
    for _, window in ipairs(hl.get_workspace_windows(SCRATCHPAD)) do
        if not window.floating then
            tiled = tiled + 1
        end
    end
    return tiled <= 1
end

-- Sized by gaps rather than a window rule, which Hyprland resolves once as the window
-- maps; gaps follow the monitor when it's rescaled
local function fit(monitor)
    -- A monitor whose output has gone away answers nil to every field
    if not monitor or not monitor.scale or monitor.scale <= 0 then
        return false
    end

    -- Quarter turns swap the work area
    local width, height = monitor.width, monitor.height
    if monitor.transform % 2 == 1 then
        width, height = height, width
    end

    -- Dimensions are physical pixels; gaps and the reserved area are logical
    local reserved = monitor.reserved
    height = height / monitor.scale - reserved.top - reserved.bottom
    width  = width / monitor.scale - reserved.left - reserved.right

    local tall = math.floor(height * share)
    local wide = width
    if alone() then
        wide = math.min(width, tall * box)
    end

    return cover(math.floor((width - wide) / 2), math.floor(height - tall))
end

-- A showing console keeps the geometry of its output; a hidden one is sized for the
-- output that will show it next
local function console_monitor()
    local ws  = hl.get_workspace(SCRATCHPAD)
    local mon = ws and ws.visible and ws.monitor

    if mon and mon.scale and mon.scale > 0 then
        return mon
    end

    return hl.get_active_monitor()
end

local function refit(monitor)
    if fit(monitor or console_monitor()) then
        -- Land the new gaps now, so the console doesn't visibly resize after dropping down
        hl.exec_scheduled_prop_refresh_immediately()
    end
end

-- Cover the whole work area until a monitor can be read, so the seed never lacks its rule
cover(0, 0)
fit(console_monitor())

hl.on("monitor.layout_changed", function() refit() end)
hl.on("monitor.focused", function() refit() end)

-- Special workspaces open on the monitor they're toggled on, so use the one handed in
hl.on("workspace.special_active", function(ws, mon)
    if ws and ws.name == SCRATCHPAD then
        refit(mon)
    end
end)

hl.on("workspace.move_to_monitor", function(ws, mon)
    if ws and ws.name == SCRATCHPAD then
        refit(mon)
    end
end)

-- Recount tiled windows as apps come and go, move on or off, or float/tile, but only
-- while the console is showing (it's refitted on its way in otherwise)
local function recount()
    local ws = hl.get_workspace(SCRATCHPAD)
    if ws and ws.visible then
        refit()
    end
end

hl.on("window.open", recount)
hl.on("window.destroy", recount)
hl.on("window.move_to_workspace", recount)
hl.on("window.update_rules", recount)
