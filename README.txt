GlowBar — High Sierra brightness control
=================================
A tiny free native Mac menu-bar hardware brightness slider, written for
macOS High Sierra (10.13) and Intel Macs. It uses the CoreDisplay brightness
setter, the exact OS function already confirmed to work on this computer.

IMPORTANT: This is source code to be COMPILED on your Mac. The hardware
brightness slider has been tested on macOS High Sierra.

TRY WITHOUT INSTALLING
1. Extract this ZIP in Downloads.
2. Right-click Try.command -> Open. If Gatekeeper objects, use Open again.
   (Or open Terminal, cd into the extracted folder, and run ./Try.command.)
3. Compilation uses only Apple's pre-existing Command Line Tools. It does
   not download packages, ask for sudo, or change system configuration.
4. Click the sun icon in the menu bar and drag the brightness slider.
5. If it works, copy Trial/GlowBar.app to Applications and launch that copy.
   To start automatically, check "Launch at Login" in the GlowBar menu.
6. If not, quit via the app's menu and delete the Trial directory.

No network access, account, permissions, startup service or daemon.
The slider stays in the safe range 5%-100% to avoid turning off the panel.
Other display types are not covered; this controls the main display only.

Source: main.m. For personal use; freely modify and redistribute.
