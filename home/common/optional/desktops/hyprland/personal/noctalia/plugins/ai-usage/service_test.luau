-- Run by tests.nix, which prepends SERVICE_SRC.

local function limit(label, percent)
  return { label = label, seconds = 18000, percent = percent, resetAt = os.time() + 3600 }
end

local function document()
  return {
    fetchedAt = os.time(),
    providers = {
      {
        id = "claude",
        name = "Claude",
        accounts = {
          { account = "one@example.com", available = true, limits = { limit("5h", 43), limit("7d", 16) }, models = {} },
          { account = "two@example.com", available = true, limits = { limit("5h", 34), limit("7d", 87) }, models = {} },
        },
      },
      {
        id = "codex",
        name = "Codex",
        accounts = {
          { account = "me@example.com", available = true, limits = { limit("5h", 34), limit("7d", 22) }, models = {} },
        },
      },
    },
  }
end

local function load(doc, outcome)
  local state = {}
  local noctalia = {
    state = {
      get = function(key) return state[key] end,
      set = function(key, value) state[key] = value end,
      watch = function() end,
    },
    runAsync = function(_, callback)
      if outcome == "unstarted" then
        return false
      end
      callback(outcome or { exitCode = 0, stdout = "report", stderr = "" })
      return true
    end,
    log = function() end,
    json = { decode = function() return doc end },
    setUpdateInterval = function() end,
  }
  local env = setmetatable({ noctalia = noctalia }, { __index = _G })
  local chunk = assert(loadstring(SERVICE_SRC))
  setfenv(chunk, env)
  chunk()
  return state, env._internals
end

local state, internals = load(document())
assert(#state.aiUsage.providers == 2, "publishes every provider")
assert(#state.aiUsage.providers[1].accounts == 2, "keeps each Claude account")
assert(state.aiUsage.providers[2].accounts[1].limits[1].percent == 34, "keeps per-account limits")
assert(state.aiUsageError == nil, "no error for a complete report")

local codexOnly = document()
table.remove(codexOnly.providers, 1)
assert(internals.normalise(codexOnly) ~= nil, "accepts a single provider with one account")

local broken = document()
broken.providers[1].accounts[1].limits[1].percent = nil
assert(internals.normalise(broken) == nil, "rejects a limit without a reading")

local windowless = document()
windowless.providers[1].accounts[1].limits[1].seconds = nil
assert(internals.normalise(windowless) == nil, "rejects a limit without a window length")

local empty = document()
empty.providers = {}
assert(internals.normalise(empty) == nil, "rejects a report with no providers")

local unusable = load(nil)
assert(unusable.aiUsageError == "AI usage query returned a report without numeric limits", "reports an unusable report")

local exited = load(document(), { exitCode = 22, stdout = "", stderr = "curl: (22) 401\nmore" })
assert(exited.aiUsageError == "AI usage query exited 22: curl: (22) 401", "reports the exit code and first stderr line")
assert(exited.aiUsage == nil, "publishes nothing from a failed query")

local unstarted = load(document(), "unstarted")
assert(string.find(unstarted.aiUsageError, "Could not start", 1, true), "reports a query that never started")
print("ai-usage service tests passed")
