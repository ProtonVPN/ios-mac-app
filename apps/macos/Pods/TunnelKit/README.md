# TunnelKit

![iOS 11+](https://img.shields.io/badge/ios-11+-green.svg)
[![OpenSSL 1.1.1g](https://img.shields.io/badge/openssl-1.1.1g-d69c68.svg)](https://www.openssl.org/news/openssl-1.1.1-notes.html)
[![License GPLv3](https://img.shields.io/badge/license-GPLv3-lightgray.svg)](LICENSE)
[![Travis-CI](https://api.travis-ci.org/passepartoutvpn/tunnelkit.svg?branch=master)](https://travis-ci.org/passepartoutvpn/tunnelkit)

This library provides a simplified Swift/Obj-C implementation of the OpenVPN® protocol for the Apple platforms. The crypto layer is built on top of [OpenSSL 1.1.1][dep-openssl], which in turn enables support for a certain range of encryption and digest algorithms.

## Getting started

The client is known to work with [OpenVPN®][openvpn] 2.3+ servers.

- [x] Handshake and tunneling over UDP or TCP
- [x] Ciphers
    - AES-CBC (128/192/256 bit)
    - AES-GCM (128/192/256 bit, 2.4)
- [x] HMAC digests
    - SHA-1
    - SHA-2 (224/256/384/512 bit)
- [x] NCP (Negotiable Crypto Parameters, 2.4)
    - Server-side
- [x] TLS handshake
    - Server validation (CA, EKU)
    - Client certificate
- [x] TLS wrapping
    - Authentication (`--tls-auth`)
    - Encryption (`--tls-crypt`)
- [x] Compression framing
    - Via `--comp-lzo` (deprecated in 2.4)
    - Via `--compress`
- [x] Compression algorithms
    - LZO (via `--comp-lzo` or `--compress lzo`)
- [x] Key renegotiation
- [x] Replay protection (hardcoded window)

The library therefore supports compression framing, just not newer compression. Remember to match server-side compression and framing, otherwise the client will shut down with an error. E.g. if server has `comp-lzo no`, client must use `compressionFraming = .compLZO`.

### Support for .ovpn configuration

TunnelKit can parse .ovpn configuration files. Below are a few limitations worth mentioning.

Unsupported:

- UDP fragmentation, i.e. `--fragment`
- Compression via `--compress` other than empty or `lzo`
- Connecting via proxy
- External file references (inline `<block>` only)
- Static key encryption (non-TLS)
- `<connection>` blocks
- `vpn_gateway` and `net_gateway` literals in routes

Ignored:

- MTU overrides
    - `--*-mtu` and variants
    - `--mssfix`
- Multiple `--remote` with different `host` values (first wins)
- Static client-side routes

Many other flags are ignored too but it's normally not an issue.

## Installation

### Requirements

- iOS 11.0+ / macOS 10.11+
- Xcode 10+ (Swift 5)
- Git (preinstalled with Xcode Command Line Tools)
- Ruby (preinstalled with macOS)
- [CocoaPods 1.6.0][dep-cocoapods]
- [jazzy][dep-jazzy] (optional, for documentation)
- [Disable Bitcode][issue-51]

It's highly recommended to use the Git and Ruby packages provided by [Homebrew][dep-brew].

### CocoaPods

To use with CocoaPods just add this to your Podfile:

```ruby
pod 'TunnelKit'
```

### Testing

Download the library codebase locally:

    $ git clone https://github.com/passepartoutvpn/tunnelkit.git

Assuming you have a [working CocoaPods environment][dep-cocoapods], setting up the library workspace only requires installing the pod dependencies:

    $ pod install

After that, open `TunnelKit.xcworkspace` in Xcode and run the unit tests found in the `TunnelKitTests` folder. A simple CMD+U while on `TunnelKit-iOS` should do that as well.

#### Demo

There is a `Demo` directory containing a simple app for testing the tunnel, called `BasicTunnel`. As usual, prepare for CocoaPods:

    $ pod install

then open `Demo.xcworkspace` and run the `BasicTunnel-iOS` target.

For the VPN to work properly, the `BasicTunnel` demo requires:

- _App Groups_ and _Keychain Sharing_ capabilities
- App IDs with _Packet Tunnel_ entitlements

both in the main app and the tunnel extension target.

In order to test connection to your own server, modify the file `Demo/BasicTunnel-[iOS|macOS]/ViewController.swift` and make sure to set `ca` to the PEM encoded certificate of your VPN server's CA.

Example:

    private let ca = CryptoContainer(pem: """
	-----BEGIN CERTIFICATE-----
	MIIFJDCC...
	-----END CERTIFICATE-----
    """)

Make sure to also update the following constants in the same files, according to your developer account and your target bundle identifiers:

    public static let appGroup
    public static let tunnelIdentifier

Remember that the App Group on macOS requires a team ID prefix.

## Documentation

The library is split into several modules, in order to decouple the low-level protocol implementation from the platform-specific bridging, namely the [NetworkExtension][ne-home] VPN framework.

Full documentation of the public interface is available and can be generated with [jazzy][dep-jazzy]. After installing the jazzy Ruby gem with:

    $ gem install jazzy

enter the root directory of the repository and run:

    $ jazzy

The generated output is stored into the `docs` directory in HTML format.

### Core

Contains the building blocks of a VPN protocol. Eventually, a consumer would implement the `Session` interface, expected to start and control the VPN session. A session is expected to work with generic network interfaces:

- `LinkInterface` (e.g. a socket)
- `TunnelInterface` (e.g. an `utun` interface)

There are no physical network implementations (e.g. UDP or TCP) in this module.

### AppExtension

Provides a layer on top of the NetworkExtension framework. Most importantly, bridges native [NWUDPSession][ne-udp] and [NWTCPConnection][ne-tcp] to an abstract `GenericSocket` interface, thus making a multi-protocol VPN dramatically easier to manage.

### Protocols/OpenVPN

Here you will find the low-level entities on top of which an OpenVPN connection is established. Code is mixed Swift and Obj-C, most of it is not exposed to consumers. The module depends on OpenSSL.

The entry point is the `OpenVPNSession` class. The networking layer is fully abstract and delegated externally with the use of opaque `IOInterface` (`LinkInterface` and `TunnelInterface`) and `OpenVPNSessionDelegate` protocols.

Another goal of this module is packaging up a black box implementation of a [NEPacketTunnelProvider][ne-ptp], which is the essential part of a Packet Tunnel Provider app extension. You will find the main implementation in the `OpenVPNTunnelProvider` class.

A debug log snapshot is optionally maintained and shared by the tunnel provider to host apps via the App Group container.

### Extra/LZO

Due to the restrictive license (GPLv2), LZO support is provided as an optional subspec.

## License

### Part I

This project is licensed under the [GPLv3][license-content].

### Part II

As seen in [libsignal-protocol-c][license-signal]:

> Additional Permissions For Submission to Apple App Store: Provided that you are otherwise in compliance with the GPLv3 for each covered work you convey (including without limitation making the Corresponding Source available in compliance with Section 6 of the GPLv3), the Author also grants you the additional permission to convey through the Apple App Store non-source executable versions of the Program as incorporated into each applicable covered work as Executable Versions only under the Mozilla Public License version 2.0 (https://www.mozilla.org/en-US/MPL/2.0/).

### Part III

Part I and II do not apply to the LZO library, which remains licensed under the terms of the GPLv2+.

### Contributing

By contributing to this project you are agreeing to the terms stated in the [Contributor License Agreement (CLA)][contrib-cla].

For more details please see [CONTRIBUTING][contrib-readme].

## Credits

- [lzo][dep-lzo-website] - © 1996 - 2017 Markus F.X.J. Oberhumer
- [PIATunnel][dep-piatunnel-repo] - © 2018-Present Private Internet Access
- [SURFnet][surfnet]
- [SwiftyBeaver][dep-swiftybeaver-repo] - © 2015 Sebastian Kreutzberger

This product includes software developed by the OpenSSL Project for use in the OpenSSL Toolkit. ([https://www.openssl.org/][dep-openssl])

© 2002-2018 OpenVPN Inc. - OpenVPN is a registered trademark of OpenVPN Inc.

## Contacts

Twitter: [@keeshux][about-twitter]

Website: [passepartoutvpn.app][about-website]

[openvpn]: https://openvpn.net/index.php/open-source/overview.html

[dep-cocoapods]: https://guides.cocoapods.org/using/getting-started.html
[dep-jazzy]: https://github.com/realm/jazzy
[dep-brew]: https://brew.sh/
[dep-openssl]: https://www.openssl.org/
[issue-51]: https://github.com/passepartoutvpn/tunnelkit/issues/51

[ne-home]: https://developer.apple.com/documentation/networkextension
[ne-ptp]: https://developer.apple.com/documentation/networkextension/nepackettunnelprovider
[ne-udp]: https://developer.apple.com/documentation/networkextension/nwudpsession
[ne-tcp]: https://developer.apple.com/documentation/networkextension/nwtcpconnection

[license-content]: LICENSE
[license-signal]: https://github.com/signalapp/libsignal-protocol-c#license
[license-mit]: https://choosealicense.com/licenses/mit/
[contrib-cla]: CLA.rst
[contrib-readme]: CONTRIBUTING.md

[dep-piatunnel-repo]: https://github.com/pia-foss/tunnel-apple
[dep-swiftybeaver-repo]: https://github.com/SwiftyBeaver/SwiftyBeaver
[dep-lzo-website]: http://www.oberhumer.com/opensource/lzo/
[surfnet]: https://www.surf.nl/en/about-surf/subsidiaries/surfnet

[about-twitter]: https://twitter.com/keeshux
[about-website]: https://passepartoutvpn.app
