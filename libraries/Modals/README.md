# Modals

Module containing various modals used across the app.

## Usage

To use the Modals module you need to create a new instance of the `ModalsFactory` providing colors for the modals to use.

```swift
let modals = ModalsFactory(colors: ModalsColors)
```

Then you can use the factory methods to retrieve modals. For the example below you have to provide and object of `UpsellConstantsProtocol` which contains some needed values.

```swift
let upsellViewController = modals.upsellViewController(constants: UpsellConstantsProtocol)
```
