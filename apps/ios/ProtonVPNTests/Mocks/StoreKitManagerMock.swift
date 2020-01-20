//
//  StoreKitManagerMock.swift
//  ProtonVPN - Created on 14/10/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import vpncore

class StoreKitManagerMock: NSObject, StoreKitManager {
    
    public var callbackSubscribeToPaymentQueue: (() -> Void)?
    public var callbackPurchaseProduct: ((String, () -> Void, (String?) -> Void, (Error) -> Void, () -> Void) -> Void)?
    public var callbackProcessAllTransactions: (() -> Void)?
    public var callbackUpdateAvailableProductsList: (() -> Void)?
    public var isReadyToPurchaseProduct = true
    public var callbackPriceLabelForProduct: ((String) -> (NSDecimalNumber, Locale)?)?
    
    // MARK: StoreKitManager implementation
    
    func subscribeToPaymentQueue() {
        callbackSubscribeToPaymentQueue?()
    }
    func purchaseProduct(withId id: String, refreshHandler: @escaping () -> Void, successCompletion: @escaping (String?) -> Void, errorCompletion: @escaping (Error) -> Void, deferredCompletion: @escaping () -> Void) {
        callbackPurchaseProduct?(id, refreshHandler, successCompletion, errorCompletion, deferredCompletion)
    }
    
    func processAllTransactions() {
        callbackProcessAllTransactions?()
    }
    
    func processAllTransactions(_ finishHandler: (() -> Void)?) {
        callbackProcessAllTransactions?()
    }
    
    func updateAvailableProductsList() {
        callbackUpdateAvailableProductsList?()
    }
    
    func readyToPurchaseProduct() -> Bool {
        return isReadyToPurchaseProduct
    }
    
    func priceLabelForProduct(id: String) -> (NSDecimalNumber, Locale)? {
        return callbackPriceLabelForProduct?(id)
    }
    
}
