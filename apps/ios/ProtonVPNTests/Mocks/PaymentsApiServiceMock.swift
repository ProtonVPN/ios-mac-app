//
//  PaymentsApiServiceMock.swift
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

import Foundation
import vpncore

class PaymentsApiServiceMock: PaymentsApiService {
    
    public var callbackServicePlans: ((((ServicePlansProperties) -> Void), ((Error) -> Void)) -> Void)?
    public var callbackApplyCredit: ((String, ((Subscription) -> Void), ((Error) -> Void)) -> Void)?
    public var callbackCredit: ((Int, String, (() -> Void), ((Error) -> Void)) -> Void)?
    public var callbackPostReceipt: ((Int, String, String, ((Subscription) -> Void), ((Error) -> Void)) -> Void)?
    public var callbackVerifyPayment: ((Int, String, ((String) -> Void), ((Error) -> Void)) -> Void)?
    public var callbackMethods: (((([PaymentMethod]?) -> Void), ((Error) -> Void)) -> Void)?
    public var callbackSubscription: ((((Subscription?) -> Void), ((Error) -> Void)) -> Void)?
    
    // MARK: PaymentsApiService implementation
    
    func servicePlans(success: @escaping ((ServicePlansProperties) -> Void), failure: @escaping ((Error) -> Void)) {
        callbackServicePlans?(success, failure)
    }
    
    func applyCredit(forPlanId planId: String, success: @escaping ((Subscription) -> Void), failure: @escaping ((Error) -> Void)) {
        callbackApplyCredit?(planId, success, failure)
    }
    
    func credit(amount: Int, receipt: String, success: @escaping (() -> Void), failure: @escaping ((Error) -> Void)) {
        callbackCredit?(amount, receipt, success, failure)
    }
    
    func postReceipt(amount: Int, receipt: String, planId: String, success: @escaping ((Subscription) -> Void), failure: @escaping ((Error) -> Void)) {
        callbackPostReceipt?(amount, receipt, planId, success, failure)
    }
    
    func verifyPayment(amount: Int, receipt: String, success: @escaping ((String) -> Void), failure: @escaping ((Error) -> Void)) {
        callbackVerifyPayment?(amount, receipt, success, failure)
    }
    
    func methods(success: @escaping (([PaymentMethod]?) -> Void), failure: @escaping ((Error) -> Void)) {
        callbackMethods?(success, failure)
    }
    
    func subscription(success: @escaping ((Subscription?) -> Void), failure: @escaping ((Error) -> Void)) {
        callbackSubscription?(success, failure)
    }
    
}
