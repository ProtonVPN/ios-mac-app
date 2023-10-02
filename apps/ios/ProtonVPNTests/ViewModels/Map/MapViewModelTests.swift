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
import LegacyCommon
import XCTest
import TimerMock
import VPNShared
import VPNSharedTesting

@testable import ProtonVPN

class MapViewModelTests: XCTestCase {

    lazy var networking = CoreNetworking(
        delegate: iOSNetworkingDelegate(alertingService: CoreAlertServiceDummy()),
        appInfo: AppInfoImplementation(),
        doh: .mock,
        authKeychain: MockAuthKeychain(),
        unauthKeychain: UnauthKeychainMock(),
        pinApiEndpoints: false
    )
    lazy var vpnKeychain = VpnKeychainMock()

    var serverStorage: ServerStorage!
    var appStateManager: AppStateManager!
    
    override func setUp() {
        super.setUp()
        ServerManagerImplementation.reset()
        serverStorage = ServerStorageMock(fileName: "LiveServers", bundle: Bundle(for: type(of: self)))

        let vpnApiService = VpnApiService(networking: networking, vpnKeychain: vpnKeychain, countryCodeProvider: CountryCodeProviderImplementation(), authKeychain: MockAuthKeychain())
        let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
        let vpnAuthKeychain = VpnAuthenticationKeychain(accessGroup: "\(appIdentifierPrefix)prt.ProtonVPN",
                                                        vpnKeysGenerator: ExtensionVPNKeysGenerator())
        let configurationPreparer = VpnManagerConfigurationPreparer(
            vpnKeychain: VpnKeychainMock(),
            alertService: AlertServiceEmptyStub(),
            propertiesManager: PropertiesManagerMock())
        appStateManager = AppStateManagerImplementation(vpnApiService: vpnApiService, vpnManager: VpnManagerMock(), networking: networking, alertService: AlertServiceEmptyStub(), timerFactory: TimerFactoryMock(), propertiesManager: PropertiesManagerMock(), vpnKeychain: vpnKeychain, configurationPreparer: configurationPreparer, vpnAuthentication: VpnAuthenticationMock(), doh: .mock, serverStorage: serverStorage, natTypePropertyProvider: NATTypePropertyProviderMock(), netShieldPropertyProvider: NetShieldPropertyProviderMock(), safeModePropertyProvider: SafeModePropertyProviderMock())
    }
    
    func testSecureCoreAnnotationLocations() {
        let mapViewModel = MapViewModel(appStateManager: appStateManager,
                                        alertService: AlertServiceEmptyStub(),
                                        serverStorage: serverStorage,
                                        vpnGateway: VpnGatewayMock(),
                                        vpnKeychain: vpnKeychain,
                                        propertiesManager: PropertiesManagerMock(),
                                        connectionStatusService: ConnectionStatusServiceMock())
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
