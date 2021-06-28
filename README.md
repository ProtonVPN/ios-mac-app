# ProtonVPN for iOS and macOS

Copyright (c) 2021 Proton Technologies AG

## Dependencies

This app uses CocoaPods for most dependencies. Everything is inside this repository, so no need to run `pod install`.

### Third-party dependencies

[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)

## Setup

- Enable [Git LFS](https://git-lfs.github.com) on your machine 
- Clone this repository
- Make sure you have go installed (`brew install go`)
- Configure code signing for all targets with a paid Apple developer account (required due to VPN entitlements) and change the bundle identifiers to something unique
- Clean build folder in Xcode (`Cmd+Shift+K`)
- Build app twice

### Localization

The app uses [SwiftGen](https://github.com/SwiftGen/SwiftGen) to generate the `Localizable.strings` file for accessing all the app strings stored in the standard `Localizable.strings` files. Just add a new string, build the project and `Localizable.strings` gets regenerated with the new string. The configuration can be found in `libraries/vpncore/swiftgen.yml`.

## Obscure XCode errors

If you get obscure XCode errors like an error from swiftlint without a place where it comes from, switch to `vpncore-ios` or `vpncore-macos` scheme and build it. Most probably lint error is in the `Core` project.

## License

The code and data files in this distribution are licensed under the terms of the GPLv3 as published by the Free Software Foundation. See <https://www.gnu.org/licenses/> for a copy of this license.

Copyright (c) 2021 Proton Technologies AG
