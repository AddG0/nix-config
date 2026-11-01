{
  harness,
  pkgs,
  ...
}: let
  hook = import ../hooks.nix {inherit pkgs;};
  hide = "${hook "hide-pick"}/bin/blind-choices-hide-pick";
  reveal = "${hook "reveal-pick"}/bin/blind-choices-reveal-pick";

  question = pkgs.writeText "question.json" (builtins.toJSON {
    tool_use_id = "toolu_1";
    tool_input.questions = [
      {
        question = "Which approach?";
        header = "Approach";
        multiSelect = false;
        options = [
          {
            label = "Hook (Recommended)";
            description = "a";
          }
          {
            label = "Prompt";
            description = "b";
          }
          {
            label = "Both";
            description = "c";
          }
        ];
      }
      {
        question = "Scope?";
        header = "Scope";
        multiSelect = false;
        options = [
          {
            label = "Popups";
            description = "x";
          }
          {
            label = "Everywhere (Recommended)";
            description = "y";
          }
        ];
      }
    ];
  });
in
  harness.bats "blind-choices-test" [./blind-choices.bats] {
    nativeBuildInputs = [pkgs.jq];
    inherit hide reveal question;
  }
