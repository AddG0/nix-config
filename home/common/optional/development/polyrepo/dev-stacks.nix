# Typed dev-service stacks layered on home-manager's tmuxinator module. Each
# window runs its service's cmd (under otel-dev unless otel = false), generating
# programs.tmux.tmuxinator.projects.
{
  config,
  lib,
  ...
}: let
  cfg = config.polyrepo.devStacks;

  mkWindow = key: let
    s = cfg.services.${key};
  in {
    ${key} = {
      root = "${config.polyrepo.ghqRoot}/${s.path}";
      panes = [
        (
          if s.otel
          then "otel-dev ${s.cmd}"
          else s.cmd
        )
      ];
    };
  };

  members = lib.unique (lib.concatLists (lib.attrValues cfg.stacks));
  unknown = lib.filter (k: !(cfg.services ? ${k})) members;
in {
  options.polyrepo.devStacks = {
    services = lib.mkOption {
      default = {};
      description = "Service registry. Each entry is one tmuxinator window; the attribute name is the window name.";
      example = lib.literalExpression ''
        {
          dashboard = { path = "gitlab.com/acme/web"; cmd = "pnpm dev"; };
          api = { path = "gitlab.com/acme/api"; cmd = "gradle bootRun"; };
        }
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Service path under polyrepo.ghqRoot.";
          };
          cmd = lib.mkOption {
            type = lib.types.str;
            description = "Dev command run in the window, at the service root.";
          };
          otel = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Wrap cmd in otel-dev for OpenTelemetry auto-instrumentation.";
          };
        };
      });
    };

    stacks = lib.mkOption {
      default = {};
      description = "Named stacks; each is a list of `services` keys launched together as one tmuxinator session.";
      example = lib.literalExpression ''{ web = ["dashboard" "api"]; }'';
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    };
  };

  config = {
    assertions = [
      {
        assertion = unknown == [];
        message = "polyrepo.devStacks: stack member(s) not defined in services: ${lib.concatStringsSep ", " unknown}";
      }
    ];

    programs.tmux.tmuxinator.projects =
      lib.mapAttrs (name: keys: {
        inherit name;
        windows = map mkWindow keys;
      })
      cfg.stacks;
  };
}
