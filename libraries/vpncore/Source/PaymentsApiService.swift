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

public protocol PaymentsApiService {
    func servicePlans(success: @escaping ((ServicePlansProperties) -> Void), failure: @escaping ((Error) -> Void))
    func applyCredit(forPlanId planId: String, success: @escaping ((Subscription) -> Void), failure: @escaping ((Error) -> Void))
    func credit(amount: Int, receipt: String, success: @escaping (() -> Void), failure: @escaping ((Error) -> Void))
    func postReceipt(amount: Int, receipt: String, planId: String, success: @escaping ((Subscription) -> Void), failure: @escaping ((Error) -> Void))
    func verifyPayment(amount: Int, receipt: String, success: @escaping ((String) -> Void), failure: @escaping ((Error) -> Void))
    func methods(success: @escaping (([PaymentMethod]?) -> Void), failure: @escaping ((Error) -> Void))
    func subscription(success: @escaping ((Subscription?) -> Void), failure: @escaping ((Error) -> Void))
}

public struct ServicePlansProperties {
    
    public let available: Bool
    public let plansDetails: [ServicePlanDetails]
    public let defaultPlanDetails: ServicePlanDetails?
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
    public func servicePlans(success: @escaping ((ServicePlansProperties) -> Void), failure: @escaping ((Error) -> Void)) {
        let dispatchGroup = DispatchGroup()
        
        var _available: Bool?
        var _plansDetails: [ServicePlanDetails]?
        var defaultPlanDetails: ServicePlanDetails?
        
        var _error: Error?
        
        let failureClosure: (Error) -> Void = { error in
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
    
    func status(success: @escaping ((Bool) -> Void),
                failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { json in
            success(json.bool(key: "Apple", or: false))
        }
        alamofireWrapper.request(PaymentsRouter.status, success: successWrapper, failure: failure)
    }
    
    public func methods(success: @escaping (([PaymentMethod]?) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { json in
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
        alamofireWrapper.request(PaymentsRouter.methods, success: successWrapper, failure: failure)
    }
    
    public func subscription(success: @escaping ((Subscription?) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { [weak self] json in
            do {
                guard let `self` = self else { return }
                success(try self.subscriptionResponse(json))
            } catch let error {
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsRouter.subscription, success: successWrapper, failure: failure)
    }
    
    func defaultPlan(success: @escaping ((ServicePlanDetails?) -> Void),
                     failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { [weak self] json in
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
        alamofireWrapper.request(PaymentsRouter.defaultPlan, success: successWrapper, failure: failure)
    }
    
    func plans(success: @escaping (([ServicePlanDetails]) -> Void),
               failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { [weak self] json in
            do {
                guard let `self` = self else { return }
                let plans = try self.plansResponse(json)
                success(plans)
            } catch let error {
                PMLog.D("Failed to parse ServicePlans: \(error.localizedDescription)", level: .error)
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsRouter.plans, success: successWrapper, failure: failure)
    }
    
    public func credit(amount: Int, receipt: String, success: @escaping (() -> Void), failure: @escaping ((Error) -> Void)) {
        alamofireWrapper.request(PaymentsRouter.credit(amount: amount, receipt: receipt), success: success, failure: failure)
    }
    
    public func postReceipt(amount: Int, receipt: String, planId: String, success: @escaping ((Subscription) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { [weak self] json in
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
        alamofireWrapper.request(PaymentsRouter.receipt(amount: amount, receipt: receipt, planId: planId), success: successWrapper, failure: failure)
    }
    
    public func applyCredit(forPlanId planId: String, success: @escaping ((Subscription) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { [weak self] json in
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
        alamofireWrapper.request(PaymentsRouter.applyCredit(planId: planId), success: successWrapper, failure: failure)
    }
    
    public func verifyPayment(amount: Int, receipt: String, success: @escaping ((String) -> Void), failure: @escaping ((Error) -> Void)) {
        
        let successWrapper: (JSONDictionary) -> Void = { json in
            do {
                guard let code = json["Code"] as? Int, code == 1000, let verificationCode = json["VerifyCode"] as? String else {
                    throw ParseError.paymentVerificationParse
                }
                success(verificationCode)
            } catch let error {
                failure(error)
            }
        }
        alamofireWrapper.request(PaymentsRouter.verify(amount: amount, receipt: receipt), success: successWrapper, failure: failure)
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
        
        let plans = try self.plansResponse(json)
        let start = Date(timeIntervalSince1970: Double(startRaw))
        let end = Date(timeIntervalSince1970: Double(endRaw))
        let subscription = Subscription(start: start, end: end, planDetails: plans, paymentMethods: nil)
        return subscription
    }
}
