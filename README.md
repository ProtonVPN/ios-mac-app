# Proton VPN for iOS and macOS

Copyright (c) 2023 Proton Technologies AG

## Dependencies

This project uses Swift Package Manager for all of it's dependencies. Allow Xcode to resolve packages before running any target.

### Third-party dependencies

[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md)

## Setup

- Enable [Git LFS](https://git-lfs.github.com) on your machine 
- Clone this repository
- Make sure you have go installed (`brew install go`)
- You'll need to use Xcode 14.x for now
- Configure code signing for all targets with a paid Apple developer account (required due to VPN entitlements) and change the bundle identifiers to something unique
- Clean build folder in Xcode (`Cmd+Shift+K`)

### Obfuscated Constants

A set of secrets is required in order to build the project.
These include URLs and keys, and are kept in files named `ObfuscatedConstants.swift`.
These files are kept in a seperate repository, which requires some additional setup to keep synchronised.

Firstly, invoke the script located at `scripts/credentials.sh` with the `setup` command.
Provide the path where you wish the secrets repository to be cloned locally using the `-p` argument, and the url of the repository using the `-r` argument.
```
./scripts/credentials.sh setup -p <path to credentials repo> -r <credentials remote>
```

Then, to verify that setup has been successful:
```
./scripts/credentials.sh checkout
```

If setup correctly, obfuscated constants will be automatically synchronised during the Generate Obfuscated Constants build phase of each app.

## Package Structure

The project is packaged by layer in order to avoid module dependency hell:
 - Foundations: small, single-purpose libraries for building bigger things. These should only ever link each other, if they do so at all.
 - Shared: slightly larger libraries meant for sharing code between applications or extensions. Portions of this library that get too big or would benefit from being their own module can be broken out into Foundations. These should only ever link Foundations libraries, with the possible exception of these libraries each linking CoreCommon .
 - Features: self-contained libraries containing a single feature. These libraries should only ever link libraries from the Shared or Foundations categories. They are included and instantiated within application, test, or extension code.

Adding new code/feature to LegacyCommon and NEHelper should be avoided if possible.
These packages should be gradually chipped away at in order to place their components into new/existing packages in the above three categories.

### Code linting

During development swiftlint is run on non-strict mode so it's easier to develop without worrying about code formatting. On CI, linting is strict and will fail on any warning. Before commiting code to this repository run the following script to add a pre-commit hook that will check all new/modified files in strict mode and stop you from committing code that won't make it through CI.

`./scripts/pre_commit_lint.sh setup`

### Localization

The app uses [SwiftGen](https://github.com/SwiftGen/SwiftGen) to generate the `Localizable.strings` file for accessing all the app strings stored in the standard `Localizable.strings` files. Just add a new string to Strings package and run the `swiftgen` command in a directory where `swiftgen.yml` is defined.

## License

The code and data files in this distribution are licensed under the terms of the GPLv3 as published by the Free Software Foundation. See <https://www.gnu.org/licenses/> for a copy of this license.

Copyright (c) 2023 Proton Technologies AG
