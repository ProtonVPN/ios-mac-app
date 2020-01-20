# ProtonVPN for iOS

Copyright (c) 2020 Proton Technologies AG

## Dependencies

This app uses CocoaPods for most dependencies, including our vpncore framework (which is shared between iOS and macOS).

### Internal

[vpncore](https://github.com/ProtonVPN/vpncore)

### Third-party dependencies

[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)

## Setup

- Clone this repository
- Clone the vpncore framework at the same directory level as this repo
- Run `pod install` first in vpncore and then this repository
- Open `ProtonVPN.xcworkspace` in Xcode
- Configure code signing for all targets with a paid Apple developer account (required due to VPN entitlements) and change the bundle identifiers to something unique
- Build app twice

## Staying in Sync

To stay in sync with changes made to vpncore, follow these three steps:
- Run `pod install`
- Clean build folder in Xcode (`Cmd+Shift+K`)
- Build app

## Testing

For UI tests to work, you have to copy `ProtonVPNUITests/credentials.example.plist` as `ProtonVPNUITests/credentials.plist` and enter working credentials and corresponding plan names. To add credentials on CI server, add env variables (at least 1 user is needed, up to 5 users can be added):
```
export IOS_VPNTEST_USER1=user1 IOS_VPNTEST_PASSWORD1=pass1 IOS_VPNTEST_PLAN1=plan1
export IOS_VPNTEST_USER1=user2 IOS_VPNTEST_PASSWORD1=pass2 IOS_VPNTEST_PLAN1=plan2
export IOS_VPNTEST_USER1=user3 IOS_VPNTEST_PASSWORD1=pass3 IOS_VPNTEST_PLAN1=plan3
export IOS_VPNTEST_USER1=user4 IOS_VPNTEST_PASSWORD1=pass4 IOS_VPNTEST_PLAN1=plan4
export IOS_VPNTEST_USER1=user5 IOS_VPNTEST_PASSWORD1=pass5 IOS_VPNTEST_PLAN1=plan5
```

## License

The code and datafiles in this distribution are licensed under the terms of the GPLv3 as published by the Free Software Foundation. See <https://www.gnu.org/licenses/> for a copy of this license.

Copyright (c) 2019 Proton Technologies AG
