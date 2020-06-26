//
//  KeychainPaymentTokenStorage.swift
//  vpncore - Created on 2020-06-22.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import KeychainAccess

/// Class for storing payment token in the keychain
public class KeychainPaymentTokenStorage: PaymentTokenStorage {
    
    private var keychain: Keychain
    private var key = "unusedPaymentToken"
    
    public init (_ keychain: Keychain) {
        self.keychain = keychain
        PMLog.D(self.isEmpty ? "No payment token saved" : "Payment token found", level: .trace)
    }
    
    public func add(_ token: PaymentToken) {
        keychain[data: key] = try? JSONEncoder().encode(token)
    }
    
    public func get() -> PaymentToken? {
        guard let data = keychain[data: key] else {
            return nil
        }
        return try? JSONDecoder().decode(PaymentToken.self, from: data)
    }
    
    public func clear() {
        keychain[data: key] = nil
    }
    
}
