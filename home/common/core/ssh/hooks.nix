# tmux hooks that drive ./agent-link.nix. Shared so ./tests.nix exercises the
# same wiring the module installs, rather than a copy that can drift.
#
# `-a` is load-bearing: the core tmux module also registers client-attached, and
# a plain `set-hook -g` overwrites index 0 instead of adding an entry.
script: ''
  set-hook -ag client-attached 'run-shell -b "${script} attach #{client_name}"'
  set-hook -ag client-active 'run-shell -b "${script} active"'
  set-hook -ag client-detached 'run-shell -b "${script} detach"'
''
