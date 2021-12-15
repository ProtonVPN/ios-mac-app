//
//  MapViewModelTests.swift
//  ProtonVPN - Created on 01.07.19.
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

import CoreLocation
import vpncore
import XCTest

class MapViewModelTests: XCTestCase {

    let alamofireWrapper = AlamofireWrapperImplementation()
    
    var appStateManager: AppStateManager!
    
    override func setUp() {
        ServerManagerImplementation.reset()
        let vpnApiService = VpnApiService(alamofireWrapper: alamofireWrapper)
        let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
        let vpnAuthKeychain = VpnAuthenticationKeychain(accessGroup: "\(appIdentifierPrefix)prt.ProtonVPN", storage: Storage())
        let configurationPreparer = VpnManagerConfigurationPreparer(
            vpnKeychain: VpnKeychainMock(),
            alertService: AlertServiceEmptyStub(),
            propertiesManager: PropertiesManager())
        appStateManager = AppStateManagerImplementation(vpnApiService: vpnApiService, vpnManager: VpnManagerMock(), alamofireWrapper: alamofireWrapper, alertService: AlertServiceEmptyStub(), timerFactory: TimerFactoryMock(), propertiesManager: PropertiesManagerMock(), vpnKeychain: VpnKeychainMock(), configurationPreparer: configurationPreparer, vpnAuthentication: VpnAuthenticationManager(alamofireWrapper: alamofireWrapper, storage: vpnAuthKeychain))
    }
    
    func testSecureCoreAnnotationLocations() {
        let serverStorage = ServerStorageMock(fileName: "LiveServers", bundle: Bundle(for: type(of: self)))
        let mapViewModel = MapViewModel(appStateManager: appStateManager, loginService: LoginServiceMock(), alertService: AlertServiceEmptyStub(), serverStorage: serverStorage, vpnGateway: nil, vpnKeychain: VpnKeychainMock(), propertiesManager: PropertiesManagerMock(), connectionStatusService: ConnectionStatusServiceMock())
        mapViewModel.setStateOf(type: .secureCore)
        
        let annotations = mapViewModel.annotations
        let secureCoreAnnotations = annotations.filter { (annotation) -> Bool in
            return annotation is SecureCoreEntryCountryModel
        }
        
        XCTAssert(secureCoreAnnotations.count == 3)
        
        let switzerland = secureCoreAnnotations.first { $0.countryCode == "CH" }!
        let iceland = secureCoreAnnotations.first { $0.countryCode == "IS" }!
        let sweden = secureCoreAnnotations.first { $0.countryCode == "SE" }!
        
        XCTAssert(switzerland.coordinate == CLLocationCoordinate2D(latitude: 46.715779, longitude: 8.402655))
        XCTAssert(iceland.coordinate == CLLocationCoordinate2D(latitude: 64.809637, longitude: -18.372633))
        XCTAssert(sweden.coordinate == CLLocationCoordinate2D(latitude: 62.736314, longitude: 15.365470))
    }
}
