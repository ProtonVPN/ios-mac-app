# Theme

This package is divided in three parts: Theme-iOS, Theme-macOS and Theme, the last being a common part of the other two. You can import the common part and one of the platform part to your module.

The colors are stored in the common part, but to retrieve them you must use the platform specific target.

For macOS the package contains `AppTheme`, which is responsible for styling the AppKit side of the app. 
You can use it to retrieve colors:
For swiftUI:
```
Color.color(.background, [.transparent, .hovered])
```
For NSColor:
```
NSColor.color(.background, [.transparent, .hovered])
```
For CGColor:
```
CGColor.cgColor(.background, [.transparent, .hovered])
```
Style attributed strings:
```
"text to sytle".styled(.hint, font: .themeFont(.small), alignment: .natural)
```
