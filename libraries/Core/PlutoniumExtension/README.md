# PlutoniumExtension

Implementation of split tunneling feature leveraging
NETransparentProxyProvider API.

## Traits

This package exposes one trait: `WithOSLogging`.

By using the OSLog backend, you gain `Activities` support within
Console.app (useful for debugging) and better overall performance.

To use it, either:

  * modify the `Package.swift` and make it a default enabled trait

```swift
     traits: [
-        .trait(name: "WithOSLogging")
+        .trait(name: "WithOSLogging"),
+        .default(enabledTraits: ["WithOSLogging"])
     ],
```

  * compile with the trait enabled: `swift build --traits WithOsLogging`
