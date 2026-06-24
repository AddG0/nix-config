# E / W recursively expand / collapse the folder subtree under the cursor.
# snacks only ships `Z` (reset the whole tree), so these add the scoped variant
# (mirrors nvim-tree's E/W). Expansion respects the explorer exclude list.
_: {
  plugins.snacks.settings.picker.sources.explorer = {
    actions = {
      expand_all.__raw = ''
        function(picker, item)
          if not item then return end
          local Tree = require("snacks.explorer.tree")
          local Actions = require("snacks.explorer.actions")
          local root = item.dir and Tree:find(item.file)
            or Tree:find(vim.fs.dirname(item.file))
          if not root then return end
          local function expand(node)
            Tree:open(node.path)
            Tree:expand(node)
            for _, child in pairs(node.children or {}) do
              if child.dir then expand(child) end
            end
          end
          expand(root)
          Actions.update(picker, { target = root.path, refresh = true })
        end
      '';
      collapse_all.__raw = ''
        function(picker, item)
          if not item then return end
          local Tree = require("snacks.explorer.tree")
          local Actions = require("snacks.explorer.actions")
          local root = item.dir and Tree:find(item.file)
            or Tree:find(vim.fs.dirname(item.file))
          if not root then return end
          local function collapse(node)
            for _, child in pairs(node.children or {}) do
              if child.dir then
                collapse(child)
                Tree:close(child.path)
              end
            end
          end
          collapse(root)
          Actions.update(picker, { target = root.path, refresh = true })
        end
      '';
    };
    win.list.keys = {
      "E" = "expand_all";
      "W" = "collapse_all";
    };
  };
}
