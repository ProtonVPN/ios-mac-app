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

public typealias SuccessCallback = (() -> Void)
public typealias GenericCallback<T> = ((T) -> Void)
public typealias JSONCallback = GenericCallback<JSONDictionary>
public typealias StringCallback = GenericCallback<String>
public typealias ErrorCallback = GenericCallback<Error>

public protocol AlamofireWrapperFactory {
    func makeAlamofireWrapper() -> AlamofireWrapper
}

public protocol AppSpecificRequestAdapterFatory {
    func makeAppSpecificRequestAdapter() -> RequestAdapter?
}

public protocol AlamofireWrapper: class {
    
    func getHumanVerificationToken() -> HumanVerificationToken?
    func setHumanVerification(token: HumanVerificationToken?)
    
    func set(alertService: CoreAlertService)
    
    func request(_ request: URLRequestConvertible, success: @escaping SuccessCallback, failure: @escaping ErrorCallback)
    func request(_ request: URLRequestConvertible, success: @escaping JSONCallback, failure: @escaping ErrorCallback)
    func request(_ request: URLRequestConvertible, success: @escaping StringCallback, failure: @escaping ErrorCallback)
    func upload(_ request: URLRequestConvertible, parameters: [String: String], files: [String: URL], success: @escaping JSONCallback, failure: @escaping ErrorCallback)
    
    func markAsFailedTLS(request: URLRequest)
}

public class AlamofireWrapperImplementation: NSObject, AlamofireWrapper {
    
    public typealias Factory = CoreAlertServiceFactory & HumanVerificationAdapterFactory & TrustKitHelperFactory & PropertiesManagerFactory & ProtonAPIAuthenticatorFactory & AppSpecificRequestAdapterFatory
    private var factory: Factory?
    
    private var alertService: CoreAlertService?
    private var trustKitHelper: TrustKitHelper?
    private var tlsFailedRequests = [URLRequest]()

    private var humanVerificationHandler: HumanVerificationAdapter?
    
    private lazy var humanVerificationHelper = HumanVerificationHelper(self, alertService: self.alertService)
    
    public func markAsFailedTLS(request: URLRequest) {
        tlsFailedRequests.append(request)
    }
    
    private let requestQueue = DispatchQueue(label: "ch.protonvpn.alamofire")
    private var session: Session!
    private var propertiesManager: PropertiesManagerProtocol?
        
    public init(factory: Factory? = nil) {
        super.init()
        
        self.factory = factory
        
        var adapters: [RequestAdapter] = []
        let retriers: [RequestRetrier] = [ GenericRequestRetrier() ]
        
        if let factory = factory {
            let humanVerificationAdapter = factory.makeHumanVerificationAdapter()
            self.humanVerificationHandler = humanVerificationAdapter
            self.alertService = factory.makeCoreAlertService()
            self.trustKitHelper = factory.makeTrustKitHelper()
            self.propertiesManager = factory.makePropertiesManager()
            adapters.append(humanVerificationAdapter)

            if let appSpecificRequestAdapter = factory.makeAppSpecificRequestAdapter() {
                adapters.append(appSpecificRequestAdapter)
            }
        }
        
        let interceptor = Interceptor(
            adapters: adapters,
            retriers: retriers
        )
        
        self.session = Session(
            delegate: self.trustKitHelper ?? SessionDelegate(),
            interceptor: interceptor,
            eventMonitors: [APILogger()]
        )
        
        NotificationCenter.default.addObserver(self, selector: #selector(authKeychainCleared), name: AuthKeychain.clearNotification, object: nil)
    }
    
    private var authInterceptor: AuthenticationInterceptor<ProtonAPIAuthenticator>?
    
    private func authInterceptor(for request: URLRequestConvertible) -> AuthenticationInterceptor<ProtonAPIAuthenticator>? {
        // No need 
        guard !(request is AuthRefreshRequest) else {
            return nil
        }
        guard let factory = factory else {
            return nil
        }
        if authInterceptor == nil {
            guard let authCredentials = AuthKeychain.fetch() else {
                return nil
            }
            authInterceptor = AuthenticationInterceptor(authenticator: factory.makeProtonAPIAuthenticator(), credential: authCredentials)
        }
        return authInterceptor
    }
    
    // MARK: - Request

    public func request(_ request: URLRequestConvertible, success: @escaping SuccessCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { _ in
            self.setHumanVerification(token: nil) // reset token to prepare for the next request
            success()
        }
        self.request(request, success: successWrapper, failure: failure)
    }
    
    public func request(_ request: URLRequestConvertible, success: @escaping JSONCallback, failure: @escaping ErrorCallback) {
        guard check(request, failure: failure) else { return }
                
        session.request(request, interceptor: self.authInterceptor(for: request)).validated.responseJSON(queue: requestQueue) { [weak self] response in
            response.debugLog()
            
            if let error = self?.failsTLS(request) {
                failure(error)
                return
            }
            
            switch response.mapApiResponse {
            case .success(let json):
                self?.setHumanVerification(token: nil) // reset token to prepare for the next request
                success(json)
            case .failure(let error):
                self?.didReceiveError(request, error: error, success: success, failure: failure)
            }
        }
    }
    
    public func request(_ request: URLRequestConvertible, success: @escaping StringCallback, failure: @escaping ErrorCallback) {
        guard check(request, failure: failure) else { return }
        session.request(request, interceptor: self.authInterceptor(for: request)).validated.responseString(queue: requestQueue) { response in
            if let result = try? response.result.get() {
                self.setHumanVerification(token: nil) // reset token to prepare for the next request
                success(result)
            }
        }
    }
    
    // MARK: - Upload
    
    public func upload(_ request: URLRequestConvertible, parameters: [String: String], files: [String: URL], success: @escaping JSONCallback, failure: @escaping ErrorCallback) {
        
        session.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: .utf8)!, withName: key)
            }
            files.forEach({ (name, file) in
                multipartFormData.append(file, withName: name)
            })
        }, with: request, interceptor: self.authInterceptor(for: request)).validated.responseJSON {[weak self] response in
            
            if let error = self?.failsTLS(request) {
                failure(error)
                return
            }
            
            switch response.mapApiResponse {
            case .success(let json):
                success(json)
            case .failure(let error):
                self?.didReceiveError(request, error: error, success: success, failure: failure)
            }
        }
    }
    
    public func set(alertService: CoreAlertService) {
        self.alertService = alertService
    }
    
    public func getHumanVerificationToken() -> HumanVerificationToken? {
        return self.humanVerificationHandler?.token
    }
    
    public func setHumanVerification(token: HumanVerificationToken?) {
        self.humanVerificationHandler?.token = token
    }
    
    // MARK: - Private functions
    
    private func failsTLS( _ request: URLRequestConvertible ) -> Error? {
        if let url = try? request.asURLRequest().url,
            let index = tlsFailedRequests.firstIndex(where: { $0.url?.absoluteString == url?.absoluteString }) {
            tlsFailedRequests.remove(at: index)
            return NetworkError.error(forCode: NetworkErrorCode.tls)
        }
        return nil
    }
    
    private func check( _ request: URLRequestConvertible, failure: ErrorCallback) -> Bool {
        do {
            _ = try request.asURLRequest()
            return true
        } catch let error {
            PMLog.D("Network request failed with error: \(error)", level: .error)
            failure(error)
            return false
        }
    }
}

extension AlamofireWrapperImplementation {
    fileprivate func didReceiveError(_ request: URLRequestConvertible, error: Error, success: @escaping JSONCallback, failure: @escaping ErrorCallback) {
        guard let apiError = error as? ApiError else { return failure(error) }
        switch apiError.code {
        case ApiErrorCode.appVersionBad, ApiErrorCode.apiVersionBad:
            self.alertService?.push(alert: AppUpdateRequiredAlert(apiError))
            return
        case ApiErrorCode.humanVerificationRequired:
            humanVerificationHelper.requestHumanVerification(request, apiError: apiError, success: success, failure: failure)
            return
        case ApiErrorCode.noActiveSubscription:
            failure(apiError) // don't write these errors to the logs
            return
        default:
            break
        }
        
        if request is AuthRefreshRequest {
            return didReceiveTokenRefreshError(request, error: error, success: success, failure: failure)
        }
        
        PMLog.D("Network request failed with error: \(apiError)", level: .error)
        failure(apiError)
    }
    
    private func didReceiveTokenRefreshError(_ request: URLRequestConvertible, error: Error, success: @escaping JSONCallback, failure: @escaping ErrorCallback) {
        guard let apiError = error as? ApiError else { return failure(error) }
        
        switch apiError.httpStatusCode {
        case HttpStatusCode.invalidRefreshToken, HttpStatusCode.badRequest:
            PMLog.ET("User logged out due to refresh token failure with error: \(error)")
            DispatchQueue.main.async { [weak self] in
                guard let alertService = self?.alertService else { return }
                alertService.push(alert: RefreshTokenExpiredAlert())
            }
            failure(apiError)
            return
            
        default:
            PMLog.D("Network request failed with error: \(apiError)", level: .error)
            failure(apiError)
        }
    }
    
    @objc func authKeychainCleared() {
        authInterceptor = nil
    }
    
}
