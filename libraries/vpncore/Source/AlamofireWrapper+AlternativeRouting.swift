//
//  AlamofireWrapper+AlternativeRouting.swift
//  ProtonVPN - Created on 24.02.2021.
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
import Alamofire

/**
 Custom Alamofire session delegate that ignores invalid certificates.

 Used only when `TrustKitHelper` is not provided by the iOS or macOS apps (so only for debug and testing purposes). Needed for running the app in debug and testing without `TrustKitHelper`, otherwise alternative routing fails because of a self-signed certificate.
 */
final class AlamofireSessionDelegate: SessionDelegate {
    override func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(URLSession.AuthChallengeDisposition.useCredential, challenge.protectionSpace.serverTrust.flatMap({ URLCredential(trust: $0) }))
    }
}

/**
 Checks if the request to given URL should be retried using alternative routing when the response fails with a specific Alamofire error.

 If the request should be retried it also gets the next alternative route and sets it as base url for all the requests so the caller can just retry the request without any modification
 */
final class AlternativeRoutingInterceptor: RequestInterceptor {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // Resolve the current base URL
        let baseUrl = ApiConstants.doh.getHostUrl()

        // If the request is being made to the current API base URL then no need to modify it
        guard let baseUrlHost = URL(string: baseUrl)?.host, let url = urlRequest.url, let requestUrlHost = url.host, requestUrlHost != baseUrlHost else {
            completion(.success(urlRequest))
            return
        }

        // If the request is being made to a different base URL, switch to the new base URL changed by alternative routing
        // This is needed for the case when the `AlamofireWrapper` is used with a generic `URLRequestConvertible` instead of a `BaseRequest` subclass
        // Every `BaseRequest` subclass handles this automatically because it calls `DoH.getHostUrl()` when forming the URL
        var urlRequest = urlRequest
        PMLog.D("Switching request \(urlRequest) to \(baseUrl)")
        urlRequest.url = URL(string: url.absoluteString.replacingOccurrences(of: requestUrlHost, with: baseUrlHost))
        completion(.success(urlRequest))
    }

    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // Check for a valid `URLRequest` and get its URL
        guard let requestUrl = request.request?.url else {
            PMLog.D("Not retrying an invalid request without an URL")
            completion(.doNotRetry)
            return
        }

        // Check if the reponse error can be recovered from using alternative routing
        // First we need to extract the underlying networking error from the Alamofire error recieved, because `DoH.handleError(:)` does not know about Alamofire.
        // Then check if `DoH` can handle the networking error. If yes the DoH.handleError(:)` call also immediatelly resolves alternative routes internally so the request can be just retried
        // The URL of this retried request will be modified in the `adapt(:)` method to use the new alternative route
        if let networkingError = extractNetworkingError(error: error as? AFError), ApiConstants.doh.handleError(host: requestUrl.absoluteString, error: networkingError) {
            PMLog.D("Retrying request \(request) with alternative route")
            completion(.retry)
            return
        }

        completion(.doNotRetry)
    }

    /**
     Attempts to extract the underlaying `URLSession` error from Alamofire error in the response. Needed because `DoH` error handling works with `URLSession` errors and does not know about Alamofire.

     - Parameter error: Alamofire error from request response
     - Returns URLSession error if found
     */
    private func extractNetworkingError(error: AFError?) -> NSError? {
        var currentError: Error? = error

        while currentError != nil {
            if let nextAfError = currentError?.asAFError?.underlyingError {
                currentError = nextAfError
            } else {
                return currentError as NSError?
            }
        }

        return nil
    }
}
