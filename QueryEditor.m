#import "QueryEditor.h"
#import <CoreText/CoreText.h>
#include <math.h>

@interface QueryEditor ()
@property(copy) NSArray *focusObservers;
@end

@implementation QueryEditor
- (NSRect)blockCursorRect {
    NSRange selection = self.selectedRange;
    if (!self.window.isKeyWindow || self.window.firstResponder != self ||
        selection.length || selection.location == NSNotFound || self.hasMarkedText) return NSZeroRect;
    NSRect rect = [self firstRectForCharacterRange:selection actualRange:NULL];
    rect = [self convertRect:[self.window convertRectFromScreen:rect] fromView:nil];
    NSFont *font = self.font ?: [NSFont monospacedSystemFontOfSize:18 weight:NSFontWeightRegular];
    rect.size.width = ceil([@"M" sizeWithAttributes:@{NSFontAttributeName:font}].width);
    if (selection.location < self.string.length) {
        NSRange character = [self.string rangeOfComposedCharacterSequenceAtIndex:selection.location];
        rect.size.width = MAX(rect.size.width, ceil([[self.string substringWithRange:character]
            sizeWithAttributes:@{NSFontAttributeName:font}].width));
    }
    return rect;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect rect = self.blockCursorRect;
    if (NSIsEmptyRect(rect) || !NSIntersectsRect(rect, dirtyRect)) return;
    [self.insertionPointColor setFill];
    NSRectFill(rect);
    if (self.selectedRange.location < self.string.length) {
        NSRange character = [self.string rangeOfComposedCharacterSequenceAtIndex:self.selectedRange.location];
        NSAttributedString *text = [[NSAttributedString alloc] initWithString:[self.string substringWithRange:character]
            attributes:@{NSFontAttributeName:self.font,
                NSForegroundColorAttributeName:self.blockTextColor ?: NSColor.blackColor}];
        NSUInteger glyph = [self.layoutManager glyphIndexForCharacterAtIndex:character.location];
        NSPoint position = [self.layoutManager locationForGlyphAtIndex:glyph];
        NSRect line = [self.layoutManager lineFragmentRectForGlyphAtIndex:glyph effectiveRange:NULL];
        [NSGraphicsContext saveGraphicsState];
        NSRectClip(rect);
        CGContextRef context = NSGraphicsContext.currentContext.CGContext;
        CGContextTranslateCTM(context, self.textContainerOrigin.x + line.origin.x + position.x,
            self.textContainerOrigin.y + line.origin.y + position.y);
        if (self.isFlipped) CGContextScaleCTM(context, 1, -1);
        CGContextSetTextMatrix(context, CGAffineTransformIdentity);
        CTLineRef glyphLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
        CTLineDraw(glyphLine, context);
        CFRelease(glyphLine);
        [NSGraphicsContext restoreGraphicsState];
    }
}

- (void)drawInsertionPointInRect:(NSRect)rect color:(NSColor *)color turnedOn:(BOOL)flag {
}

- (void)updateInsertionPointStateAndRestartTimer:(BOOL)restartFlag {
    self.needsDisplay = YES;
}

- (void)setSelectedRanges:(NSArray<NSValue *> *)ranges affinity:(NSSelectionAffinity)affinity
    stillSelecting:(BOOL)stillSelecting {
    [super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelecting];
    self.needsDisplay = YES;
}

- (void)didChangeText {
    [super didChangeText];
    self.needsDisplay = YES;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (id observer in self.focusObservers) [center removeObserver:observer];
    NSMutableArray *observers = [NSMutableArray array];
    __weak QueryEditor *editor = self;
    if (self.window) {
        for (NSNotificationName name in @[NSWindowDidBecomeKeyNotification, NSWindowDidResignKeyNotification]) {
            [observers addObject:[center addObserverForName:name object:self.window queue:nil
                usingBlock:^(NSNotification *notification) { editor.needsDisplay = YES; }]];
        }
    }
    self.focusObservers = observers;
}

- (void)dealloc {
    for (id observer in _focusObservers) [NSNotificationCenter.defaultCenter removeObserver:observer];
}

- (void)keyDown:(NSEvent *)event {
    NSEventModifierFlags modifiers = event.modifierFlags &
        (NSEventModifierFlagControl | NSEventModifierFlagCommand | NSEventModifierFlagOption);
    if (modifiers == NSEventModifierFlagControl) {
        NSString *key = event.charactersIgnoringModifiers.lowercaseString;
        if ([key isEqualToString:@"u"] || [event.characters isEqualToString:@"\x15"]) {
            [self insertText:@"" replacementRange:NSMakeRange(0, self.string.length)];
            return;
        }
        if ([key isEqualToString:@"w"] || [event.characters isEqualToString:@"\x17"]) {
            [self deleteWordBackward:nil];
            return;
        }
    }
    [super keyDown:event];
}
@end
