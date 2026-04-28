//
//  Created on 28/04/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import LegacyCommon
import SystemExtensions

/// Wrapper class for `OSSystemExtensionRequest` that lets us keep track of individual requests more easily.
/// Every call to a delegate function is routed through the `stateChangeCallback` property. This callback is
/// generated uniquely for every request in the `SystemExtensionsDriverClient`, so we know the state of each
/// installation request individually.
public class SystemExtensionRequest: NSObject {
    private static let requestQueue = DispatchQueue(label: "ch.proton.sysex.requests")

    let action: Action
    let osRequest: OSSystemExtensionRequest
    let stateChangeCallback: (State) -> Void
    let replacementPolicy: (ExtensionInfo, ExtensionInfo) -> Bool
    let onFinish: (SystemExtensionRequest) -> Void
    let userInitiated: Bool

    let uuid = UUID()

    enum Action {
        case install
        case uninstall
    }

    enum State {
        /// We have told sysextd we want our extension to replace an existing one in the system.
        case replacing
        /// Request has been received, but is waiting on user action to proceed.
        case userActionRequired
        /// Request has completed successfully.
        case succeeded(OSSystemExtensionRequest.Result)
        /// Request has been cancelled by the application. This can happen for a couple of reasons:
        /// - Most likely, an existing extension with the same (or greater) version is already installed.
        /// - The system asked if the application wants to replace an extension that is not recognized.
        case cancelled
        /// Request has been superseded by another one (user requested another sysext install).
        case superseded
        /// Request has failed with an error.
        case failed(Error)
    }

    func shouldExtension(_ existing: ExtensionInfo, beReplacedBy newExtension: ExtensionInfo) -> Bool {
        replacementPolicy(existing, newExtension)
    }

    // MARK: - Init

    required init(
        action: Action,
        osRequest: OSSystemExtensionRequest,
        stateChange: @escaping (State) -> Void,
        replacementPolicy: @escaping (ExtensionInfo, ExtensionInfo) -> Bool,
        onFinish: @escaping (SystemExtensionRequest) -> Void,
        userInitiated: Bool
    ) {
        self.action = action
        self.osRequest = osRequest
        self.stateChangeCallback = stateChange
        self.replacementPolicy = replacementPolicy
        self.onFinish = onFinish
        self.userInitiated = userInitiated
    }

    static func install(
        type: SystemExtensionType,
        userInitiated: Bool,
        stateChange: @escaping (State) -> Void,
        replacementPolicy: @escaping (ExtensionInfo, ExtensionInfo) -> Bool,
        onFinish: @escaping (SystemExtensionRequest) -> Void
    ) -> Self {
        let result = Self(
            action: .install,
            osRequest: .activationRequest(
                forExtensionWithIdentifier: type.rawValue,
                queue: Self.requestQueue
            ),
            stateChange: stateChange,
            replacementPolicy: replacementPolicy,
            onFinish: onFinish,
            userInitiated: userInitiated
        )
        result.osRequest.delegate = result
        return result
    }

    static func uninstall(
        type: SystemExtensionType,
        userInitiated: Bool,
        stateChange: @escaping (State) -> Void,
        replacementPolicy: @escaping (ExtensionInfo, ExtensionInfo) -> Bool,
        onFinish: @escaping (SystemExtensionRequest) -> Void
    ) -> Self {
        let result = Self(
            action: .uninstall,
            osRequest: .deactivationRequest(
                forExtensionWithIdentifier: type.rawValue,
                queue: Self.requestQueue
            ),
            stateChange: stateChange,
            replacementPolicy: replacementPolicy,
            onFinish: onFinish,
            userInitiated: userInitiated
        )
        result.osRequest.delegate = result
        return result
    }

    deinit {
        log.debug("Deinit request \(uuid.uuidString) for \(osRequest.identifier)")
    }
}

extension SystemExtensionRequest: OSSystemExtensionRequestDelegate {
    public func request(
        _: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        assert(
            existing.bundleIdentifier == ext.bundleIdentifier,
            "Extensions have mismatched identifiers? (\(existing.bundleIdentifier) and \(ext.bundleIdentifier))"
        )

        let shouldReplace = shouldExtension(
            .init(
                version: existing.bundleShortVersion,
                build: existing.bundleVersion,
                bundleId: existing.bundleIdentifier
            ),
            beReplacedBy: .init(
                version: ext.bundleShortVersion,
                build: ext.bundleVersion,
                bundleId: ext.bundleIdentifier
            )
        )

        // Allow equal-version replacement when the run is user-initiated to surface the approval flow.
        if !shouldReplace, userInitiated {
            let isEqualVersion = (existing.bundleShortVersion == ext.bundleShortVersion) && (existing.bundleVersion == ext.bundleVersion)
            if isEqualVersion {
                stateChangeCallback(.replacing)
                return .replace
            }
        }

        // Don't call stateChangeCallback(.cancelled) here, we do that when sysextd calls us again
        // with `request(_:didFailWithError:)`.
        guard shouldReplace else { return .cancel }

        stateChangeCallback(.replacing)
        return .replace
    }

    public func requestNeedsUserApproval(_: OSSystemExtensionRequest) {
        stateChangeCallback(.userActionRequired)
    }

    public func request(_: OSSystemExtensionRequest, didFailWithError error: Error) {
        guard let sysextError = error as? OSSystemExtensionError else {
            stateChangeCallback(.failed(error))
            return
        }

        switch sysextError.code {
        case .requestCanceled:
            stateChangeCallback(.cancelled)
        case .requestSuperseded:
            stateChangeCallback(.superseded)
        default:
            stateChangeCallback(.failed(sysextError))
        }

        onFinish(self)
    }

    public func request(_: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        stateChangeCallback(.succeeded(result))

        onFinish(self)
    }
}
