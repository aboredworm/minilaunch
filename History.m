#import "History.h"
#import "Search.h"
#include <limits.h>

@interface LaunchHistory ()
@property(readwrite, copy) NSDictionary<NSString *, NSNumber *> *counts;
@property NSURL *url;
@end

@implementation LaunchHistory
- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (!self) return nil;
    self.url = url;
    NSMutableDictionary *counts = [NSMutableDictionary dictionary];
    NSData *data = [NSData dataWithContentsOfURL:url];
    id stored = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if ([stored isKindOfClass:NSDictionary.class]) {
        for (NSString *path in stored) {
            id value = stored[path];
            if (![value isKindOfClass:NSNumber.class]) continue;
            if (CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) continue;
            long long count = [value longLongValue];
            if (count > 0 && [value isEqualToNumber:@(count)]) counts[path] = @(count);
        }
    }
    self.counts = counts;
    return self;
}

- (BOOL)recordLaunch:(NSURL *)app {
    NSMutableDictionary *counts = self.counts.mutableCopy;
    long long count = [counts[app.path] longLongValue];
    counts[app.path] = @(count < LLONG_MAX ? count + 1 : count);
    NSError *error = nil;
    BOOL saved = [NSFileManager.defaultManager createDirectoryAtURL:self.url.URLByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:&error];
    if (saved) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:counts
            options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        saved = data && [data writeToURL:self.url options:NSDataWritingAtomic error:&error];
    }
    if (!saved) {
        fprintf(stderr, "Could not save launch history: %s\n", error.localizedDescription.UTF8String);
        return NO;
    }
    self.counts = counts;
    return YES;
}
@end

NSArray<NSURL *> *rankApps(NSArray<NSURL *> *apps, NSString *query,
    NSDictionary<NSString *, NSNumber *> *counts) {
    NSMutableArray *candidates = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSNumber *> *scores = [NSMutableDictionary dictionary];
    for (NSURL *app in apps) {
        if (query.length) {
            NSInteger score = fuzzyScore(query, app.lastPathComponent.stringByDeletingPathExtension);
            if (score < 0) continue;
            scores[app.path] = @(score);
        } else if ([counts[app.path] longLongValue] <= 0) {
            continue;
        }
        [candidates addObject:app];
    }
    return [candidates sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        if (query.length) {
            NSInteger leftScore = scores[a.path].integerValue, rightScore = scores[b.path].integerValue;
            if (leftScore != rightScore) return leftScore > rightScore ? NSOrderedAscending : NSOrderedDescending;
        }
        long long left = [counts[a.path] longLongValue];
        long long right = [counts[b.path] longLongValue];
        if (left != right) return left > right ? NSOrderedAscending : NSOrderedDescending;
        NSComparisonResult nameOrder = [a.lastPathComponent localizedCaseInsensitiveCompare:b.lastPathComponent];
        return nameOrder == NSOrderedSame ? [a.path compare:b.path] : nameOrder;
    }];
}
