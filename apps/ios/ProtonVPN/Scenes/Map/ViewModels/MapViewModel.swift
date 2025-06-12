//
//  MapViewModel.swift
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

import Foundation
import MapKit

import Dependencies

import Domain
import Ergonomics
import Persistence
import LegacyCommon

class MapPin: NSObject, MKAnnotation {
    let countryCode: String
    let locationName: String
    let coordinate: CLLocationCoordinate2D
    
    init(countryCode: String, locationName: String, coordinate: CLLocationCoordinate2D) {
        self.countryCode = countryCode
        self.locationName = locationName
        self.coordinate = coordinate
        
        super.init()
    }
}

class MapViewModel: SecureCoreToggleHandler {
    let alertService: AlertService
    var vpnGateway: VpnGatewayProtocol
    
    var activeView: ServerType = .standard
    
    private let appStateManager: AppStateManager
    private let vpnKeychain: VpnKeychainProtocol
    let propertiesManager: PropertiesManagerProtocol
    
    private var countryExitAnnotations: [CountryAnnotationViewModel] = []
    private var secureCoreEntryAnnotations: Set<SecureCoreEntryCountryModel> = []
    private var secureCoreConnections: [ConnectionViewModel] = []
    private var activeConnection: ConnectionViewModel?
    private let connectionStatusService: ConnectionStatusService
    
    var secureCoreOn: Bool {
        activeView == .secureCore
    }
    
    var annotations: [AnnotationViewModel] {
        [AnnotationViewModel](countryExitAnnotations) + [SecureCoreEntryCountryModel](secureCoreEntryAnnotations)
    }
    
    var connections: [ConnectionViewModel] {
        var cons: [ConnectionViewModel] = []
        if let connection = activeConnection {
            cons.append(connection)
        }
        if secureCoreOn {
            // connected but not to a SC server
            if vpnGateway.connection == .connected, let activeServer = appStateManager.activeConnection()?.server {
                if activeServer.serverType == .standard {
                    cons.append(contentsOf: secureCoreConnections)
                }
            } else { // not connected
                cons.append(contentsOf: secureCoreConnections)
            }
        }
        
        return cons
    }
    
    var enableViewToggle: Bool {
        vpnGateway.connection != .connecting
    }
    
    var contentChanged: (() -> Void)?
    var connectionStateChanged: (() -> Void)?
    var reorderAnnotations: (() -> Void)?

    init(
        appStateManager: AppStateManager,
        alertService: AlertService, 
        vpnGateway: VpnGatewayProtocol,
        vpnKeychain: VpnKeychainProtocol,
        propertiesManager: PropertiesManagerProtocol,
        connectionStatusService: ConnectionStatusService
    ) {
        self.appStateManager = appStateManager
        self.alertService = alertService
        self.vpnGateway = vpnGateway
        self.vpnKeychain = vpnKeychain
        self.propertiesManager = propertiesManager
        self.connectionStatusService = connectionStatusService
        
        secureCoreConnections = []
        
        setStateOf(type: propertiesManager.serverTypeToggle)
        
        refreshAnnotations(forView: activeView)
        
        addObservers()
    }
    
    @objc func mapTapped() {
        for annotation in countryExitAnnotations {
            annotation.deselect()
        }
        
        for annotation in secureCoreEntryAnnotations {
            annotation.highlight(false)
        }
        
        reorderAnnotations?()
    }
    
    // MARK: - Private functions

    private func addObservers() {
        AppEvent.activeServerTypeChanged.subscribe(self, selector: #selector(activeServerTypeSet))
        AppEvent.connectionStateChanged.subscribe(self, selector: #selector(connectionChanged))
        AppEvent.planChanged.subscribe(self, selector: #selector(resetCurrentState))
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetCurrentState),
            name: ServerListUpdateNotification.name,
            object: nil
        )
    }
    
    private func refreshAnnotations(forView viewType: ServerType) {
        let vpnCredentials = try? vpnKeychain.fetchCached()
        let userTier = vpnCredentials?.maxTier ?? .paidTier

        countryExitAnnotations = exitAnnotations(type: viewType, userTier: userTier)
        
        switch viewType {
        case .standard, .p2p, .tor, .unspecified:
            secureCoreEntryAnnotations = []
        case .secureCore:
            secureCoreEntryAnnotations = secureCoreEntryAnnotations(userTier)
        }
    }
    
    private func exitAnnotations(type: ServerType, userTier: Int) -> [CountryAnnotationViewModel] {
        @Dependency(\.serverRepository) var repository
        let isMapConnectionDisabled = userTier.isFreeTier

        let featureFilter = VPNServerFilter.features(type.serverTypeFilter)
        let kindFilter = VPNServerFilter.kind(.country) // Exclude gateways

        let serverGroups = repository.getGroups(filteredBy: [featureFilter, kindFilter])
        return serverGroups.compactMap { group in
            makeAnnotationViewModel(
                countryGroup: group,
                isMapConnectionDisabled: isMapConnectionDisabled,
                userTier: userTier
            )
        }
    }

    private func makeAnnotationViewModel(
        countryGroup: ServerGroupInfo,
        isMapConnectionDisabled: Bool,
        userTier: Int
    ) -> CountryAnnotationViewModel? {
        guard case let .country(countryCode) = countryGroup.kind else {
            assertionFailure("We should have filtered out gateways, but we found a: \(countryGroup.kind)")
            return nil
        }

        let annotationViewModel = CountryAnnotationViewModel(
            countryCode: countryCode,
            groupInfo: countryGroup,
            serverType: activeView,
            vpnGateway: vpnGateway,
            appStateManager: appStateManager,
            enabled: isMapConnectionDisabled ? false : countryGroup.minTier <= userTier,
            alertService: alertService,
            connectionStatusService: connectionStatusService
        )

        if let oldAnnotationViewModel = countryExitAnnotations.first(where: { oldAnnotationViewModel -> Bool in
            return oldAnnotationViewModel.countryCode == annotationViewModel.countryCode
        }) {
            annotationViewModel.viewState = oldAnnotationViewModel.viewState
        }

        annotationViewModel.countryTapped = { [unowned self] tappedAnnotationViewModel in
            for annotation in countryExitAnnotations {
                if annotation !== tappedAnnotationViewModel {
                    annotation.deselect()
                }
            }

            for annotation in secureCoreEntryAnnotations {
                if let activeServer = appStateManager.activeConnection()?.server, vpnGateway.connection == .connected, tappedAnnotationViewModel.countryCode == activeServer.exitCountryCode, annotation.countryCode == activeServer.entryCountryCode {
                    annotation.highlight(true)
                } else {
                    annotation.highlight(false)
                }
            }

            reorderAnnotations?()
        }

        return annotationViewModel
    }

    private func secureCoreEntryAnnotations(_ userTier: Int) -> Set<SecureCoreEntryCountryModel> {
        var entryCountries = Set<SecureCoreEntryCountryModel>()

        let isSecureCore = VPNServerFilter.features(.secureCore)
        let isCountry = VPNServerFilter.kind(.country) // Exclude gateways

        @Dependency(\.serverRepository) var repository
        let secureCoreServers = repository.getServers(filteredBy: [isSecureCore, isCountry], orderedBy: .none)
        for server in secureCoreServers {
            var entryCountry = SecureCoreEntryCountryModel(
                appStateManager: appStateManager,
                countryCode: server.logical.entryCountryCode,
                location: LocationUtility.coordinate(forCountry: server.logical.entryCountryCode),
                vpnGateway: vpnGateway
            )
            if let oldEntry = entryCountries.first(where: { element -> Bool in return entryCountry == element }) {
                entryCountry = oldEntry
            }
            entryCountry.addExitCountryCode(server.logical.exitCountryCode)
            entryCountries.update(with: entryCountry)
        }

        let entriesArray = [SecureCoreEntryCountryModel](entryCountries)
        secureCoreConnections = entriesArray.enumerated().map({ (offset: Int, element: SecureCoreEntryCountryModel) -> ConnectionViewModel in
            return ConnectionViewModel(.connected, between: element, and: entriesArray[(offset + 1) % entriesArray.count])
        })

        return entryCountries
    }

    func setStateOf(type: ServerType) {
        activeView = type
        refreshAnnotations(forView: activeView)
        connectionChanged()
    }
    
    @objc private func activeServerTypeSet() {
        guard propertiesManager.serverTypeToggle != activeView else { return }
        
        resetCurrentState()
    }
    
    @objc private func resetCurrentState() {
        executeOnUIThread {
            self.setStateOf(type: self.propertiesManager.serverTypeToggle)
            self.contentChanged?()
        }
    }
    
    @objc private func connectionChanged() {
        if let activeServer = appStateManager.activeConnection()?.server, vpnGateway.connection == .connected {
            // draw connection line
            if let entryCountry = secureCoreEntryAnnotations.first(where: { element -> Bool in element.countryCode == activeServer.entryCountryCode }),
               let exitCountry = countryExitAnnotations.first(where: { element -> Bool in element.countryCode == activeServer.exitCountryCode }) {
                activeConnection = ConnectionViewModel(.connected, between: entryCountry, and: exitCountry)
                if exitCountry.viewState == .selected {
                    entryCountry.highlight(true)
                }
            } else {
                activeConnection = nil
            }
        } else {
            activeConnection = nil
            for annotation in secureCoreEntryAnnotations {
                annotation.highlight(false)
            }
        }
        
        connectionStateChanged?()
    }
}
