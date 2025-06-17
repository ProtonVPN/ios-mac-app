//
//  CertificateConstants.swift
//  Core
//
//  Created by Jaroslav on 2021-07-08.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

public enum CertificateConstants {
    /// Certificate life duration requested from API. Set to nil to get default duration from API (24h). For testing use "10 minutes" or similar.
    public static var certificateDuration: String?
}
