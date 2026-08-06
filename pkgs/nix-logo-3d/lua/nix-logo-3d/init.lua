-- Animated 3D nix snowflake for the snacks dashboard.
--
-- Drawn as extmarks in the dashboard buffer rather than through a snacks
-- `terminal` section: that needs a long-lived process behind a float, and snacks
-- orphans those floats on re-render.

local M = {}

local ns = vim.api.nvim_create_namespace("nix_logo_3d")
local data, groups
local timers = {} ---@type table<integer, uv.uv_timer_t>

local function load()
  data = data or require("nix-logo-3d.frames")
  return data
end

local function define_highlights()
  groups = {}
  for i, pair in ipairs(load().palette) do
    local name = "NixLogo3d" .. i
    vim.api.nvim_set_hl(0, name, {
      fg = pair[1] or nil,
      bg = pair[2] or nil,
    })
    groups[i] = name
  end
end

-- :colorscheme clears every highlight group, and stylix applies one late.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("nix_logo_3d", { clear = true }),
  callback = function()
    if groups then
      define_highlights()
    end
  end,
})

---Stop animating `buf` and clear the frame it left behind.
---@param buf integer
function M.detach(buf)
  local timer = timers[buf]
  if timer then
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
    timers[buf] = nil
  end
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
  end
end

local function draw(buf, row, frame, cols)
  local lines = vim.api.nvim_buf_get_lines(buf, row, row + #frame, false)
  for i, chunks in ipairs(frame) do
    local virt = {}
    for j, run in ipairs(chunks) do
      virt[j] = run[2] > 0 and { run[1], groups[run[2]] } or { run[1] }
    end
    -- Derive the column from the reserved line rather than from the position
    -- snacks reports: that one is an offset into the assembled line, which in a
    -- window narrower than the dashboard lands past the end and draws nothing.
    local line = lines[i]
    if line then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, row + i - 1, math.max(#line - cols, 0), {
        id = i,
        virt_text = virt,
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end
  end
end

---Start animating at `pos` ({row, col}, 1-indexed) in the dashboard buffer.
---@param buf integer
---@param pos integer[]
function M.attach(buf, pos)
  local d = load()
  if not groups then
    define_highlights()
  end
  -- A re-render reuses the buffer; two timers would fight over the extmarks.
  M.detach(buf)

  local row = pos[1] - 1
  local frame, count = 1, #d.frames
  local timer = assert(vim.uv.new_timer())
  timers[buf] = timer
  timer:start(
    0,
    math.floor(1000 / d.fps + 0.5),
    vim.schedule_wrap(function()
      if not vim.api.nvim_buf_is_valid(buf) or #vim.fn.win_findbuf(buf) == 0 then
        M.detach(buf)
        return
      end
      draw(buf, row, d.frames[frame], d.cols)
      frame = frame % count + 1
    end)
  )
end

---Section for snacks' dashboard `sections` list. Its blank lines both reserve
---the space and give the overlay extmarks columns to sit on.
---@param opts? {padding?: integer}
function M.section(opts)
  local d = load()
  local lines = {}
  for _ = 1, d.rows do
    lines[#lines + 1] = string.rep(" ", d.cols)
  end
  return {
    padding = (opts or {}).padding,
    text = table.concat(lines, "\n"),
    render = function(self, pos)
      M.attach(self.buf, pos)
    end,
  }
end

return M
