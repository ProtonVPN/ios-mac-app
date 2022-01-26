# Onboarding

Onboarding module used in the iOS app.

## Usage

To use the Onboarding module you first need to create a new instance of the `OnboardingCoordinator` providing basic configuration

```swift
coordinator = OnboardingCoordinator(configuration: Configuration(variant: OnboardingVariant, colors: Colors))
```

The `Configuration` struct lets you choose between the `A` and `B` screen flow variants and provided all the colors the Onboarding module uses for full customization.

Next assign the `OnboardingCoordinatorDelegate` to the newly created coordinator

```swift
coordinator.delegate = self
```

Finally you can start the coordinator and get back an `UINavigationController` instance that you can present in your iOS app

```swift
let viewController = onboardingCoordinator.start()
```

The `OnboardingCoordinatorDelegate` informs you when the coordinator finishes so you can dismiss it, when it requires the app to make a VPN connection and when it needs an `UIViewController` with the payments UI provided so it can allow the user to buy a Plus plan.

## Development

You can develop the Onboarding module as part of the project workspace or separately as a Swift Package Manager package. 

### External tools

There is no way to integrate any custom build steps to a Swift Package Manager package project type in Xcode, so external tools need to be run manually or as part of the CI.

The CI is set to run a linting step with `SwiftLint`, to make sure your code will not fail the linting step execute `swiftlint --strict` from the module folder (`libraries/Onboarding`).

If you add a new string to `Localizable.strings` you need to execute the `swiftgen` command from the module folder (`libraries/Onboarding`) to regenerate the `LocalizedString.swift` file that allows you a strongly typed access to all the strings in the project.

## Testing

You can use the OnboardingSampleApp to easily test the Onboarding module functionality. The OnboardingSampleApp allows you to choose between the A and B screen flows and simulate successful or failed VPN connection.
