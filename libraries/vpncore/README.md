# vpncore for ProtonVPN macOS & iOS Apps

Copyright (c) 2020 Proton Technologies AG

This project is for use with the ProtonVPN macOS and iOS apps and has no runnable targets of its own.

## Dependencies

We use the CocoaPods dependency manager for most dependencies.

This repository is used as a pod by the ProtonVPN iOS and macOS apps, but is not available through the CocoaPods repository. Instead, this repository must be cloned into a directory at the same level as the parent project and is used as a local dependency.

### Internal

[go-srp](https://github.com/ProtonMail/go-srp)

### Third-party dependencies

[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)

## Setup

- Clone into folder named `vpncore`
- Run `pod install` to make sure all pods are up to date and installed
- Run tests for macOS scheme and iOS scheme independently

## License

The code and datafiles in this distribution are licensed under the terms of the GPLv3 as published by the Free Software Foundation. See <https://www.gnu.org/licenses/> for a copy of this license.
