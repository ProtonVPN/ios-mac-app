//
//  Sentry.swift
//  SentryHelper
//
//  Created by Jaroslav on 2021-09-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Sentry

/// `SentryHelper` defines a `log` instance method, we need to rename `log` in this file
private let moduleLog = VPNAppCore.log

public final class SentryHelper {
    public private(set) nonisolated(unsafe) static var shared: SentryHelper?

    /// Prepares Sentry and starts it when the user currently shares crash reports.
    ///
    /// The helper keeps `dsn` and `isEnabled` so `setSentryEnabled(_:)` can start and stop the SDK
    /// later, when the user changes the setting.
    public static func setupSentry(dsn: String, isEnabled: @escaping () -> Bool, getUserId _: @escaping () -> String?) {
        guard shared == nil else {
            moduleLog.assertionFailure("Sentry already setup")
            return
        }

        let helper = SentryHelper(dsn: dsn, isEnabled: isEnabled)
        shared = helper
        helper.setSentryEnabled(isEnabled())
    }

    private let dsn: String
    private let isEnabled: () -> Bool

    private init(dsn: String, isEnabled: @escaping () -> Bool) {
        self.dsn = dsn
        self.isEnabled = isEnabled
    }

    /// Starts or stops Sentry to follow the user's crash report sharing choice.
    ///
    /// Stopping removes Sentry's crash and signal handlers, so a disabled Sentry collects nothing.
    /// Refusing the upload alone would leave those handlers installed.
    public func setSentryEnabled(_ enabled: Bool) {
        switch (enabled, SentrySDK.isEnabled) {
        case (true, false):
            start()
        case (false, true):
            moduleLog.info("Crash reports sharing is disabled. Shutting Sentry down.")
            SentrySDK.close()
        case (true, true), (false, false):
            break
        }
    }

    private func start() {
        let dsn = dsn
        let isEnabled = isEnabled

        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            options.enableAutoSessionTracking = false
            options.maxBreadcrumbs = 50

            options.beforeSend = { event in
                // The user can withdraw consent while Sentry is shutting down, and closing it sends
                // whatever it has already queued. Drop those events too.
                guard isEnabled() else {
                    moduleLog.warning("Crash reports sharing is disabled. Won't send error report.", metadata: ["error": "\(String(describing: event.error))"])
                    return nil
                }

                return event
            }
        }
    }

    public func log(error: Error) {
        // Capture is finished by calling `options.beforeSend`, where we check
        // if crash reporting is enabled.
        SentrySDK.capture(error: error)
    }

    public func log(message: String, extra: [String: Any] = [:]) {
        let event = Event()
        event.message = SentryMessage(formatted: message)
        event.extra = extra
        SentrySDK.capture(event: event)
    }

    /// Reports an error to Sentry, for injecting into modules that must not link the Sentry SDK themselves.
    ///
    /// The message is context for the log; Sentry groups on the error itself.
    public static let reportError: @Sendable (_ message: String, _ error: Error) -> Void = { _, error in
        shared?.log(error: error)
    }
}
