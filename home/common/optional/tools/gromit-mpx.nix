_: {
  # Screen annotation tool for screen sharing / recordings
  # F9 = toggle drawing | Shift+F9 = clear | Ctrl+F9 = toggle visibility
  # F10 = undo | Shift+F10 = redo
  # Default: red pen | Shift: blue pen | Ctrl: yellow pen | Middle click: green arrow (large) | Right click: eraser
  services.gromit-mpx = {
    enable = true;
    tools = [
      {
        device = "default";
        type = "pen";
        size = 5;
        color = "red";
      }
      {
        device = "default";
        type = "pen";
        size = 5;
        color = "blue";
        modifiers = ["SHIFT"];
      }
      {
        device = "default";
        type = "pen";
        size = 5;
        color = "yellow";
        modifiers = ["CONTROL"];
      }
      {
        device = "default";
        type = "pen";
        size = 10;
        color = "green";
        arrowSize = 2;
        modifiers = ["2"];
      }
      {
        device = "default";
        type = "eraser";
        size = 75;
        modifiers = ["3"];
      }
    ];
  };
}
