#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <math.h>

typedef void (*SetUserBrightnessFn)(CGDirectDisplayID, double);
typedef double (*GetUserBrightnessFn)(CGDirectDisplayID);

@interface BrightnessMenuApp : NSObject <NSApplicationDelegate, NSMenuDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenu *menu;
@property (nonatomic, strong) NSSlider *slider;
@property (nonatomic, strong) NSTextField *valueLabel;
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
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit GlowBar" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target = NSApp;
    [self.menu addItem:quit];
    self.statusItem.menu = self.menu;
    [self syncFromDisplay];
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
