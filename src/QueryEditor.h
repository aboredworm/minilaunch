#import <AppKit/AppKit.h>

@interface QueryEditor : NSTextView
@property NSColor *blockTextColor;
- (NSRect)blockCursorRect;
@end
