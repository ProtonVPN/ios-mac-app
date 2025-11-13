//
//  Created on 28/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Combine
import Foundation

import Dependencies
import DependenciesMacros

import struct Domain.Alert
import protocol Domain.AlertConvertibleError
import protocol Domain.ProtonVPNError
import protocol Foundation.LocalizedError
import Logging
import enum Strings.Localizable

package let log = Logging.Logger(label: "ProtonVPN.Modals.Logger")

/// A basic AlertService.
public struct AlertService: DependencyKey {
    /// A stream of alerts.
    public internal(set) var alerts: @Sendable () async -> AsyncStream<Alert> = { .init { $0.finish() } }
    /// Entry point of errors that will be treated accordingly by the service.
    public internal(set) var feed: @Sendable (Error) async -> Void = unimplemented()
    /// Manually interrupt alert listening.
    public internal(set) var finish: @Sendable () async -> Void = unimplemented()
}

public extension AlertService {
    static let live: AlertService = {
        let subject = CurrentValueSubject<Alert?, Never>(nil)

        return AlertService(
            alerts: {
                // We're using a CurrentValueSubject because it can retain the last alert that was forwarded
                // So we could add checks before forwarding the alert if we're feeding the same alert twice in a row for example
                AsyncStream { continuation in
                    let cancellable = subject.compactMap { $0 }
                        .removeDuplicates()
                        .sink { value in
                            continuation.yield(value)
                        }
                    continuation.onTermination = { _ in cancellable.cancel() }
                }
            },
            feed: { error in
                if let protonVpnError = error as? ProtonVPNError {
                    log.error("Alerting user to error: \(protonVpnError.debugDescription)")
                } else {
                    log.error("Alerting user to error: \(String(describing: error))")
                }

                let alert: Alert = if let alertConvertibleError = error as? AlertConvertibleError {
                    alertConvertibleError.alert
                } else if let localizedError = error as? LocalizedError {
                    Alert(localizedError: localizedError)
                } else {
                    Alert(title: Localizable.genericErrorTitle, message: "\(error.localizedDescription)")
                }
                subject.send(alert)
            },
            finish: {
                subject.send(completion: .finished)
            }
        )
    }()
}

// MARK: - Dependency

public extension AlertService {
    static let liveValue: AlertService = .live
    static let testValue: AlertService = .live // live implementation is already generic enough and lightweight
}

public extension DependencyValues {
    var alertService: AlertService {
        get { self[AlertService.self] }
        set { self[AlertService.self] = newValue }
    }
}
