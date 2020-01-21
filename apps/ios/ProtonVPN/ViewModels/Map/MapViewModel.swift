//
//  MapsViewModel.swift
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
import vpncore

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
    var vpnGateway: VpnGatewayProtocol?
    
    var activeView: ServerType = .standard
    
    private let appStateManager: AppStateManager
    private let loginService: LoginService
    private let serverManager: ServerManager
    private let vpnKeychain: VpnKeychainProtocol
    
    private var countryExitAnnotations: [CountryAnnotationViewModel] = []
    private var secureCoreEntryAnnotations: Set<SecureCoreEntryCountryModel> = []
    private var secureCoreConnections: [ConnectionViewModel] = []
    private var activeConnection: ConnectionViewModel?
    
    var secureCoreOn: Bool {
        return activeView == .secureCore
    }
    
    var annotations: [AnnotationViewModel] {
        return [AnnotationViewModel](countryExitAnnotations) + [SecureCoreEntryCountryModel](secureCoreEntryAnnotations)
    }
    
    var connections: [ConnectionViewModel] {
        var cons: [ConnectionViewModel] = []
        if let connection = activeConnection {
            cons.append(connection)
        }
        if secureCoreOn {
            // connected but not to a SC server
            if let vpnGateway = vpnGateway, vpnGateway.connection == .connected, let activeServer = vpnGateway.activeServer {
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
        return vpnGateway == nil || vpnGateway?.connection != .connecting
    }
    
    var contentChanged: (() -> Void)?
    var connectionStateChanged: (() -> Void)?
    var reorderAnnotations: (() -> Void)?
    
    init(appStateManager: AppStateManager, loginService: LoginService, alertService: AlertService, serverStorage: ServerStorage, vpnGateway: VpnGatewayProtocol?, vpnKeychain: VpnKeychainProtocol) {
        self.appStateManager = appStateManager
        self.loginService = loginService
        self.alertService = alertService
        self.serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.max, serverStorage: serverStorage)
        self.vpnGateway = vpnGateway
        self.vpnKeychain = vpnKeychain
        
        self.secureCoreConnections = []
        
        setStateOf(type: vpnGateway?.activeServerType ?? .standard)
        
        refreshAnnotations(forView: activeView)
        
        addObservers()
    }
    
    @objc func mapTapped() {
        countryExitAnnotations.forEach { (annotation) in
            annotation.deselect()
        }
        
        secureCoreEntryAnnotations.forEach { (annotation) in
            annotation.hightlight(false)
        }
        
        reorderAnnotations?()
    }
    
    // MARK: - Private functions
    private func addObservers() {
        guard vpnGateway != nil else { return }
        
        NotificationCenter.default.addObserver(self, selector: #selector(activeServerTypeSet),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetCurrentState),
                                               name: serverManager.contentChanged, object: nil)
    }
    
    private func refreshAnnotations(forView viewType: ServerType) {
        let vpnCredentials = try? vpnKeychain.fetch()
        let userTier = vpnCredentials?.maxTier ?? CoreAppConstants.VpnTiers.visionary
        
        countryExitAnnotations = exitAnnotations(type: viewType, userTier: userTier)
        
        switch viewType {
        case .standard, .p2p, .tor, .unspecified:
            secureCoreEntryAnnotations = []
        case .secureCore:
            secureCoreEntryAnnotations = secureCoreEntryAnnotations(userTier)
        }
    }
    
    private func exitAnnotations(type: ServerType, userTier: Int) -> [CountryAnnotationViewModel] {
        return serverManager.grouping(for: type).map {
            let annotationViewModel = CountryAnnotationViewModel(countryModel: $0.0, servers: $0.1, serverType: activeView, vpnGateway: vpnGateway, enabled: $0.0.lowestTier <= userTier, alertService: alertService, loginService: loginService)
            
            if let oldAnnotationViewModel = countryExitAnnotations.first(where: { (oldAnnotationViewModel) -> Bool in
                return oldAnnotationViewModel.countryCode == annotationViewModel.countryCode
            }) {
                annotationViewModel.viewState = oldAnnotationViewModel.viewState
            }
            
            annotationViewModel.countryTapped = { [unowned self] tappedAnnotationViewModel in
                self.countryExitAnnotations.forEach({ (annotation) in
                    if annotation !== tappedAnnotationViewModel {
                        annotation.deselect()
                    }
                })
                
                if let vpnGateway = self.vpnGateway {
                    self.secureCoreEntryAnnotations.forEach({ (annotation) in
                        if let activeServer = vpnGateway.activeServer, vpnGateway.connection == .connected, tappedAnnotationViewModel.countryCode == activeServer.exitCountryCode, annotation.countryCode == activeServer.entryCountryCode {
                            annotation.hightlight(true)
                        } else {
                            annotation.hightlight(false)
                        }
                    })
                }
                
                self.reorderAnnotations?()
            }
            return annotationViewModel
        }
    }
    
    private func secureCoreEntryAnnotations(_ userTier: Int) -> Set<SecureCoreEntryCountryModel> {
        var entryCountries = Set<SecureCoreEntryCountryModel>()
        serverManager.grouping(for: .secureCore).forEach { group in
            group.1.forEach { (server) in
                var entryCountry = SecureCoreEntryCountryModel(countryCode: server.entryCountryCode, location: LocationUtility.coordinate(forCountry: server.entryCountryCode))
                if let oldEntry = entryCountries.first(where: { (element) -> Bool in return entryCountry == element }) {
                    entryCountry = oldEntry
                }
                entryCountry.addExitCountryCode(server.exitCountryCode)
                entryCountries.update(with: entryCountry)
            }
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
        guard let vpnGateway = vpnGateway,
            vpnGateway.activeServerType != activeView else { return }
        
        resetCurrentState()
    }
    
    @objc private func resetCurrentState() {
        guard let vpnGateway = vpnGateway else {
            return
        }
        
        setStateOf(type: vpnGateway.activeServerType)
        contentChanged?()
    }
    
    @objc private func connectionChanged() {
        if let vpnGateway = vpnGateway, let activeServer = vpnGateway.activeServer, vpnGateway.connection == .connected {
            
            // draw connection line
            if let entryCountry = secureCoreEntryAnnotations.first(where: { (element) -> Bool in element.countryCode == activeServer.entryCountryCode }),
                let exitCountry = countryExitAnnotations.first(where: { (element) -> Bool in element.countryCode == activeServer.exitCountryCode }) {
                activeConnection = ConnectionViewModel(.connected, between: entryCountry, and: exitCountry)
                if exitCountry.viewState == .selected {
                    entryCountry.hightlight(true)
                }
            } else {
                activeConnection = nil
            }
        } else {
            activeConnection = nil
            secureCoreEntryAnnotations.forEach { (annotation) in
                annotation.hightlight(false)
            }
        }
        
        connectionStateChanged?()
    }
}
