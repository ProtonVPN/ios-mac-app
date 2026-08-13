# NEProviders
This package contains the code responsible for connection with the ProTUN core framework extension.

## Where protun.xcframework comes from

`Package.swift` downloads the framework from the public host by default. Set `CI_NEXUS_URL` and it downloads
from the internal Nexus mirror instead, which is how CI builds it and how anyone can build a release candidate
before it reaches the public host. The manifest reads the variable through `Context.environment`, so no setup
script is involved.

The checksum is the same for both hosts, so it also confirms the mirror serves the same file.

## Setup

Get the Nexus host from a teammate and export it in your shell profile (e.g. `~/.zshrc`):

```bash
export CI_NEXUS_URL=https://nexus.example.invalid
```

You only need this to build a version that has not been published to the public host yet. Without it, builds
of published versions work normally.

Xcode.app does not inherit your shell profile. To make the variable reach a manifest that Xcode evaluates,
either launch Xcode from a terminal, or register the variable with launchd and restart Xcode:

```bash
launchctl setenv CI_NEXUS_URL https://nexus.example.invalid
```

## Every time the ProTUN version changes

Edit the `artifact` and `checksum` constants in `Package.swift`. Nothing else to do; both hosts follow the
same path layout below their prefix.

## Verification

Check which URL the manifest produces, without downloading anything:

```bash
cd libraries/Core/NEProviders
swift package dump-package | grep -o 'https://[^"]*xcframework.zip'
```

Run it with and without `CI_NEXUS_URL` set to see each host.
