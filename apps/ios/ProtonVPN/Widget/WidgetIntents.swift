//
//  Created on 2025-01-13.
//
//  Copyright (c) 2025 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import Ergonomics
import VPNAppCore
import AppIntents
import Domain
import UIKit
import Connection
import ComposableArchitecture
import AsyncAlgorithms

internal struct DisconnectFromVPNIntent: AppIntent {
    static var title: LocalizedStringResource = "Disconnect from VPN"

    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {

        @Dependencies.Dependency(\.disconnectVPN) var disconnectVPN
        try? await disconnectVPN(.widget)
        return .result()
    }
}

internal struct ConnectToVPNIntent: AppIntent {

    static var title: LocalizedStringResource = "Connect to VPN"
    static var openAppWhenRun = true

    private static let timeOut = 20 // 20 Seconds

    @Parameter(title: "Recent Connection Index") var recentIndex: Int?

    init() {
        recentIndex = nil
    }

    init(recentIndex: Int) {
        self.recentIndex = recentIndex
    }

    func perform() async throws -> some IntentResult {
        @Dependencies.Dependency(\.connectToVPN) var connectToVPN
        @SharedReader(.connectionState) var connectionState: ConnectionState

        guard let spec = recentIndex.flatMap(getRecentConnection) ?? getDefaultConnection() else {
            return .result()
        }

        // Wait until the connection state is not .resolving
        guard let _ = try? await $connectionState.when(willMatch: {
            if case .resolving = $0 { return false }
            return true
        }, every: .milliseconds(20), deadline: .seconds(Self.timeOut), operation: { _ in
            // no-op
        }) else {
            log.error("The connectionState hasn’t been changed from `resolving` in \(Self.timeOut) seconds. Skipping the widget connection intent.")
            return .result()
        }

        // Trigger connection
        do {
            try await connectToVPN(spec, defaultConnectionStorage.getDefaultProtocol(), .widget)
        } catch {
            log.error("Failed to connect to VPN from widget with error: \(error)")
        }

        // Wait until the connection state either goes into .connected or .disconnecting.
        try? await $connectionState.when(willMatch: { state in
            switch state {
            case .connected(let intent, _, _, _):
                return intent.spec == spec
            case .disconnecting(let intent, _):
                return intent.spec == spec
            default:
                return false
            }
        }, every: .milliseconds(20), deadline: .seconds(Self.timeOut), operation: { state in
            if case .connected = state {
                // VPN connection established, now suspending the app.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                }
            }
        })

        return .result()
    }

    // MARK: - Private helpers:

    @Dependencies.Dependency(\.recentsStorage) private var recentsStorage
    @Dependencies.Dependency(\.defaultConnectionStorage) private var defaultConnectionStorage

    private func getRecentConnection(_ index: Int) -> ConnectionSpec? {

        @Dependencies.Dependency(\.connectionInventory) var connectionInventory

        return connectionInventory.recentConnectionList(
            .fastest,
            recentsStorage.readFromStorage(),
            ConnectionSpec.defaultFastest
        ).elements[safe: index]?.connection
    }

    private func getDefaultConnection() -> ConnectionSpec? {
        let preference = try? defaultConnectionStorage.getPreference()
        switch preference ?? .fastest {
        case .fastest:
            return .defaultFastest
        case .mostRecent:
            let recents = recentsStorage.readFromStorage()
            return recents.elements.first?.connection ?? .defaultFastest
        case .recent(let spec):
            return spec
        }
    }
}

internal struct LoginIntent: AppIntent {
    static var title: LocalizedStringResource = "Login"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - Private helpers

fileprivate struct SharedReaderTimeoutError: Error {}

extension SharedReader {
    /// Regularly checks when the underlying value satisfies the provided matching condition.
    /// When the value matches (i.e. the matcher returns true), the `operation` closure is executed once with the matched value, and the function returns.
    /// If the deadline passes, the function throws a timeout error.
    /// - Parameters:
    ///   - matcher: A closure that compares the new value and returns true when it matches.
    ///   - interval: The interval at which we check if the deadline has passed.
    ///   - clock: The clock on which we base time calculations.
    ///   - deadlineDuration: The deadline after which the check times out.
    ///   - operation: The operation to perform when a match occurs, receiving the matched value.
    fileprivate func when<C: Clock>(
        willMatch matcher: @escaping (Value) -> Bool,
        every interval: C.Duration,
        on clock: C = ContinuousClock(),
        deadline deadlineDuration: C.Duration,
        operation: @escaping (Value) async throws -> Void
    ) async throws where C.Duration: Hashable {
        let combinedSequence = combineLatest(publisher.values, clock.timer(interval: interval))
        let deadline = clock.now.advanced(by: deadlineDuration)

        for await (newValue, _) in combinedSequence {
            try Task.checkCancellation()
            guard clock.now < deadline else {
                throw SharedReaderTimeoutError()
            }
            if matcher(newValue) {
                try await operation(newValue)
                return
            }
        }
    }
}
