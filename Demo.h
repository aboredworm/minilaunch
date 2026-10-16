#import <Foundation/Foundation.h>

NSURL *demoStateURL(void);
BOOL resetDemoStyle(NSURL *state, NSError **error);
NSString *nextDemoStyle(NSString *directory, NSURL *state, NSError **error);
