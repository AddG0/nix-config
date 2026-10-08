-- Compact combined view: Claude's usage above its expected pace, with points ahead of that pace.

-- Points ahead of pace that read as burning too fast; same as the panel.
local AHEAD_WARNING = 15

local report = noctalia.state.get("aiUsage")
local errorMessage = noctalia.state.get("aiUsageError")

-- Claude's limit averaged across its accounts; capacity returns at the soonest reset.
local function window(label)
  local used, expected, count, resetAt = 0, 0, 0, math.huge
  for _, provider in ipairs(report and report.providers or {}) do
    if provider.id == "claude" then
      for _, account in ipairs(provider.accounts) do
        for _, limit in ipairs(account.limits) do
          if limit.label == label then
            used += limit.percent
            expected += math.max(0, math.min(100, (1 - (limit.resetAt - os.time()) / limit.seconds) * 100))
            count += 1
            resetAt = math.min(resetAt, limit.resetAt)
          end
        end
      end
    end
  end
  if count == 0 then
    return nil
  end
  return { percent = used / count, expected = expected / count, resetAt = resetAt }
end

local function rounded(value)
  return math.floor(value + 0.5)
end

local function countdown(resetAt)
  local seconds = math.max(0, math.floor(resetAt - os.time()))
  local hours, minutes = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
  if hours >= 24 then
    return string.format("%dd", math.floor(hours / 24))
  end
  return string.format("%dh %dm", hours, minutes)
end

local function color(item)
  if item.percent >= 100 then
    return "error"
  end
  if item.percent - item.expected > AHEAD_WARNING then
    return "secondary"
  end
  return "primary"
end

local function gauge(item)
  return ui.column({ gap = 1, width = 30 }, {
    ui.progress({ progress = math.min(item.percent / 100, 1), fill = color(item), track = "on_surface/0.12", radius = 3, height = 5 }),
    ui.progress({ progress = item.expected / 100, fill = "on_surface/0.45", track = "on_surface/0.10", radius = 2, height = 3 }),
  })
end

local function ahead(item)
  return string.format("%+d", rounded(item.percent - item.expected))
end

local function summary(item)
  return string.format("%d%% used · %d%% expected · capacity returns in %s", rounded(item.percent), rounded(item.expected), countdown(item.resetAt))
end

local function render()
  local short, weekly = window("5h"), window("7d")
  -- Hidden without fresh data: a stale or empty widget gives nothing to act on.
  if errorMessage or not short or not weekly then
    barWidget.setVisible(false)
    return
  end

  barWidget.setVisible(true)
  barWidget.render(ui.row({ gap = 5, align = "center" }, {
    ui.glyph({ name = "brain", size = 14, color = "on_surface" }),
    gauge(short),
    ui.label({ text = "5h " .. ahead(short), fontSize = 11, fontWeight = "semibold", color = color(short) }),
    gauge(weekly),
    ui.label({ text = "7d " .. ahead(weekly), fontSize = 11, fontWeight = "semibold", color = color(weekly) }),
  }))
  barWidget.setTooltip({
    { key = "5 hour average", value = summary(short) },
    { key = "7 day average", value = summary(weekly) },
  })
end

noctalia.state.watch("aiUsage", function(value)
  report = value
  render()
end)
noctalia.state.watch("aiUsageError", function(value)
  errorMessage = value
  render()
end)

function onClick()
  noctalia.state.set("aiUsageRefresh", noctalia.nowMs())
  noctalia.togglePanel("addg/ai-usage:details")
end

noctalia.setUpdateInterval(30000)
render()

function update()
  render()
end
