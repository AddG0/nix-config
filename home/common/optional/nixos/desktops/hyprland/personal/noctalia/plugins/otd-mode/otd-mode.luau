-- Bar widget: shows the current OpenTabletDriver output mode as an icon and
-- cycles Absolute -> Relative -> Artist on click; hidden when the tablet is
-- unplugged. @otd@ / @journalctl@ are baked absolute paths (runAsync has no PATH).
--
-- setoutputmode is live-only (never writes settings.json), so a daemon restart
-- reverts to the GUI-saved mode; the live mode is read back from the journal.

local OTD = "@otd@"
local JOURNALCTL = "@journalctl@"
local TABLET = "Wacom PTK-670"
local HID = "000003F7" -- USB product id of the Intuos Pro M twin-dial pad

-- Cycling into Artist Mode loses dial scroll (OTD can't scroll in Artist).
local ORDER = {"Absolute", "Relative", "Artist"}
local INFO = {
  Absolute = {glyph = "pointer", path = "OpenTabletDriver.Desktop.Output.AbsoluteMode", tip = "Absolute Mode"},
  Relative = {glyph = "mouse", path = "OpenTabletDriver.Desktop.Output.RelativeMode", tip = "Relative Mode"},
  Artist = {glyph = "brush", path = "OpenTabletDriver.Desktop.Output.LinuxArtistMode", tip = "Artist Mode"},
}

local current = nil

local function getInt(key, fallback)
  local v = noctalia.getConfig(key)
  if type(v) == "number" then
    return v
  end
  return fallback
end

-- POSIX single-quote escaping: a'b -> 'a'\''b'.
local function shellQuote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function apply(mode)
  local info = INFO[mode]
  if not info then
    return
  end
  current = mode
  barWidget.setVisible(true)
  barWidget.setGlyph(info.glyph)
  barWidget.setText("")
  barWidget.setTooltip(info.tip)
end

-- The hidraw guard emits the mode only while the pad is present, so the widget
-- hides itself when the tablet is unplugged.
local function refresh()
  local cmd = string.format(
    "grep -qs %s /sys/class/hidraw/*/device/uevent && %s --user -u opentabletdriver.service -r -n 1 -g 'Output mode:' --no-pager -o cat",
    HID, JOURNALCTL
  )
  noctalia.runAsync(cmd, function(result)
    local out = result and result.stdout and result.stdout:gsub("%s+$", "") or ""
    if out == "" then
      current = nil
      return barWidget.setVisible(false)
    end
    if out:find("Absolute") then
      apply("Absolute")
    elseif out:find("Relative") then
      apply("Relative")
    elseif out:find("Artist") then
      apply("Artist")
    else
      barWidget.setVisible(false)
    end
  end)
end

-- Start hidden; refresh() reveals it only once the tablet is confirmed present.
barWidget.setVisible(false)

function update()
  noctalia.setUpdateInterval(getInt("refresh_seconds", 5) * 1000)
  refresh()
end

-- OTD recreates its virtual device on every switch, so overlapping switches
-- thrash it — hence the in-flight guard.
local switching = false

function onClick()
  if switching then
    return
  end
  local idx = 1
  for i, m in ipairs(ORDER) do
    if m == current then
      idx = i
    end
  end
  local nextMode = ORDER[(idx % #ORDER) + 1]
  switching = true
  apply(nextMode) -- optimistic; refresh() below confirms from the daemon
  -- Live-only: reverts to the module's defaultOutputMode on daemon restart.
  noctalia.runAsync(
    string.format("%s setoutputmode %s %s", OTD, shellQuote(TABLET), INFO[nextMode].path),
    function()
      switching = false
      refresh()
    end
  )
end
