#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 2;
        pid_t pid = (pid_t)atoi(argv[1]);
        NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
        if (!app.active) fprintf(stderr, "MiniLaunch is not the active app.\n");
        NSArray *windows = CFBridgingRelease(CGWindowListCopyWindowInfo(
            kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
        for (NSDictionary *window in windows) {
            if ([window[(id)kCGWindowOwnerPID] intValue] != pid) continue;
            CGRect bounds;
            if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)window[(id)kCGWindowBounds], &bounds)) continue;
            for (NSScreen *screen in NSScreen.screens) {
                if (CGSizeEqualToSize(bounds.size, screen.frame.size)) {
                    if (!app.active) fprintf(stderr, "The overlay is still on screen.\n");
                    return app.active ? 0 : 1;
                }
            }
        }
        fprintf(stderr, "No screen-sized MiniLaunch window is on screen.\n");
        return 1;
    }
}
