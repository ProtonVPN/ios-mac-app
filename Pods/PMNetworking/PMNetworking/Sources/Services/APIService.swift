//
//  APIService.swift
//  Pods
//
//  Created on 5/22/20.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.

// swiftlint:disable identifier_name todo function_parameter_count

import Foundation

/// http headers key
public struct HTTPHeader {
    static public let apiVersion = "x-pm-apiversion"
}

extension Bundle {
    /// Returns the app version in a nice to read format
    var appVersion: String {
        return "\(majorVersion) (\(buildVersion))"
    }

    /// Returns the build version of the app.
    var buildVersion: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    /// Returns the major version of the app.
    public var majorVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// struct ErrorResponse: Codable {
//    var code: Int
//    var error: String
//    var errorDescription: String
// }

///
public protocol APIServerConfig {
    // host name    xxx.xxxxxxx.com
    var host: String { get }
    // http https ws wss etc ...
    var `protocol` : String {get}
    // prefixed path after host example:  /api
    var path: String {get}
    // full host with protocol, without path
    var hostUrl: String {get}
}

extension APIServerConfig {
    public var hostUrl: String {
        return self.protocol + "://" + self.host
    }
}

// Predefined servers, could also add the serverlist load from config env later
public enum Server: APIServerConfig {
    case live // "api.protonmail.ch"
    case testlive // "test-api.protonmail.ch"

    case dev1 // "dev.protonmail.com"
    case dev2 // "dev-api.protonmail.ch"

    case blue // "protonmail.blue"
    case midnight // "midnight.protonmail.blue"

    // local test
    // static let URL_HOST : String = "http://127.0.0.1"  //http

    public var host: String {
        switch self {
        case .live:
            return "api.protonmail.ch"
        case .blue:
            return "protonmail.blue"
        case .midnight:
            return "midnight.protonmail.blue"
        case .testlive:
            return "test-api.protonmail.ch"
        case .dev1:
            return "dev.protonmail.com"
        case .dev2:
            return "dev-api.protonmail.ch"
        }
    }

    public var path: String {
        switch self {
        case .live, .testlive, .dev2:
            return ""
        case .blue, .midnight, .dev1:
            return "/api"
        }
    }

    public var `protocol`: String {
        return "https"
    }

}

// enum <T> {
//     case failure(Error)
//     case success(T)
// }

public typealias CompletionBlock = (_ task: URLSessionDataTask?, _ response: [String: Any]?, _ error: NSError?) -> Void

public protocol API {
    func request(method: HTTPMethod, path: String,
                 parameters: Any?, headers: [String: Any]?,
                 authenticated: Bool, autoRetry: Bool,
                 customAuthCredential: AuthCredential?,
                 completion: CompletionBlock?)
}

/// this is auth UI related
public protocol APIServiceDelegate: class {
    func onUpdate(serverTime: Int64)
    // func onError(error: NSError)

    // check if server reachable or check if network avaliable
    func isReachable() -> Bool

    var appVersion: String { get }

    var userAgent: String? { get }

    func onDohTroubleshot()

    func onChallenge(challenge: URLAuthenticationChallenge,
                     credential: AutoreleasingUnsafeMutablePointer<URLCredential?>?) -> URLSession.AuthChallengeDisposition
}

public protocol HumanVerifyDelegate: class {
    typealias HumanVerifyHeader = [String: Any]
    typealias HumanVerifyIsClosed = Bool

    func onHumanVerify(methods: [VerifyMethod], startToken: String?, completion: (@escaping (HumanVerifyHeader, HumanVerifyIsClosed, SendVerificationCodeBlock?) -> Void))
    func getSupportURL() -> URL
}

public enum HumanVerifyEndResult {
    case success
    case cancel
}

public protocol HumanVerifyResponseDelegate: class {
    func onHumanVerifyStart()
    func onHumanVerifyEnd(result: HumanVerifyEndResult)
}

public enum PaymentTokenStatus {
    case success
    case fail
}

public protocol HumanVerifyPaymentDelegate: class {
    var paymentToken: String? { get }
    func paymentTokenStatusChanged(status: PaymentTokenStatus)
}

public protocol ForceUpgradeDelegate: class {
    func onForceUpgrade(message: String)
}

public protocol ForceUpgradeResponseDelegate: class {
    func onQuitButtonPressed()
    func onUpdateButtonPressed()
}

public typealias AuthRefreshComplete = (_ auth: Credential?, _ hasError: NSError?) -> Void

/// this is auth related delegate in background
public protocol AuthDelegate: class {
    func getToken(bySessionUID uid: String) -> AuthCredential?
    func onLogout(sessionUID uid: String)
    func onUpdate(auth: Credential)
    func onRefresh(bySessionUID uid: String, complete:  @escaping AuthRefreshComplete)
    func onForceUpgrade()
}

public protocol APIService: API {
    // var network : NetworkLayer {get}
    // var vpn : VPNInterface {get}
    // var doh:  DoH  {get}//depends on NetworkLayer. {get}
    // var queue : [Request] {get}

    func setSessionUID(uid: String)

    var serviceDelegate: APIServiceDelegate? {get set}
    var authDelegate: AuthDelegate? {get set}
    var humanDelegate: HumanVerifyDelegate? {get set}
    var doh: DoH { get set}
    var signUpDomain: String { get }
}

class TestResponse: Response {

}

typealias RequestComplete = (_ task: URLSessionDataTask?, _ response: Response) -> Void

public extension APIService {
    // init
    func exec<T>(route: Request) -> T? where T: Response {
        var ret_res: T?
        var ret_error: NSError?
        let sema = DispatchSemaphore(value: 0)
        // TODO :: 1 make a request , 2 wait for the respons async 3. valid response 4. parse data into response 5. some data need save into database.
        let completionWrapper: CompletionBlock = { _, res, error in
            defer {
                sema.signal()
            }
            let realType = T.self
            let apiRes = realType.init()
            if error != nil {
                // TODO check error
                apiRes.ParseHttpError(error!)
                ret_error = apiRes.error
                return
            }

            if res == nil {
                // TODO:: check res
                // apiRes.error = NSError.badResponse()
                ret_error = apiRes.error
                return
            }

            var hasError = apiRes.ParseResponseError(res!)
            if !hasError {
                hasError = !apiRes.ParseResponse(res!)
            }
            if hasError {
                ret_error = apiRes.error
                return
            }
            ret_res = apiRes
        }
        // TODO:: missing auth
        var header = route.header
        header[HTTPHeader.apiVersion] = route.version
        self.request(method: route.method, path: route.path,
                     parameters: route.parameters,
                     headers: header,
                     authenticated: route.isAuth,
                     autoRetry: route.autoRetry,
                     customAuthCredential: route.authCredential,
                     completion: completionWrapper)

        // wait operations
        _ = sema.wait(timeout: DispatchTime.distantFuture)
        if let e = ret_error {
            // TODO::fix me
            print(e.localizedDescription)
        }
        return ret_res
    }

    func exec<T>(route: Request,
                 complete: @escaping  (_ task: URLSessionDataTask?, _ response: T) -> Void) where T: Response {

        // 1 make a request , 2 wait for the respons async 3. valid response 4. parse data into response 5. some data need save into database.
        let completionWrapper: CompletionBlock = { task, res, error in
            let realType = T.self
            let apiRes = realType.init()
            if error != nil {
                apiRes.ParseHttpError(error!, response: res)
                if let resRaw = res {
                    _ = apiRes.ParseResponse(resRaw)
                }
                complete(task, apiRes)
                return
            }

            if res == nil {
                // TODO:: check res
                // apiRes.error = NSError.badResponse()
                complete(task, apiRes)
                return
            }

            var hasError = apiRes.ParseResponseError(res!)
            if !hasError {
                hasError = !apiRes.ParseResponse(res!)
            }
            complete(task, apiRes)
        }

        var header = route.header
        header[HTTPHeader.apiVersion] = route.version
        self.request(method: route.method, path: route.path,
                     parameters: route.parameters,
                     headers: header,
                     authenticated: route.isAuth,
                     autoRetry: route.autoRetry,
                     customAuthCredential: route.authCredential,
                     completion: completionWrapper)
    }

    func exec<T>(route: Request, complete: @escaping (_ response: T) -> Void) where T: Response {

        // 1 make a request , 2 wait for the respons async 3. valid response 4. parse data into response 5. some data need save into database.
        let completionWrapper: CompletionBlock = { _, res, error in
            let realType = T.self
            let apiRes = realType.init()
            if error != nil {
                // TODO check error
                apiRes.ParseHttpError(error!, response: res)
                if let resRaw = res {
                    _ = apiRes.ParseResponse(resRaw)
                }
                complete(apiRes)
                return
            }

            if res == nil {
                // TODO:: check res
                // apiRes.error = NSError.badResponse()
                complete(apiRes)
                return
            }

            var hasError = apiRes.ParseResponseError(res!)
            if !hasError {
                hasError = !apiRes.ParseResponse(res!)
            }
            complete(apiRes)
        }

        var header = route.header
        header[HTTPHeader.apiVersion] = route.version
        self.request(method: route.method, path: route.path,
                     parameters: route.parameters,
                     headers: header,
                     authenticated: route.isAuth,
                     autoRetry: route.autoRetry,
                     customAuthCredential: route.authCredential,
                     completion: completionWrapper)
    }

    func exec<T>(route: Request, complete: @escaping (_ task: URLSessionDataTask?, _ result: Result<T, Error>) -> Void) where T: Codable {

        // 1 make a request , 2 wait for the respons async 3. valid response 4. parse data into response 5. some data need save into database.
        let completionWrapper: CompletionBlock = { task, res, error in
            do {
                if let res = res {
                    // this is a workaround for afnetworking, will change it
                    let responseData = try JSONSerialization.data(withJSONObject: res, options: .prettyPrinted)

                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .decapitaliseFirstLetter
                    // server error code
                    if let error = try? decoder.decode(ErrorResponse.self, from: responseData) {
                        throw NSError(error)
                    }
                    // server SRP
                    let decodedResponse = try decoder.decode(T.self, from: responseData)
                    complete(task, .success(decodedResponse))
                } else {
                    // todo fix the cast
                    complete(task, .failure(error!))
                }

            } catch let err {
                complete(task, .failure(err))
            }
        }
        var header = route.header
        header[HTTPHeader.apiVersion] = route.version
        self.request(method: route.method, path: route.path,
                     parameters: route.parameters,
                     headers: header,
                     authenticated: route.isAuth,
                     autoRetry: route.autoRetry,
                     customAuthCredential: route.authCredential,
                     completion: completionWrapper)
    }

    func exec<T>(route: Request, complete: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
        // 1 make a request , 2 wait for the respons async 3. valid response 4. parse data into response 5. some data need save into database.
        let completionWrapper: CompletionBlock = { _, res, error in
            do {
                if let res = res {
                    // this is a workaround for afnetworking, will change it
                    let responseData = try JSONSerialization.data(withJSONObject: res, options: .prettyPrinted)

                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .decapitaliseFirstLetter
                    // server error code
                    if let error = try? decoder.decode(ErrorResponse.self, from: responseData) {
                        throw NSError(error)
                    }
                    // server SRP
                    let decodedResponse = try decoder.decode(T.self, from: responseData)
                    complete(.success(decodedResponse))
                } else {
                    // todo fix the cast
                    complete(.failure(error!))
                }

            } catch let err {
                complete(.failure(err))
            }
        }
        var header = route.header
        header[HTTPHeader.apiVersion] = route.version
        self.request(method: route.method, path: route.path,
                     parameters: route.parameters,
                     headers: header,
                     authenticated: route.isAuth,
                     autoRetry: route.autoRetry,
                     customAuthCredential: route.authCredential,
                     completion: completionWrapper)
    }

    //    func exec(content: URLRequestConvertible ) {
    //           // get doh url
    //
    //           // check if enable vpn
    //
    //           //build body
    //
    //           //build the request
    //
    //           //queue requests
    //
    //           // pass request to networklayer
    //
    //           // waiting response
    //
    //           //complete/error
    //       }
    //       func errorHandling() {
    //           // if doh do
    //               //retry
    //           // if humanverification do
    //           // if networking issue do
    //           // if token expiared do
    //               // renew token with authitection framewrok
    //           // if renew token failed do
    //
    //           // a lot of error handling here and will trigger delegates
    //       }
}
