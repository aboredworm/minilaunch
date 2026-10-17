#import <AppKit/AppKit.h>

@interface LauncherConfig : NSObject
@property(readonly) NSColor *backgroundColor;
@property(readonly) NSColor *textColor;
@property(readonly) NSColor *selectionBackground;
@property(readonly) NSColor *selectionColor;
@property(readonly) NSFont *font;
@property(readonly) CGFloat backgroundOpacity;
@property(readonly) CGFloat padding;
@property(readonly) CGFloat resultSpacing;
@property(readonly) NSUInteger visibleRows;
@property(readonly) CGFloat xPosition;
@property(readonly) CGFloat yPosition;
+ (NSString *)defaultPath;
- (instancetype)initWithContentsOfFile:(NSString *)path;
- (BOOL)isEqualToConfig:(LauncherConfig *)other;
@end
