local settings = require("sbar-config-libs/settings")
local colors = require("sbar-config-libs/colors")

local popup_width = 280
local meeting_url = nil

local next_event = sbar.add("item", {
  icon = {
    color = colors.white,
    padding_left = 8,
    padding_right = 0,
    font = {
      style = settings.font.style_map["Bold"],
      size = 11.0,
    },
    string = "􀉉",
  },
  label = {
    color = colors.white,
    padding_right = 8,
    font = { family = settings.font.numbers, size = 12.0 },
    max_chars = 30,
  },
  position = "right",
  padding_left = 1,
  padding_right = 1,
  update_freq = 60,
  background = {
    color = colors.bg2,
    border_color = colors.black,
    border_width = 1
  },
  popup = { align = "center", height = 30 }
})

-- Popup items
local popup_title = sbar.add("item", {
  position = "popup." .. next_event.name,
  icon = { drawing = false },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 14,
    },
    max_chars = 30,
    string = "",
    color = colors.white,
  },
  width = popup_width,
  align = "center",
  background = {
    height = 2,
    color = colors.grey,
    y_offset = -15,
  },
})

local popup_time = sbar.add("item", {
  position = "popup." .. next_event.name,
  icon = {
    align = "left",
    string = "Time:",
    width = popup_width / 3,
    font = { style = settings.font.style_map["Bold"] },
  },
  label = {
    string = "",
    width = popup_width * 2 / 3,
    align = "right",
  },
})

local popup_countdown = sbar.add("item", {
  position = "popup." .. next_event.name,
  icon = {
    align = "left",
    string = "Starts in:",
    width = popup_width / 3,
    font = { style = settings.font.style_map["Bold"] },
  },
  label = {
    string = "",
    width = popup_width * 2 / 3,
    align = "right",
  },
})

local popup_join = sbar.add("item", {
  position = "popup." .. next_event.name,
  drawing = false,
  icon = {
    string = "􀍃",
    color = colors.white,
    font = { size = 14 },
  },
  label = {
    string = "Join Meeting",
    color = colors.white,
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 13,
    },
  },
  width = popup_width,
  align = "center",
  background = {
    color = colors.green,
    corner_radius = 6,
    height = 26,
  },
})

sbar.add("bracket", { next_event.name }, {
  background = {
    color = colors.transparent,
    height = 30,
    border_color = colors.grey,
  }
})

sbar.add("item", { position = "right", width = settings.group_paddings })

local function format_relative(seconds)
  if seconds < 0 then return "now" end
  if seconds < 60 then return "<1m" end
  if seconds < 3600 then return math.floor(seconds / 60) .. "m" end
  local hrs = math.floor(seconds / 3600)
  local mins = math.floor((seconds % 3600) / 60)
  return mins > 0 and (hrs .. "h " .. mins .. "m") or (hrs .. "h")
end

local function extract_meeting_url(text)
  if not text then return nil end
  return text:match("https://meet%.google%.com/%S+")
      or text:match("https://zoom%.us/%S+")
      or text:match("https://%S+%.zoom%.us/%S+")
      or text:match("https://teams%.microsoft%.com/%S+")
end

local function update_event()
  -- Get the short version for the bar label
  sbar.exec("icalBuddy -n -li 1 -npn -nc -nrd -ps '/ - /' -eed -po 'datetime,title' -tf '%H:%M' -df '' eventsToday 2>/dev/null", function(result)
    if not result or result == "" then
      next_event:set({ drawing = false })
      return
    end

    local time_str, title = result:match("^(%S+)%s*-%s*(.+)")
    if not title then
      next_event:set({ label = result:gsub("%s+$", ""), drawing = true })
      return
    end

    title = title:gsub("%s+$", "")
    local h, m = time_str:match("(%d+):(%d+)")
    if not h then
      next_event:set({ label = title, drawing = true })
      return
    end

    local now = os.time()
    local event_time = os.time({
      year = os.date("%Y"), month = os.date("%m") + 0,
      day = os.date("%d") + 0, hour = h + 0, min = m + 0, sec = 0
    })
    local diff = event_time - now
    local relative = format_relative(diff)
    next_event:set({ label = relative .. " - " .. title, drawing = true })

    -- Format 12h time for popup
    local hour = tonumber(h)
    local ampm = hour >= 12 and "PM" or "AM"
    if hour > 12 then hour = hour - 12 end
    if hour == 0 then hour = 12 end
    local time_12h = string.format("%d:%s %s", hour, m, ampm)

    popup_title:set({ label = title })
    popup_time:set({ label = time_12h })
    popup_countdown:set({ label = relative })
  end)

  -- Get full event details for meeting URL
  sbar.exec("icalBuddy -n -li 1 -npn -nc -nrd -eed -po 'notes,url,location' eventsToday 2>/dev/null", function(result)
    meeting_url = extract_meeting_url(result)
    popup_join:set({ drawing = meeting_url ~= nil })
  end)
end

next_event:subscribe("mouse.clicked", function(env)
  next_event:set({ popup = { drawing = "toggle" } })
end)

popup_join:subscribe("mouse.clicked", function(env)
  if meeting_url then
    sbar.exec("open '" .. meeting_url .. "'")
    next_event:set({ popup = { drawing = false } })
  end
end)

next_event:subscribe({ "forced", "routine", "system_woke" }, function(env)
  update_event()
end)
