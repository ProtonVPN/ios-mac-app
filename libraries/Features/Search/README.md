# Search

Search module used in the iOS app.

## Usage

To use the Search module you first need to create a new instance of the `SearchCoordinator` providing basic configuration and an implementation of the `SearchStorage` protocol.

```swift
coordinator = SearchCoordinator(configuration: Configuration(colors: Colors(), constants: Constants()), storage: searchStorage)
```

The `Configuration` struct lets you provide all the colors and constants the Search module uses for full customization. The `SearchStorage` protocol provides a way for the Search module to save and load recent searches made by the user.

Next assign the `SearchCoordinatorDelegate` to the newly created coordinator

```swift
coordinator.delegate = self
```

Finally you can start the coordinator calling the `start` method providing an `UINavigationController`, all the data and the `SearchMode`

```swift
let viewController = coordinator.start(navigationController: navigationController, data: searchData, mode: searchMode)
```

The `UINavigationController` is needed because the coordinator pushes a new view controller as a way of presenting the UI. 

The search data contains a list of countries conforming to the `CountryViewModel` protocol which represent specific countries that also include all the servers for each country. 

Search mode determines if the search is being done by a free user so an upsell banner should be shown, a paid user, or if it is search in secure core countries and servers.

The `SearchCoordinatorDelegate` informs the app when the user requsted showing the detail of a specific country or wants to see the upsell modal.

## Development

You can develop the Search module as part of the project workspace or separately as a Swift Package Manager package. 

### External tools

There is no way to integrate any custom build steps to a Swift Package Manager package project type in Xcode, so external tools need to be run manually or as part of the CI.

The CI is set to run a linting step with `SwiftLint`, to make sure your code will not fail the linting step execute `swiftlint --strict` from the module folder (`libraries/Search`).

## Testing

The project contains a unit tests target that you can run directly from Xcode. It is also run from an app unit tests testplan duing testing on CI. 

