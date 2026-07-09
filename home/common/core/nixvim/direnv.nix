{
  # Exports the project's direnv env into nvim so LSP servers (spawned as nvim children) resolve deps from the dev-env python.
  plugins.direnv = {
    enable = true;
    settings.silent_load = 1; # match programs.direnv.silent
  };
}
