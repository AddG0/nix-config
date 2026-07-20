{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.opentabletdriver;
  ns = "OpenTabletDriver.Desktop";

  modePath = {
    absolute = "${ns}.Output.AbsoluteMode";
    relative = "${ns}.Output.RelativeMode";
    artist = "${ns}.Output.LinuxArtistMode";
  };

  ucfirst = s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (builtins.stringLength s) s;

  # Binding spec -> OTD binding JSON (or null). Spec is one of:
  #   null · {scroll="vertical"|"horizontal"} · {key="a"} · {keys=["ctrl" "c"]} · {mouse="Left"}
  mkBinding = b: let
    binding = path: prop: value: {
      Path = "${ns}.Binding.${path}";
      Settings = [
        {
          Property = prop;
          Value = value;
        }
      ];
      Enable = true;
    };
  in
    if b == null
    then null
    else if b ? scroll
    then {
      Path = "${ns}.Binding.MouseScrollBinding";
      # Amount sign picks direction: +down/right, -up/left (OTD's own doc).
      Settings =
        [
          {
            Property = "Direction";
            Value = ucfirst b.scroll;
          }
        ]
        ++ lib.optional (b ? amount) {
          Property = "Amount";
          Value = b.amount;
        };
      Enable = true;
    }
    else if b ? key
    then binding "KeyBinding" "Key" b.key
    else if b ? keys
    then binding "MultiKeyBinding" "Keys" (lib.concatStringsSep "+" b.keys)
    else if b ? mouse
    then binding "MouseBinding" "Button" b.mouse
    else throw "programs.opentabletdriver: unrecognized binding ${builtins.toJSON b}";

  adaptive = v: {
    Path = "${ns}.Binding.AdaptiveBinding";
    Settings = [
      {
        Property = "Binding";
        Value = v;
      }
    ];
    Enable = true;
  };

  # A dial spec is either a plain scroll (auto-inverted per direction so the dial
  # scrolls both ways) or {cw=…; ccw=…;} for explicit per-direction bindings.
  mkWheel = spec: let
    plainScroll = spec != null && spec ? scroll && !(spec ? cw) && !(spec ? ccw);
    amt =
      if spec != null
      then spec.amount or 120
      else 120;
    cw =
      if plainScroll
      then spec // {amount = amt;}
      else if spec != null && spec ? cw
      then spec.cw
      else spec;
    ccw =
      if plainScroll
      then spec // {amount = 0 - amt;}
      else if spec != null && spec ? ccw
      then spec.ccw
      else spec;
  in {
    WheelButtons = [];
    ClockwiseRotation = mkBinding cw;
    ClockwiseActivationThreshold = 15.0;
    CounterClockwiseRotation = mkBinding ccw;
    CounterClockwiseActivationThreshold = 15.0;
    StepSize = 15.0;
  };

  # Tablet specs, read from OTD's own shipped configs so no geometry is hardcoded.
  configRoot = "${cfg.package.src}/OpenTabletDriver.Configurations/Configurations";
  readDirRec = dir:
    lib.concatLists (lib.mapAttrsToList (
      n: type:
        if type == "directory"
        then readDirRec "${dir}/${n}"
        else lib.optional (lib.hasSuffix ".json" n) "${dir}/${n}"
    ) (builtins.readDir dir));
  allConfigs = map (f: builtins.fromJSON (builtins.readFile f)) (readDirRec configRoot);
  tabletSpec = name: let
    matches = builtins.filter (c: (c.Name or null) == name) allConfigs;
  in
    if matches == []
    then throw "programs.opentabletdriver: no OTD config matches tablet name '${name}'"
    else (builtins.head matches).Specifications;

  monitors = config.display.monitors or [];
  targetMonitor = out: let
    byOut = builtins.filter (m: m.output == out) monitors;
    primary = builtins.filter (m: m.primary or false) monitors;
  in
    if out != null && byOut != []
    then builtins.head byOut
    else if primary != []
    then builtins.head primary
    else if monitors != []
    then builtins.head monitors
    else throw "programs.opentabletdriver: no monitors in config.display.monitors to map the pen to";

  mkProfile = name: t: let
    spec = tabletSpec name;
    mon = targetMonitor t.mapToOutput;
    dig = spec.Digitizer;
    auxCount = spec.AuxiliaryButtons.ButtonCount or 0;
    aux = map mkBinding (t.buttons ++ t.dialButtons);
  in {
    Tablet = name;
    # The bar widget switches mode live; this is the value the daemon starts with.
    OutputMode = {
      Path = modePath.${cfg.defaultOutputMode};
      Settings = [];
      Enable = true;
    };
    Filters = [];
    AbsoluteModeSettings = {
      # Full tablet surface mapped onto one monitor. OTD's area X/Y is the center.
      Display = {
        Width = mon.width;
        Height = mon.height;
        X = mon.x + mon.width / 2.0;
        Y = mon.y + mon.height / 2.0;
        Rotation = 0.0;
      };
      Tablet = {
        inherit (dig) Width Height;
        X = dig.Width / 2.0;
        Y = dig.Height / 2.0;
        Rotation = 0.0;
      };
      EnableClipping = true;
      EnableAreaLimiting = false;
      LockAspectRatio = false;
    };
    RelativeModeSettings = {
      XSensitivity = 10.0;
      YSensitivity = 10.0;
      RelativeRotation = 0.0;
      RelativeResetDelay = "00:00:00.1000000";
    };
    Bindings = {
      TipActivationThreshold = 1.0;
      TipButton = adaptive "Tip";
      EraserActivationThreshold = 1.0;
      EraserButton = adaptive "Eraser";
      PenButtons = map (i: adaptive "Button ${toString i}") (lib.range 1 (spec.Pen.ButtonCount or 0));
      # OTD wants exactly ButtonCount entries; pad the unspecified tail with null.
      AuxButtons = lib.take auxCount (aux ++ lib.genList (_: null) auxCount);
      MouseButtons = [];
      MouseScrollUp = null;
      MouseScrollDown = null;
      WheelBindings = lib.optionals ((spec.Wheels or []) != []) [
        (mkWheel t.dials.left)
        (mkWheel t.dials.right)
      ];
      DisablePressure = false;
      DisableTilt = false;
      EnableDragBindings = false;
    };
  };

  settings = {
    Revision = "0.6.7";
    Profiles = lib.mapAttrsToList mkProfile cfg.tablets;
    LockUsableAreaDisplay = true;
    LockUsableAreaTablet = true;
    Tools = [];
  };

  bindingType = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
in {
  options.programs.opentabletdriver = {
    package = lib.mkPackageOption pkgs "opentabletdriver" {};

    defaultOutputMode = lib.mkOption {
      type = lib.types.enum ["absolute" "relative" "artist"];
      default = "absolute";
      description = ''
        Output mode the daemon starts in. The bar widget switches it live within
        a session; on daemon restart it reverts to this value.
      '';
    };

    tablets = lib.mkOption {
      default = {};
      description = ''
        Per-tablet OTD profiles keyed by the tablet's OTD name (e.g. "Wacom
        PTK-670"). Generates a read-only ~/.config/OpenTabletDriver/settings.json;
        the bar widget still switches mode live (that path never writes the file).
        Tablet geometry is read from OTD's shipped configs, so nothing
        machine-specific is hardcoded.
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          mapToOutput = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''Connector (e.g. "DP-3") the pen's absolute area maps to; null = primary monitor.'';
          };
          dials = {
            left = lib.mkOption {
              type = bindingType;
              default = null;
              description = "Left dial binding (a plain binding applies to both rotation directions).";
            };
            right = lib.mkOption {
              type = bindingType;
              default = null;
              description = "Right dial binding.";
            };
          };
          buttons = lib.mkOption {
            type = lib.types.listOf bindingType;
            default = [];
            description = "Express-key bindings, in hardware order.";
          };
          dialButtons = lib.mkOption {
            type = lib.types.listOf bindingType;
            default = [];
            description = "Dial-press button bindings, appended after the express keys.";
          };
        };
      });
    };
  };

  config = lib.mkIf (cfg.tablets != {}) {
    xdg.configFile."OpenTabletDriver/settings.json".text = builtins.toJSON settings;
  };
}
