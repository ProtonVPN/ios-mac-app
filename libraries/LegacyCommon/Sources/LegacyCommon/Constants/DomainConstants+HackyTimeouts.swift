//
//  AppConstants.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Strings
import Domain

/// Everything in this extension should go away once LegacyCommon is no longer needed.
public extension DomainConstants {
    enum UpdateTime {
        public static let quickUpdateTime: TimeInterval = 3.0
        public static let quickReconnectTime: TimeInterval = 0.5
    }

    // Pause between reconnection with another protocol
    static let protocolChangeDelay: Int = 1 // seconds
}
