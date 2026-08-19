# tmux hooks that drive ./agent-link.nix. Shared so ./tests.nix exercises the
# same wiring the module installs, rather than a copy that can drift.
script: ''
  set-hook -g client-attached 'run-shell -b "${script} attach #{client_name}"'
  set-hook -g client-active 'run-shell -b "${script} active"'
  set-hook -g client-detached 'run-shell -b "${script} detach"'
''
