//
//  SigninInfoContainer.swift
//  ProtonVPN - Created on 2019-11-19.
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

protocol SigninInfoContainerFactory {
    func makeSigninInfoContainer() -> SigninInfoContainer
}

/// Object used to temporarily save sign-in info that may be needed to make Human Verification UX better
class SigninInfoContainer {
    
    public var email: String?
    
}
