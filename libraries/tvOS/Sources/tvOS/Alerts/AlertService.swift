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

import Combine
import ComposableArchitecture
import Dependencies
import protocol Foundation.LocalizedError

import XCTestDynamicOverlay

/// An error meant to be displayed within an ``AlertService.Alert`` alert.
public protocol AlertConvertibleError: Error {
    var alert: AlertService.Alert { get }
}

// TODO: - When Swift 6 is available, consider generalizing to an AsyncSequence<Alert> instead of a concrete AsyncStream

/// A basic AlertService.
public struct AlertService {
    /// A stream of alerts.
    public internal(set) var alerts: @Sendable () async -> AsyncStream<Alert> = unimplemented()
    /// Entry point of errors that will be treated accordingly by the service.
    var feed: @Sendable (Error) async -> Void = unimplemented()
    /// Manually interrupt alert listening.
    public internal(set) var finish: @Sendable () async -> Void = unimplemented()
}

extension AlertService {
    public static var live: AlertService {
        let subject = CurrentValueSubject<Alert?, Never>(nil)
        let stream = subject.compactMap { $0 }.values.eraseToStream()

        return AlertService {
            return stream
        } feed: { error in
            let alert: Alert
            if let alertConvertibleError = error as? AlertConvertibleError {
                alert = alertConvertibleError.alert
            } else if let localizedError = error as? LocalizedError {
                alert = Alert(localizedError: localizedError)
            } else {
                alert = Alert()
            }
            if let currentAlert = subject.value, alert == currentAlert {
                log.warning("An error of this type has already been received, feeding anyway...")
            } else {
                subject.send(alert)
            }
        } finish: {
            subject.send(completion: .finished)
        }
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

// MARK: - Error Conformances

extension ConnectionError: AlertConvertibleError {
    public var alert: AlertService.Alert {
        return ConnectionFailedAlert()
    }
}
