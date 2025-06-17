//
//  TokenStorage.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 01.11.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCorePayments

final class TokenStorage: PaymentTokenStorage {
    var token: PaymentToken?

    func add(_ token: PaymentToken) {
        self.token = token
    }

    func get() -> PaymentToken? {
        token
    }

    func clear() {
        token = nil
    }
}
