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

public protocol AlamofireWrapper: class {
    
    var refreshAccessToken: ((_ success: @escaping (() -> Void), _ failure: @escaping ((Error) -> Void)) -> Void)? { get set }
    
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
    
    public typealias Factory = CoreAlertServiceFactory & HumanVerificationAdapterFactory & TrustKitHelperFactory & PropertiesManagerFactory
    
    private var alertService: CoreAlertService?
    private var trustKitHelper: TrustKitHelper?
    private var tlsFailedRequests = [URLRequest]()

    private var humanVerificationHandler: HumanVerificationAdapter?
    
    private lazy var humanVerificationHelper = HumanVerificationHelper(self, alertService: self.alertService)
    private lazy var accessTokenHelper = AccessRequestHelper(self, alertService: self.alertService)
    
    public func markAsFailedTLS(request: URLRequest) {
        tlsFailedRequests.append(request)
    }
    
    private let requestQueue = DispatchQueue(label: "ch.protonvpn.alamofire")
    private var session: Session!
    private var propertiesManager: PropertiesManagerProtocol?
    
    public var refreshAccessToken: ((_ success: @escaping SuccessCallback, _ failure: @escaping ErrorCallback) -> Void)?
    
    public init(factory: Factory? = nil) {
        super.init()
        
        var adapters: [RequestAdapter] = []
        
        if let factory = factory {
            let humanVerificationAdapter = factory.makeHumanVerificationAdapter()
            self.humanVerificationHandler = humanVerificationAdapter
            self.alertService = factory.makeCoreAlertService()
            self.trustKitHelper = factory.makeTrustKitHelper()
            self.propertiesManager = factory.makePropertiesManager()
            adapters.append(humanVerificationAdapter)
        }
        
        let interceptor = Interceptor(
            adapters: adapters,
            retriers: [ GenericRequestRetrier() ]
        )
        
        self.session = Session(
            delegate: self.trustKitHelper ?? SessionDelegate(),
            interceptor: interceptor,
            eventMonitors: [APILogger()]
        )
    }
    
    // MARK: - Request

    public func request(_ request: URLRequestConvertible, success: @escaping SuccessCallback, failure: @escaping ErrorCallback) {
        let successWrapper: JSONCallback = { _ in success() }
        self.request(request, success: successWrapper, failure: failure)
    }
    
    public func request(_ request: URLRequestConvertible, success: @escaping JSONCallback, failure: @escaping ErrorCallback) {
        guard check(request, failure: failure) else { return }
        session.request(request).validated.responseJSON(queue: requestQueue) { [weak self] response in
            response.debugLog()
            
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
    
    public func request(_ request: URLRequestConvertible, success: @escaping StringCallback, failure: @escaping ErrorCallback) {
        guard check(request, failure: failure) else { return }
        session.request(request).validated.responseString(queue: requestQueue) { response in
            if let result = try? response.result.get() {
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
        }, with: request).validated.responseJSON {[weak self] response in
            
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
    fileprivate func didReceiveError( _ request: URLRequestConvertible, error: Error, success: @escaping JSONCallback, failure: @escaping ErrorCallback ) {
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
        
        switch (error as NSError).code {
        case HttpStatusCode.invalidAccessToken :
            accessTokenHelper.requestAccessTokenVerification(request, apiError: apiError, success: success, failure: failure)
        default:
            PMLog.D("Network request failed with error: \(apiError)", level: .error)
            failure(apiError)
        }
    }
}
