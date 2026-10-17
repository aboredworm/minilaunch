#import "Config.h"
#include <math.h>

static NSColor *parseColor(NSString *value) {
    if (value.length != 7 || ![value hasPrefix:@"#"]) return nil;
    NSString *hex = [value substringFromIndex:1];
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    if ([hex rangeOfCharacterFromSet:digits.invertedSet].location != NSNotFound) return nil;
    unsigned int rgb = 0;
    if (![[NSScanner scannerWithString:hex] scanHexInt:&rgb]) return nil;
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 255) / 255.0
        green:((rgb >> 8) & 255) / 255.0 blue:(rgb & 255) / 255.0 alpha:1];
}

static NSNumber *parseNumber(NSString *value, double minimum, double maximum, BOOL integer) {
    NSScanner *scanner = [NSScanner scannerWithString:value];
    scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double number;
    if (![scanner scanDouble:&number] || !scanner.isAtEnd || !isfinite(number) ||
        number < minimum || number > maximum || (integer && floor(number) != number)) return nil;
    return @(number);
}

@implementation LauncherConfig
+ (NSString *)defaultPath {
    NSString *root = NSProcessInfo.processInfo.environment[@"XDG_CONFIG_HOME"];
    if (!root.isAbsolutePath) root = [NSHomeDirectory() stringByAppendingPathComponent:@".config"];
    return [root stringByAppendingPathComponent:@"minilaunch/config"];
}

- (instancetype)init {
    return [self initWithContentsOfFile:nil];
}

- (instancetype)initWithContentsOfFile:(NSString *)path {
    self = [super init];
    if (!self) return nil;
    NSMutableDictionary *values = [@{
        @"background-color":parseColor(@"#282828"), @"text-color":parseColor(@"#ffffff"),
        @"font":@"system", @"font-size":@18, @"background-opacity":@0.8,
        @"padding":@4, @"result-spacing":@15, @"visible-rows":@7,
        @"x-position":@40, @"y-position":@35
    } mutableCopy];
    NSDictionary *ranges = @{
        @"font-size":@[@8, @72], @"background-opacity":@[@0, @1],
        @"padding":@[@0, @32], @"result-spacing":@[@0, @100],
        @"visible-rows":@[@1, @30], @"x-position":@[@0, @100], @"y-position":@[@0, @100]
    };
    NSSet *colors = [NSSet setWithArray:@[@"background-color", @"text-color",
        @"selection-background", @"selection-color"]];
    NSError *error = nil;
    NSString *contents = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error] : nil;
    if (error && error.code != NSFileReadNoSuchFileError) {
        fprintf(stderr, "MiniLaunch: could not read %s: %s\n", path.UTF8String, error.localizedDescription.UTF8String);
    }
    NSUInteger lineNumber = 0;
    for (NSString *rawLine in [contents componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        lineNumber++;
        NSString *line = [rawLine stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!line.length || [line hasPrefix:@"#"]) continue;
        NSRange separator = [line rangeOfString:@"="];
        if (separator.location == NSNotFound) {
            fprintf(stderr, "MiniLaunch: %s:%lu: expected key = value\n", path.UTF8String, (unsigned long)lineNumber);
            continue;
        }
        NSString *key = [[line substringToIndex:separator.location]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSString *value = [[line substringFromIndex:NSMaxRange(separator)]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        id parsed = nil;
        if ([colors containsObject:key]) {
            parsed = parseColor(value);
        } else if ([key isEqualToString:@"font"]) {
            if (value.length) parsed = value;
        } else if (ranges[key]) {
            NSArray *range = ranges[key];
            parsed = parseNumber(value, [range[0] doubleValue], [range[1] doubleValue],
                [key isEqualToString:@"visible-rows"]);
        } else {
            fprintf(stderr, "MiniLaunch: %s:%lu: unknown setting '%s'\n", path.UTF8String,
                (unsigned long)lineNumber, key.UTF8String);
            continue;
        }
        if (parsed) values[key] = parsed;
        else fprintf(stderr, "MiniLaunch: %s:%lu: invalid value for '%s'\n", path.UTF8String,
            (unsigned long)lineNumber, key.UTF8String);
    }
    _backgroundColor = values[@"background-color"];
    _textColor = values[@"text-color"];
    _selectionBackground = values[@"selection-background"] ?: _textColor;
    _selectionColor = values[@"selection-color"] ?: _backgroundColor;
    CGFloat fontSize = [values[@"font-size"] doubleValue];
    NSString *fontName = values[@"font"];
    if (![fontName isEqualToString:@"system"]) {
        _font = [NSFont fontWithName:fontName size:fontSize];
        if (!_font) fprintf(stderr, "MiniLaunch: font '%s' is not installed; using system monospace\n", fontName.UTF8String);
    }
    if (!_font) _font = [NSFont monospacedSystemFontOfSize:fontSize weight:NSFontWeightBold];
    _backgroundOpacity = [values[@"background-opacity"] doubleValue];
    _padding = [values[@"padding"] doubleValue];
    _resultSpacing = [values[@"result-spacing"] doubleValue];
    _visibleRows = [values[@"visible-rows"] unsignedIntegerValue];
    _xPosition = [values[@"x-position"] doubleValue];
    _yPosition = [values[@"y-position"] doubleValue];
    return self;
}

- (BOOL)isEqualToConfig:(LauncherConfig *)other {
    return [self.backgroundColor isEqual:other.backgroundColor] &&
        [self.textColor isEqual:other.textColor] &&
        [self.selectionBackground isEqual:other.selectionBackground] &&
        [self.selectionColor isEqual:other.selectionColor] &&
        [self.font isEqual:other.font] && self.backgroundOpacity == other.backgroundOpacity &&
        self.padding == other.padding && self.resultSpacing == other.resultSpacing &&
        self.visibleRows == other.visibleRows && self.xPosition == other.xPosition && self.yPosition == other.yPosition;
}
@end
