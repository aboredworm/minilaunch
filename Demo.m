#import "Demo.h"

NSURL *demoStateURL(void) {
    NSString *root = NSProcessInfo.processInfo.environment[@"XDG_CACHE_HOME"];
    if (root.isAbsolutePath) root = [root stringByAppendingPathComponent:@"minilaunch"];
    else root = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/MiniLaunch"];
    return [NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"demo-next"]];
}

static BOOL writeIndex(NSUInteger index, NSURL *state, NSError **error) {
    if (![NSFileManager.defaultManager createDirectoryAtURL:state.URLByDeletingLastPathComponent
        withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    return [[NSString stringWithFormat:@"%lu\n", (unsigned long)index]
        writeToURL:state atomically:YES encoding:NSUTF8StringEncoding error:error];
}

BOOL resetDemoStyle(NSURL *state, NSError **error) {
    return writeIndex(0, state, error);
}

NSString *nextDemoStyle(NSString *directory, NSURL *state, NSError **error) {
    NSArray *styles = @[@"default", @"warm", @"electric", @"paper"];
    NSString *stored = [[NSString stringWithContentsOfURL:state encoding:NSUTF8StringEncoding error:nil]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSUInteger index = stored ? [@[@"0", @"1", @"2", @"3"] indexOfObject:stored] : 0;
    if (index == NSNotFound) index = 0;
    NSString *path = [directory stringByAppendingPathComponent:[styles[index] stringByAppendingPathExtension:@"conf"]];
    if (![NSFileManager.defaultManager isReadableFileAtPath:path]) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError
            userInfo:@{NSFilePathErrorKey:path}];
        return nil;
    }
    if (!writeIndex((index + 1) % styles.count, state, error)) return nil;
    return path;
}
