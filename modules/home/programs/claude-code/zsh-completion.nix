{
  cfg,
  lib,
  pkgs,
}: let
  zshCompletion = pkgs.runCommand "claude-zsh-completion" {} ''
        mkdir -p $out/share/zsh/site-functions
        cat > $out/share/zsh/site-functions/_claude << 'COMPLETION'
    #compdef claude

    _claude_profiles() {
      local -a profiles
      profiles=(${lib.concatStringsSep " " (lib.mapAttrsToList (
        name: profile: let
          desc =
            if profile.description != ""
            then profile.description
            else name;
        in "'${name}:${desc}'"
      )
      cfg.profiles)})
      _describe 'profile' profiles
    }

    _claude_main() {
      local curcontext="$curcontext" state line
      typeset -A opt_args

      local -a commands
      commands=(
        'doctor:Check the health of your Claude Code auto-updater'
        'install:Install Claude Code native build'
        'mcp:Configure and manage MCP servers'
        'plugin:Manage Claude Code plugins'
        'setup-token:Set up a long-lived authentication token'
        'update:Check for updates and install if available'
      )

      _arguments -C \
        '(-P --profile)'{-P,--profile}'[Use a specific profile]:profile:_claude_profiles' \
        '--list-profiles[List available profiles]' \
        '(-p --print)'{-p,--print}'[Print response without interactive mode]' \
        '(-c --continue)'{-c,--continue}'[Continue most recent conversation]' \
        '--resume[Resume a specific conversation by session ID]:session_id:' \
        '(-v --verbose)'{-v,--verbose}'[Enable verbose logging]' \
        '--dangerously-skip-permissions[Skip permission checks]' \
        '--allowedTools[Comma-separated list of allowed tools]:tools:' \
        '--disallowedTools[Comma-separated list of disallowed tools]:tools:' \
        '--mcp-config[Path to MCP config file]:file:_files' \
        '--permission-mode[Permission mode]:mode:(default acceptEdits bypassPermissions)' \
        '(-m --model)'{-m,--model}'[Model to use]:model:' \
        '--max-turns[Max conversation turns]:turns:' \
        '--version[Show version]' \
        '(-h --help)'{-h,--help}'[Display help]' \
        '1: :->cmds' \
        '*::arg:->args'

      case $state in
        cmds)
          _describe 'command' commands
          _files
          ;;
        args)
          case $words[1] in
            mcp)
              local -a mcp_commands
              mcp_commands=(
                'add:Add an MCP server'
                'list:List configured MCP servers'
                'remove:Remove an MCP server'
                'serve:Start the Claude Code MCP server'
              )
              _describe 'mcp command' mcp_commands
              ;;
            plugin)
              local -a plugin_commands
              plugin_commands=(
                'install:Install a plugin'
                'list:List installed plugins'
                'uninstall:Uninstall a plugin'
                'enable:Enable a plugin'
                'disable:Disable a plugin'
              )
              _describe 'plugin command' plugin_commands
              ;;
            *)
              _files
              ;;
          esac
          ;;
      esac
    }

    _claude() {
      _claude_main "$@"
    }
    COMPLETION
  '';
in {
  inherit zshCompletion;
}
