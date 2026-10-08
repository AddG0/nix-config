// Usage: app-visibility <hide|unhide> <pid>...  AppKit hide needs no Automation permission, unlike System Events.
#import <AppKit/AppKit.h>

int main(int argc, char *argv[]) {
  @autoreleasepool {
    if (argc < 2 || (strcmp(argv[1], "hide") != 0 && strcmp(argv[1], "unhide") != 0)) {
      fprintf(stderr, "app-visibility: unknown action \"%s\", expected hide or unhide\n", argc < 2 ? "" : argv[1]);
      return 2;
    }
    BOOL hide = strcmp(argv[1], "hide") == 0;
    for (int i = 2; i < argc; i++) {
      NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:atoi(argv[i])];
      if (app == nil) continue; // exited since the snapshot
      if (hide) [app hide]; else [app unhide];
    }
  }
  return 0;
}
