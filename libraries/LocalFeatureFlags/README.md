# LocalFeatureFlags

Enable and disable features that are actively in development.

## Enable/Disable

To enable a feature:

```sh
swift package plugin ff enable "VPN" "ExampleFeature"
```

To disable a feature:

```sh
swift package plugin ff disable "VPN" "ExampleFeature"
```

Feature flags are organized into "categories," for example:

```
[
    'Protocol':
    [
        'NewProtocol': true,
        'DisableOldProtocol': false,
    ],
    
    'NewConnectionUI':
    [
        'Animations': true,
        'FancyLogo': true,
    ]
]
```

## New Feature

To declare a new feature in code, create an object that conforms to the `FeatureFlag` protocol:

```swift
struct NewFeatureFlag: FeatureFlag {
    let category = "VPN"
    let feature = "NewFeature"
}

func myFun() {
    if isEnabled(NewFeatureFlag()) {
        // New feature stuff
    }
}
```

For more complicated features or to organize subsystems, using an enum may be more convenient:

```swift
enum ConnectionFeature: String, FeatureFlag {
    var category: String {
        "Connection"
    }
    
    case newAnimations = "NewAnimations"
    case fancyProtocol = "FancyProtocol"
}

func myFun() {
    if isEnabled(ConnectionFeature.newAnimations) {
        // New feature stuff
    }
}
```

Then you can continue implementing your feature as normal.
