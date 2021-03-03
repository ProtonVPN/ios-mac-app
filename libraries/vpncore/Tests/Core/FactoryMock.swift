//
//  FactoryMock.swift
//  vpncore - Created on 25.02.2021.
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
//

import Alamofire
import Foundation

final class FactoryMock: CoreAlertServiceFactory & HumanVerificationAdapterFactory & TrustKitHelperFactory & PropertiesManagerFactory & ProtonAPIAuthenticatorFactory & AuthApiServiceFactory & AlamofireWrapperFactory & AppSpecificRequestAdapterFatory {

    private lazy var alamofireWrapper: AlamofireWrapper = {
        return AlamofireWrapperImplementation(factory: self)
    }()

    func makeAuthApiService() -> AuthApiService {
        return AuthApiServiceImplementation(alamofireWrapper: alamofireWrapper)
    }

    func makeAlamofireWrapper() -> AlamofireWrapper {
        return alamofireWrapper
    }

    let propertiesManagerMock = PropertiesManagerMock()

    func makeCoreAlertService() -> CoreAlertService {
        return CoreAlertServiceMock()
    }

    func makeHumanVerificationAdapter() -> HumanVerificationAdapter {
        return HumanVerificationAdapter()
    }

    func makeTrustKitHelper() -> TrustKitHelper? {
        return TrustKitHelper(factory: self)
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManagerMock
    }

    func makeProtonAPIAuthenticator() -> ProtonAPIAuthenticator {
        return ProtonAPIAuthenticator(self)
    }

    func makeAppSpecificRequestAdapter() -> RequestAdapter? {
        return nil
    }
}
