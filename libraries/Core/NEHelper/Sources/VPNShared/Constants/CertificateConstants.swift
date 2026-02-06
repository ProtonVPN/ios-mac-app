//
//  CertificateConstants.swift
//  Core
//
//  Created by Jaroslav on 2021-07-08.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public enum CertificateConstants {
    private static let lock = NSLock()
    private static var _certificateDuration: String?

    /// Certificate life duration requested from API. Set to nil to get default duration from API (24h). For testing use "10 minutes" or similar.
    /// If the value is non nil, further overrides of the value won't work. Reset it to `nil` to force it.
    public nonisolated(unsafe) static var certificateDuration: String? {
        get {
            lock.withLock {
                _certificateDuration
            }
        }
        set {
            lock.withLock {
                if newValue == nil {
                    _certificateDuration = nil
                }
                if _certificateDuration == nil {
                    _certificateDuration = newValue
                }
            }
        }
    }
}
