#import "../Demo.h"
#include <assert.h>

int main(void) {
    @autoreleasepool {
        NSFileManager *fm = NSFileManager.defaultManager;
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NSURL *styles = [root URLByAppendingPathComponent:@"styles with spaces" isDirectory:YES];
        NSURL *state = [root URLByAppendingPathComponent:@"cache/demo-next"];
        assert([fm createDirectoryAtURL:styles withIntermediateDirectories:YES attributes:nil error:nil]);
        NSArray *names = @[@"default", @"warm", @"electric", @"paper"];
        for (NSString *name in names) {
            NSURL *file = [styles URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"conf"]];
            assert([@"font-size=18\n" writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:nil]);
        }
        for (NSUInteger i = 0; i < 9; i++) {
            NSString *path = nextDemoStyle(styles.path, state, nil);
            assert([path.lastPathComponent isEqualToString:[names[i % 4] stringByAppendingPathExtension:@"conf"]]);
        }
        assert(resetDemoStyle(state, nil));
        assert([nextDemoStyle(styles.path, state, nil).lastPathComponent isEqualToString:@"default.conf"]);
        for (NSString *bad in @[@"broken", @"4", @"-1", @"1junk", @"", @"99999"]) {
            assert([bad writeToURL:state atomically:YES encoding:NSUTF8StringEncoding error:nil]);
            assert([nextDemoStyle(styles.path, state, nil).lastPathComponent isEqualToString:@"default.conf"]);
        }
        NSURL *warm = [styles URLByAppendingPathComponent:@"warm.conf"];
        assert([fm removeItemAtURL:warm error:nil]);
        NSError *error = nil;
        assert(nextDemoStyle(styles.path, state, &error) == nil && error != nil);
        assert([[NSString stringWithContentsOfURL:state encoding:NSUTF8StringEncoding error:nil] isEqualToString:@"1\n"]);

        NSURL *blocked = [root URLByAppendingPathComponent:@"blocked"];
        assert([@"file" writeToURL:blocked atomically:YES encoding:NSUTF8StringEncoding error:nil]);
        NSURL *badState = [blocked URLByAppendingPathComponent:@"demo-next"];
        error = nil;
        assert(!resetDemoStyle(badState, &error) && error != nil);
        error = nil;
        assert(nextDemoStyle(styles.path, badState, &error) == nil && error != nil);

        NSString *xdg = NSProcessInfo.processInfo.environment[@"XDG_CACHE_HOME"];
        NSString *expected = xdg.isAbsolutePath ? [xdg stringByAppendingPathComponent:@"minilaunch/demo-next"] :
            [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/MiniLaunch/demo-next"];
        assert([demoStateURL().path isEqualToString:expected]);
        assert([fm removeItemAtURL:root error:nil]);
        puts("Demo unit tests passed: order, wraparound, reset, corrupt state, missing styles, write failure, cache path.");
    }
    return 0;
}
