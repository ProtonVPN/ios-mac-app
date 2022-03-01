//
//  CertificateRefreshRequest.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-06-30.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
#if os(iOS)
import UIKit
#endif

// Important! If changing this request, don't forget there is `CertificateRequest` class that does the same request, but in vpncore.

class CertificateRefreshRequest: ExtensionAPIRequest {
        
    private let endpointUrl = "vpn/v1/certificate"
    
    enum CertificateRefreshRequestError: Error {
        case noCredentials
        case requestError(Error)
        case noData
        case parseError
        case apiTokenRefreshError(Error?)
    }
    
    /// Ask API to refresh certificate for a given public key
    public func refresh(publicKey: String, features: VPNConnectionFeatures?, refreshApiTokenIfNeeded: Bool = true, completionHandler: @escaping (Result<VpnCertificate, CertificateRefreshRequestError>) -> Void) {
        guard let credential = AuthKeychain.fetch() else {
            log.info("Can't load API credentials from keychain. Won't refresh certificate.", category: .userCert)
            completionHandler(.failure(.noCredentials))
            return
        }
                
        let task = session.dataTask(with: request(authCredentials: credential, certificatePublicKey: publicKey, features: features)) { data, response, error in
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                guard refreshApiTokenIfNeeded else {
                    log.error("Will not refresh API token.", category: .api)
                    completionHandler(.failure(.apiTokenRefreshError(error)))
                    return
                }
                self.handleTokenExpired(publicKey: publicKey, features: features, completionHandler: completionHandler)
                return
            }

            if let error = error {
                log.error("Error refreshing certificate: \(error)", category: .userCert)
                completionHandler(.failure(.requestError(error)))
                return
            }
            guard let data = data else {
                log.error("No response data", category: .userCert)
                completionHandler(.failure(.noData))
                return
            }
            guard let dict = data.jsonDictionary,
                  let certificate = try? VpnCertificate(dict: dict) else {
                log.error("Can't parse response JSON: \(String(data: data, encoding: .utf8) ?? "")", category: .userCert)
                completionHandler(.failure(.parseError))
                return
            }
            
            log.info("Response cert is valid until: \(certificate.validUntil)", category: .userCert)
            completionHandler(.success(certificate))
            
        }
        task.resume()
    }

    private func handleTokenExpired(publicKey: String, features: VPNConnectionFeatures?, completionHandler: @escaping (Result<VpnCertificate, CertificateRefreshRequestError>) -> Void) {
        log.debug("Will try to refresh API token", category: .api)
        guard let credential = AuthKeychain.fetch() else {
            log.info("Can't load API credentials from keychain. Won't refresh certificate.", category: .api)
            completionHandler(.failure(.noCredentials))
            return
        }

        let request = TokenRefreshRequest()
        request.refresh(authCredentials: credential) { result in
            switch result {
            case .success(let newCredentials):
                do {
                    try AuthKeychain.store(newCredentials)
                    self.refresh(publicKey: publicKey, features: features, completionHandler: completionHandler)
                } catch {
                    completionHandler(.failure(.apiTokenRefreshError(error)))
                }

            case .failure(let error):
                completionHandler(.failure(.apiTokenRefreshError(error)))
            }
        }
    }
    
    private func request(authCredentials: AuthCredentials, certificatePublicKey: String, features: VPNConnectionFeatures?) -> URLRequest {
        var request = initialRequest(endpoint: endpointUrl)
        request.httpMethod = "POST"
                
        let params = Params(clientPublicKey: certificatePublicKey,
                            clientPublicKeyMode: "EC",
                            deviceName: deviceName,
                            mode: "session",
                            duration: CertificateConstants.certificateDuration,
                            features: features)
        
        request.httpBody = try! JSONEncoder().encode(params)
        
        // Headers
        request.setValue("Bearer \(authCredentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(authCredentials.sessionId, forHTTPHeaderField: "x-pm-uid")
        
        return request
    }

    private var deviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? ""
        #endif
    }
    
    private struct Params: Codable {
        let clientPublicKey: String
        let clientPublicKeyMode: String
        let deviceName: String
        let mode: String
        let duration: String?
        let features: VPNConnectionFeatures?
        
        enum CodingKeys: String, CodingKey {
            case clientPublicKey = "ClientPublicKey"
            case clientPublicKeyMode = "ClientPublicKeyMode"
            case deviceName = "DeviceName"
            case mode = "Mode"
            case duration = "Duration"
            case features = "Features"
        }
    }
    
}
