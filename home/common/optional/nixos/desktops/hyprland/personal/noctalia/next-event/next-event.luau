-- Bar widget: next upcoming event ("Standup · 25m"), or the bare calendar icon
-- when nothing is close. Reads Noctalia's own event cache (the in-app accounts
-- write it). @noctalia@ / @jq@ are absolute binary paths substituted at build
-- time (runAsync inherits no PATH).
--
-- The cache holds every resolved instance (~2k events, hundreds of KB). Decoding
-- that whole blob inside a script callback blows Noctalia's fixed execution
-- budget ("update timed out" → the widget gets disabled), so jq does the heavy
-- filtering in a separate process and we only decode the handful it returns.

local JQ = "@jq@"

local function getInt(key, fallback)
  local v = barWidget.getConfig(key)
  if type(v) == "number" then
    return v
  end
  return fallback
end

local function cachePath()
  local xdg = noctalia.getenv("XDG_CACHE_HOME")
  if xdg and xdg ~= "" then
    return xdg .. "/noctalia/calendar/events.json"
  end
  return (noctalia.getenv("HOME") or "") .. "/.cache/noctalia/calendar/events.json"
end

-- POSIX-safe single-quote shell escaping: a'b -> 'a'\''b'.
local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- Sliced small so what we decode stays tiny no matter how big the cache grows.
local FILTER = [==[
{ events: [ .events[]
    | select((.all_day // false) | not)
    | select(.end > $now)
    | {start, end, title, location} ]
  | sort_by(.start) | .[0:12] }
]==]

-- Relative time until an event, mirroring the old jq formatter.
local function relTime(d)
  if d <= 0 then
    return "now"
  elseif d < 3600 then
    return string.format("%dm", math.floor(d / 60))
  elseif d < 86400 then
    return string.format("%dh%dm", math.floor(d / 3600), math.floor((d % 3600) / 60))
  end
  return string.format("%dd", math.floor(d / 86400))
end

-- Nothing close: keep just the bare calendar icon on the bar.
local function applyEmpty()
  barWidget.setGlyph("calendar-month")
  barWidget.setText("")
  barWidget.clearTooltip()
  barWidget.setVisible(true)
end

local function render(events, now)
  local lookahead = getInt("lookahead_minutes", 30) * 60
  local maxChars = getInt("max_chars", 22)

  -- jq guarantees these are unfinished timed events, so no guards needed here.
  local ongoing, upcoming = nil, nil
  for _, e in ipairs(events) do
    if e.start <= now then
      if ongoing == nil or e.start < ongoing.start then ongoing = e end
    elseif upcoming == nil or e.start < upcoming.start then
      upcoming = e
    end
  end

  -- Primary line: the meeting we're in, else the next one once it's in the window.
  local primary = ongoing
  if primary == nil and upcoming ~= nil and (lookahead == 0 or (upcoming.start - now) <= lookahead) then
    primary, upcoming = upcoming, nil
  end
  if primary == nil then
    return applyEmpty()
  end

  -- While in a meeting, also flag the next one when it's close (back-to-back heads-up).
  local nextClose = ongoing ~= nil and upcoming ~= nil and (lookahead == 0 or (upcoming.start - now) <= lookahead)

  local function trunc(t)
    t = t or ""
    if #t > maxChars then
      t = string.sub(t, 1, maxChars)
    end
    return t
  end

  local function tipFor(e)
    local s = string.format("%s — %s–%s", e.title or "", os.date("%a %I:%M %p", e.start), os.date("%I:%M %p", e["end"]))
    if e.location and e.location ~= "" then
      s = s .. " @ " .. e.location
    end
    return s
  end

  local text = string.format("%s · %s", trunc(primary.title), relTime(primary.start - now))
  local tip = tipFor(primary)
  if nextClose then
    text = text .. string.format(" → %s · %s", trunc(upcoming.title), relTime(upcoming.start - now))
    tip = tip .. "\n" .. tipFor(upcoming)
  end

  barWidget.setVisible(true)
  barWidget.setGlyph("calendar-month")
  barWidget.setText(text)
  barWidget.setTooltip(tip)
end

local function refresh()
  local now = os.time()
  local cmd = string.format(
    "%s -c --argjson now %d %s %s",
    JQ, now, shellQuote(FILTER), shellQuote(cachePath())
  )
  noctalia.runAsync(cmd, function(result)
    if not result or result.exitCode ~= 0 then
      return applyEmpty()
    end
    local out = (result.stdout or ""):gsub("%s+$", "")
    if out == "" then
      return applyEmpty()
    end
    local data = noctalia.json.decode(out)
    if type(data) ~= "table" or type(data.events) ~= "table" then
      return applyEmpty()
    end
    render(data.events, now)
  end)
end

-- Immediate icon before the first interval tick.
barWidget.setGlyph("calendar-month")

function update()
  noctalia.setUpdateInterval(getInt("refresh_seconds", 30) * 1000)
  refresh()
end

-- Reuse the panel the clock opens, so the widget doubles as a calendar button.
function onClick()
  noctalia.runAsync("@noctalia@ msg panel-toggle control-center calendar")
end
