#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreServices/CoreServices.h>
#include <dlfcn.h>
#include <math.h>

typedef void (*SetUserBrightnessFn)(CGDirectDisplayID, double);
typedef double (*GetUserBrightnessFn)(CGDirectDisplayID);

@interface BrightnessMenuApp : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *menu;
@property (nonatomic, strong) NSSlider *slider;
@property (nonatomic, strong) NSTextField *valueLabel;
@property (nonatomic, strong) NSMenuItem *launchAtLoginItem;
@property (nonatomic, assign) SetUserBrightnessFn setBrightness;
@property (nonatomic, assign) GetUserBrightnessFn getBrightness;
@end

@implementation BrightnessMenuApp

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    void *framework = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_NOW | RTLD_LOCAL);
    if (framework) {
        self.setBrightness = (SetUserBrightnessFn)dlsym(framework, "CoreDisplay_Display_SetUserBrightness");
        self.getBrightness = (GetUserBrightnessFn)dlsym(framework, "CoreDisplay_Display_GetUserBrightness");
    }
    if (!self.setBrightness) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Brightness control is unavailable";
        alert.informativeText = @"CoreDisplay's brightness setter could not be loaded on this Mac.";
        [alert runModal];
        [NSApp terminate:nil];
        return;
    }

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"☀";
    self.statusItem.button.toolTip = @"GlowBar — click to adjust";

    self.menu = [[NSMenu alloc] initWithTitle:@"GlowBar"];
    self.menu.delegate = self;

    NSMenuItem *sliderItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 260, 54)];

    NSTextField *heading = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 31, 155, 17)];
    heading.stringValue = @"Display brightness";
    heading.editable = NO;
    heading.bordered = NO;
    heading.drawsBackground = NO;
    heading.selectable = NO;
    [view addSubview:heading];

    self.valueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(195, 31, 49, 17)];
    self.valueLabel.alignment = NSTextAlignmentRight;
    self.valueLabel.editable = NO;
    self.valueLabel.bordered = NO;
    self.valueLabel.drawsBackground = NO;
    self.valueLabel.selectable = NO;
    [view addSubview:self.valueLabel];

    self.slider = [[NSSlider alloc] initWithFrame:NSMakeRect(15, 7, 230, 24)];
    self.slider.minValue = 0.05;  // Keep the backlight above off for safety.
    self.slider.maxValue = 1.0;
    self.slider.continuous = YES;
    self.slider.target = self;
    self.slider.action = @selector(brightnessChanged:);
    [view addSubview:self.slider];

    sliderItem.view = view;
    [self.menu addItem:sliderItem];
    [self.menu addItem:[NSMenuItem separatorItem]];
    self.launchAtLoginItem = [[NSMenuItem alloc] initWithTitle:@"Launch at Login" action:@selector(toggleLaunchAtLogin:) keyEquivalent:@""];
    self.launchAtLoginItem.target = self;
    [self.menu addItem:self.launchAtLoginItem];
    [self.menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit GlowBar" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target = NSApp;
    [self.menu addItem:quit];
    self.statusItem.menu = self.menu;
    [self syncFromDisplay];
}

// High Sierra's native login items list (also visible in Users & Groups).
- (BOOL)loginItemMatches:(LSSharedFileListItemRef)item {
    CFURLRef resolvedURL = NULL;
    OSStatus status = LSSharedFileListItemResolve(
        item,
        kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes,
        &resolvedURL, NULL);
    BOOL matches = NO;
    if (status == noErr && resolvedURL) {
        NSString *listedPath = [[(__bridge NSURL *)resolvedURL path] stringByStandardizingPath];
        NSString *appPath = [[[NSBundle mainBundle] bundlePath] stringByStandardizingPath];
        matches = [listedPath isEqualToString:appPath];
    }
    if (resolvedURL) CFRelease(resolvedURL);
    return matches;
}

- (BOOL)launchAtLoginEnabled {
    LSSharedFileListRef list = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (!list) return NO;

    CFArrayRef snapshot = LSSharedFileListCopySnapshot(list, NULL);
    BOOL found = NO;
    if (snapshot) {
        for (CFIndex i = 0; i < CFArrayGetCount(snapshot); i++) {
            LSSharedFileListItemRef item = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(snapshot, i);
            if ([self loginItemMatches:item]) {
                found = YES;
                break;
            }
        }
        CFRelease(snapshot);
    }
    CFRelease(list);
    return found;
}

- (void)showLoginItemError:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Unable to change login item";
    alert.informativeText = message;
    [alert runModal];
}

- (void)toggleLaunchAtLogin:(NSMenuItem *)sender {
    BOOL enable = (sender.state != NSControlStateValueOn);
    NSString *appPath = [[NSBundle mainBundle] bundlePath];

    // A temporary trial build is replaced on every compile; don't register that path.
    if (enable && [appPath rangeOfString:@"/Trial/"].location != NSNotFound) {
        [self showLoginItemError:@"Move GlowBar.app to Applications and open that copy before enabling Launch at Login."];
        return;
    }

    LSSharedFileListRef list = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (!list) {
        [self showLoginItemError:@"macOS did not make the login items list available."];
        return;
    }

    BOOL success = YES;
    if (enable) {
        LSSharedFileListItemRef added = LSSharedFileListInsertItemURL(
            list, kLSSharedFileListItemLast, CFSTR("GlowBar"), NULL,
            (__bridge CFURLRef)[[NSBundle mainBundle] bundleURL], NULL, NULL);
        success = (added != NULL);
        if (added) CFRelease(added);
    } else {
        CFArrayRef snapshot = LSSharedFileListCopySnapshot(list, NULL);
        if (!snapshot) {
            success = NO;
        } else {
            for (CFIndex i = 0; i < CFArrayGetCount(snapshot); i++) {
                LSSharedFileListItemRef item = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(snapshot, i);
                if ([self loginItemMatches:item] && LSSharedFileListItemRemove(list, item) != noErr)
                    success = NO;
            }
            CFRelease(snapshot);
        }
    }
    CFRelease(list);

    BOOL current = [self launchAtLoginEnabled];
    sender.state = current ? NSControlStateValueOn : NSControlStateValueOff;
    if (!success || current != enable) {
        [self showLoginItemError:@"Check System Preferences → Users & Groups → Login Items and try again."];
    }
}

- (void)syncFromDisplay {
    double level = self.getBrightness ? self.getBrightness(CGMainDisplayID()) : 0.5;
    if (!isfinite(level) || level < 0.0 || level > 1.0) level = 0.5;
    level = fmin(1.0, fmax(0.05, level));
    self.slider.doubleValue = level;
    self.valueLabel.stringValue = [NSString stringWithFormat:@"%d%%", (int)lround(level * 100.0)];
}

- (void)menuWillOpen:(NSMenu *)menu {
    (void)menu;
    [self syncFromDisplay];
    self.launchAtLoginItem.state = [self launchAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)brightnessChanged:(NSSlider *)sender {
    double level = sender.doubleValue;
    if (self.setBrightness) self.setBrightness(CGMainDisplayID(), level);
    self.valueLabel.stringValue = [NSString stringWithFormat:@"%d%%", (int)lround(level * 100.0)];
}
@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        BrightnessMenuApp *delegate = [[BrightnessMenuApp alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
