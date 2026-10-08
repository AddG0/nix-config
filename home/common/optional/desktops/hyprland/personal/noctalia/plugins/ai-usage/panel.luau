-- Provider tabs on the left (Claude, Codex); on the right cards grouped by limit window or by
-- account, comparing actual usage with the expected pace (share of the window elapsed).

local PROVIDER_GLYPHS = { claude = "sparkles", codex = "brand-openai" }
-- Points ahead of the expected pace before a limit reads as burning too fast.
local AHEAD_WARNING = 15

local report = noctalia.state.get("aiUsage")
local errorMessage = noctalia.state.get("aiUsageError")
local selected = noctalia.state.get("aiUsageTab")
local grouping = noctalia.state.get("aiUsageGrouping") or "window"

local function providers()
  return report and report.providers or {}
end

local function current()
  local list = providers()
  for _, p in ipairs(list) do
    if p.id == selected then
      return p
    end
  end
  return list[1]
end

local function rounded(value)
  return math.floor(value + 0.5)
end

local function duration(seconds)
  seconds = math.max(0, math.floor(seconds))
  local days, hours, minutes = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
  if days > 0 then
    return string.format("%dd %dh", days, hours)
  end
  if hours > 0 then
    return string.format("%dh %dm", hours, minutes)
  end
  return string.format("%dm", minutes)
end

local function secondsLeft(limit)
  return limit.resetAt - os.time()
end

-- "5 hours", "7 days" from the label's own unit, so "7d" never reads as "1 week".
local UNIT_NAMES = { m = "minute", h = "hour", d = "day", w = "week" }

local function windowName(limit)
  local n, unit = string.match(limit.label, "^(%d+)([mhdw])$")
  return string.format("%s %s%s", n, UNIT_NAMES[unit], n == "1" and "" or "s")
end

local function expected(limit)
  return math.max(0, math.min(100, (1 - secondsLeft(limit) / limit.seconds) * 100))
end

-- When the limit runs out if usage keeps its rate so far; nil if it lasts until the reset.
local function exhaustion(limit)
  local left = secondsLeft(limit)
  local elapsed = limit.seconds - left
  if limit.percent >= 100 then
    return "limit reached"
  end
  if elapsed < 60 or limit.percent <= 0 then
    return nil
  end
  local untilFull = (100 - limit.percent) / (limit.percent / elapsed)
  if untilFull >= left then
    return nil
  end
  return "runs out in ~" .. duration(untilFull)
end

local function barColor(actual, expect)
  if actual >= 100 then
    return "error"
  end
  if actual - expect > AHEAD_WARNING then
    return "secondary"
  end
  return "primary"
end

local function shortName(account)
  return string.match(account, "^([^@]+)") or account
end

local STATUS_CHIPS = {
  rejected = { "Limited", "error" },
  allowed_warning = { "Warning", "secondary" },
}

local function chip(text, color)
  return ui.row({ paddingH = 6, paddingV = 1, radius = 6, fill = color .. "/0.18" }, {
    ui.label({ text = text, fontSize = 10, fontWeight = "semibold", color = color }),
  })
end

-- Actual usage with a tick at the expected pace. Keyed: unkeyed boxes reuse old props by position.
local function paceBar(actual, expect, color)
  local segments = {}
  local function segment(key, units, fill)
    if units > 0 then
      table.insert(segments, ui.box({ key = key, height = 6, flexGrow = units, fill = fill }))
    end
  end
  local tick = ui.box({ key = "tick", width = 2, height = 10, fill = "on_surface" })
  actual = math.min(actual, 100)
  local low, high = math.min(actual, expect), math.max(actual, expect)
  segment("onPace", low, color .. "/0.55")
  if actual > expect then
    table.insert(segments, tick)
    segment("ahead", high - low, color)
  else
    segment("behind", high - low, "on_surface/0.22")
    table.insert(segments, tick)
  end
  segment("rest", 100 - high, "on_surface/0.10")
  return ui.row({ flexGrow = 1, align = "center" }, segments)
end

local function accountStatus(account, limit)
  return not account.available and { "Unavailable", "error" } or STATUS_CHIPS[limit.status or ""]
end

local function limitRow(title, limit, status)
  local expect = expected(limit)
  local color = barColor(limit.percent, expect)
  local usage = string.format("%d%% used · %d%% expected", rounded(limit.percent), rounded(expect))
  local runsOut = exhaustion(limit)
  local timing = limit.firstResetAt and "first reset in " .. duration(limit.firstResetAt - os.time())
    or "resets in " .. duration(secondsLeft(limit))
  if runsOut then
    timing = runsOut .. " · " .. timing
  end
  local header = {
    ui.label({ text = title, fontSize = 12, fontWeight = "semibold", color = "on_surface", flexGrow = 1 }),
  }
  if status then
    table.insert(header, chip(status[1], status[2]))
  end
  table.insert(header, ui.label({
    text = string.format("%+d", rounded(limit.percent - expect)),
    fontSize = 13,
    fontWeight = "bold",
    color = color,
  }))
  return ui.column({ gap = 3 }, {
    ui.row({ gap = 6, align = "center" }, header),
    paceBar(limit.percent, expect, color),
    ui.label({ text = usage, fontSize = 11, color = "on_surface_variant" }),
    ui.label({ text = timing, fontSize = 11, color = runsOut and color or "on_surface_variant" }),
  })
end

local function card(title, rows)
  local children = { ui.label({ text = title, fontSize = 13, fontWeight = "bold", color = "on_surface" }) }
  for _, row in ipairs(rows) do
    table.insert(children, row)
  end
  return ui.column({ gap = 10, padding = 12, radius = 12, fill = "surface_variant/0.40", border = "outline/0.08", borderWidth = 1 }, children)
end

-- Every window any of the provider's accounts has, shortest first.
local function windows(provider)
  local seen, list = {}, {}
  for _, account in ipairs(provider.accounts) do
    for _, limit in ipairs(account.limits) do
      if not seen[limit.label] then
        seen[limit.label] = true
        table.insert(list, limit)
      end
    end
  end
  table.sort(list, function(a, b)
    return a.seconds < b.seconds
  end)
  return list
end

-- The accounts as one pool: averaging reset times averages their expected pace too.
local function pooled(limits)
  local percent, resetAt, firstResetAt = 0, 0, math.huge
  for _, limit in ipairs(limits) do
    percent += limit.percent / #limits
    resetAt += limit.resetAt / #limits
    firstResetAt = math.min(firstResetAt, limit.resetAt)
  end
  return { seconds = limits[1].seconds, percent = percent, resetAt = resetAt, firstResetAt = firstResetAt }
end

local function windowCard(provider, window)
  local rows, limits = {}, {}
  for _, account in ipairs(provider.accounts) do
    for _, limit in ipairs(account.limits) do
      if limit.label == window.label then
        table.insert(rows, limitRow(shortName(account.account), limit, accountStatus(account, limit)))
        table.insert(limits, limit)
      end
    end
  end
  if #limits > 1 then
    table.insert(rows, 1, limitRow("All accounts", pooled(limits)))
  end
  return card(windowName(window), rows)
end

-- Per-account extras that aren't windows: overage and per-model quotas.
local function extras(account)
  local lines = {}
  if account.overage then
    local o = account.overage
    local state = (o.status == "rejected" or o.limit <= 0) and "off" or string.format("of $%.2f", o.limit)
    table.insert(lines, ui.label({ text = string.format("Overage $%.2f used · %s", o.used, state), fontSize = 11, color = "on_surface_variant" }))
  end
  for _, model in ipairs(account.models) do
    table.insert(lines, ui.label({ text = string.format("%s %s · %d%%", model.model, model.label, rounded(model.percent)), fontSize = 11, color = "on_surface_variant" }))
  end
  return lines
end

local function accountCard(account)
  local rows = {}
  for _, limit in ipairs(account.limits) do
    table.insert(rows, limitRow(windowName(limit), limit, accountStatus(account, limit)))
  end
  local lines = extras(account)
  if #lines > 0 then
    table.insert(rows, ui.column({ gap = 2 }, lines))
  end
  return card(shortName(account.account), rows)
end

local function accountsCard(provider)
  local rows = {}
  for _, account in ipairs(provider.accounts) do
    local lines = extras(account)
    if #lines > 0 then
      table.insert(lines, 1, ui.label({ text = shortName(account.account), fontSize = 12, fontWeight = "semibold", color = "on_surface" }))
      table.insert(rows, ui.column({ gap = 2 }, lines))
    end
  end
  return #rows > 0 and card("Accounts", rows) or nil
end

local function updatedText()
  local minutes = math.floor(math.max(0, os.time() - report.fetchedAt) / 60)
  return minutes < 1 and "Updated just now" or string.format("Updated %dm ago", minutes)
end

local render

local function groupingToggle()
  local buttons = {}
  for _, option in ipairs({ { "window", "By window", "clock" }, { "account", "By account", "user" } }) do
    table.insert(buttons, ui.button({
      key = option[1],
      text = option[2],
      glyph = option[3],
      variant = grouping == option[1] and "secondary" or "ghost",
      contentAlign = "start",
      onClick = function()
        grouping = option[1]
        noctalia.state.set("aiUsageGrouping", grouping)
        render()
      end,
    }))
  end
  return ui.column({ gap = 4 }, buttons)
end

local function tabs(active)
  local column = {
    ui.row({ gap = 6, align = "center" }, {
      ui.glyph({ name = "brain", size = 16, color = "primary" }),
      ui.label({ text = "AI usage", fontSize = 14, fontWeight = "bold", color = "on_surface" }),
    }),
  }
  for _, provider in ipairs(providers()) do
    table.insert(column, ui.button({
      key = provider.id,
      text = provider.name,
      glyph = PROVIDER_GLYPHS[provider.id] or "robot",
      variant = provider.id == active.id and "secondary" or "ghost",
      contentAlign = "start",
      onClick = function()
        selected = provider.id
        noctalia.state.set("aiUsageTab", selected)
        render()
      end,
    }))
  end
  table.insert(column, ui.spacer({ flexGrow = 1 }))
  -- One account has nothing to compare per window, so it only gets the account view.
  if #active.accounts > 1 then
    table.insert(column, groupingToggle())
  end
  if errorMessage then
    table.insert(column, ui.label({ text = errorMessage, fontSize = 11, color = "error" }))
  end
  table.insert(column, ui.label({ text = updatedText(), fontSize = 11, color = "on_surface_variant" }))
  return ui.column({ width = 150, gap = 6 }, column)
end

function render()
  local active = current()
  if not active then
    panel.render(ui.column({ flexGrow = 1, gap = 8, padding = 14 }, {
      ui.label({ text = "AI usage", fontSize = 15, fontWeight = "bold", color = "on_surface" }),
      ui.label({ text = errorMessage or "Waiting for the first usage reading", color = errorMessage and "error" or "on_surface_variant" }),
    }))
    return
  end
  local cards = {}
  if #active.accounts > 1 and grouping == "window" then
    for _, window in ipairs(windows(active)) do
      table.insert(cards, windowCard(active, window))
    end
    local summary = accountsCard(active)
    if summary then
      table.insert(cards, summary)
    end
  else
    for _, account in ipairs(active.accounts) do
      table.insert(cards, accountCard(account))
    end
  end
  panel.render(ui.row({ flexGrow = 1, gap = 14, padding = 4 }, {
    tabs(active),
    ui.scroll({ flexGrow = 1, gap = 10 }, cards),
  }))
end

noctalia.state.watch("aiUsage", function(value)
  report = value
  render()
end)
noctalia.state.watch("aiUsageError", function(value)
  errorMessage = value
  render()
end)

function onOpen()
  noctalia.state.set("aiUsageRefresh", noctalia.nowMs())
  panel.setWantsSecondTicks(true)
  render()
end

function onClose()
  panel.setWantsSecondTicks(false)
end

function update()
  render()
end

render()
