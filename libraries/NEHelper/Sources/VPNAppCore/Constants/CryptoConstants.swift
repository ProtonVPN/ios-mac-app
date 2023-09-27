//
//  Created on 27.09.23.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation
import VPNCrypto

public enum CryptoConstants {
    public static let widgetChallengeKeyType: CryptoService.KeyType = .rsa
    public static let widgetChallengeKeyWidth = 2048
    public static var widgetChallengeAlgorithm: CryptoService.Algorithm = .rsaSignatureMessagePKCS1v15SHA256
}
