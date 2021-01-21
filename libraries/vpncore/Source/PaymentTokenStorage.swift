//
//  PaymentTokenStorage.swift
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

/// Storage for current Payment Token that is not yet used.
/// Can hold exactly one token as it is meant to be short lived and should be consumed at the first possibility.
public protocol PaymentTokenStorage {
    func add(_ token: PaymentToken)
    func get() -> PaymentToken?
    func clear()
}

extension PaymentTokenStorage {
    var isEmpty: Bool { return self.get() == nil }
}

public protocol PaymentTokenStorageFactory {
    func makePaymentTokenStorage() -> PaymentTokenStorage
}

public class MemoryPaymentTokenStorage: PaymentTokenStorage {
    
    var token: PaymentToken?
    var validUntil: Date?
    
    private var lifetime: TimeInterval
    
    public init(lifetime: TimeInterval) {
        self.lifetime = lifetime
    }
    
    public func add(_ token: PaymentToken) {
        self.token = token
        self.validUntil = Date() + lifetime
        PMLog.D("MemoryPaymentTokenStorage new token set. Valid until \(String(describing: self.validUntil)).")
    }
    
    public func get() -> PaymentToken? {
        guard let until = validUntil, until.isFuture else {
            return nil
        }
        return token
    }
    
    public func clear() {
        token = nil
        validUntil = nil
        PMLog.D("MemoryPaymentTokenStorage cleared")
    }
    
}
