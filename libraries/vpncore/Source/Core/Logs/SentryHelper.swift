//
//  SentryHelper.swift
//  SentryHelper
//
//  Created by Jaroslav on 2021-09-10.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import Sentry

public final class SentryHelper {
    
    public static func setupSentry(dsn: String) {
        #if RELEASE // to avoid issues with bitcode uploads not being reliable during development
        SentrySDK.start { (options) in
            options.dsn = dsn
            options.debug = false
            options.enableAutoSessionTracking = false
            options.attachStacktrace = false
            options.maxBreadcrumbs = 25

            options.beforeSend = { event in
                // Remove heaviest part of event to make sure event doesn't reach max request size. Can be removed after the issue is fixed on the infra side (INFSUP-682).
                event.debugMeta = nil
                return event
            }
        }
        #endif
    }
    
}
