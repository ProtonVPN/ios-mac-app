//
//  FeatureFlags+Local.swift
//  ProtonVPN
//
//  Created by Jaroslav on 2021-06-02.
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
