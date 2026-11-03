{pkgs, ...}: {
  programs.sesh = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "sesh-with-tmuxinator-shim";
      paths = [pkgs.sesh];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/sesh --prefix PATH : ${pkgs.callPackage ./tmuxinator-shim.nix {}}/bin
      '';
    };
    enableAlias = true;
    enableTmuxIntegration = true;
    tmuxKey = "T";
    icons = true;
    settings = {};
  };

  # Alt-S: the sesh picker from a bare shell (Prefix+T only works inside tmux).
  # Shadows the default spell-word bind.
  programs.zsh.initContent = ''
    sesh-fzf-widget() {
      local target
      target=$(sesh list --icons | fzf \
        --height 60% --reverse --border --ansi \
        --prompt '⚡ ' --preview 'sesh preview {}') || return
      [[ -z "$target" ]] && return
      BUFFER="sesh connect ''${(q)target}"
      zle accept-line
    }
    zle -N sesh-fzf-widget
    bindkey '^[s' sesh-fzf-widget
  '';
}
