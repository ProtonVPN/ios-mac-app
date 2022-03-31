# Review

Review module used in the iOS app.

## Usage

Create a new `Review` instance providing configuration, current user plan and a logger

```swift
let review = Review(configuration: Configuration(...), plan: ..., logger: { message in ... })
```

The Review module will then show a standard AppStore rating request when all the condition provided by the given configuration are met. You just need to track application events and forward them to the `Review` instance.

### Tracking application events

#### Successfull VPN connection

```swift
review.connected()
```

#### Failed VPN connection

```swift
review.connectionFailed()
```

#### VPN disconnected

```swift
review.disconnected()
```

#### User plan changed

```swift
review.update(plan:)
```

#### Configuration changed

```swift
review.update(configuration:)
```

#### Application activated

Typically called from `AppDelegate.didBecomeActive`

```swift
review.activated()
```

### Clearing Review data

You can delete all the Review module data calling

```swift
review.clear()
```

You typically want to do that on user logout.

## Development

You can develop the Search module as part of the project workspace or separately as a Swift Package Manager package. 

### External tools

There is no way to integrate any custom build steps to a Swift Package Manager package project type in Xcode, so external tools need to be run manually or as part of the CI.

The CI is set to run a linting step with `SwiftLint`, to make sure your code will not fail the linting step execute `swiftlint --strict` from the module folder (`libraries/Review`).

## Testing

The project contains a unit tests target that you can run directly from Xcode or from the terminal running `swift test` from the module folder (`libraries/Review`).
