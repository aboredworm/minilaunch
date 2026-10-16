#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#import "History.h"
#import "QueryEditor.h"
#include <assert.h>
#include <math.h>

enum { VisibleRows = 7 };
static const CGFloat FontSize = 18;
static const CGFloat Padding = 4;
static const CGFloat ResultSpacing = 15;

static NSColor *backgroundColor(void) {
    return [NSColor colorWithSRGBRed:40.0/255 green:40.0/255 blue:40.0/255 alpha:1];
}

static NSColor *textColor(void) {
    return [NSColor colorWithSRGBRed:212.0/255 green:190.0/255 blue:152.0/255 alpha:1];
}

static NSFont *launcherFont(void) {
    static NSFont *font;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *url = [NSBundle.mainBundle URLForResource:@"NotoSansMono-ExtraCondensedBlack" withExtension:@"ttf"];
        if (url) CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, NULL);
        font = [NSFont fontWithName:@"NotoSansMono-ExtraCondensedBlack" size:FontSize]
            ?: [NSFont fontWithName:@"FiraMonoNFM-Bold" size:FontSize]
            ?: [NSFont monospacedSystemFontOfSize:FontSize weight:NSFontWeightBold];
    });
    return font;
}

static CGFloat textHeight(void) {
    NSFont *font = launcherFont();
    return ceil(font.ascender - font.descender + font.leading);
}

static CGFloat rowHeight(void) {
    return textHeight() + Padding * 2;
}

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

static void sendControlKey(QueryEditor *editor, NSString *key) {
    NSString *character = [key isEqualToString:@"u"] ? @"\x15" : @"\x17";
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:NSEventModifierFlagControl timestamp:0 windowNumber:editor.window.windowNumber
        context:nil characters:character charactersIgnoringModifiers:key isARepeat:NO
        keyCode:[key isEqualToString:@"u"] ? 32 : 13];
    [editor keyDown:event];
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

@interface ResultsView : NSView
@property NSArray<NSString *> *names;
@property NSInteger selected;
@property(copy) void (^onSelect)(NSInteger, BOOL);
@end

@implementation ResultsView
- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    for (NSUInteger i = 0; i < self.names.count; i++) {
        BOOL selected = (NSInteger)i == self.selected;
        NSDictionary *attributes = @{
            NSFontAttributeName:launcherFont(),
            NSForegroundColorAttributeName:selected ? backgroundColor() : textColor(),
            NSParagraphStyleAttributeName:paragraph
        };
        CGFloat y = i * (rowHeight() + ResultSpacing);
        if (selected) {
            [textColor() setFill];
            CGFloat width = MIN(self.bounds.size.width,
                ceil([self.names[i] sizeWithAttributes:attributes].width) + Padding * 2);
            NSRectFill(NSMakeRect(0, y, width, rowHeight()));
        }
        [self.names[i] drawInRect:NSMakeRect(Padding, y + Padding,
            self.bounds.size.width - Padding * 2, textHeight()) withAttributes:attributes];
    }
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger row = floor(point.y / (rowHeight() + ResultSpacing));
    CGFloat withinRow = point.y - row * (rowHeight() + ResultSpacing);
    if (row >= 0 && row < (NSInteger)self.names.count && withinRow < rowHeight()) {
        if (self.onSelect) self.onSelect(row, event.clickCount == 2);
    }
}
@end

@interface LauncherWindow : NSWindow
@end

@implementation LauncherWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

@interface Launcher : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextFieldDelegate>
@property NSWindow *window;
@property NSView *selector;
@property NSTextField *prompt;
@property NSTextField *search;
@property QueryEditor *editor;
@property ResultsView *results;
@property NSArray<NSURL *> *apps;
@property NSArray<NSURL *> *filtered;
@property NSInteger selected;
@property NSUInteger firstVisible;
@property BOOL smokeTest;
@property BOOL launching;
@property LaunchHistory *history;
@end

@implementation Launcher
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.apps = installedApps();
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
        inDomains:NSUserDomainMask].firstObject;
    NSURL *historyURL = [[support URLByAppendingPathComponent:@"MiniLaunch"] URLByAppendingPathComponent:@"usage.json"];
    if (self.smokeTest) {
        historyURL = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
    }
    self.history = [[LaunchHistory alloc] initWithURL:historyURL];
    NSRect screen = NSScreen.mainScreen.frame;
    self.window = [[LauncherWindow alloc] initWithContentRect:screen
        styleMask:NSWindowStyleMaskBorderless
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"MiniLaunch";
    self.window.delegate = self;
    self.window.releasedWhenClosed = NO;
    self.window.opaque = NO;
    self.window.hasShadow = NO;
    self.window.backgroundColor = [backgroundColor() colorWithAlphaComponent:0.8];
    self.window.level = NSFloatingWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorFullScreenAuxiliary;

    CGFloat x = floor(screen.size.width * 0.4);
    CGFloat width = screen.size.width - x - 16;
    CGFloat resultsHeight = VisibleRows * rowHeight() + (VisibleRows - 1) * ResultSpacing;
    CGFloat height = rowHeight() + ResultSpacing + resultsHeight;
    self.selector = [[NSView alloc] initWithFrame:NSMakeRect(x,
        floor(screen.size.height * 0.65 - height), width, height)];
    [self.window.contentView addSubview:self.selector];

    self.prompt = [NSTextField labelWithString:@">  "];
    self.prompt.font = launcherFont();
    self.prompt.textColor = textColor();
    CGFloat promptWidth = ceil([@">  " sizeWithAttributes:@{NSFontAttributeName:launcherFont()}].width);
    self.prompt.frame = NSMakeRect(Padding, height - rowHeight() + Padding, promptWidth, textHeight());
    [self.selector addSubview:self.prompt];

    self.search = [[NSTextField alloc] initWithFrame:NSMakeRect(Padding + promptWidth,
        height - rowHeight() + Padding, width - promptWidth - Padding * 2, textHeight())];
    self.search.font = launcherFont();
    self.search.textColor = textColor();
    self.search.bezeled = NO;
    self.search.bordered = NO;
    self.search.drawsBackground = NO;
    self.search.focusRingType = NSFocusRingTypeNone;
    self.search.delegate = self;
    NSTextFieldCell *cell = self.search.cell;
    cell.wraps = NO;
    cell.usesSingleLineMode = YES;
    cell.scrollable = YES;
    [self.selector addSubview:self.search];

    self.results = [[ResultsView alloc] initWithFrame:NSMakeRect(0, 0, width, resultsHeight)];
    __weak Launcher *weakSelf = self;
    self.results.onSelect = ^(NSInteger row, BOOL launch) {
        Launcher *launcher = weakSelf;
        if (!launcher) return;
        launcher.selected = launcher.firstVisible + row;
        [launcher renderResults];
        if (launch) [launcher launchSelected:nil];
    };
    [self.selector addSubview:self.results];
    [self updateResults];
    [self show];

    if (self.smokeTest) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            BOOL ok = self.window.isVisible && self.window.isKeyWindow && self.apps.count > 0;
            ok &= self.filtered.count == 0 && self.selected == -1 && self.results.names.count == 0;
            ok &= self.window.styleMask == NSWindowStyleMaskBorderless;
            ok &= !self.window.hasShadow && !self.window.isOpaque;
            ok &= fabs(self.window.backgroundColor.alphaComponent - 0.8) < 0.001;
            ok &= NSEqualRects(self.window.frame, self.window.screen.frame);
            ok &= fabs(self.selector.frame.origin.x - floor(self.window.frame.size.width * 0.4)) < 1;
            ok &= fabs(NSMaxY(self.selector.frame) - self.window.frame.size.height * 0.65) < 1;
            ok &= self.search.currentEditor == self.window.firstResponder;
            ok &= !self.search.isBordered && !self.search.drawsBackground;
            ok &= [self.editor.insertionPointColor isEqual:textColor()];
            [self.editor insertText:@"Example" replacementRange:NSMakeRange(0, self.editor.string.length)];
            [self updateResults];
            [self.editor setSelectedRange:NSMakeRange(0, 0)];
            NSRect queryText = [self.editor convertRect:self.editor.blockCursorRect toView:self.selector];
            ok &= fabs(NSMidY(self.prompt.frame) - NSMidY(queryText)) < 1;
            ok &= fabs(NSMinX(self.search.frame) - NSMinX(queryText)) < 1;
            ok &= [launcherFont().fontName isEqualToString:@"NotoSansMono-ExtraCondensedBlack"];
            ok &= launcherFont().pointSize == FontSize;
            NSArray *installed = self.apps;
            NSMutableArray *fixtures = [NSMutableArray array];
            for (int i = 0; i < 10; i++) {
                [fixtures addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"/Applications/Example %02d.app", i]]];
            }
            self.apps = fixtures;
            self.search.stringValue = @"Example";
            [self updateResults];
            ok &= self.results.names.count == VisibleRows;
            const char *preview = getenv("MINILAUNCH_PREVIEW");
            if (preview) {
                [self.editor setSelectedRange:NSMakeRange(MIN(3, self.editor.string.length), 0)];
                self.results.needsDisplay = YES;
                NSBitmapImageRep *image = [self.selector bitmapImageRepForCachingDisplayInRect:self.selector.bounds];
                [self.selector cacheDisplayInRect:self.selector.bounds toBitmapImageRep:image];
                NSData *png = [image representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                ok &= [png writeToFile:@(preview) atomically:YES];
            }
            for (int i = 0; i < VisibleRows + 1; i++) [self moveSelection:1];
            ok &= self.selected == VisibleRows + 1 && self.firstVisible == 2;
            ok &= self.results.selected == VisibleRows - 1;
            [self moveSelection:-1];
            ok &= self.selected == VisibleRows && self.firstVisible == 2;
            [self moveSelection:self.filtered.count];
            ok &= self.selected == (NSInteger)self.filtered.count - 1;
            ok &= self.results.selected == VisibleRows - 1;
            [self moveSelection:-(NSInteger)self.filtered.count];
            ok &= self.selected == 0 && self.firstVisible == 0;
            self.results.onSelect(1, NO);
            ok &= self.selected == 1 && self.results.selected == 1;
            self.search.stringValue = self.apps.firstObject.lastPathComponent.stringByDeletingPathExtension;
            [self updateResults];
            ok &= [self.filtered containsObject:self.apps.firstObject] && self.selected == 0;
            ok &= self.firstVisible == 0;
            [self moveSelection:-1];
            ok &= self.selected == 0;
            self.search.stringValue = @"this-app-does-not-exist-123456789";
            [self updateResults];
            ok &= self.filtered.count == 0 && self.selected == -1 && self.results.names.count == 0;
            [self launchSelected:nil];
            [self.editor insertText:@"Example 09" replacementRange:NSMakeRange(0, self.editor.string.length)];
            ok &= [self.search.stringValue isEqualToString:@"Example 09"] && self.filtered.count == 1;
            sendControlKey(self.editor, @"w");
            ok &= [self.search.stringValue isEqualToString:@"Example "] && self.filtered.count == 10;
            [self.editor setSelectedRange:NSMakeRange(2, 0)];
            sendControlKey(self.editor, @"u");
            ok &= self.search.stringValue.length == 0 && self.filtered.count == 0;
            sendControlKey(self.editor, @"w");
            sendControlKey(self.editor, @"u");
            ok &= self.editor.string.length == 0;
            [self.editor insertText:@"café world" replacementRange:NSMakeRange(0, self.editor.string.length)];
            sendControlKey(self.editor, @"w");
            ok &= [self.editor.string isEqualToString:@"café "];
            [self.editor setSelectedRange:NSMakeRange(0, 4)];
            ok &= NSIsEmptyRect(self.editor.blockCursorRect);
            sendControlKey(self.editor, @"w");
            ok &= [self.editor.string isEqualToString:@" "];
            [self.editor insertText:@"one two three" replacementRange:NSMakeRange(0, self.editor.string.length)];
            [self.editor setSelectedRange:NSMakeRange(7, 0)];
            sendControlKey(self.editor, @"w");
            ok &= [self.editor.string isEqualToString:@"one  three"];
            sendControlKey(self.editor, @"u");
            [self.editor insertText:@"abc" replacementRange:NSMakeRange(0, self.editor.string.length)];
            [self.editor deleteBackward:nil];
            ok &= [self.search.stringValue isEqualToString:@"ab"];
            sendControlKey(self.editor, @"\x17");
            ok &= self.search.stringValue.length == 0;
            NSRect caret = self.editor.blockCursorRect;
            ok &= !NSIsEmptyRect(caret) && caret.size.width >= 5;
            [self.editor drawInsertionPointInRect:caret color:textColor() turnedOn:NO];
            [self.editor updateInsertionPointStateAndRestartTimer:YES];
            ok &= NSEqualRects(caret, self.editor.blockCursorRect);
            self.apps = installed;
            self.search.stringValue = @"";
            [self updateResults];
            ok &= self.filtered.count == 0 && self.selected == -1;
            printf("UI smoke test: %s (%lu apps, font: %s)\n", ok ? "PASS" : "FAIL",
                (unsigned long)self.apps.count, launcherFont().fontName.UTF8String);
            exit(ok ? 0 : 1);
        });
    }
}

- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)object {
    if (object != self.search) return nil;
    if (!self.editor) {
        self.editor = [QueryEditor new];
        self.editor.font = launcherFont();
        self.editor.textContainerInset = NSMakeSize(0, 4.5);
        self.editor.textContainer.lineFragmentPadding = 0;
        self.editor.blockTextColor = backgroundColor();
        self.editor.fieldEditor = YES;
        self.editor.drawsBackground = NO;
        self.editor.richText = NO;
        self.editor.insertionPointColor = textColor();
        self.editor.selectedTextAttributes = @{
            NSBackgroundColorAttributeName:textColor(),
            NSForegroundColorAttributeName:backgroundColor()
        };
        self.editor.automaticQuoteSubstitutionEnabled = NO;
        self.editor.automaticSpellingCorrectionEnabled = NO;
    }
    return self.editor;
}

- (void)show {
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.search];
    if (self.search.currentEditor == self.editor) {
        self.editor.textContainer.lineFragmentPadding = 0;
        [self.editor invalidateTextContainerOrigin];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)visible {
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
    self.filtered = rankApps(self.filtered, query, self.history.counts);
    self.selected = self.filtered.count ? 0 : -1;
    self.firstVisible = 0;
    [self renderResults];
}

- (void)renderResults {
    NSUInteger count = MIN(VisibleRows, self.filtered.count - self.firstVisible);
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger i = self.firstVisible; i < self.firstVisible + count; i++) {
        [names addObject:self.filtered[i].lastPathComponent.stringByDeletingPathExtension];
    }
    self.results.names = names;
    self.results.selected = self.selected - (NSInteger)self.firstVisible;
    self.results.needsDisplay = YES;
}

- (void)moveSelection:(NSInteger)step {
    if (!self.filtered.count) return;
    self.selected = MAX(0, MIN((NSInteger)self.filtered.count - 1, self.selected + step));
    if (self.selected < (NSInteger)self.firstVisible) self.firstVisible = self.selected;
    if (self.selected >= (NSInteger)self.firstVisible + VisibleRows) {
        self.firstVisible = self.selected - VisibleRows + 1;
    }
    [self renderResults];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self updateResults];
}

- (void)launchSelected:(id)sender {
    NSInteger row = self.selected;
    if (self.launching || row < 0 || row >= (NSInteger)self.filtered.count) return;
    NSURL *url = self.filtered[row];
    self.launching = YES;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:url
        configuration:NSWorkspaceOpenConfiguration.configuration
        completionHandler:^(NSRunningApplication *app, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    self.launching = NO;
                    NSAlert *alert = [NSAlert new];
                    alert.messageText = @"Could not launch app";
                    alert.informativeText = error.localizedDescription;
                    [alert runModal];
                } else {
                    [self.history recordLaunch:url];
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
        [self moveSelection:command == @selector(moveDown:) ? 1 : -1];
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
