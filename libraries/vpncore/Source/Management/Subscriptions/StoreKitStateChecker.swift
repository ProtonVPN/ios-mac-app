//
//  StoreKitStateChecker.swift
//  vpncore - Created on 2020-06-23.
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

/// Return a plan ready to be purchased in case user already paid for it with apple but has not yet received the purchase from us.
public protocol StoreKitStateChecker {
    
    /// Check if user started IAP transaction and not finished it yet.
    func isBuyProcessRunning() -> Bool
    
    /// Returns a plan that user has started buying but not finished yet.
    func planBuyStarted() -> AccountPlan?
}

public protocol StoreKitStateCheckerFactory {
    func makeStoreKitStateChecker() -> StoreKitStateChecker
}

public class StoreKitStateCheckerImplementation: StoreKitStateChecker {
    
    public typealias Factory = StoreKitManagerFactory
    private let factory: Factory
    
    private lazy var storeKitManager = factory.makeStoreKitManager()
    
    public init(factory: Factory) {
        self.factory = factory
    }
    
    public func isBuyProcessRunning() -> Bool {
        return !storeKitManager.readyToPurchaseProduct()
    }
        
    public func planBuyStarted() -> AccountPlan? {
        guard let transaction = storeKitManager.currentTransaction() else {
            return nil
        }
        guard let plan = AccountPlan(storeKitProductId: transaction.payment.productIdentifier) else {
            PMLog.ET("Can't find AccountPlan in a transaction")
            return nil
        }
        return plan
    }
    
}
