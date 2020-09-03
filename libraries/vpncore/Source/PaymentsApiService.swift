//
//  PaymentsApiService.swift
//  vpncore - Created on 26.06.19.
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

import Foundation

public typealias PlanPropsCallback = GenericCallback<ServicePlansProperties>
public typealias PaymentTokenCallback = GenericCallback<PaymentToken>
public typealias PaymentTokenStatusCallback = GenericCallback<PaymentTokenStatusResponse>
public typealias SubscriptionCallback = GenericCallback<Subscription>
public typealias OptionalSubCallback = GenericCallback<Subscription?>
public typealias PaymentsMethodCallback = GenericCallback<[PaymentMethod]?>
public typealias OptionalPlanDetailsCallback = GenericCallback<ServicePlanDetails?>
public typealias PlansDetailsCallback = GenericCallback<[ServicePlanDetails]>
public typealias BoolCallback = GenericCallback<Bool>
public typealias ValidateSubscriptionResponseCallback = GenericCallback<ValidateSubscriptionResponse>

public protocol PaymentsApiService {
    func servicePlans(success: @escaping PlanPropsCallback, failure: @escaping ErrorCallback)
    func applyCredit(forPlanId planId: String, success: @escaping SubscriptionCallback, failure: @escaping ErrorCallback)
    func credit(amount: Int, receipt: PaymentAction, success: @escaping SuccessCallback, failure: @escaping ErrorCallback)
    func methods(success: @escaping PaymentsMethodCallback, failure: @escaping ErrorCallback)
    func subscription(success: @escaping OptionalSubCallback, failure: @escaping ErrorCallback)
    func createPaymentToken(amount: Int, receipt: String, success: @escaping PaymentTokenCallback, failure: @escaping ErrorCallback)
    /// Get current token status
    func getPaymentTokenStatus(token: PaymentToken, success: @escaping PaymentTokenStatusCallback, failure: @escaping ErrorCallback)
    func buyPlan(id planId: String, price: Int, paymentToken: PaymentAction, success: @escaping SubscriptionCallback, failure: @escaping ErrorCallback)
    /// Get the amount needed to buy a plan
    func validateSubscription(id planId: String, success: @escaping ValidateSubscriptionResponseCallback, failure: @escaping ErrorCallback)
}

public protocol PaymentsApiServiceFactory {
    func makePaymentsApiService() -> PaymentsApiService
}

public class PaymentsApiServiceImplementation: PaymentsApiService {
    
    private let alamofireWrapper: AlamofireWrapper

    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
    }
    
    // makes calls asynchronously and returns results if successful else error if any issues
    public func servicePlans(success: @escaping PlanPropsCallback, failure: @escaping ErrorCallback) {
        let dispatchGroup = DispatchGroup()
        
        var _available: Bool?
        var _plansDetails: [ServicePlanDetails]?
        var defaultPlanDetails: ServicePlanDetails?
        
        var _error: Error?
        
        let failureClosure: ErrorCallback = { error in
            _error = error
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        status(success: { (available) in
            _available = available
            dispatchGroup.leave()
        }, failure: failureClosure)
        
        dispatchGroup.enter()
        plans(success: { (planDetails) in
            _plansDetails = planDetails
            dispatchGroup.leave()
        }, failure: failureClosure)
        
        dispatchGroup.enter()
        defaultPlan(success: { (defaultPlanDeets) in
            defaultPlanDetails = defaultPlanDeets
            dispatchGroup.leave()
        }, failure: failureClosure)
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            if let available = _available, let plansDetails = _plansDetails {
                success(ServicePlansProperties(available: available, plansDetails: plansDetails, defaultPlanDetails: defaultPlanDetails))
            } else if let error = _error {
                failure(error)
            } else {
                failure(ParseError.subscriptionsParse)
            }
        }
    }
    
    func status(success: @escaping BoolCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { json in
            success(json.bool(key: "Apple", or: false))
        }
        alamofireWrapper.request(PaymentsStatusRequest(), success: successWrapper, failure: failure)
    }
    
    public func methods(success: @escaping PaymentsMethodCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { json in
            do {
                let data = try JSONSerialization.data(withJSONObject: json["PaymentMethods"] as Any, options: [])
                let decoder = JSONDecoder()
                // this strategy is decapitalizing first letter of response's labels to get appropriate name of the ServicePlanDetails object
                decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
                let methods = try decoder.decode(Array<PaymentMethod>.self, from: data)
                success(methods)
            } catch let error {
                PMLog.D("Failed to parse PaymentMethods: \(error.localizedDescription)", level: .error)
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsMethodsRequest(), success: successWrapper, failure: failure)
    }
    
    public func subscription(success: @escaping OptionalSubCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { [weak self] json in
            do {
                guard let `self` = self else { return }
                success(try self.subscriptionResponse(json))
            } catch let error {
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsSubscriptionRequest(), success: successWrapper, failure: failure)
    }
    
    func defaultPlan(success: @escaping OptionalPlanDetailsCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { [weak self] json in
            do {
                guard let `self` = self else { return }
                let servicePlans = try self.plansResponse(json)
                let defaultPlan = servicePlans.filter({ (details) -> Bool in
                    return details.title.contains("ProtonVPN Free")
                }).first
                success(defaultPlan)
            } catch let error {
                PMLog.D("Failed to parse ServicePlans: \(error.localizedDescription)", level: .error)
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsDefaultPlanRequest(), success: successWrapper, failure: failure)
    }
    
    func plans(success: @escaping PlansDetailsCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { [weak self] json in
            do {
                guard let `self` = self else { return }
                let plans = try self.plansResponse(json)
                success(plans)
            } catch let error {
                PMLog.D("Failed to parse ServicePlans: \(error.localizedDescription)", level: .error)
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsPlansRequest(), success: successWrapper, failure: failure)
    }
    
    public func credit(amount: Int, receipt: PaymentAction, success: @escaping SuccessCallback, failure: @escaping ErrorCallback) {
        alamofireWrapper.request(PaymentsCreditRequest(amount, payment: receipt), success: success, failure: failure)
    }
    
    public func applyCredit(forPlanId planId: String, success: @escaping SubscriptionCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { [weak self] json in
            do {
                guard let `self` = self else { return }
                guard let code = json["Code"] as? Int, code == 1000 else {
                    throw ParseError.subscriptionsParse
                }
                let subscription = try self.subscriptionResponse(json)
                success(subscription)
            } catch let error {
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsApplyCreditRequest(planId), success: successWrapper, failure: failure)
    }
    
    public func createPaymentToken(amount: Int, receipt: String, success: @escaping PaymentTokenCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { json in
            do {
                let data = try JSONSerialization.data(withJSONObject: json as Any, options: [])
                let decoder = JSONDecoder()
                // this strategy is decapitalizing first letter of response's labels to get appropriate name of the ServicePlanDetails object
                decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
                let token = try decoder.decode(PaymentToken.self, from: data)
                
                success(token)
            } catch let error {
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsTokenRequest(amount, receipt: receipt), success: successWrapper, failure: failure)
    }
    
    public func getPaymentTokenStatus(token: PaymentToken, success: @escaping PaymentTokenStatusCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { json in
            do {
                let data = try JSONSerialization.data(withJSONObject: json as Any, options: [])
                let decoder = JSONDecoder()
                // this strategy is decapitalizing first letter of response's labels to get appropriate name of the ServicePlanDetails object
                decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
                let token = try decoder.decode(PaymentTokenStatusResponse.self, from: data)
                
                success(token)
            } catch let error {
                failure(error)
            }
        }
        alamofireWrapper.request(GetPaymentsTokenRequest(token), success: successWrapper, failure: failure)
    }
    
    public func buyPlan(id planId: String, price: Int, paymentToken: PaymentAction, success: @escaping SubscriptionCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { [weak self] json in
            do {
                guard let `self` = self else { return }
                guard let code = json["Code"] as? Int, code == 1000 else {
                    throw ParseError.subscriptionsParse
                }
                let subscription = try self.subscriptionResponse(json)
                success(subscription)
            } catch let error {
                failure(error)
            }
        }
        
        self.validateSubscription(id: planId, success: {response in
            self.alamofireWrapper.request(BuyPlanRequest(planId, amount: response.amountDue, payment: paymentToken), success: successWrapper, failure: failure)
        }, failure: {error in
            self.alamofireWrapper.request(BuyPlanRequest(planId, amount: price, payment: paymentToken), success: successWrapper, failure: failure)
        })
    }
    
    public func validateSubscription(id planId: String, success: @escaping ValidateSubscriptionResponseCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { json in
            do {
                let data = try JSONSerialization.data(withJSONObject: json as Any, options: [])
                let decoder = JSONDecoder()
                // this strategy is decapitalizing first letter of response's labels to get appropriate name of the ServicePlanDetails object
                decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
                let validateSubscriptionResponse = try decoder.decode(ValidateSubscriptionResponse.self, from: data)
                
                success(validateSubscriptionResponse)
            } catch let error {
                failure(error)
            }
        }
        alamofireWrapper.request(ValidateSubscriptionRequest(planId), success: successWrapper, failure: failure)
    }
    
    // MARK: - Private
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
    
    private func decapitalizeFirstLetter(_ path: [CodingKey]) -> CodingKey {
        let original: String = path.last!.stringValue
        let uncapitalized = original.prefix(1).lowercased() + original.dropFirst()
        return Key(stringValue: uncapitalized) ?? path.last!
    }
    
    private func plansResponse(_ json: JSONDictionary) throws -> [ServicePlanDetails] {
        let data = try JSONSerialization.data(withJSONObject: json["Plans"] as Any, options: [])
        let decoder = JSONDecoder()
        // this strategy is decapitalizing first letter of response's labels to get appropriate name of the ServicePlanDetails object
        decoder.keyDecodingStrategy = .custom(self.decapitalizeFirstLetter)
        let plans = try decoder.decode(Array<ServicePlanDetails>.self, from: data)
        return plans
    }
    
    private func subscriptionResponse(_ json: JSONDictionary) throws -> Subscription {
        guard let json = json["Subscription"] as? JSONDictionary,
            let startRaw = json["PeriodStart"] as? Int,
            let endRaw = json["PeriodEnd"] as? Int else {
                throw ParseError.subscriptionsParse
        }
        let couponCode = json["PeriodEnd"] as? String
        let cycle = json["Cycle"] as? Int
        
        let plans = try self.plansResponse(json)
        let start = Date(timeIntervalSince1970: Double(startRaw))
        let end = Date(timeIntervalSince1970: Double(endRaw))
        let subscription = Subscription(start: start, end: end, planDetails: plans, paymentMethods: nil, couponCode: couponCode, cycle: cycle)
        return subscription
    }
}
