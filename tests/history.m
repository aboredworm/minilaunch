#import "../History.h"
#include <assert.h>
#include <limits.h>

static void expectOrder(NSArray *actual, NSArray *expected) {
    assert([actual isEqualToArray:expected]);
}

int main(void) {
    @autoreleasepool {
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NSURL *url = [root URLByAppendingPathComponent:@"nested/usage.json"];
        NSURL *alpha = [NSURL fileURLWithPath:@"/Applications/Alpha.app"];
        NSURL *beta = [NSURL fileURLWithPath:@"/Applications/Beta.app"];
        NSURL *zeta = [NSURL fileURLWithPath:@"/Applications/Zeta.app"];
        NSArray *apps = @[zeta, alpha, beta];
        LaunchHistory *history = [[LaunchHistory alloc] initWithURL:url];
        assert(history.counts.count == 0);
        expectOrder(rankApps(apps, @"", history.counts), @[]);
        expectOrder(rankApps(apps, @"a", history.counts), @[alpha, beta, zeta]);
        assert([history recordLaunch:beta]);
        assert([history recordLaunch:beta]);
        for (int i = 0; i < 3; i++) assert([history recordLaunch:zeta]);
        expectOrder(rankApps(apps, @"", history.counts), @[zeta, beta]);
        expectOrder(rankApps(apps, @"a", history.counts), @[zeta, beta, alpha]);
        expectOrder(rankApps(@[alpha, beta], @"", history.counts), @[beta]);

        LaunchHistory *loaded = [[LaunchHistory alloc] initWithURL:url];
        assert([loaded.counts isEqualToDictionary:history.counts]);
        for (int i = 0; i < 3; i++) assert([loaded recordLaunch:alpha]);
        expectOrder(rankApps(apps, @"", loaded.counts), @[alpha, zeta, beta]);

        NSURL *badURL = [root URLByAppendingPathComponent:@"invalid.json"];
        NSDictionary *invalid = @{alpha.path:@2, beta.path:@(-1), zeta.path:@1.5,
            @"/string":@"3", @"/bool":@YES, @"/zero":@0};
        NSData *data = [NSJSONSerialization dataWithJSONObject:invalid options:0 error:nil];
        assert([data writeToURL:badURL atomically:YES]);
        LaunchHistory *cleaned = [[LaunchHistory alloc] initWithURL:badURL];
        assert(cleaned.counts.count == 1 && [cleaned.counts[alpha.path] intValue] == 2);
        assert([[@"broken JSON" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:badURL atomically:YES]);
        assert([[LaunchHistory alloc] initWithURL:badURL].counts.count == 0);
        assert([[@"[]" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:badURL atomically:YES]);
        assert([[LaunchHistory alloc] initWithURL:badURL].counts.count == 0);

        data = [NSJSONSerialization dataWithJSONObject:@{alpha.path:@(LLONG_MAX)} options:0 error:nil];
        assert([data writeToURL:badURL atomically:YES]);
        LaunchHistory *maximum = [[LaunchHistory alloc] initWithURL:badURL];
        assert([maximum recordLaunch:alpha]);
        assert([maximum.counts[alpha.path] longLongValue] == LLONG_MAX);

        LaunchHistory *blocked = [[LaunchHistory alloc] initWithURL:[url URLByAppendingPathComponent:@"blocked.json"]];
        assert(![blocked recordLaunch:alpha]);
        assert(blocked.counts.count == 0);
        assert([NSFileManager.defaultManager removeItemAtURL:root error:nil]);
        puts("History tests passed: empty defaults, frequency ranking, ties, persistence, invalid data, overflow, write failure.");
    }
    return 0;
}
