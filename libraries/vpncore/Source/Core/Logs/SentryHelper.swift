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
        }
        #endif
    }
    
}
