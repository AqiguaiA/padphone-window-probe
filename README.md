# iPadOS window sizing reproduction

A standalone UIKit reproduction for testing fixed window sizes on iPadOS 27 using an app compiled with the iOS 26.5 SDK and device family 1,2.

The test displays a synthetic cyan rectangle inside a black view, changes its picture aspect from 1080x2340 to 1080x498 and back, and measures both the content and the outside window frame. It also attempts a manual corner resize. Screenshots and JSON reports are retained for one day.

The baseline reproduces an earlier implementation: set the preferred content size before displaying the window, then apply maximum=infinite, minimum=preferred, maximum=preferred after viewDidAppear. [Its first complete run](https://github.com/AqiguaiA/padphone-window-probe/actions/runs/40038949121) failed all three window phases: the outer frame did not immediately adopt the requested dimensions.

The current candidate also asks the scene to refresh its geometry with all supported interface orientations, without requesting a video-specific rotation. Full localized geometry errors are included in the JSON report. This is a reproduction under test, not a verified fix. A failing workflow may be the expected result if iPadOS does not honor the requested size.

[The geometry refresh run](https://github.com/AqiguaiA/padphone-window-probe/actions/runs/40040094754) also failed all three outside-window assertions with the same dimensions. XCTest finished its assertions, but the xcodebuild process timed out during cleanup, before the script could copy the JSON files. The textual job log retains the three measurements; the missing JSON does not establish whether the geometry request itself returned an error.

Run the manually triggered **Test actual iPadOS window sizing** workflow. It uses standard macOS and xcode-27 GitHub-hosted runners. The first job compiles the app with SDK 26.5; the second builds the UI test driver with SDK 27 and runs that prebuilt app on an iPad simulator.

This repository has no AirPlay implementation, networking, device pairing, signing keys, app assets, or application history. The main application remains private. No signing credentials or repository secrets are required by this test.

Use free standard runners in this public repository only. Do not enable paid or larger runners, paid resource upgrades, or overage billing. The separate **Inspect window geometry interfaces** workflow reads class and method metadata without changing window settings.

Source is licensed under GPL-3.0; see LICENSE.
