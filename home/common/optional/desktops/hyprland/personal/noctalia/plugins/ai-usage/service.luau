-- Polls the restricted Grafana token through a local command, keeping it out of plugin state.

local QUERY_COMMAND = "@usageQuery@"
local REFRESH_MS = 5 * 60 * 1000

local inFlight = false
local report = noctalia.state.get("aiUsage")

local function numeric(x)
  return type(x) == "number"
end

-- Accepts any number of providers and accounts; each limit needs numeric readings.
local function normalise(value)
  if type(value) ~= "table" or type(value.providers) ~= "table" or #value.providers == 0 then
    return nil
  end
  for _, provider in ipairs(value.providers) do
    if type(provider.id) ~= "string" or type(provider.accounts) ~= "table" or #provider.accounts == 0 then
      return nil
    end
    for _, account in ipairs(provider.accounts) do
      if type(account.account) ~= "string" or type(account.limits) ~= "table" then
        return nil
      end
      for _, limit in ipairs(account.limits) do
        if not (numeric(limit.percent) and numeric(limit.resetAt) and numeric(limit.seconds)) then
          return nil
        end
      end
    end
  end
  return value
end

local function fail(message)
  noctalia.log("ai-usage: " .. message)
  noctalia.state.set("aiUsageError", message)
end

local function refresh()
  if inFlight then
    return
  end
  inFlight = true

  local started = noctalia.runAsync({ QUERY_COMMAND }, function(result)
    inFlight = false
    if result.exitCode ~= 0 then
      fail(string.format("AI usage query exited %d: %s", result.exitCode, string.match(result.stderr or "", "[^\n]*")))
      return
    end
    local nextReport = normalise(noctalia.json.decode(result.stdout))
    if not nextReport then
      fail("AI usage query returned a report without numeric limits")
      return
    end
    report = nextReport
    noctalia.state.set("aiUsage", report)
    noctalia.state.set("aiUsageError", nil)
  end, 30000)

  if not started then
    inFlight = false
    fail("Could not start the AI usage query " .. QUERY_COMMAND)
  end
end

_internals = { normalise = normalise }

noctalia.state.watch("aiUsageRefresh", refresh)
noctalia.setUpdateInterval(REFRESH_MS)
refresh()

function update()
  refresh()
end
