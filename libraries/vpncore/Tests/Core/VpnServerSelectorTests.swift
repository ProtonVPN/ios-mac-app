//
//  VpnServerSelectorTests.swift
//  vpncore - Created on 2020-06-02.
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

import XCTest

class VpnServerSelectorTests: XCTestCase {
    
    private var grouping1: [CountryGroup]!
    private var serversGB: [ServerModel]!
    private var serversDE: [ServerModel]!

    override func setUpWithError() throws {
        if grouping1 == nil {
            serversGB = [
                getServerModel(id: "GB0", countryCode: "GB", tier: 3, score: 1),
                getServerModel(id: "GB1", countryCode: "GB", tier: 2, score: 3, feature: .tor),
                getServerModel(id: "GB2", countryCode: "GB", tier: 1, score: 5, feature: .secureCore),
            ]
            
            serversDE = [
                getServerModel(id: "DE0", countryCode: "DE", tier: 3, score: 2),
                getServerModel(id: "DE1", countryCode: "DE", tier: 2, score: 4, feature: .tor),
                getServerModel(id: "DE2", countryCode: "DE", tier: 1, score: 6, feature: .secureCore)
            ]
            grouping1 = [(CountryModel(serverModel: serversGB[0]), serversGB), (CountryModel(serverModel: serversDE[0]), serversDE)];
        }
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSelectsFastestOverall() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .fastest, vpnProtocol: .ike, netShieldType: .off)
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping1, appStateGetter: {
            return AppState.disconnected
        })
        XCTAssertEqual(serversGB[0], selector.selectServer(connectionRequest: connectionRequest))
    }

    func testSelectsFastestInCountry() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("DE", .fastest), vpnProtocol: .ike, netShieldType: .off)
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping1, appStateGetter: {
            return AppState.disconnected
        })
        XCTAssertEqual(serversDE[0], selector.selectServer(connectionRequest: connectionRequest))
    }

    func testSelectsFastestInAvailableTier() throws {
        let currentUserTier = 1
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .fastest, vpnProtocol: .ike, netShieldType: .off)
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping1, appStateGetter: {
            return AppState.disconnected
        })
        XCTAssertEqual(serversGB[2], selector.selectServer(connectionRequest: connectionRequest))
    }

    func testSelectsFastestInAvailableTierByCountry() throws {
        let currentUserTier = 1
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("DE", .fastest), vpnProtocol: .ike, netShieldType: .off)
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping1, appStateGetter: {
            return AppState.disconnected
        })
        XCTAssertEqual(serversDE[2], selector.selectServer(connectionRequest: connectionRequest))
    }

    func testSelectsServer() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("DE", .server(getServerModel(id: "DE2", countryCode: "DE", tier: 1, score: 6))), vpnProtocol: .ike, netShieldType: .off)
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping1, appStateGetter: {
            return AppState.disconnected
        })
        XCTAssertEqual(serversDE[2].id, selector.selectServer(connectionRequest: connectionRequest)?.id)
    }
    
    func testReturnsNilForEmptyCountry() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("FR", .random), vpnProtocol: .ike, netShieldType: .off)
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping1, appStateGetter: {
            return AppState.disconnected
        })
        XCTAssertEqual(nil, selector.selectServer(connectionRequest: connectionRequest))
    }
    
    func testDoesntReturnServerUnderMaintenance() throws {
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("GB", .random), vpnProtocol: .ike, netShieldType: .off)
        
        let servers = [
            getServerModel(id: "GB0", countryCode: "GB", tier: 3, score: 1, status: 0), // status - 0, in maintenance
            getServerModel(id: "GB1", countryCode: "GB", tier: 2, score: 3, status: 0),
            getServerModel(id: "GB2", countryCode: "GB", tier: 1, score: 5, status: 0),
        ]
        let grouping = [(CountryModel(serverModel: servers[0]), servers)];
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping, appStateGetter: {
            return AppState.disconnected
        })
        
        var notifiedNoResultion = false
        selector.notifyResolutionUnavailable = { _, _, _ in
            notifiedNoResultion = true
        }
        
        XCTAssertEqual(nil, selector.selectServer(connectionRequest: connectionRequest))
        XCTAssertEqual(true, notifiedNoResultion)
    }
    
    func testDoesntReturnServersOfHigherTiers() throws {
        let currentUserTier = 1
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .country("GB", .random), vpnProtocol: .ike, netShieldType: .off)
        
        let servers = [
            getServerModel(id: "GB0", countryCode: "GB", tier: 3, score: 1),
            getServerModel(id: "GB1", countryCode: "GB", tier: 2, score: 3),
        ]
        let grouping = [(CountryModel(serverModel: servers[0]), servers)];
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping, appStateGetter: {
            return AppState.disconnected
        })
        
        var notifiedNoResultion = false
        selector.notifyResolutionUnavailable = { _, _, _ in
            notifiedNoResultion = true
        }
        
        XCTAssertEqual(nil, selector.selectServer(connectionRequest: connectionRequest))
        XCTAssertEqual(true, notifiedNoResultion)
    }

    func testChangesActiveServerType() throws {
        let currentUserTier = 1
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .secureCore, connectionType: .fastest, vpnProtocol: .ike, netShieldType: .off)
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping1, appStateGetter: {
            return AppState.disconnected
        })
        var currentServerType = ServerType.unspecified
        selector.changeActiveServerType = { serverType in
            currentServerType = serverType
        }
        
        XCTAssertEqual(serversGB[2], selector.selectServer(connectionRequest: connectionRequest))
        XCTAssertEqual(currentServerType, ServerType.secureCore)
    }
    
    func testSelectsByTierAndScore() throws {
        let servers1 = [
            getServerModel(id: "GB0", countryCode: "GB", tier: 2, score: 1), // Best tier
            getServerModel(id: "GB1", countryCode: "GB", tier: 1, score: 3),
            getServerModel(id: "GB2", countryCode: "GB", tier: 1, score: 5),
        ]
        
        let servers2 = [
            getServerModel(id: "DE0", countryCode: "DE", tier: 1, score: 0.5), // Best score
            getServerModel(id: "DE1", countryCode: "DE", tier: 1, score: 4),
            getServerModel(id: "DE2", countryCode: "DE", tier: 1, score: 6)
        ]
        let grouping = [(CountryModel(serverModel: servers1[0]), servers1), (CountryModel(serverModel: servers2[0]), servers2)];
        
        
        let currentUserTier = 3
        let type = ServerType.unspecified
        let connectionRequest = ConnectionRequest(serverType: .unspecified, connectionType: .fastest, vpnProtocol: .ike, netShieldType: .off)
        
        let selector = VpnServerSelector(serverType: type, userTier: currentUserTier, serverGrouping: grouping, appStateGetter: {
            return AppState.disconnected
        })
        XCTAssertEqual(servers2[0], selector.selectServer(connectionRequest: connectionRequest))
    }

    // MARK: - Helpers
    
    private func getServerModel(id: String, countryCode: String, tier: Int, score: Double, feature: ServerFeature = .zero, status: Int = 1) -> ServerModel {
        return ServerModel(id: id, name: "", domain: "", load: 0, entryCountryCode: countryCode, exitCountryCode: countryCode, tier: tier, feature: feature, city: nil, ips: [ServerIp](), score: score, status: status, location: ServerLocation(lat: 0, long: 0))
    }
    
}
