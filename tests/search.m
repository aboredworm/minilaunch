#import "../src/Search.h"
#import "../src/History.h"
#include <assert.h>
#include <limits.h>

static NSURL *app(NSString *name) {
    return [NSURL fileURLWithPath:[@"/Applications" stringByAppendingPathComponent:
        [name stringByAppendingPathExtension:@"app"]]];
}

int main(void) {
    @autoreleasepool {
        assert(fuzzyScore(@"", @"Safari") == 0);
        assert(fuzzyScore(@"", @"") == 0);
        assert(fuzzyScore(@"x", @"") == -1);
        assert(fuzzyScore(@"sfr", @"Safari") > 0);
        assert(fuzzyScore(@"NCM", @"Nimble Commander") > 0);
        assert(fuzzyScore(@"fs", @"Safari") == -1);
        assert(fuzzyScore(@"safarix", @"Safari") == -1);
        assert(fuzzyScore(@"aa", @"a") == -1);
        assert(fuzzyScore(@"aa", @"Alpha") > 0);
        assert(fuzzyScore(@"cafe", @"Café") == fuzzyScore(@"CAFE", @"Cafe\u0301"));
        assert(fuzzyScore(@"cfe", @"Café") > 0);
        assert(fuzzyScore(@"🚀e", @"🚀 Explorer") > 0);
        assert(fuzzyScore(@"👩‍💻b", @"a👩‍💻b") > 0);

        assert(fuzzyScore(@"hel", @"Hel") > fuzzyScore(@"hel", @"Helium"));
        assert(fuzzyScore(@"hel", @"Helium") > fuzzyScore(@"hel", @"Archive Utility"));
        assert(fuzzyScore(@"abc", @"xabc") > fuzzyScore(@"abc", @"xaxbxc"));
        assert(fuzzyScore(@"ab", @"xaxb") > fuzzyScore(@"ab", @"xaxxxxxb"));
        assert(fuzzyScore(@"nc", @"Nimble Commander") > fuzzyScore(@"nc", @"Sync"));
        assert(fuzzyScore(@"fc", @"FinalCut") > fuzzyScore(@"fc", @"xfxxc"));
        assert(fuzzyScore(@"pv", @"PDFViewer") > fuzzyScore(@"pv", @"xpxxv"));
        assert(fuzzyScore(@"ab", @"xaxxxxxxxxxxab") > fuzzyScore(@"ab", @"xaxxxxxxxxxxxb"));
        assert(fuzzyScore(@"hel", @"Helium") == fuzzyScore(@"hel", @"Helix"));

        NSURL *helium = app(@"Helium"), *archive = app(@"Archive Utility"), *safari = app(@"Safari");
        NSArray *apps = @[archive, safari, helium];
        NSDictionary *counts = @{archive.path:@(LLONG_MAX)};
        assert(([rankApps(apps, @"hel", counts) isEqualToArray:@[helium, archive]]));
        assert(([rankApps(apps, @"HEL", counts) isEqualToArray:@[helium, archive]]));
        assert(([rankApps(apps, @"", counts) isEqualToArray:@[archive]]));
        assert(rankApps(apps, @"", @{}).count == 0);
        assert(rankApps(apps, @"not-an-app", counts).count == 0);
        assert(rankApps(@[], @"hel", counts).count == 0);

        NSURL *helix = app(@"Helix"), *heliumBeta = app(@"Helium Beta");
        NSDictionary *tieCounts = @{helix.path:@20, helium.path:@1, archive.path:@(LLONG_MAX)};
        assert(([rankApps(@[archive, helium, helix], @"hel", tieCounts) isEqualToArray:@[helix, helium, archive]]));
        assert(([rankApps(@[helix, helium], @"hel", @{}) isEqualToArray:@[helium, helix]]));
        assert(([rankApps(@[heliumBeta, helium], @"helium", @{heliumBeta.path:@(LLONG_MAX)})
            isEqualToArray:@[helium, heliumBeta]]));
        NSURL *duplicate = [NSURL fileURLWithPath:@"/Users/test/Applications/Helium.app"];
        assert(([rankApps(@[duplicate, helium], @"helium", @{}) isEqualToArray:@[helium, duplicate]]));
        puts("Search tests passed: match quality, prefixes, word boundaries, gaps, Unicode, usage ties, and hel/Helium regression.");
    }
    return 0;
}
