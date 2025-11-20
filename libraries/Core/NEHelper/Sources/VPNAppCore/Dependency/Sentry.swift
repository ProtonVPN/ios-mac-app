//
//  Sentry.swift
//  SentryHelper
//
//  Created by Jaroslav on 2021-09-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Domain
import Foundation
import ProtonCoreFeatureFlags
import Sentry
import VPNShared

/// `SentryHelper` defines a `log` instance method, we need to rename `log` in this file
private let moduleLog = VPNAppCore.log

public final class SentryHelper {
    public private(set) static var shared: SentryHelper?

    public static func setupSentry(dsn: String, isEnabled: @escaping () -> Bool, getUserId _: @escaping () -> String?) {
        guard shared == nil else {
            moduleLog.assertionFailure("Sentry already setup")
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            options.enableAutoSessionTracking = false
            options.maxBreadcrumbs = 50

            options.beforeSend = { event in
                // Make sure crash reporting is still enabled.
                // If not, returning nil will prevent Sentry from sending the report.
                guard isEnabled() else {
                    moduleLog.warning("Crash reports sharing is disabled. Won't send error report.", metadata: ["error": "\(String(describing: event.error))"])
                    return nil
                }

                return event
            }

            shared = SentryHelper(isEnabled: isEnabled)
        }
    }

    private let sentryEnabled: () -> Bool

    init(isEnabled: @escaping () -> Bool) {
        self.sentryEnabled = isEnabled
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
}
