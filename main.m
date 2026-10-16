#import <AppKit/AppKit.h>
#import "Config.h"
#import "History.h"
#import "QueryEditor.h"
#include <assert.h>
#include <math.h>

static LauncherConfig *config;
static NSUInteger VisibleRows;
static CGFloat Padding;
static CGFloat ResultSpacing;

static NSColor *backgroundColor(void) {
    return config.backgroundColor;
}

static NSColor *textColor(void) {
    return config.textColor;
}

static NSFont *launcherFont(void) {
    return config.font;
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
            NSForegroundColorAttributeName:selected ? config.selectionColor : textColor(),
            NSParagraphStyleAttributeName:paragraph
        };
        CGFloat y = i * (rowHeight() + ResultSpacing);
        if (selected) {
            [config.selectionBackground setFill];
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
@property(copy) NSString *configPath;
@property BOOL launching;
@property LaunchHistory *history;
@end

@implementation Launcher
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    config = [[LauncherConfig alloc] initWithContentsOfFile:self.configPath];
    Padding = config.padding;
    ResultSpacing = config.resultSpacing;
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
    self.window.backgroundColor = [backgroundColor() colorWithAlphaComponent:config.backgroundOpacity];
    self.window.level = NSFloatingWindowLevel;
    self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorFullScreenAuxiliary;

    CGFloat minimumWidth = ceil([@">  MMMM" sizeWithAttributes:@{NSFontAttributeName:launcherFont()}].width) + Padding * 2;
    CGFloat x = MIN(floor(screen.size.width * config.xPosition / 100), MAX(0, screen.size.width - minimumWidth - 16));
    CGFloat width = screen.size.width - x - 16;
    NSUInteger fittingRows = MAX(1, floor((screen.size.height - rowHeight()) / (rowHeight() + ResultSpacing)));
    VisibleRows = MIN(config.visibleRows, fittingRows);
    CGFloat resultsHeight = VisibleRows * rowHeight() + (VisibleRows - 1) * ResultSpacing;
    CGFloat height = rowHeight() + ResultSpacing + resultsHeight;
    CGFloat y = MAX(0, floor(screen.size.height * (1 - config.yPosition / 100) - height));
    self.selector = [[NSView alloc] initWithFrame:NSMakeRect(x, y, width, height)];
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
    cell.usesSingleLineMode = NO;
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
            ok &= fabs(self.window.backgroundColor.alphaComponent - config.backgroundOpacity) < 0.001;
            ok &= NSEqualRects(self.window.frame, self.window.screen.frame);
            ok &= fabs(self.selector.frame.origin.x - x) < 1;
            ok &= fabs(self.selector.frame.origin.y - y) < 1;
            ok &= NSContainsRect(self.window.contentView.bounds, self.selector.frame);
            ok &= self.search.currentEditor == self.window.firstResponder;
            ok &= !self.search.isBordered && !self.search.drawsBackground;
            ok &= [self.editor.insertionPointColor isEqual:config.selectionBackground];
            ok &= [self.editor.blockTextColor isEqual:config.selectionColor];
            ok &= [self.editor.selectedTextAttributes[NSBackgroundColorAttributeName] isEqual:config.selectionBackground];
            ok &= [self.editor.selectedTextAttributes[NSForegroundColorAttributeName] isEqual:config.selectionColor];
            [self.editor insertText:@"Fgjp" replacementRange:NSMakeRange(0, self.editor.string.length)];
            [self updateResults];
            NSRange glyphs = [self.editor.layoutManager glyphRangeForTextContainer:self.editor.textContainer];
            NSRect line = [self.editor.layoutManager lineFragmentRectForGlyphAtIndex:glyphs.location effectiveRange:NULL];
            ok &= line.size.height >= floor(launcherFont().ascender - launcherFont().descender);
            NSRect textRect = NSOffsetRect(line, self.editor.textContainerOrigin.x, self.editor.textContainerOrigin.y);
            ok &= NSMinY(textRect) >= NSMinY(self.editor.bounds);
            ok &= NSMaxY(textRect) <= NSMaxY(self.editor.bounds);
            [self.editor setSelectedRange:NSMakeRange(0, 0)];
            NSRect queryText = [self.editor convertRect:self.editor.blockCursorRect toView:self.selector];
            ok &= fabs(NSMidY(self.prompt.frame) - NSMidY(queryText)) < 1;
            ok &= fabs(NSMinX(self.search.frame) - NSMinX(queryText)) < 1;
            ok &= [self.editor.font isEqual:config.font] && [self.search.font isEqual:config.font];
            ok &= [self.search.textColor isEqual:config.textColor] && [self.prompt.textColor isEqual:config.textColor];
            NSArray *installed = self.apps;
            NSMutableArray *fixtures = [NSMutableArray array];
            for (NSUInteger i = 0; i < MAX(10, VisibleRows + 3); i++) {
                [fixtures addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"/Applications/Example %02lu.app", (unsigned long)i]]];
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
            for (NSUInteger i = 0; i < VisibleRows + 1; i++) [self moveSelection:1];
            ok &= self.selected == (NSInteger)VisibleRows + 1 && self.firstVisible == 2;
            ok &= self.results.selected == (NSInteger)VisibleRows - 1;
            [self moveSelection:-1];
            ok &= self.selected == (NSInteger)VisibleRows && self.firstVisible == MIN(2, VisibleRows);
            [self moveSelection:self.filtered.count];
            ok &= self.selected == (NSInteger)self.filtered.count - 1;
            ok &= self.results.selected == (NSInteger)VisibleRows - 1;
            [self moveSelection:-(NSInteger)self.filtered.count];
            ok &= self.selected == 0 && self.firstVisible == 0;
            NSInteger clickedRow = MIN(1, VisibleRows - 1);
            self.results.onSelect(clickedRow, NO);
            ok &= self.selected == clickedRow && self.results.selected == clickedRow;
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
            ok &= [self.search.stringValue isEqualToString:@"Example "] && self.filtered.count == fixtures.count;
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
            ok &= !NSIsEmptyRect(caret) && caret.size.width > 0;
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
        self.editor.textContainerInset = NSZeroSize;
        self.editor.textContainer.lineFragmentPadding = 0;
        self.editor.blockTextColor = config.selectionColor;
        self.editor.fieldEditor = YES;
        self.editor.drawsBackground = NO;
        self.editor.richText = NO;
        self.editor.insertionPointColor = config.selectionBackground;
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
        self.editor.selectedTextAttributes = @{
            NSBackgroundColorAttributeName:config.selectionBackground,
            NSForegroundColorAttributeName:config.selectionColor
        };
        self.editor.textContainerInset = NSZeroSize;
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
    if (self.selected >= (NSInteger)self.firstVisible + (NSInteger)VisibleRows) {
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
        BOOL test = NO, smokeTest = NO;
        NSString *configPath = nil;
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--test") == 0) test = YES;
            else if (strcmp(argv[i], "--smoke-test") == 0) smokeTest = YES;
            else if (strcmp(argv[i], "--config") == 0 && i + 1 < argc) configPath = @(argv[++i]).stringByExpandingTildeInPath;
            else {
                fprintf(stderr, "Usage: MiniLaunch [--config PATH] [--test | --smoke-test]\n");
                return 2;
            }
        }
        if (test) {
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
        launcher.smokeTest = smokeTest;
        launcher.configPath = configPath ?: (smokeTest ? nil : LauncherConfig.defaultPath);
        app.delegate = launcher;
        [app run];
    }
    return 0;
}
