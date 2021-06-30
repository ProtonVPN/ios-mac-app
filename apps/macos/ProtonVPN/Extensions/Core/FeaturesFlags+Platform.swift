//
//  FeaturesFlags+Platform.swift
//  ProtonVPN-mac
//
//  Created by Igor Kulman on 28.05.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import vpncore

extension FeatureFlags {
    var isWireGuard: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
}
