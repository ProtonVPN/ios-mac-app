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

import enum Connection.ConnectionError

import ComposableArchitecture
import Dependencies
import protocol Foundation.LocalizedError

import XCTestDynamicOverlay

/// An error meant to be displayed within an ``AlertService.Alert`` alert.
public protocol AlertConvertibleError: Error {
    var alert: AlertService.Alert { get }
}

/// A basic AlertService.
public struct AlertService {
    /// A stream of alerts.
    public internal(set) var alerts: () -> AsyncStream<Alert> = unimplemented()
    /// Entry point of errors that will be treated accordingly by the service.
    var feed: @Sendable (Error) async -> Void = unimplemented()
}

extension AlertService {
    public static var live: AlertService {
        let (asyncStream, continuation) = AsyncStream<Alert>.makeStream(bufferingPolicy: .unbounded)

        return AlertService { asyncStream } feed: { error in
            let alert: Alert
            if let alertConvertibleError = error as? AlertConvertibleError {
                alert = alertConvertibleError.alert
            } else if let localizedError = error as? LocalizedError {
                alert = Alert(localizedError: localizedError)
            } else {
                alert = Alert()
            }
            continuation.yield(alert)
        }
    }
}

// MARK: - Error Conformances

extension ConnectionError: AlertConvertibleError {
    public var alert: AlertService.Alert {
        return ConnectionFailedAlert()
    }
}
