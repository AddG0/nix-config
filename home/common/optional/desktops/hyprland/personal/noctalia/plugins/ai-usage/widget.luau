-- Compact combined view: each provider's usage above its expected pace, with points ahead of that pace.

-- Same glyphs as the panel; Tabler has no Claude logo.
local PROVIDER_GLYPHS = { claude = "sparkles", codex = "brand-openai" }

-- Points ahead of pace that read as burning too fast; same as the panel.
local AHEAD_WARNING = 15

local report = noctalia.state.get("aiUsage")
local errorMessage = noctalia.state.get("aiUsageError")

-- The pacer resumes a paused account within the week, so it only counts toward weekly windows.
local PAUSE_SECONDS = 7 * 24 * 3600

-- A provider's limit averaged across the accounts that can use it; capacity returns at the soonest reset.
local function window(provider, label)
  local used, expected, count, resetAt = 0, 0, 0, math.huge
  for _, account in ipairs(provider.accounts) do
    for _, limit in ipairs(account.limits) do
      local pooled = account.available or (account.paused and limit.seconds >= PAUSE_SECONDS)
      if pooled and limit.label == label then
        used += limit.percent
        expected += math.max(0, math.min(100, (1 - (limit.resetAt - os.time()) / limit.seconds) * 100))
        count += 1
        resetAt = math.min(resetAt, limit.resetAt)
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

local WINDOWS = { { "5h", "5 hour average" } }

local function render()
  -- Hidden only when the query failed: there is nothing to report at all.
  if errorMessage or not report then
    barWidget.setVisible(false)
    return
  end

  local row, tooltip = {}, {}
  for _, provider in ipairs(report.providers) do
    table.insert(row, ui.glyph({ name = PROVIDER_GLYPHS[provider.id] or "robot", size = 14, color = "on_surface" }))
    local draining = {}
    for _, account in ipairs(provider.accounts) do
      if account.draining then
        table.insert(draining, (account.account:match("^[^@]+") or account.account))
      end
    end
    if #draining > 0 then
      table.insert(row, ui.glyph({ name = "flame", size = 12, color = "primary" }))
      table.insert(tooltip, { key = provider.name .. " draining", value = table.concat(draining, ", ") })
    end
    local shown = false
    for _, w in ipairs(WINDOWS) do
      local item = window(provider, w[1])
      if item then
        shown = true
        table.insert(row, gauge(item))
        table.insert(row, ui.label({ text = w[1] .. " " .. ahead(item), fontSize = 11, fontWeight = "semibold", color = color(item) }))
        table.insert(tooltip, { key = provider.name .. " " .. w[2], value = summary(item) })
      end
    end
    if not shown then
      table.insert(row, ui.label({ text = "unavailable", fontSize = 11, fontWeight = "semibold", color = "error" }))
      table.insert(tooltip, { key = provider.name, value = "No account is available" })
    end
  end
  barWidget.setVisible(true)
  barWidget.render(ui.row({ gap = 5, align = "center" }, row))
  barWidget.setTooltip(tooltip)
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
