# IntelliJ-style "Compact Middle Packages": a run of directories that each
# have exactly one child collapses into a single row (e.g. `java/ai/shipperhq/
# auth` instead of 4 nested rows) — the classic deep-package-tree readability
# problem. snacks.explorer has no native support for this (unlike
# explorer-nesting.nix's auto-descend, this changes which rows exist, not just
# navigation), so it's patched in directly.
#
# DELETE THIS FILE (auto-imported via scanPaths) if snacks ever gains a native
# option for this.
_: {
  extraConfigLua = ''
    do
      local Explorer = require("snacks.picker.source.explorer")
      local Format = require("snacks.picker.format")
      local orig_explorer_finder = Explorer.explorer
      local orig_filename = Format.filename

      -- Format.filename derives the displayed basename purely from item.file
      -- via vim.fn.fnamemodify(..., ":t") — it never reads item.text — so a
      -- merged row's label can't be set on the item alone; the rendered
      -- segment (tagged field == "file") has to be swapped after the fact.
      Format.filename = function(item, picker)
        local ret = orig_filename(item, picker)
        if item.nixcfg_compact_label then
          for _, seg in ipairs(ret) do
            if seg.field == "file" then
              seg[1] = item.nixcfg_compact_label
            end
          end
        end
        return ret
      end

      -- Fields naming the actual folder a merged row represents: everything
      -- except structural position (parent/last, kept from the chain's first
      -- node so M.tree's connector math needs no changes) comes from here.
      local TERMINAL_FIELDS = { "file", "open", "dir_status", "status", "severity", "type" }

      -- Walks forward from `item` through directories that each have exactly
      -- one (directory) child, returning the chain as an array. A non-chain
      -- item (a file, or a directory with 0/2+ children) yields a length-1
      -- chain, so callers don't need a separate "did this even start a chain" check.
      local function chain_from(item, children_of)
        local chain, cur = { item }, item
        while cur.dir do
          local kids = children_of[cur]
          if not kids or #kids ~= 1 or not kids[1].dir then
            break
          end
          cur = kids[1]
          chain[#chain + 1] = cur
        end
        return chain
      end

      -- M.tree (format.lua) draws connectors purely from item.parent/.last,
      -- so keeping the chain's FIRST node's parent/last (structural position)
      -- and the chain's LAST node's file/open/status/etc (the real folder
      -- being represented) keeps every row's indentation correct with no
      -- changes needed to the connector renderer itself.
      local function compact_chains(raw)
        local children_of = {}
        for _, item in ipairs(raw) do
          if item.parent then
            local list = children_of[item.parent]
            if not list then
              list = {}
              children_of[item.parent] = list
            end
            list[#list + 1] = item
          end
        end

        local skip = {}
        local replace_parent = {}
        local final = {}

        for _, item in ipairs(raw) do
          if not skip[item] then
            local chain = chain_from(item, children_of)
            if #chain == 1 then
              final[#final + 1] = item
            else
              local terminal = chain[#chain]
              local labels = {}
              for i, c in ipairs(chain) do
                -- chain[1] becomes `merged` below; the rest must not also
                -- surface later as their own row.
                if i > 1 then
                  skip[c] = true
                end
                labels[#labels + 1] = vim.fn.fnamemodify(c.file, ":t")
              end
              local merged = vim.tbl_extend("force", {}, item)
              for _, field in ipairs(TERMINAL_FIELDS) do
                merged[field] = terminal[field]
              end
              merged.nixcfg_compact_label = table.concat(labels, "/")
              replace_parent[terminal] = merged
              final[#final + 1] = merged
            end
          end
        end

        for _, item in ipairs(final) do
          if item.parent and replace_parent[item.parent] then
            item.parent = replace_parent[item.parent]
          end
        end

        return final
      end

      Explorer.explorer = function(opts, ctx)
        local finder = orig_explorer_finder(opts, ctx)
        if not ctx.filter:is_empty() then
          -- actively fuzzy-searching within the explorer: a flat match list,
          -- not a directory tree — nothing to compact.
          return finder
        end
        return function(cb)
          local raw = {}
          finder(function(item)
            raw[#raw + 1] = item
          end)
          local ok, final = pcall(compact_chains, raw)
          for _, item in ipairs(ok and final or raw) do
            cb(item)
          end
        end
      end
    end
  '';
}
