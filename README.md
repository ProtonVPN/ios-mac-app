# ProtonVPN for iOS and macOS

Copyright (c) 2021 Proton Technologies AG

## Dependencies

This app uses CocoaPods for most dependencies. Everything is inside this repository, so no need to run `pod install`.

### Third-party dependencies

[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)

## Setup

- Clone this repository
- Configure code signing for all targets with a paid Apple developer account (required due to VPN entitlements) and change the bundle identifiers to something unique
- Clean build folder in Xcode (`Cmd+Shift+K`)
- Build app twice

## Obscure XCode errors

If you get obscure XCode errors like an error from swiftlint without a place where it comes from, switch to `vpncore-ios` or `vpncore-macos` scheme and build it. Most probably lint error is in the `Core` project.

## License

The code and datafiles in this distribution are licensed under the terms of the GPLv3 as published by the Free Software Foundation. See <https://www.gnu.org/licenses/> for a copy of this license.

Copyright (c) 2021 Proton Technologies AG
