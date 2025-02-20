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
import SwiftNavigation

import Logging
import protocol Foundation.LocalizedError
import struct Domain.Alert
import protocol Domain.AlertConvertibleError

package let log = Logging.Logger(label: "ProtonVPN.Modals.Logger")

import XCTestDynamicOverlay

/// A basic AlertService.
@DependencyClient
public struct AlertService {
    /// A stream of alerts.
    public internal(set) var alerts: @Sendable () async -> AsyncStream<Alert> = { .init { $0.finish() } }
    /// Entry point of errors that will be treated accordingly by the service.
    public internal(set) var feed: @Sendable (Error) async -> Void
    /// Manually interrupt alert listening.
    public internal(set) var finish: @Sendable () async -> Void
}

extension AlertService {
    public static let live: AlertService = {
        let subject = CurrentValueSubject<Alert?, Never>(nil)
        // We're using a CurrentValueSubject because it can retain the last alert that was forwarded
        // So we could add checks before forwarding the alert if we're feeding the same alert twice in a row for example
        let stream = subject.compactMap { $0 }.values.eraseToStream()

        return AlertService {
            return stream
        } feed: { error in
            log.error("Alerting user to error: \(String(describing: error))")

            let alert: Alert
            if let alertConvertibleError = error as? AlertConvertibleError {
                alert = alertConvertibleError.alert
            } else if let localizedError = error as? LocalizedError {
                alert = Alert(localizedError: localizedError)
            } else if type(of: error) is NSError.Type {
                alert = Alert(title: "Error", message: (error as NSError).localizedDescription)
            } else {
                alert = Alert(title: "Error", message: "\(error)")
            }
            subject.send(alert)
        } finish: {
            subject.send(completion: .finished)
        }
    }()
}

extension Alert {
    public func alertState<Action>(from: Action.Type) -> AlertState<Action> {
        let title = TextState(String(localized: title))
        let message = TextState(String(localized: message))
        return AlertState<Action>(title: title, message: message)
    }
}

// MARK: - Dependency

extension AlertService: DependencyKey {
    public static let liveValue: AlertService = .live
    public static let testValue: AlertService = .live // live implementation is already generic enough and lightweight
}

extension DependencyValues {
    public var alertService: AlertService {
        get { self[AlertService.self] }
        set { self[AlertService.self] = newValue }
    }
}
