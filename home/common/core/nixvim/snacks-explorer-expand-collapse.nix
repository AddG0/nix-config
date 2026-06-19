# Recursively expand / collapse the folder subtree under the cursor in the
# snacks explorer.
#
# snacks ships `Z` (explorer_close_all), but that resets the *whole* tree and
# there's no built-in scoped variant. These two custom actions walk the
# directory under the cursor (or the focused file's parent):
#   E - open it and every descendant folder (respects the explorer exclude
#       list, so node_modules/.git stay collapsed)
#   W - close every descendant folder, keeping the cursor folder itself open
# Mirrors nvim-tree's E (expand all) / W (collapse all).
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
