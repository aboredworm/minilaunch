#import <AppKit/AppKit.h>
#include <assert.h>
#include <math.h>

static BOOL matches(NSString *query, NSString *name) {
    NSStringCompareOptions options = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    NSUInteger start = 0;
    for (NSUInteger i = 0; i < query.length;) {
        NSRange character = [query rangeOfComposedCharacterSequenceAtIndex:i];
        NSRange found = [name rangeOfString:[query substringWithRange:character]
                                   options:options
                                     range:NSMakeRange(start, name.length - start)];
        if (found.location == NSNotFound) return NO;
        start = NSMaxRange(found);
        i = NSMaxRange(character);
    }
    return YES;
}

static NSArray<NSURL *> *installedApps(void) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *directories = @[@"/Applications", @"/Applications/Utilities",
        @"/System/Applications", @"/System/Applications/Utilities",
        @"/System/Library/CoreServices/Applications", @"~/Applications"];
    NSMutableArray *apps = [NSMutableArray array];
    for (NSString *directory in directories) {
        NSArray *entries = [fm contentsOfDirectoryAtURL:
            [NSURL fileURLWithPath:directory.stringByExpandingTildeInPath]
            includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
        for (NSURL *url in entries) {
            if ([url.pathExtension.lowercaseString isEqualToString:@"app"]) [apps addObject:url];
        }
    }
    return [apps sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        return [a.lastPathComponent localizedCaseInsensitiveCompare:b.lastPathComponent];
    }];
}

@interface LauncherWindow : NSPanel
@end

@implementation LauncherWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

@interface Launcher : NSObject <NSApplicationDelegate, NSWindowDelegate,
    NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property NSWindow *window;
@property NSView *selector;
@property NSTextField *search;
@property NSTableView *table;
@property NSArray<NSURL *> *apps;
@property NSArray<NSURL *> *filtered;
@property BOOL smokeTest;
@end

@implementation Launcher
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.apps = installedApps();
    NSRect screen = NSScreen.mainScreen.frame;
    self.window = [[LauncherWindow alloc] initWithContentRect:screen
        styleMask:NSWindowStyleMaskBorderless
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"MiniLaunch";
    self.window.delegate = self;
    self.window.releasedWhenClosed = NO;
    self.window.opaque = NO;
    self.window.hasShadow = NO;
    self.window.backgroundColor = [NSColor colorWithWhite:0 alpha:0.6];
    self.window.level = NSFloatingWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorFullScreenAuxiliary;

    CGFloat width = MIN(560, screen.size.width - 32);
    CGFloat height = MIN(330, screen.size.height - 32);
    self.selector = [[NSView alloc] initWithFrame:NSMakeRect(
        (screen.size.width - width) / 2, (screen.size.height - height) / 2, width, height)];
    [self.window.contentView addSubview:self.selector];

    self.search = [[NSTextField alloc] initWithFrame:NSMakeRect(16, height - 44, width - 32, 28)];
    self.search.placeholderString = @"Search apps…";
    self.search.delegate = self;
    [self.selector addSubview:self.search];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 16, width - 32, height - 72)];
    scroll.hasVerticalScroller = YES;
    self.table = [[NSTableView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"app"];
    column.width = width - 52;
    [self.table addTableColumn:column];
    self.table.headerView = nil;
    self.table.rowHeight = 30;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.target = self;
    self.table.doubleAction = @selector(launchSelected:);
    scroll.documentView = self.table;
    [self.selector addSubview:scroll];
    [self updateResults];
    [self show];

    if (self.smokeTest) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            BOOL ok = self.window.isVisible && self.window.isKeyWindow && self.table.numberOfRows > 0;
            ok &= self.window.styleMask == NSWindowStyleMaskBorderless;
            ok &= !self.window.hasShadow && !self.window.isOpaque;
            ok &= self.window.backgroundColor.alphaComponent > 0 && self.window.backgroundColor.alphaComponent < 1;
            ok &= NSEqualRects(self.window.frame, self.window.screen.frame);
            ok &= fabs(NSMidX(self.selector.frame) - NSMidX(self.window.contentView.bounds)) < 1;
            ok &= fabs(NSMidY(self.selector.frame) - NSMidY(self.window.contentView.bounds)) < 1;
            ok &= self.search.currentEditor == self.window.firstResponder;
            self.search.stringValue = self.apps.firstObject.lastPathComponent.stringByDeletingPathExtension;
            [self updateResults];
            ok &= [self.filtered containsObject:self.apps.firstObject] && self.table.selectedRow == 0;
            [self control:self.search textView:[NSTextView new] doCommandBySelector:@selector(moveUp:)];
            ok &= self.table.selectedRow == 0;
            self.search.stringValue = @"this-app-does-not-exist-123456789";
            [self updateResults];
            ok &= self.filtered.count == 0 && self.table.selectedRow == -1;
            [self launchSelected:nil];
            self.search.stringValue = @"";
            [self updateResults];
            printf("UI smoke test: %s (%ld apps)\n", ok ? "PASS" : "FAIL", (long)self.table.numberOfRows);
            exit(ok ? 0 : 1);
        });
    }
}

- (void)show {
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.search];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible {
    if (self.window.isVisible) {
        [self.window orderOut:nil];
        [app terminate:nil];
        return NO;
    }
    [self show];
    return YES;
}

- (void)updateResults {
    NSString *query = [self.search.stringValue stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    self.filtered = [self.apps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:
        ^BOOL(NSURL *url, NSDictionary *bindings) {
            return matches(query, url.lastPathComponent.stringByDeletingPathExtension);
        }]];
    [self.table reloadData];
    if (self.filtered.count) {
        [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self.table scrollRowToVisible:0];
    }
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self updateResults];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)table {
    return self.filtered.count;
}

- (NSView *)tableView:(NSTableView *)table viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    NSTextField *label = [NSTextField labelWithString:
        self.filtered[row].lastPathComponent.stringByDeletingPathExtension];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

- (void)launchSelected:(id)sender {
    NSInteger row = self.table.selectedRow;
    if (row < 0 || row >= (NSInteger)self.filtered.count) return;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:self.filtered[row]
        configuration:NSWorkspaceOpenConfiguration.configuration
        completionHandler:^(NSRunningApplication *app, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSAlert *alert = [NSAlert new];
                    alert.messageText = @"Could not launch app";
                    alert.informativeText = error.localizedDescription;
                    [alert runModal];
                } else {
                    [NSApp terminate:nil];
                }
            });
        }];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)view doCommandBySelector:(SEL)command {
    if (command == @selector(cancelOperation:)) {
        [NSApp terminate:nil];
    } else if (command == @selector(insertNewline:)) {
        [self launchSelected:nil];
    } else if (command == @selector(moveDown:) || command == @selector(moveUp:)) {
        NSInteger count = self.filtered.count;
        if (count) {
            NSInteger row = self.table.selectedRow + (command == @selector(moveDown:) ? 1 : -1);
            row = MAX(0, MIN(count - 1, row));
            [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [self.table scrollRowToVisible:row];
        }
    } else {
        return NO;
    }
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--test") == 0) {
            assert(matches(@"", @"Safari"));
            assert(matches(@"sfr", @"Safari"));
            assert(matches(@"NCM", @"Nimble Commander"));
            assert(matches(@"cafe", @"Café"));
            assert(!matches(@"fs", @"Safari"));
            assert(!matches(@"safarix", @"Safari"));
            assert(installedApps().count > 0);
            puts("Search and app discovery tests passed.");
            return 0;
        }
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        Launcher *launcher = [Launcher new];
        launcher.smokeTest = argc > 1 && strcmp(argv[1], "--smoke-test") == 0;
        app.delegate = launcher;
        [app run];
    }
    return 0;
}
