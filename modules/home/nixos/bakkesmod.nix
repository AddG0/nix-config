# BakkesMod module for Home Manager
# Based on https://github.com/CrumblyLiquid/BakkesLinux
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.bakkesmod;
in {
  options.programs.bakkesmod = {
    enable = mkEnableOption "BakkesMod for Rocket League";

    package = mkOption {
      type = types.package;
      default = pkgs.bakkesmod;
      description = "The BakkesMod package to use.";
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = [];
      example = literalExpression ''
        [
          pkgs.bakkesmod-plugins.ingamerank
        ]
      '';
      description = ''
        List of BakkesMod plugins to install via Nix.

        These plugins will be managed declaratively:
        - Added when in this list
        - Removed when removed from this list
        - Updated when the Nix package updates

        Manually installed plugins (those without .nix-managed markers)
        will be preserved and not touched by this module.

        Available plugins can be found in pkgs.bakkesmod-plugins.*

        Example: To add the IngameRank plugin, use:
        pkgs.bakkesmod-plugins.ingamerank
      '';
    };

    config = {
      # GUI and Interface Settings
      gui = {
        alpha = mkOption {
          type = types.nullOr types.float;
          default = null;
          description = "Alpha transparency for BakkesMod GUI (0.0-1.0)";
        };

        lightMode = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable light mode for GUI";
        };

        scale = mkOption {
          type = types.nullOr types.float;
          default = null;
          description = "GUI scaling factor";
        };

        theme = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Theme file to use (e.g., 'visibility.json')";
        };

        quickSettingsRows = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Maximum rows to display in quicksettings";
        };
      };

      # Console Settings
      console = {
        enabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show the console";
        };

        toggleable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Allow console to be toggled (when false, disables console altogether)";
        };

        key = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Key to toggle the console (e.g., 'Tilde', 'F3')";
        };

        bufferSize = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Maximum amount of messages to store in console log";
        };

        suggestions = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Maximum amount of suggestions to show";
        };

        logKeys = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Log keypresses into the console";
        };

        height = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Height of the console window";
        };

        width = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Width of the console window";
        };

        x = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "X position of the console window";
        };

        y = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Y position of the console window";
        };
      };

      # Ranked and MMR Display
      ranked = {
        showRanks = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show opponent ranks in ranked matches";
        };

        showRanksCasual = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show player ranks in casual modes";
        };

        showRanksCasualMenu = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show casual MMR in the queue menu";
        };

        showRanksMenu = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show player ranks in the queue menu";
        };

        showRanksGameOver = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Only show opponent ranks when game is over";
        };

        disableRanks = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Disable rank display entirely";
        };

        disregardPlacements = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Don't take placement matches into account when calculating MMR";
        };

        aprilFools = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable april fools rank mode";
        };

        autoGG = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically say GG at the end of the match";
        };

        autoGGDelay = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Time range to wait before sending GG (e.g., '(250, 2500)')";
        };

        autoGGId = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "GG message ID 0-3 (order in post-game quickchats)";
        };

        autoQueue = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically queue on match end";
        };

        autoSaveReplay = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically save ranked replay at end of match";
        };

        autoSaveReplayAll = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically save replay at end of all matches";
        };
      };

      # Replay and Recording Settings
      replay = {
        autoUploadBallchasing = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Upload replays to ballchasing.com automatically";
        };

        autoUploadBallchasingAuthKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Auth token for ballchasing.com";
        };

        autoUploadBallchasingVisibility = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Replay visibility on ballchasing.com (public/unlisted/private)";
        };

        autoUploadCalculated = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Upload replays to calculated.gg automatically";
        };

        autoUploadCalculatedVisibility = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Replay visibility on calculated.gg";
        };

        autoUploadNotifications = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show notifications on successful uploads";
        };

        autoUploadSave = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Save all replay files to export filepath";
        };

        autoUploadFilepath = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to export replays to";
        };

        nameTemplate = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Template for replay filename";
        };

        recordFPS = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "FPS to record replays at";
        };

        demoAutoSave = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Autosave last X demos (0 to disable)";
        };

        demoNameplates = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show nameplates in demos";
        };
      };

      # Freeplay Settings
      freeplay = {
        enableGoal = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable goal scoring in freeplay";
        };

        enableGoalBakkesmod = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Use BakkesMod version of enabling goals";
        };

        goalSpeed = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show speed at which goals are scored";
        };

        bindings = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable BakkesMod freeplay bindings";
        };

        limitBoostDefault = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Limit boost in freeplay when loaded";
        };

        carColor = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable normal car colors in freeplay";
        };

        stadiumColors = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable stadium colors in freeplay";
        };

        unlimitedFlips = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Allow unlimited flips in the air for practice";
        };
      };

      # Training Variance Settings
      training = {
        enabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable custom training variance";
        };

        allowMirror = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Mirror custom training shots randomly";
        };

        autoShuffle = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically shuffle playlists";
        };

        clock = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Time limit for shots in seconds (0 for unlimited)";
        };

        timeupReset = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Reset shot instead of going to next when time is up";
        };

        limitBoost = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Limit boost in custom training (-1 for unlimited)";
        };

        playerVelocity = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Initial player velocity value";
        };

        useFreeplayMap = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Use the map you use in freeplay for custom training";
        };

        useRandomMap = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Use a random map for custom training";
        };

        varLocation = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Ball location variance in unreal units (e.g., '(-150, 150)')";
        };

        varLocationZ = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Ball Z location variance in unreal units (e.g., '(-20, 100)')";
        };

        varRotation = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Ball rotation variance in % (e.g., '(-2.5, 2.5)')";
        };

        varSpeed = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Ball velocity variance in % (e.g., '(-5, 5)')";
        };

        varSpin = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Ball spin variance in unreal units (e.g., '(-6, 6)')";
        };

        varCarLocation = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Car location variance in unreal units";
        };

        varCarRotation = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Car rotation variance in %";
        };

        goalBlockerEnabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable goal blocker in training";
        };

        printJson = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Print training JSON data";
        };
      };

      # Anonymizer Settings
      anonymizer = {
        modeTeam = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Anonymizer mode for team (0=off, 1=on)";
        };

        modeParty = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Anonymizer mode for party members (0=off, 1=on)";
        };

        modeOpponent = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Anonymizer mode for opponents (0=off, 1=on)";
        };

        alwaysShowCars = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Never anonymize cars";
        };

        bot = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Use bot names for anonymization";
        };

        scores = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Hide scoreboard info";
        };

        hideForfeit = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Hide forfeit votes";
        };

        kickoffQuickchat = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Only turn on quickchat during 3,2,1 countdown";
        };
      };

      # Loadout and Cosmetics
      loadout = {
        colorEnabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Override car colors";
        };

        colorSame = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Use same car color for both teams";
        };

        bluePrimary = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Primary RGB values for blue car (e.g., '0.08 0.10 0.90 -1')";
        };

        blueSecondary = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Secondary RGB values for blue car";
        };

        orangePrimary = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Primary RGB values for orange car";
        };

        orangeSecondary = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Secondary RGB values for orange car";
        };

        alphBoost = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Wear alpha boost";
        };

        itemModEnabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable item mod";
        };

        itemModCode = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Current loadout code for item mod";
        };
      };

      # Camera and Replay Settings
      camera = {
        clipToField = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Clip camera to field in replays";
        };

        goalReplayPOV = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Use POV goal replays";
        };

        goalReplayTimeout = mkOption {
          type = types.nullOr types.float;
          default = null;
          description = "How long to wait before switching to another player after a hit";
        };
      };

      # DollyCam Settings
      dollyCam = {
        render = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Render the current camera path";
        };

        renderFrame = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Render frame numbers on the path";
        };

        interpMode = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Interpolation mode to use";
        };

        interpModeLocation = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Interpolation mode for location";
        };

        interpModeRotation = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Interpolation mode for rotation";
        };

        chaikinDegree = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Amount of times to apply Chaikin smoothing to the spline";
        };

        splineAcc = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Spline interpolation time accuracy";
        };

        pathDirectory = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Location for saving and loading paths";
        };
      };

      # Mechanical Limits
      mechanical = {
        enabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable/disable mechanical steer functionality";
        };

        steerLimit = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Clamp steering input";
        };

        throttleLimit = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Clamp throttle input";
        };

        pitchLimit = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Clamp pitch input";
        };

        yawLimit = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Clamp yaw input";
        };

        rollLimit = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Clamp roll input";
        };

        disableJump = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Disable jump";
        };

        disableBoost = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Disable boost";
        };

        disableHandbrake = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Disable handbrake";
        };

        holdBoost = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Hold boost automatically";
        };

        holdRoll = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Hold air roll automatically";
        };
      };

      # RCON Settings
      rcon = {
        enabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable the RCON plugin";
        };

        port = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "RCON server port";
        };

        password = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "RCON password";
        };

        timeout = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "RCON timeout in seconds";
        };

        log = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Log all incoming RCON commands";
        };
      };

      # Miscellaneous Client Settings
      misc = {
        drawFPSOnBoot = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Draw FPS counter when game starts";
        };

        drawSystemTime = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Draw system time on screen";
        };

        systemTimeFormat = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Format string for system time (e.g., '%I:%M %p')";
        };

        onlineStatusDetailed = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show detailed match info for friends (score & game time)";
        };

        ballFadeIn = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable ball fade in effect";
        };

        boostCounter = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Boost counts up instead of down";
        };

        jumpHelp = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Play sounds for jumping (0=off, 1=countdown, 2=elapsed, 3=both)";
        };

        jumpHelpCarColor = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Make car red/green based on jump availability";
        };

        workshopFreecam = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enter/exit spectator mode in custom maps";
        };

        mainMenuBackground = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Main menu background ID";
        };

        misophoniaModeEnabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Disable items with food sounds (e.g., donut goal explosion)";
        };

        notificationsEnabledBeta = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable BakkesMod notifications";
        };

        notificationsRanked = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Show MMR change popup after match";
        };

        renderingDisabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable/disable rendering entirely";
        };

        scaleformDisabled = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable/disable Scaleform rendering";
        };

        goalSlomo = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Enable/disable slow-motion after scoring";
        };

        alliterationAndy = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Give all players alliterated names (e.g., Stalling Steven)";
        };

        logInstantFlush = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Instantly write log to file";
        };

        inputBufferResetAutomatic = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically reset input buffer after alt-tab";
        };
      };

      # Queue Menu Settings
      queueMenu = {
        closeJoining = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically close queue menu when joining match";
        };

        openMainMenu = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically open queue menu when entering main menu";
        };

        openMatchEnded = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = "Automatically open queue menu on match end";
        };
      };

      # Plugin favorites
      pluginFavorites = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "List of favorite plugins (semicolon separated)";
      };
    };
  };

  config = mkIf cfg.enable (let
    # Helper function to convert bool to "0" or "1"
    boolToStr = b:
      if b
      then "1"
      else "0";

    # Helper function to format a config line
    formatConfigLine = key: value:
      if value == null
      then ""
      else if builtins.isBool value
      then "${key} \"${boolToStr value}\""
      else if builtins.isInt value
      then "${key} \"${toString value}\""
      else if builtins.isFloat value
      then "${key} \"${toString value}\""
      else "${key} \"${value}\"";

    # Generate config content from options
    generateConfigContent = let
      c = cfg.config;
      lines = [
        # GUI Settings
        (formatConfigLine "bakkesmod_style_alpha" c.gui.alpha)
        (formatConfigLine "bakkesmod_style_light" c.gui.lightMode)
        (formatConfigLine "bakkesmod_style_scale" c.gui.scale)
        (formatConfigLine "bakkesmod_style_theme" c.gui.theme)
        (formatConfigLine "gui_quicksettings_rows" c.gui.quickSettingsRows)

        # Console Settings
        (formatConfigLine "cl_console_enabled" c.console.enabled)
        (formatConfigLine "cl_console_toggleable" c.console.toggleable)
        (formatConfigLine "cl_console_key" c.console.key)
        (formatConfigLine "cl_console_buffersize" c.console.bufferSize)
        (formatConfigLine "cl_console_suggestions" c.console.suggestions)
        (formatConfigLine "cl_console_logkeys" c.console.logKeys)
        (formatConfigLine "cl_console_height" c.console.height)
        (formatConfigLine "cl_console_width" c.console.width)
        (formatConfigLine "cl_console_x" c.console.x)
        (formatConfigLine "cl_console_y" c.console.y)

        # Ranked Settings
        (formatConfigLine "ranked_showranks" c.ranked.showRanks)
        (formatConfigLine "ranked_showranks_casual" c.ranked.showRanksCasual)
        (formatConfigLine "ranked_showranks_casual_menu" c.ranked.showRanksCasualMenu)
        (formatConfigLine "ranked_showranks_menu" c.ranked.showRanksMenu)
        (formatConfigLine "ranked_showranks_gameover" c.ranked.showRanksGameOver)
        (formatConfigLine "ranked_disableranks" c.ranked.disableRanks)
        (formatConfigLine "ranked_disregardplacements" c.ranked.disregardPlacements)
        (formatConfigLine "ranked_aprilfools" c.ranked.aprilFools)
        (formatConfigLine "ranked_autogg" c.ranked.autoGG)
        (formatConfigLine "ranked_autogg_delay" c.ranked.autoGGDelay)
        (formatConfigLine "ranked_autogg_id" c.ranked.autoGGId)
        (formatConfigLine "ranked_autoqueue" c.ranked.autoQueue)
        (formatConfigLine "ranked_autosavereplay" c.ranked.autoSaveReplay)
        (formatConfigLine "ranked_autosavereplay_all" c.ranked.autoSaveReplayAll)

        # Replay Settings
        (formatConfigLine "cl_autoreplayupload_ballchasing" c.replay.autoUploadBallchasing)
        (formatConfigLine "cl_autoreplayupload_ballchasing_authkey" c.replay.autoUploadBallchasingAuthKey)
        (formatConfigLine "cl_autoreplayupload_ballchasing_visibility" c.replay.autoUploadBallchasingVisibility)
        (formatConfigLine "cl_autoreplayupload_calculated" c.replay.autoUploadCalculated)
        (formatConfigLine "cl_autoreplayupload_calculated_visibility" c.replay.autoUploadCalculatedVisibility)
        (formatConfigLine "cl_autoreplayupload_notifications" c.replay.autoUploadNotifications)
        (formatConfigLine "cl_autoreplayupload_save" c.replay.autoUploadSave)
        (formatConfigLine "cl_autoreplayupload_filepath" c.replay.autoUploadFilepath)
        (formatConfigLine "cl_autoreplayupload_replaynametemplate" c.replay.nameTemplate)
        (formatConfigLine "cl_record_fps" c.replay.recordFPS)
        (formatConfigLine "cl_demo_autosave" c.replay.demoAutoSave)
        (formatConfigLine "cl_demo_nameplates" c.replay.demoNameplates)

        # Freeplay Settings
        (formatConfigLine "sv_freeplay_enablegoal" c.freeplay.enableGoal)
        (formatConfigLine "sv_freeplay_enablegoal_bakkesmod" c.freeplay.enableGoalBakkesmod)
        (formatConfigLine "sv_freeplay_goalspeed" c.freeplay.goalSpeed)
        (formatConfigLine "sv_freeplay_bindings" c.freeplay.bindings)
        (formatConfigLine "sv_freeplay_limitboost_default" c.freeplay.limitBoostDefault)
        (formatConfigLine "cl_freeplay_carcolor" c.freeplay.carColor)
        (formatConfigLine "cl_freeplay_stadiumcolors" c.freeplay.stadiumColors)
        (formatConfigLine "sv_soccar_unlimitedflips" c.freeplay.unlimitedFlips)

        # Training Settings
        (formatConfigLine "sv_training_enabled" c.training.enabled)
        (formatConfigLine "sv_training_allowmirror" c.training.allowMirror)
        (formatConfigLine "sv_training_autoshuffle" c.training.autoShuffle)
        (formatConfigLine "sv_training_clock" c.training.clock)
        (formatConfigLine "sv_training_timeup_reset" c.training.timeupReset)
        (formatConfigLine "sv_training_limitboost" c.training.limitBoost)
        (formatConfigLine "sv_training_player_velocity" c.training.playerVelocity)
        (formatConfigLine "sv_training_usefreeplaymap" c.training.useFreeplayMap)
        (formatConfigLine "sv_training_userandommap" c.training.useRandomMap)
        (formatConfigLine "sv_training_var_loc" c.training.varLocation)
        (formatConfigLine "sv_training_var_loc_z" c.training.varLocationZ)
        (formatConfigLine "sv_training_var_rot" c.training.varRotation)
        (formatConfigLine "sv_training_var_speed" c.training.varSpeed)
        (formatConfigLine "sv_training_var_spin" c.training.varSpin)
        (formatConfigLine "sv_training_var_car_loc" c.training.varCarLocation)
        (formatConfigLine "sv_training_var_car_rot" c.training.varCarRotation)
        (formatConfigLine "sv_training_goalblocker_enabled" c.training.goalBlockerEnabled)
        (formatConfigLine "cl_training_printjson" c.training.printJson)

        # Anonymizer Settings
        (formatConfigLine "cl_anonymizer_mode_team" c.anonymizer.modeTeam)
        (formatConfigLine "cl_anonymizer_mode_party" c.anonymizer.modeParty)
        (formatConfigLine "cl_anonymizer_mode_opponent" c.anonymizer.modeOpponent)
        (formatConfigLine "cl_anonymizer_alwaysshowcars" c.anonymizer.alwaysShowCars)
        (formatConfigLine "cl_anonymizer_bot" c.anonymizer.bot)
        (formatConfigLine "cl_anonymizer_scores" c.anonymizer.scores)
        (formatConfigLine "cl_anonymizer_hideforfeit" c.anonymizer.hideForfeit)
        (formatConfigLine "cl_anonymizer_kickoff_quickchat" c.anonymizer.kickoffQuickchat)

        # Loadout Settings
        (formatConfigLine "cl_loadout_color_enabled" c.loadout.colorEnabled)
        (formatConfigLine "cl_loadout_color_same" c.loadout.colorSame)
        (formatConfigLine "cl_loadout_blue_primary" c.loadout.bluePrimary)
        (formatConfigLine "cl_loadout_blue_secondary" c.loadout.blueSecondary)
        (formatConfigLine "cl_loadout_orange_primary" c.loadout.orangePrimary)
        (formatConfigLine "cl_loadout_orange_secondary" c.loadout.orangeSecondary)
        (formatConfigLine "cl_alphaboost" c.loadout.alphBoost)
        (formatConfigLine "cl_itemmod_enabled" c.loadout.itemModEnabled)
        (formatConfigLine "cl_itemmod_code" c.loadout.itemModCode)

        # Camera Settings
        (formatConfigLine "cl_camera_cliptofield" c.camera.clipToField)
        (formatConfigLine "cl_goalreplay_pov" c.camera.goalReplayPOV)
        (formatConfigLine "cl_goalreplay_timeout" c.camera.goalReplayTimeout)

        # DollyCam Settings
        (formatConfigLine "dolly_render" c.dollyCam.render)
        (formatConfigLine "dolly_render_frame" c.dollyCam.renderFrame)
        (formatConfigLine "dolly_interpmode" c.dollyCam.interpMode)
        (formatConfigLine "dolly_interpmode_location" c.dollyCam.interpModeLocation)
        (formatConfigLine "dolly_interpmode_rotation" c.dollyCam.interpModeRotation)
        (formatConfigLine "dolly_chaikin_degree" c.dollyCam.chaikinDegree)
        (formatConfigLine "dolly_spline_acc" c.dollyCam.splineAcc)
        (formatConfigLine "dolly_path_directory" c.dollyCam.pathDirectory)

        # Mechanical Settings
        (formatConfigLine "mech_enabled" c.mechanical.enabled)
        (formatConfigLine "mech_steer_limit" c.mechanical.steerLimit)
        (formatConfigLine "mech_throttle_limit" c.mechanical.throttleLimit)
        (formatConfigLine "mech_pitch_limit" c.mechanical.pitchLimit)
        (formatConfigLine "mech_yaw_limit" c.mechanical.yawLimit)
        (formatConfigLine "mech_roll_limit" c.mechanical.rollLimit)
        (formatConfigLine "mech_disable_jump" c.mechanical.disableJump)
        (formatConfigLine "mech_disable_boost" c.mechanical.disableBoost)
        (formatConfigLine "mech_disable_handbrake" c.mechanical.disableHandbrake)
        (formatConfigLine "mech_hold_boost" c.mechanical.holdBoost)
        (formatConfigLine "mech_hold_roll" c.mechanical.holdRoll)

        # RCON Settings
        (formatConfigLine "rcon_enabled" c.rcon.enabled)
        (formatConfigLine "rcon_port" c.rcon.port)
        (formatConfigLine "rcon_password" c.rcon.password)
        (formatConfigLine "rcon_timeout" c.rcon.timeout)
        (formatConfigLine "rcon_log" c.rcon.log)

        # Misc Settings
        (formatConfigLine "cl_draw_fpsonboot" c.misc.drawFPSOnBoot)
        (formatConfigLine "cl_draw_systemtime" c.misc.drawSystemTime)
        (formatConfigLine "cl_draw_systemtime_format" c.misc.systemTimeFormat)
        (formatConfigLine "cl_online_status_detailed" c.misc.onlineStatusDetailed)
        (formatConfigLine "cl_soccar_ballfadein" c.misc.ballFadeIn)
        (formatConfigLine "cl_soccar_boostcounter" c.misc.boostCounter)
        (formatConfigLine "cl_soccar_jumphelp" c.misc.jumpHelp)
        (formatConfigLine "cl_soccar_jumphelp_carcolor" c.misc.jumpHelpCarColor)
        (formatConfigLine "cl_workshop_freecam" c.misc.workshopFreecam)
        (formatConfigLine "cl_mainmenu_background" c.misc.mainMenuBackground)
        (formatConfigLine "cl_misophoniamode_enabled" c.misc.misophoniaModeEnabled)
        (formatConfigLine "cl_notifications_enabled_beta" c.misc.notificationsEnabledBeta)
        (formatConfigLine "cl_notifications_ranked" c.misc.notificationsRanked)
        (formatConfigLine "cl_rendering_disabled" c.misc.renderingDisabled)
        (formatConfigLine "cl_rendering_scaleform_disabled" c.misc.scaleformDisabled)
        (formatConfigLine "sv_soccar_goalslomo" c.misc.goalSlomo)
        (formatConfigLine "alliteration_andy" c.misc.alliterationAndy)
        (formatConfigLine "bakkesmod_log_instantflush" c.misc.logInstantFlush)
        (formatConfigLine "inputbuffer_reset_automatic" c.misc.inputBufferResetAutomatic)

        # Queue Menu Settings
        (formatConfigLine "queuemenu_close_joining" c.queueMenu.closeJoining)
        (formatConfigLine "queuemenu_open_mainmenu" c.queueMenu.openMainMenu)
        (formatConfigLine "queuemenu_open_match_ended" c.queueMenu.openMatchEnded)

        # Plugin Favorites
        (formatConfigLine "cl_settings_plugin_favorites" c.pluginFavorites)
      ];
    in
      concatStringsSep "\n" (filter (l: l != "") lines);

    # Config sync script - manages BakkesMod configuration
    bakkes-config-sync = pkgs.writeShellScriptBin "bakkes-config-sync" ''
          #!/usr/bin/env bash
          set -euo pipefail

          BAKKES_DATA="$1"

          if [ ! -d "$BAKKES_DATA" ]; then
              echo "BakkesMod data directory not found: $BAKKES_DATA"
              exit 1
          fi

          mkdir -p "$BAKKES_DATA/cfg"

          # Generate Nix-managed config file
          NIX_CONFIG="$BAKKES_DATA/cfg/nix-config.cfg"
          cat > "$NIX_CONFIG" << 'EOF'
      // Nix-managed BakkesMod configuration
      // This file is automatically generated from your Nix configuration
      // Do not edit manually - changes will be overwritten
      ${generateConfigContent}
      EOF

          # Ensure autoexec.cfg loads our Nix config
          AUTOEXEC="$BAKKES_DATA/cfg/autoexec.cfg"

          # Create autoexec if it doesn't exist
          touch "$AUTOEXEC"

          # Check if our exec line is already in autoexec
          if ! grep -qF "exec nix-config.cfg" "$AUTOEXEC" 2>/dev/null; then
              echo "exec nix-config.cfg" >> "$AUTOEXEC"
              echo "Added nix-config.cfg to autoexec.cfg"
          fi

          echo "Config sync complete"
    '';

    # Plugin sync script - manages BakkesMod plugins
    bakkes-plugin-sync = pkgs.writeShellScriptBin "bakkes-plugin-sync" ''
      #!/usr/bin/env bash
      set -euo pipefail

      BAKKES_DATA="$1"

      if [ ! -d "$BAKKES_DATA" ]; then
          echo "BakkesMod data directory not found: $BAKKES_DATA"
          exit 1
      fi

      mkdir -p "$BAKKES_DATA/plugins"
      mkdir -p "$BAKKES_DATA/plugins/settings"
      mkdir -p "$BAKKES_DATA/data"

      # Build list of plugin names we want from Nix
      WANTED_PLUGINS=""
      ${concatMapStringsSep "\n" (plugin: ''
          if [ -d "${plugin}/share/bakkesmod" ]; then
              PLUGIN_NAME="${plugin.pname or "unknown"}"
              WANTED_PLUGINS="$WANTED_PLUGINS $PLUGIN_NAME"
          fi
        '')
        cfg.plugins}

      # Remove Nix-managed plugins that are no longer wanted
      for marker in "$BAKKES_DATA/plugins"/*.nix-managed; do
          if [ -f "$marker" ]; then
              PLUGIN_NAME=$(basename "$marker" .nix-managed)
              if ! echo "$WANTED_PLUGINS" | grep -qw "$PLUGIN_NAME"; then
                  echo "Removing plugin: $PLUGIN_NAME"
                  PLUGIN_NAME_LOWER=$(echo "$PLUGIN_NAME" | tr '[:upper:]' '[:lower:]')

                  # Read list of files from marker and remove them
                  while IFS= read -r file; do
                      rm -f "$BAKKES_DATA/$file" 2>/dev/null
                  done < "$marker"

                  # Remove the marker itself
                  rm -f "$marker"

                  # Remove from plugins.cfg
                  if [ -f "$BAKKES_DATA/cfg/plugins.cfg" ]; then
                      # Remove the plugin load line
                      ${pkgs.gnused}/bin/sed -i "/^plugin load $PLUGIN_NAME_LOWER$/d" "$BAKKES_DATA/cfg/plugins.cfg"
                      echo "Disabled $PLUGIN_NAME in plugins.cfg"
                  fi
              fi
          fi
      done

      # Copy/update Nix-managed plugins with all their files
      ${concatMapStringsSep "\n" (plugin: ''
          if [ -d "${plugin}/share/bakkesmod" ]; then
              PLUGIN_NAME="${plugin.pname or "unknown"}"
              PLUGIN_NAME_LOWER=$(echo "$PLUGIN_NAME" | tr '[:upper:]' '[:lower:]')
              MARKER_FILE="$BAKKES_DATA/plugins/$PLUGIN_NAME.nix-managed"

              echo "Installing/updating plugin: $PLUGIN_NAME"

              # Start fresh marker file
              > "$MARKER_FILE"

              # Copy all files from plugin package to BakkesMod data directory
              # This includes both plugins/ and data/ directories
              cd "${plugin}/share/bakkesmod"
              find . -type f | while read -r file; do
                  # Remove leading ./
                  REL_PATH="''${file#./}"

                  # Create directory structure if needed
                  DIR_PATH=$(dirname "$REL_PATH")
                  if [ "$DIR_PATH" != "." ]; then
                      mkdir -p "$BAKKES_DATA/$DIR_PATH"
                  fi

                  # Copy file if newer or missing
                  if [ ! -f "$BAKKES_DATA/$REL_PATH" ] || [ "$file" -nt "$BAKKES_DATA/$REL_PATH" ]; then
                      ${pkgs.coreutils}/bin/cp -f "$file" "$BAKKES_DATA/$REL_PATH"
                  fi

                  # Track in marker file (relative to BakkesMod root)
                  echo "$REL_PATH" >> "$MARKER_FILE"
              done

              # Enable plugin in cfg/plugins.cfg
              mkdir -p "$BAKKES_DATA/cfg"
              touch "$BAKKES_DATA/cfg/plugins.cfg"

              # Check if plugin is already in config
              if ! grep -q "^plugin load $PLUGIN_NAME_LOWER$" "$BAKKES_DATA/cfg/plugins.cfg" 2>/dev/null; then
                  echo "plugin load $PLUGIN_NAME_LOWER" >> "$BAKKES_DATA/cfg/plugins.cfg"
                  echo "Enabled $PLUGIN_NAME in plugins.cfg"
              fi
          fi
        '')
        cfg.plugins}

      echo "Plugin sync complete"
    '';

    # Launcher script - runs BakkesMod when Rocket League starts
    bakkes-launcher = pkgs.writeShellScriptBin "bakkes-launcher" ''
      # BakkesMod launcher for NixOS
      # Add to Rocket League Steam launch options:
      #   bakkes-launcher %command%

      # Rocket League prefix and Proton paths
      RL_PREFIX="$HOME/.steam/steam/steamapps/compatdata/252950"

      # Detect Proton version from config_info (don't fail if it errors)
      PROTON=$(${pkgs.gnused}/bin/sed -n 3p "$RL_PREFIX/config_info" 2>/dev/null | ${pkgs.findutils}/bin/xargs -d '\n' dirname 2>/dev/null) || true

      # Ensure Windows 10 is set (BakkesMod requires it)
      if [ -d "$RL_PREFIX/pfx" ] && [ -n "$PROTON" ]; then
          WIN_VER=$(WINEPREFIX="$RL_PREFIX/pfx" "$PROTON/bin/wine64" reg query 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentVersion 2>/dev/null | ${pkgs.gnugrep}/bin/grep "10.0" || echo "")
          if [ -z "$WIN_VER" ]; then
              WINEPREFIX="$RL_PREFIX/pfx" "$PROTON/bin/wine64" reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentVersion /t REG_SZ /d "10.0" /f >/dev/null 2>&1
              WINEPREFIX="$RL_PREFIX/pfx" "$PROTON/bin/wine64" reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuild /t REG_SZ /d "19045" /f >/dev/null 2>&1
          fi
      fi

      # Background worker - launches BakkesMod when game starts
      (
          # Wait for Rocket League to start (the Windows exe, not the launcher)
          while ! ${pkgs.procps}/bin/pgrep -f "Z:.*RocketLeague.exe" 2> /dev/null; do
              ${pkgs.coreutils}/bin/sleep 1
          done

          # Let RL fully initialize before injecting
          ${pkgs.coreutils}/bin/sleep 5

          # Run BakkesMod directly from nix store - it's self-contained!
          WINEDEBUG=-all WINEFSYNC=1 WINEPREFIX="$RL_PREFIX/pfx" "$PROTON/bin/wine64" ${cfg.package}/bin/BakkesMod.exe 2>/dev/null &
          BAKKES_PID=$!

          # Wait for BakkesMod to create its data directory (max 30 seconds)
          BAKKES_DATA="$RL_PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/bakkesmod/bakkesmod"
          WAIT_COUNT=0
          while [ ! -d "$BAKKES_DATA" ] && [ $WAIT_COUNT -lt 30 ]; do
              ${pkgs.coreutils}/bin/sleep 1
              WAIT_COUNT=$((WAIT_COUNT + 1))
          done

          # Sync Nix-managed configuration and plugins
          if [ -d "$BAKKES_DATA" ]; then
              ${bakkes-config-sync}/bin/bakkes-config-sync "$BAKKES_DATA"
              ${bakkes-plugin-sync}/bin/bakkes-plugin-sync "$BAKKES_DATA"
          fi
      ) &
      BAKKES_WORKER_PID=$!

      # Run the game in foreground
      "$@"
      GAME_EXIT_CODE=$?

      # Game exited - clean up BakkesMod
      kill $BAKKES_WORKER_PID 2>/dev/null
      ${pkgs.procps}/bin/pkill -f "BakkesMod.exe" 2>/dev/null

      exit $GAME_EXIT_CODE
    '';
  in {
    home.packages = [
      # To use: add 'bakkes-launcher %command%' to Rocket League Steam launch options
      bakkes-launcher
    ];
  });
}
