#import <Foundation/Foundation.h>

@interface LaunchHistory : NSObject
@property(readonly, copy) NSDictionary<NSString *, NSNumber *> *counts;
- (instancetype)initWithURL:(NSURL *)url;
- (BOOL)recordLaunch:(NSURL *)app;
@end

NSArray<NSURL *> *rankApps(NSArray<NSURL *> *apps, NSString *query,
    NSDictionary<NSString *, NSNumber *> *counts);
