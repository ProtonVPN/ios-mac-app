//
//  Created on 04.10.23.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation

/**
 * ExpiringValue: after a value has been set, wait a specified timeout interval before resetting the value back to nil.
 *
 * If a new value is set for the property wrapper before the timeout has expired, the timeout duration is reset to the
 * beginning and the new value will again persist for the specified time interval.
 *
 * The timeout is variable and can be set to `nil`, which signifies that the value will never time out. This can be
 * useful in the case where the timeout is determined by some remote configuration value, or in the case where a
 * feature flag needs to disable a particular value timeout.
 */
@propertyWrapper
open class ExpiringValue<Value> {
    public var _wrappedValue: Value?

    public var wrappedValue: Value? {
        get {
            didTimeOut ? nil : _wrappedValue
        }

        set {
            _wrappedValue = newValue
            expiry = .now.addingTimeInterval(timeout)
        }
    }

    public var timeout: TimeInterval {
        didSet {
            let oldStart = expiry - oldValue
            expiry = oldStart + timeout
        }
    }

    public private(set) var expiry: Date

    public var didTimeOut: Bool {
        Date.now.timeIntervalSince(expiry) >= 0
    }

    public init(wrappedValue: Value? = nil, timeout: TimeInterval) {
        self._wrappedValue = wrappedValue
        self.timeout = timeout
        self.expiry = .now.addingTimeInterval(timeout)
    }
}
