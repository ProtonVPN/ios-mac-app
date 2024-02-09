//
//  SentryHelper.swift
//  SentryHelper
//
//  Created by Jaroslav on 2021-09-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Sentry
import VPNShared

public final class SentryHelper {

    public static var shared: SentryHelper?

    public static func setupSentry(dsn: String, isEnabled: @escaping () -> Bool, getUserId: @escaping () -> String?) {
        guard shared == nil else {
            assertionFailure("Sentry already setup")
            return
        }

        SentrySDK.start { (options) in
            options.dsn = dsn
            options.debug = false
            options.enableAutoSessionTracking = false
            options.maxBreadcrumbs = 50

            options.beforeSend = { event in
                // Make sure crash reporting is still enabled.
                // If not, returning nil will prevent Sentry from sending the report.
                guard isEnabled() else {
                    LegacyCommon.log.warning("Crash reports sharing is disabled. Won't send error report.", metadata: ["error": "\(String(describing: event.error))"])
                    return nil
                }

                // Remove heaviest part of event to make sure event doesn't reach max request size. Can be removed after the issue is fixed on the infra side (INFSUP-682).
                event.debugMeta = nil

                // Add internal, encrypted user ID to Sentry errors
                if let userId = getUserId() {
                    event.user = User(userId: userId)
                }

                return event
            }

            shared = SentryHelper(isEnabled: isEnabled)
        }
    }

    private let sentryEnabled: () -> Bool

    init(isEnabled: @escaping () -> Bool) {
        sentryEnabled = isEnabled
    }

    public func log(error: Error) {
        // Capture is finished by calling `options.beforeSend`, where we check
        // if crash reporting is enabled.
        SentrySDK.capture(error: error)
    }

}
