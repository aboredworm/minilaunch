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
        BOOL test = NO;
        NSString *configPath = nil;
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--test") == 0) test = YES;
            else if (strcmp(argv[i], "--config") == 0 && i + 1 < argc) configPath = @(argv[++i]).stringByExpandingTildeInPath;
            else {
                fprintf(stderr, "Usage: MiniLaunch [--config PATH] [--test]\n");
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
        launcher.configPath = configPath ?: LauncherConfig.defaultPath;
        app.delegate = launcher;
        [app run];
    }
    return 0;
}
