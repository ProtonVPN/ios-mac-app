//
//  AlamofireWrapper.swift
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

import Alamofire
import Foundation

struct RequestItem {
    let request: URLRequestConvertible
    let success: ((JSONDictionary) -> Void)
    let failure: ((Error) -> Void)
}

public protocol AlamofireWrapperFactory {
    func makeAlamofireWrapper() -> AlamofireWrapper
}

public protocol AlamofireWrapper: class {
    
    var refreshAccessToken: ((_ success: @escaping (() -> Void), _ failure: @escaping ((Error) -> Void)) -> Void)? { get set }
    
    func getHumanVerificationToken() -> HumanVerificationToken?
    func setHumanVerification(token: HumanVerificationToken?)
    
    func set(alertService: CoreAlertService)
    
    func request(_ request: URLRequestConvertible,
                 success: @escaping (() -> Void),
                 failure: @escaping ((Error) -> Void))
    
    func request(_ request: URLRequestConvertible,
                 success: @escaping ((JSONDictionary) -> Void),
                 failure: @escaping ((Error) -> Void))
    
    func request(_ request: URLRequestConvertible,
                 success: @escaping ((String) -> Void),
                 failure: @escaping ((Error) -> Void))
    
    func upload(_ request: URLRequestConvertible,
                parameters: [String: String],
                files: [String: URL],
                success: @escaping ((JSONDictionary) -> Void),
                failure: @escaping ((Error) -> Void))
}

public class AlamofireWrapperImplementation: AlamofireWrapper {
    
    public typealias Factory = CoreAlertServiceFactory & HumanVerificationAdapterFactory & TrustKitHelperFactory
    
    private var alertService: CoreAlertService?
    private var humanVerificationHandler: HumanVerificationAdapter?
    private var trustKitHelper: TrustKitHelper?
    
    private let requestQueue = DispatchQueue(label: "ch.protonvpn.alamofire")
    private let sessionManager = SessionManager()
    private var accessTokenRequestsQueue = [RequestItem]()
    private var humanVerificationRequestsQueue = [RequestItem]()
    private var fetchingNewAccessToken = false
    private var fetchingNewHumanVerificationToken = false
    
    public var refreshAccessToken: ((_ success: @escaping (() -> Void), _ failure: @escaping ((Error) -> Void)) -> Void)?
    
    private enum ApiResponse {
        case success(JSONDictionary)
        case failure(Error)
    }
    
    public init(factory: Factory? = nil) {
        if let factory = factory {
            self.alertService = factory.makeCoreAlertService()
            self.humanVerificationHandler = factory.makeHumanVerificationAdapter()
            self.trustKitHelper = factory.makeTrustKitHelper()
            sessionManager.adapter = self.humanVerificationHandler
        }
        sessionManager.retrier = GenericRequestRetrier()
        if let trustKitHelper = trustKitHelper {
            sessionManager.delegate.taskDidReceiveChallengeWithCompletion = trustKitHelper.authenticationChallengeTask
        }
    }
    
    public func set(alertService: CoreAlertService) {
        self.alertService = alertService
    }
    
    public func request(_ request: URLRequestConvertible,
                        success: @escaping (() -> Void),
                        failure: @escaping ((Error) -> Void)) {
        let successWrapper: ((JSONDictionary) -> Void) = { (_) in
            success()
        }
        self.request(request, success: successWrapper, failure: failure)
    }
    
    public func request(_ request: URLRequestConvertible,
                        success: @escaping ((JSONDictionary) -> Void),
                        failure: @escaping ((Error) -> Void)) {
        do {
            _ = try request.asURLRequest()
            sessionManager.request(request).responseJSON(queue: requestQueue) { [weak self] response in
                guard let `self` = self else { return }
                
                self.debugLog(response)
                
                switch self.filterDataResponse(response: response) {
                case .success(let json):
                    success(json)
                case .failure(let error):
                    self.received(error: error, forRequest: request, success: success, failure: failure)
                }
            }
        } catch let error {
            PMLog.D("Network request failed with error: \(error)", level: .error)
            failure(error)
        }
    }
    
    public func request(_ request: URLRequestConvertible,
                        success: @escaping ((String) -> Void),
                        failure: @escaping ((Error) -> Void)) {
        do {
            _ = try request.asURLRequest()
            sessionManager.request(request).responseString(queue: requestQueue) { response in
                if response.result.isSuccess, let result = response.result.value {
                    success(result)
                }
            }
        } catch let error {
            PMLog.D("Network request failed with error: \(error)", level: .error)
            failure(error)
        }
    }
    
    public func upload(_ request: URLRequestConvertible,
                       parameters: [String: String],
                       files: [String: URL],
                       success: @escaping ((JSONDictionary) -> Void),
                       failure: @escaping ((Error) -> Void)) {
        
        sessionManager.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: .utf8)!, withName: key)
            }
            files.forEach({ (name, file) in
                multipartFormData.append(file, withName: name)
            })
        },
                              with: request,
                              encodingCompletion: {encodingResult in
                                switch encodingResult {
                                case .success(let uploadRequest, _, _):
                                    uploadRequest.responseJSON { response in
                                        switch self.filterDataResponse(response: response) {
                                        case .success(let json):
                                            success(json)
                                        case .failure(let error):
                                            self.received(error: error, forRequest: request, success: success, failure: failure)
                                        }
                                    }
                                case .failure(let encodingError):
                                    PMLog.D("File encoding error: \(encodingError)", level: .error)
                                    failure(encodingError)
                                }
        })
    }
        
    public func getHumanVerificationToken() -> HumanVerificationToken? {
        return self.humanVerificationHandler?.token
    }
    
    public func setHumanVerification(token: HumanVerificationToken?) {
        self.humanVerificationHandler?.token = token
    }
    
    // MARK: - Private functions
    
    private func filterDataResponse(response: DataResponse<Any>) -> ApiResponse {
        if response.result.isSuccess, let statusCode = response.response?.statusCode, let json = response.result.value as? JSONDictionary, let code = json.int(key: "Code") {
            if statusCode == 200 && code == 1000 {
                return .success(json)
            } else if code == ApiErrorCode.humanVerificationRequired {
                return .failure(ApiError(httpStatusCode: statusCode, code: code, localizedDescription: json.string("Error"), responseBody: json))
            } else {
                return .failure(ApiError(httpStatusCode: statusCode, code: code, localizedDescription: json.string("Error")))
            }
        } else if response.result.isFailure, let error = response.error as NSError? {
            return .failure(NetworkError.error(forCode: error.code))
        } else {
            return .failure(ApiError.uknownError)
        }
    }
    
    /// Log error and try reconnecting or call failure closure
    private func received(error: Error, forRequest request: URLRequestConvertible, success: @escaping ((JSONDictionary) -> Void), failure: @escaping ((Error) -> Void)) {
        guard let apiError = error as? ApiError else {
            PMLog.D("Network request failed with error: \(error)", level: .error)
            failure(error)
            return
        }
        
        if apiError.httpStatusCode == HttpStatusCode.invalidAccessToken {
            let requestItem = RequestItem(request: request, success: success, failure: failure)
            self.accessTokenRequestsQueue.append(requestItem)
            if !self.fetchingNewAccessToken {
                PMLog.D("Network request failed with error: \(error)", level: .error)
                self.fetchNewAccessToken(failure)
            } // else ignore error, since we are in the process of getting a new refresh token
        } else {
            switch apiError.code {
            case ApiErrorCode.appVersionBad, ApiErrorCode.apiVersionBad:
                self.alertService?.push(alert: AppUpdateRequiredAlert(apiError))
            case ApiErrorCode.noActiveSubscription:
                failure(apiError) // don't write these errors to the logs
                
            case ApiErrorCode.humanVerificationRequired:
                let requestItem = RequestItem(request: request, success: success, failure: failure)
                self.humanVerificationRequestsQueue.append(requestItem)
                if !self.fetchingNewHumanVerificationToken {
                    PMLog.D("Human verification request received", level: .warn)
                    self.fetchNewHumanVerificationToken(error: apiError, failure: failure)
                } // else ignore error, since we are in the process of getting a human verification token
                
            default:
                PMLog.D("Network request failed with error: \(apiError)", level: .error)
                failure(apiError)
            }
        }
    }
    
    // MARK: Access token
        
    private func fetchNewAccessToken(_ failure: @escaping (Error) -> Void) {
        fetchingNewAccessToken = true
        
        refreshAccessToken?({ [weak self] in
            guard let `self` = self else { return }
            self.fetchingNewAccessToken = false
            self.retryRequestsWithNewAccessToken()
        }, { [weak self] (error) in
            guard let `self` = self else { return }
            PMLog.D("Refresh access token failed with error: \(error)")
            self.fetchingNewAccessToken = false
            self.failRequestsWithoutNewAccessToken(error)
            
            guard let apiError = error as? ApiError else {
                failure(error)
                return
            }
            
            switch (apiError.httpStatusCode, apiError.code) {
            case (HttpStatusCode.tooManyRequests, _):
                failure(error)
            case (400...499, _):
                PMLog.ET("User logged out due to refresh access token failure with error: \(error)")
                DispatchQueue.main.async { [weak self] in
                    guard let `self` = self else { return }
                    self.alertService?.push(alert: RefreshTokenExpiredAlert())
                }
            default:
                failure(error)
            }
        })
    }
    
    private func retryRequestsWithNewAccessToken() {
        accessTokenRequestsQueue.forEach { requestItem in
            completedRequestWithNewAccessToken(requestItem.request)
            request(requestItem.request, success: requestItem.success, failure: requestItem.failure)
        }
    }
    
    private func failRequestsWithoutNewAccessToken(_ error: Error) {
        accessTokenRequestsQueue.removeAll()
        // We don't call failure callbacks because user will be logged out and no more additional errors should be shown
    }
    
    private func completedRequestWithNewAccessToken(_ request: URLRequestConvertible) {
        if let index = accessTokenRequestsQueue.index(where: { $0.request.urlRequest! == request.urlRequest! }) {
            accessTokenRequestsQueue.remove(at: index)
        }
    }
    
    // MARK: Human verification
    
    private func fetchNewHumanVerificationToken(error: ApiError, failure: @escaping (Error) -> Void) {
        guard let alertService = alertService else {
            failure(error)
            return
        }
        guard let verificationMethods = VerificationMethods.fromApiError(apiError: error) else {
            failure(error)
            return
        }
        fetchingNewHumanVerificationToken = true
        
        let alert = UserVerificationAlert(verificationMethods: verificationMethods, message: error.localizedDescription, success: {[weak self] token in
            guard let `self` = self else { return }
            self.humanVerificationHandler?.token = token
            self.fetchingNewHumanVerificationToken = false
            self.retryRequestsAfterHumanVerification()
            
        }, failure: {[weak self] (error) in
            guard let `self` = self else { return }
            PMLog.ET("Getting human verification token failed with error: \(error)")
            self.fetchingNewHumanVerificationToken = false
            self.failRequestsAfterHumanVerification(error)
            
            switch (error as NSError).code {
            case NSURLErrorTimedOut,
                    NSURLErrorNotConnectedToInternet,
                    NSURLErrorNetworkConnectionLost,
                    NSURLErrorCannotConnectToHost,
                    HttpStatusCode.serviceUnavailable,
                    ApiErrorCode.apiOffline:
                failure(error)
            default:
                failure(UserError.failedHumanValidation)
            }
        })
        alertService.push(alert: alert)
    }
    
    private func retryRequestsAfterHumanVerification() {
        humanVerificationRequestsQueue.forEach { requestItem in
            completedRequestAfterHumanVerification(requestItem.request)
            request(requestItem.request, success: requestItem.success, failure: requestItem.failure)
        }
    }
    
    private func failRequestsAfterHumanVerification(_ error: Error) {
        humanVerificationRequestsQueue.forEach { requestItem in
            completedRequestAfterHumanVerification(requestItem.request)
            requestItem.failure(error)
        }
    }
    
    private func completedRequestAfterHumanVerification(_ request: URLRequestConvertible) {
        if let index = humanVerificationRequestsQueue.index(where: { $0.request.urlRequest! == request.urlRequest! }) {
            humanVerificationRequestsQueue.remove(at: index)
        }
    }
    
    // MARK: Debugging
    
    private func debugLog(_ response: DataResponse<Any>) {
        #if DEBUG
        debugPrint("======================================= start =======================================")
        debugPrint(response.request?.url as Any)
        debugPrint(response.request?.allHTTPHeaderFields as Any)
        if let data = response.request?.httpBody {
            debugPrint(String(data: data, encoding: .utf8) as Any)
        }
        debugPrint("------------------------------------- response -------------------------------------")
        debugPrint(response.response?.statusCode as Any)
        debugPrint(response.result.value as Any)
        debugPrint("======================================= end =======================================")
        #endif
    }
    
}
