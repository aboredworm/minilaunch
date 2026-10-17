#import "../src/Config.h"
#include <assert.h>
#include <math.h>

static void expectColor(NSColor *color, unsigned int hex) {
    color = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    assert(fabs(color.redComponent - ((hex >> 16) & 255) / 255.0) < 0.001);
    assert(fabs(color.greenComponent - ((hex >> 8) & 255) / 255.0) < 0.001);
    assert(fabs(color.blueComponent - (hex & 255) / 255.0) < 0.001);
}

static LauncherConfig *load(NSString *path, NSString *text) {
    assert([text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]);
    return [[LauncherConfig alloc] initWithContentsOfFile:path];
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        assert([NSFileManager.defaultManager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:nil]);
        NSString *path = [root stringByAppendingPathComponent:@"config"];
        LauncherConfig *defaults = [LauncherConfig new];
        LauncherConfig *missing = [[LauncherConfig alloc] initWithContentsOfFile:path];
        expectColor(defaults.backgroundColor, 0x282828);
        expectColor(defaults.textColor, 0xffffff);
        assert([defaults.font isEqualTo:missing.font]);
        assert(defaults.font.pointSize == 18);
        assert(defaults.backgroundOpacity == 0.8 && defaults.visibleRows == 7);
        assert(defaults.padding == 4 && defaults.resultSpacing == 15);
        assert(defaults.xPosition == 40 && defaults.yPosition == 35);
        assert([defaults.selectionColor isEqual:defaults.backgroundColor]);
        assert([defaults.selectionBackground isEqual:defaults.textColor]);
        assert([load(path, @"").font isEqualTo:defaults.font]);

        NSString *fontName = [NSFont systemFontOfSize:18].fontName;
        LauncherConfig *custom = load(path, [NSString stringWithFormat:
            @"# whole-line comment\r\n  background-color = #1234Ab \r\ntext-color=#d4be98\r\n"
            "selection-background = #123456\nselection-color = #fedcba\nfont = %@\nfont-size = 24.5\n"
            "background-opacity = 0.65\npadding = 6.5\nresult-spacing = 9\nvisible-rows = 4\n"
            "x-position = 20\ny-position = 70\n", fontName]);
        expectColor(custom.backgroundColor, 0x1234ab);
        expectColor(custom.textColor, 0xd4be98);
        expectColor(custom.selectionBackground, 0x123456);
        expectColor(custom.selectionColor, 0xfedcba);
        assert([custom.font.fontName isEqualToString:fontName] && custom.font.pointSize == 24.5);
        assert(custom.backgroundOpacity == 0.65 && custom.visibleRows == 4);
        assert(custom.padding == 6.5 && custom.resultSpacing == 9);
        assert(custom.xPosition == 20 && custom.yPosition == 70);

        LauncherConfig *inverted = load(path, @"text-color = #aabbcc\nbackground-color = #112233\n");
        expectColor(inverted.selectionBackground, 0xaabbcc);
        expectColor(inverted.selectionColor, 0x112233);
        LauncherConfig *duplicate = load(path, @"font-size=20\nfont-size=22\nfont-size=0\n");
        assert(duplicate.font.pointSize == 22);
        LauncherConfig *fallback = load(path, @"font = MiniLaunchNonexistentFont1234\nfont-size = 23\n");
        assert([fallback.font isEqualTo:[NSFont monospacedSystemFontOfSize:23 weight:NSFontWeightBold]]);

        LauncherConfig *bad = load(path, @"not a setting\nunknown=value\n=empty-key\nfont=\n"
            "background-color=#12345\ntext-color=#gggggg\nselection-background=red\nselection-color=#abcdabcd\n"
            "font-size=nan\nfont-size=inf\nfont-size=73\nfont-size=7\nfont-size=18px\n"
            "background-opacity=-1\nbackground-opacity=1.1\npadding=-1\npadding=33\n"
            "result-spacing=101\nvisible-rows=0\nvisible-rows=31\nvisible-rows=2.5\n"
            "x-position=101\ny-position=-1\n");
        expectColor(bad.backgroundColor, 0x282828);
        expectColor(bad.textColor, 0xffffff);
        expectColor(bad.selectionBackground, 0xffffff);
        expectColor(bad.selectionColor, 0x282828);
        assert([bad.font isEqualTo:defaults.font]);
        assert(bad.backgroundOpacity == 0.8 && bad.visibleRows == 7);
        assert(bad.padding == 4 && bad.resultSpacing == 15);
        assert(bad.xPosition == 40 && bad.yPosition == 35);

        LauncherConfig *bounds = load(path, @"font-size=72\nbackground-opacity=0\npadding=0\n"
            "result-spacing=0\nvisible-rows=1\nx-position=0\ny-position=100\n");
        assert(bounds.font.pointSize == 72 && bounds.visibleRows == 1);
        assert(bounds.backgroundOpacity == 0 && bounds.padding == 0 && bounds.resultSpacing == 0);
        assert(bounds.xPosition == 0 && bounds.yPosition == 100);
        assert(load(path, @"background-opacity=1\n").backgroundOpacity == 1);
        assert(load(path, @"font-size=8\n").font.pointSize == 8);
        assert(load(path, @"visible-rows=30\n").visibleRows == 30);
        LauncherConfig *reloaded = load(path, @"text-color=#010203\n");
        expectColor(reloaded.textColor, 0x010203);
        expectColor(custom.textColor, 0xd4be98);
        assert([defaults isEqualToConfig:[LauncherConfig new]]);
        assert([defaults isEqualToConfig:bad]);
        assert(![defaults isEqualToConfig:nil]);
        NSArray *changes = @[@"background-color=#112233", @"text-color=#112233",
            @"selection-background=#112233", @"selection-color=#112233",
            [NSString stringWithFormat:@"font=%@", fontName], @"font-size=19",
            @"background-opacity=0.7", @"padding=5", @"result-spacing=16", @"visible-rows=8",
            @"x-position=41", @"y-position=36"];
        for (NSString *change in changes) {
            LauncherConfig *changed = load(path, change);
            assert(![defaults isEqualToConfig:changed]);
            assert(![changed isEqualToConfig:defaults]);
        }

        NSDictionary *environment = NSProcessInfo.processInfo.environment;
        NSString *xdg = environment[@"XDG_CONFIG_HOME"];
        NSString *expectedRoot = xdg.isAbsolutePath ? xdg : [NSHomeDirectory() stringByAppendingPathComponent:@".config"];
        assert([LauncherConfig.defaultPath isEqualToString:[expectedRoot stringByAppendingPathComponent:@"minilaunch/config"]]);
        assert([NSFileManager.defaultManager removeItemAtPath:root error:nil]);
        puts("Config tests passed: defaults, overrides, colors, fonts, validation, bounds, reload, path.");
    }
    return 0;
}
