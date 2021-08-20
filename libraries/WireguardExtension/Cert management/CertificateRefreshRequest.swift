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

class CertificateRefreshRequest {
        
    private let url = URL(string: "https://api.protonvpn.ch/vpn/v1/certificate")!
    
    enum CertificateRefreshRequestError: Error {
        case noCredentials
        case requestError(Error)
        case noData
        case parseError
    }
    
    /// Ask API to refresh certificate for a given public key
    public func refresh(publicKey: String, completionHandler: @escaping (Result<VpnCertificate, CertificateRefreshRequestError>) -> Void) {
        guard let credential = AuthKeychain.fetch() else {
            wg_log(.default, message: "Can't load API credentials from keychain. Won't refresh certificate.")
            completionHandler(.failure(.noCredentials))
            return
        }
                
        let task = session.dataTask(with: request(authCredentials: credential, certificatePublicKey: publicKey)) { data, response, error in
            if let error = error {
                wg_log(.error, message: "Error refreshing certificate: \(error)")
                completionHandler(.failure(.requestError(error)))
                return
            }
            guard let data = data else {
                wg_log(.error, message: "No response data")
                completionHandler(.failure(.noData))
                return
            }
            guard let dict = data.jsonDictionary,
                  let certificate = try? VpnCertificate(dict: dict) else {
                wg_log(.error, message: "Can't parse response JSON: \(String(data: data, encoding: .utf8) ?? "")")
                completionHandler(.failure(.parseError))
                return
            }
            
            wg_log(.debug, message: "Response cert is valid until: \(certificate.validUntil)")
            completionHandler(.success(certificate))
            
        }
        task.resume()
    }
    
    // MARK: - URLRequest, params, headers
    
    private let config = URLSessionConfiguration.default
    private lazy var session = URLSession(configuration: config)
    
    private func request(authCredentials: AuthCredentials, certificatePublicKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        var params = [
            "ClientPublicKey": certificatePublicKey,
            "ClientPublicKeyMode": "EC",
            "DeviceName": deviceName,
            "Mode": "session"
        ]
        if let duration = CertificateConstants.certificateDuration {
            params["Duration"] = duration
        }
        request.httpBody = try! JSONEncoder().encode(params)
        
        // Headers
        request.setValue(appVersion, forHTTPHeaderField: "x-pm-appversion")
        request.setValue("3", forHTTPHeaderField: "x-pm-apiversion")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.protonmail.v1+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
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
    
    private var userAgent: String {
        let info = ProcessInfo()
        let osVersion = info.operatingSystemVersion
        let processName = info.processName
        var os = "unknown"
        var device = ""
        #if os(iOS)
        os = "iOS"
        device = "; \(UIDevice.current.modelName)"
        #elseif os(macOS)
        os = "Mac OS X"
        #elseif os(watchOS)
        os = "watchOS"
        #elseif os(tvOS)
        os = "tvOS"
        #endif
        return "\(processName)/\(bundleShortVersion) (\(os) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)\(device))"
    }
    
    private var bundleShortVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    
    private var bundleVersion: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
    
    private var appVersion: String {
        return clientId + "_" + bundleShortVersion
    }
    
    private var clientId: String {
        return clientDictionary.object(forKey: "Id") as? String ?? ""
    }
    
    private var clientDictionary: NSDictionary {
        guard let file = Bundle.main.path(forResource: "Client", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: file) else {
            return NSDictionary()
        }
        return dict
    }
    
}
