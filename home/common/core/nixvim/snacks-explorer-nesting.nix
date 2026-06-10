# Single-child folder auto-descend for the snacks explorer.
#
# snacks has no group_empty / single-child-collapse option, so this adds a
# custom action: opening a directory that contains only one subdirectory
# descends straight down the chain (e.g. `src` holding only `main` jumps to the
# deepest folder). Counts raw dir entries, so an extra/excluded sibling
# (node_modules, .git, …) stops the descent.
#
# It's registered as `confirm_descend` (not `confirm`) and the open keys are
# rebound to it, because the explorer's setup() force-merges its own `confirm`
# over any user-provided one.
#
# DELETE THIS FILE (auto-imported via scanPaths) and enable the native option
# once snacks adds single-child folder collapsing.
_: {
  programs.nixvim.plugins.snacks.settings.picker.sources.explorer = {
    actions.confirm_descend.__raw = ''
      function(picker, item, action)
        if not item then return end
        local Tree = require("snacks.explorer.tree")
        local Actions = require("snacks.explorer.actions")
        if picker.input.filter.meta.searching then
          Actions.update(picker, { target = item.file })
        elseif item.dir then
          local node = Tree:find(item.file)
          if node.open then
            Tree:close(item.file)
            Actions.update(picker, { target = item.file, refresh = true })
          else
            Tree:open(node.path)
            Tree:expand(node)
            while true do
              local only, count = nil, 0
              for _, child in pairs(node.children) do
                count = count + 1
                only = child
              end
              if count == 1 and only.dir then
                Tree:open(only.path)
                Tree:expand(only)
                node = only
              else
                break
              end
            end
            Actions.update(picker, { target = node.path, refresh = true })
          end
        else
          Snacks.picker.actions.jump(picker, item, action)
        end
      end
    '';
    # Rebind the open keys to the custom action (setup() owns `confirm`).
    win.list.keys = {
      "<CR>" = "confirm_descend";
      "l" = "confirm_descend";
      "<2-LeftMouse>" = "confirm_descend";
    };
  };
}
