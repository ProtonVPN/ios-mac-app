# NEHelper

Package contains several modules intended to help with Network Extension development.

## NEHelper

Contains classes used by all (or most) of our Network Extensions. Currently, main functionality of this library is certificate management. It contains classes that communicate with API to setup Certificate based authentication used by VPN clients.
Tests for this library are inside `NEHelperTests`.

## VPNShared

Classes that are used by both `NetworkExtension`s and `vpncore` library are placed into this library to prevent code duplication. Some of these classes are tested in `VPNSharedTests`.

## VPNAppCore

Builds on top of `VPNShared` with classes used by MacOS and iOS Application targets, but which are not necessary for Network Extensions.

This module will completely replace VPNCore, once SPM support is added for Accounts/Core.

## VPNSharedTesting

Contains mocks of classes from `VPNShared` library. Include this in tests that need these mocks. 
