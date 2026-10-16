#import "Search.h"

static NSArray<NSString *> *characters(NSString *string) {
    NSMutableArray *result = [NSMutableArray array];
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
        options:NSStringEnumerationByComposedCharacterSequences
        usingBlock:^(NSString *substring, NSRange range, NSRange enclosingRange, BOOL *stop) {
            [result addObject:substring];
        }];
    return result;
}

static BOOL contains(NSString *character, NSCharacterSet *set) {
    return [character rangeOfCharacterFromSet:set].location != NSNotFound;
}

static BOOL wordStart(NSArray<NSString *> *name, NSUInteger index) {
    if (index == 0) return YES;
    NSString *previous = name[index - 1], *current = name[index];
    if (!contains(previous, NSCharacterSet.alphanumericCharacterSet)) return YES;
    if (!contains(current, NSCharacterSet.uppercaseLetterCharacterSet)) return NO;
    return contains(previous, NSCharacterSet.lowercaseLetterCharacterSet) ||
        (index + 1 < name.count && contains(name[index + 1], NSCharacterSet.lowercaseLetterCharacterSet));
}

NSInteger fuzzyScore(NSString *query, NSString *name) {
    enum { ExactScore = 2000000, PrefixScore = 1000000, MatchBonus = 16,
        BoundaryBonus = 24, ConsecutiveBonus = 18 };
    if (!query.length) return 0;
    NSStringCompareOptions options = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    if ([name compare:query options:options] == NSOrderedSame) return ExactScore;
    if ([name rangeOfString:query options:options | NSAnchoredSearch].location != NSNotFound) return PrefixScore;
    NSArray<NSString *> *needle = characters(query), *haystack = characters(name);
    if (needle.count > haystack.count) return -1;
    NSUInteger count = haystack.count;
    NSMutableData *previousData = [NSMutableData dataWithLength:count * sizeof(NSInteger)];
    NSMutableData *currentData = [NSMutableData dataWithLength:count * sizeof(NSInteger)];
    NSInteger *previous = previousData.mutableBytes, *current = currentData.mutableBytes;
    const NSInteger invalid = NSIntegerMin / 4;
    NSMutableArray<NSNumber *> *boundaries = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger j = 0; j < count; j++) {
        previous[j] = invalid;
        [boundaries addObject:@(wordStart(haystack, j) ? BoundaryBonus : 0)];
    }
    for (NSUInteger i = 0; i < needle.count; i++) {
        NSInteger bestGap = invalid;
        for (NSUInteger j = 0; j < count; j++) {
            if (i > 0 && j > 0 && previous[j - 1] != invalid) {
                bestGap = MAX(bestGap, previous[j - 1] + (NSInteger)j - 1);
            }
            current[j] = invalid;
            if ([needle[i] compare:haystack[j] options:options] != NSOrderedSame) continue;
            NSInteger bonus = MatchBonus + boundaries[j].integerValue;
            if (i == 0) {
                current[j] = bonus - (NSInteger)j;
            } else {
                if (bestGap != invalid) current[j] = bestGap + bonus - ((NSInteger)j - 1);
                if (j > 0 && previous[j - 1] != invalid) {
                    current[j] = MAX(current[j], previous[j - 1] + bonus + ConsecutiveBonus);
                }
            }
        }
        NSInteger *swap = previous;
        previous = current;
        current = swap;
    }
    NSInteger best = invalid;
    for (NSUInteger j = 0; j < count; j++) best = MAX(best, previous[j]);
    return best == invalid ? -1 : MAX(1, MIN(PrefixScore - 1, 10000 + best));
}
