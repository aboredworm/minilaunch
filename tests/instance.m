#import "../InstanceLock.h"
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

static int probe(NSString *executable, NSURL *directory) {
    NSTask *task = [NSTask new];
    task.executableURL = NSBundle.mainBundle.executableURL;
    task.arguments = @[@"--probe", executable, directory.path];
    assert([task launchAndReturnError:nil]);
    [task waitUntilExit];
    return task.terminationStatus;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc == 4 && strcmp(argv[1], "--probe") == 0) {
            NSError *error = nil;
            int fd = acquireInstanceLock(@(argv[2]), [NSURL fileURLWithPath:@(argv[3])], &error);
            if (fd >= 0) { close(fd); return 0; }
            return [error.domain isEqualToString:NSPOSIXErrorDomain] && error.code == EWOULDBLOCK ? 1 : 2;
        }
        NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NSURL *directory = [root URLByAppendingPathComponent:@"instances"];
        NSString *installed = @"/Users/test/install with spaces/MiniLaunch.app/Contents/MacOS/MiniLaunch";
        NSString *development = @"/Users/test/projects/MiniLaunch.app/Contents/MacOS/MiniLaunch";
        int fd = acquireInstanceLock(installed, directory, nil);
        assert(fd >= 0);
        assert(fcntl(fd, F_GETFD) & FD_CLOEXEC);
        assert(probe(installed, directory) == 1);
        assert(probe(development, directory) == 0);
        close(fd);
        assert(probe(installed, directory) == 0);
        assert(probe(installed, directory) == 0);
        NSURL *blocked = [root URLByAppendingPathComponent:@"blocked"];
        assert([@"file" writeToURL:blocked atomically:YES encoding:NSUTF8StringEncoding error:nil]);
        NSError *error = nil;
        assert(acquireInstanceLock(installed, [blocked URLByAppendingPathComponent:@"instances"], &error) == -1);
        assert(error != nil);
        assert([NSFileManager.defaultManager removeItemAtURL:root error:nil]);
        puts("Instance unit tests passed: exclusivity, executable isolation, close-on-exec, release, and errors.");
    }
    return 0;
}
