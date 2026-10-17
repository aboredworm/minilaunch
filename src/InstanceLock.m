#import "InstanceLock.h"
#import <CommonCrypto/CommonDigest.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>

int acquireInstanceLock(NSString *executable, NSURL *directory, NSError **error) {
    if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES
        attributes:nil error:error]) return -1;
    NSData *data = [executable dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *name = [NSMutableString string];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [name appendFormat:@"%02x", digest[i]];
    NSString *path = [directory.path stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"lock"]];
    int fd = open(path.fileSystemRepresentation, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (fd >= 0 && flock(fd, LOCK_EX | LOCK_NB) == 0) return fd;
    int code = errno;
    if (fd >= 0) close(fd);
    if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:@{NSFilePathErrorKey:path}];
    return -1;
}
