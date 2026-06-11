-- Noctalia scripted bar widget: shows the next upcoming calendar event
-- ("Standup · 25m") and opens the Control Center calendar panel on click.
--
-- Noctalia 5 has no calendar IPC, but the in-app CalDAV/Google accounts write
-- every resolved event instance to a JSON cache. We read that cache and let jq
-- pick + format the next not-yet-finished, timed event. @jq@ / @noctalia@ are
-- substituted with absolute Nix store paths at build time (substituteAll), so
-- the widget does not depend on the session PATH.

barWidget.define({
  label = "Next event",
  version = "1.0.0",
  icon = "calendar-month",
  description = "Shows the next upcoming calendar event from Noctalia's cache",
  settings = {
    { key = "max_chars", type = "int", label = "Max title length", default = 22, min = 6, max = 60 },
    { key = "refresh_seconds", type = "int", label = "Refresh interval (s)", default = 30, min = 5, max = 600 },
    -- Notion-style: only surface an event once it starts within this many
    -- minutes. Ongoing events always show regardless of the window. 0 disables
    -- the limit (show the next event no matter how far out).
    { key = "lookahead_minutes", type = "int", label = "Show within (min)", default = 30, min = 0, max = 1440 },
    { key = "hide_when_empty", type = "bool", label = "Hide when nothing is upcoming", default = false },
  },
})

local JQ = "@jq@"

local function cfg(key, default)
  return barWidget.getConfig(key, default)
end

-- POSIX-safe single-quote shell escaping: a'b -> 'a'\''b'.
local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function cachePath()
  local xdg = noctalia.getenv("XDG_CACHE_HOME")
  if xdg and xdg ~= "" then
    return xdg .. "/noctalia/calendar/events.json"
  end
  return (noctalia.getenv("HOME") or "") .. "/.cache/noctalia/calendar/events.json"
end

-- Emits "<title> · <relative>\t<title> — <Day HH:MM>–<HH:MM>[ @ location]".
-- The tab separates the bar label (field 1) from the richer tooltip (field 2).
-- $lookahead is a window in seconds (0 = unlimited). An event qualifies when it
-- has not finished and either is already running or starts within the window.
local FILTER = [==[
[ .events[]
  | select((.all_day // false) | not)
  | select(.end > $now)
  | select($lookahead == 0 or (.start - $now) <= $lookahead) ]
| sort_by(.start) | .[0]
| if . == null then "" else
    . as $e | ($e.start - $now) as $d
    | (if $d <= 0 then "now"
       elif $d < 3600 then "\(($d/60)|floor)m"
       elif $d < 86400 then "\(($d/3600)|floor)h\((($d%3600)/60)|floor)m"
       else "\(($d/86400)|floor)d" end) as $rel
    | "\($e.title[0:$max]) · \($rel)\t\($e.title) — \($e.start|strflocaltime("%a %H:%M"))–\($e.end|strflocaltime("%H:%M"))\(if (($e.location // "") != "") then " @ " + $e.location else "" end)"
  end
]==]

local function applyEmpty()
  barWidget.setText("")
  barWidget.clearTooltip()
  barWidget.setVisible(not cfg("hide_when_empty", false))
end

local function refresh()
  local cmd = string.format(
    "%s -r --argjson now %d --argjson max %d --argjson lookahead %d %s %s",
    JQ, os.time(), cfg("max_chars", 22), cfg("lookahead_minutes", 30) * 60,
    shellQuote(FILTER), shellQuote(cachePath())
  )
  noctalia.runAsync(cmd, function(result)
    if result.exitCode ~= 0 then
      applyEmpty()
      return
    end
    local out = (result.stdout or ""):gsub("%s+$", "")
    if out == "" then
      applyEmpty()
      return
    end
    local text, tip = out:match("^(.-)\t(.*)$")
    barWidget.setVisible(true)
    barWidget.setText(text or out)
    if tip and tip ~= "" then
      barWidget.setTooltip(tip)
    else
      barWidget.clearTooltip()
    end
  end)
end

barWidget.setGlyph("calendar-month")
barWidget.setUpdateInterval(cfg("refresh_seconds", 30) * 1000)
refresh()

function update()
  refresh()
end

-- Reuse the same panel the clock opens, so the widget doubles as a calendar button.
function onClick()
  noctalia.runAsync("@noctalia@ msg panel-toggle control-center calendar")
end
