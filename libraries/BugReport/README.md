# BugReportUI

Report Bug feature UI. Supports both iOS and macOS. 

Minimum iOS version is set to 12, but in reality it will return ViewController only on iOS version 14+. 

For usage example please see `BugReportSampleApp` project.

## Assets

This package contains all assets that it needs. If you add new translation, you should regenerate `Assets.swift` file by going to this libs folder and running swiftgen: `../../Pods/SwiftGen/bin/swiftgen`.

Colors contained in the assets are only used for previews (but are valid for the app at the time this lib is written). Apps should always provide colors to `BugReportCreator`.


## Dependency injection

Everything related to the views (concretely colors) is injected via SwiftUIs environment. Everything related to side effects (like a delegate to get initial data or send back filled report) is injected using `Current` global variable of type `BugReportEnvironment`. Initialy data is set to use mocked `BugReportModel`, but it is set either in `BugReportCreator` or if using `BugReportView` directly from the app, `CurrentEnv.bugReportDelegate` should be pre-set directly.


## Development

If during development you need SwiftUI previews working, change `Package.swift` file `platforms` iOS value to `.iOS(.v15)` otherwise previews won't work.
