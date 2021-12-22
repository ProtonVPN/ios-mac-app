# BugReportUI

Report Bug feature UI. Supports both iOS and macOS. 

Minimum iOS version is set to 12, but in reality it will return ViewController only on iOS version 14+. 

For usage example please see `BugReportSampleApp` project.


## Translations

This package contains all translations that it needs. If you add new translation, you should regenerate `LocalizedString.swift` file by going to this libs folder and running swiftgen: `../../Pods/SwiftGen/bin/swiftgen`.


## Assets

This package contains all assets that it needs. If you add new translation, you should regenerate `Assets.swift` file by going to this libs folder and running swiftgen: `../../Pods/SwiftGen/bin/swiftgen`.

Colors contained in the assets are only used for previews. When using the module, you should rpovide the colors from the ouside by TODO: code example.


## Dependency injection

Everything related to the views (contertely colors) is injected via SviftUIs environment. Everything related to side effects (like a delegate to get initial data or send back filled report) is injected using `Current` global variable of type `BugReportEnvironment`. Initialy data is set to use mocked `BugReportModel`, but it is set either in `BugReportCreator` or if using BugReportView directly from the app, `Current.bugReportDelegate` should be pre-set directly.
