# ProtonVPN for macOS

Copyright (c) 2020 Proton Technologies AG

## Dependencies

This app uses CocoaPods for most dependencies, including our vpncore framework (which is shared between iOS and macOS).

### Internal

[vpncore](https://github.com/ProtonVPN/vpncore)

### Third-party dependencies

[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)

## Setup

- Clone this repository
- Clone the vpncore repo at the same directory level as this repo
- Run `pod install` first in vpncore and then this repository
- Configure code signing for all targets with a paid Apple developer account (required due to VPN entitlements) and change the bundle identifiers to something unique
- Clean build folder in Xcode (`Cmd+Shift+K`)
- Build app twice

If you receive any dependency-related errors, try running `pod repo update` and then `pod install` again.

## Staying in Sync

To stay in sync with changes made to vpncore, follow these three steps:
- Run `pod install`
- Clean build folder in Xcode (`Cmd+Shift+K`)
- Build app

## License

The code and datafiles in this distribution are licensed under the terms of the GPLv3 as published by the Free Software Foundation. See <https://www.gnu.org/licenses/> for a copy of this license.

Copyright (c) 2019 Proton Technologies AG
