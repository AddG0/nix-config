# Force the snacks explorer to re-read git status when nvim regains focus.
#
# snacks watches `<root>/.git` for index changes, but in a git *worktree*
# (gwq/gwadd checkouts) `.git` is a FILE pointing at the real gitdir, not a
# directory — so the watcher never fires and status is stale until the module's
# hardcoded 15-min TTL expires. Committing from a CLI outside nvim hits the same
# gap. FocusGained (+ leaving/closing a terminal) is our reliable "something
# happened out there" signal.
#
# DELETE THIS FILE once snacks resolves the real gitdir for worktrees
# (see snacks.explorer.watch / snacks.explorer.git upstream).
_: {
  autoCmd = [
    {
      event = ["FocusGained" "TermLeave" "TermClose"];
      callback.__raw = ''
        function()
          local ok_git, Git = pcall(require, "snacks.explorer.git")
          local ok_watch, Watch = pcall(require, "snacks.explorer.watch")
          if not (ok_git and ok_watch and Snacks and Snacks.picker) then return end
          local pickers = Snacks.picker.get({ source = "explorer" })
          if #pickers == 0 then return end
          for _, p in ipairs(pickers) do
            Git.refresh(p:cwd()) -- reset TTL so the next find() re-runs `git status`
          end
          Watch.refresh()
        end
      '';
    }
  ];
}
