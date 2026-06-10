# NEHelper

Package contains several modules intended to help with Network Extension development.

## VPNShared

Classes that are used by both `NetworkExtension`s and `vpncore` library are placed into this library to prevent code duplication. Some of these classes are tested in `VPNSharedTests`.

## VPNAppCore

Builds on top of `VPNShared` with classes used by MacOS and iOS Application targets, but which are not necessary for Network Extensions.

This module will completely replace VPNCore, once SPM support is added for Accounts/Core.

## VPNSharedTesting

Contains mocks of classes from `VPNShared` library. Include this in tests that need these mocks. 
