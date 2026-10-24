# iPadOS window sizing reproduction

A standalone UIKit reproduction for testing fixed window sizes on iPadOS 27 using an app compiled with the iOS 26.5 SDK and device family 1,2.

The test displays a synthetic cyan rectangle inside a black view, changes its picture aspect from 1080x2340 to 1080x498 and back, and measures both the content and the outside window frame. It also attempts a manual corner resize. Screenshots and JSON reports are retained for one day.

The baseline reproduces an earlier implementation: set the preferred content size before displaying the window, then apply maximum=infinite, minimum=preferred, maximum=preferred after viewDidAppear. [Its first complete run](https://github.com/AqiguaiA/padphone-window-probe/actions/runs/40038949121) failed all three window phases: the outer frame did not immediately adopt the requested dimensions.

The working tree keeps this baseline and the read-only metadata inspection. It is a reproduction of an unresolved sizing issue, not a verified fix. Failed experimental geometry requests are retained only in Git history.

[The geometry refresh run](https://github.com/AqiguaiA/padphone-window-probe/actions/runs/40040094754) also failed all three outside-window assertions with the same dimensions. XCTest finished its assertions, but the xcodebuild process timed out during cleanup, before the script could copy the JSON files. The textual job log retains the three measurements; the missing JSON does not establish whether the geometry request itself returned an error.

[The scene client-size request run](https://github.com/AqiguaiA/padphone-window-probe/actions/runs/40044789122), at commit 9d9f615, also failed all three phases. The internal preferredContentSize request was supported and read back exactly, but the actual outer windows remained 538x865.5, 1201x865.5 and 1201x865.5. This demonstrates that submitting that preference did not resize the native window. XCTest completed all assertions; xcodebuild then timed out during cleanup, and the updated harness collected both JSON reports. The internal setter experiment was removed from the working tree.

Run the manually triggered **Test actual iPadOS window sizing** workflow. It uses standard macOS and xcode-27 GitHub-hosted runners. The first job compiles the app with SDK 26.5; the second builds the UI test driver with SDK 27 and runs that prebuilt app on an iPad simulator.

This repository has no AirPlay implementation, networking, device pairing, signing keys, app assets, or application history. The main application remains private. No signing credentials or repository secrets are required by this test.

Use free standard runners in this public repository only. Do not enable paid or larger runners, paid resource upgrades, or overage billing. The separate **Inspect window geometry interfaces** workflow reads class and method metadata without changing window settings.

[Runtime inspection](https://github.com/AqiguaiA/padphone-window-probe/actions/runs/40043920320) completed successfully through XCTest. Earlier direct simctl installation attempts timed out before the app ran, so those attempts provide no evidence about interface support. The metadata artifact contains only system class names, selectors and method type encodings.

Source is licensed under GPL-3.0; see LICENSE.
