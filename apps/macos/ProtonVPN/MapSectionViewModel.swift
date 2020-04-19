//
//  MapSectionViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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

struct AnnotationChange {
    
    let oldAnnotations: [CountryAnnotationViewModel]
    let newAnnotations: [CountryAnnotationViewModel]
}

protocol MapSectionViewModelFactory {
    func makeMapSectionViewModel(viewToggle: Notification.Name) -> MapSectionViewModel
}

extension DependencyContainer: MapSectionViewModelFactory {
    func makeMapSectionViewModel(viewToggle: Notification.Name) -> MapSectionViewModel {
        return MapSectionViewModel(appStateManager: makeAppStateManager(),
                                   propertiesManager: makePropertiesManager(),
                                   vpnGateway: makeVpnGateway(),
                                   navService: makeNavigationService(),
                                   vpnKeychain: makeVpnKeychain(),
                                   viewToggle: viewToggle,
                                   alertService: makeCoreAlertService())
    }
}

class MapSectionViewModel {
    
    private let countrySelected = Notification.Name("MapSectionViewModelCountrySelected")
    private let scEntryCountrySelected = Notification.Name("MapSectionViewModelScEntryCountrySelected")
    private let scExitCountrySelected = Notification.Name("MapSectionViewModelScExitCountrySelected")
    private let serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.max, serverStorage: ServerStorageConcrete())
    private let appStateManager: AppStateManager
    private let vpnGateway: VpnGatewayProtocol
    private let navService: NavigationService
    private let vpnKeychain: VpnKeychainProtocol
    private let propertiesManager: PropertiesManagerProtocol
    private let alertService: CoreAlertService
    
    var contentChanged: ((AnnotationChange) -> Void)?
    var connectionsChanged: (([ConnectionViewModel]) -> Void)?
    
    private var activeView: ServerType = .standard
    
    var annotations: [CountryAnnotationViewModel] = []
    var connections: [ConnectionViewModel] = []
    
    init(appStateManager: AppStateManager, propertiesManager:PropertiesManagerProtocol,
         vpnGateway: VpnGatewayProtocol, navService: NavigationService, vpnKeychain: VpnKeychainProtocol,
         viewToggle: Notification.Name, alertService: CoreAlertService) {
        
        self.appStateManager = appStateManager
        self.propertiesManager = propertiesManager
        self.vpnGateway = vpnGateway
        self.navService = navService
        self.vpnKeychain = vpnKeychain
        self.alertService = alertService
        
        NotificationCenter.default.addObserver(self, selector: #selector(appStateChanged),
                                               name: appStateManager.stateChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewToggled(_:)),
                                               name: viewToggle, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetCurrentState),
                                               name: serverManager.contentChanged, object: nil)
        
        activeView = propertiesManager.serverTypeToggle
        annotations = annotations(forView: activeView)
        connections = connections(forView: activeView)
    }
    
    // MARK: - Private functions
    @objc private func appStateChanged() {
        if appStateManager.state.isConnected,
            let serverType = appStateManager.activeConnection()?.server.serverType, serverType != activeView {
            setView(serverType)
        }
        
        annotations.forEach { (annotation) in
            annotation.appStateChanged()
        }
        
        updateConnections()
    }
    
    @objc private func viewToggled(_ notification: Notification) {
        if let newView = notification.object as? ServerType, newView != activeView {
            setView(newView)
        }
    }
    
    @objc private func resetCurrentState() {
        setView(activeView)
        updateConnections()
    }
    
    private func updateConnections() {
        connections = connections(forView: activeView)

        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            self.connectionsChanged?(self.connections)
        }
    }
    
    private func setView(_ newView: ServerType) {
        let oldAnnotations = annotations
        activeView = newView
        annotations = annotations(forView: activeView)
        let contentChange = AnnotationChange(oldAnnotations: oldAnnotations, newAnnotations: annotations)
        
        connections = connections(forView: activeView)
        
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            self.contentChanged?(contentChange)
        }
        
    }
    
    private func annotations(forView viewType: ServerType) -> [CountryAnnotationViewModel] {
        do {
            let vpnCredentials = try vpnKeychain.fetch()
            let userTier = vpnCredentials.maxTier
            
            let annotations: [CountryAnnotationViewModel]
            switch viewType {
            case .standard, .p2p, .tor, .unspecified:
                annotations = standardAnnotations(userTier)
            case .secureCore:
                annotations = secureCoreAnnotations(userTier)
            }
            return annotations
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
            return []
        }
    }
    
    private func connections(forView viewType: ServerType) -> [ConnectionViewModel] {
        let connections: [ConnectionViewModel]
        switch viewType {
        case .standard, .p2p, .tor, .unspecified:
            connections = standardConnections()
        case .secureCore:
            connections = secureCoreConnections()
        }
        return connections
    }
    
    private func standardAnnotations(_ userTier: Int) -> [CountryAnnotationViewModel] {
        return serverManager.grouping(for: .standard).map {
            let annotation = StandardCountryAnnotationViewModel(appStateManager: appStateManager,
                                                                      vpnGateway: vpnGateway,
                                                                     country: $0.0,
                                                                     userTier: userTier,
                                                                   coordinate: $0.0.location)
            return annotation
        }
    }
    
    private func secureCoreEntrySelectionChange(_ selection: SCEntryCountrySelection) {
        annotations.forEach({ (annotation) in
            if let annotation = annotation as? SCEntryCountryAnnotationViewModel {
                if annotation.countryCode != selection.countryCode {
                    annotation.secureCoreSelected(selection)
                }
            }
        })
        
        updateConnections()
    }
    
    private func secureCoreExitSelectionChange(_ selection: SCExitCountrySelection) {
        annotations.forEach({ (annotation) in
            if let annotation = annotation as? SCEntryCountryAnnotationViewModel {
                if annotation.countryCode != selection.countryCode {
                    annotation.countrySelected(selection)
                }
            }
        })
        
        updateConnections()
    }
    
    private func secureCoreAnnotations(_ userTier: Int) -> [CountryAnnotationViewModel] {
        let exitCountries = serverManager.grouping(for: .secureCore).map {
            let annotation = SCExitCountryAnnotationViewModel(appStateManager: appStateManager,
                                                                                  vpnGateway: vpnGateway,
                                                                                     country: $0.0,
                                                                                     servers: $0.1,
                                                                                    userTier: userTier,
                                                                                  coordinate: $0.0.location)
            annotation.externalViewStateChange = { [weak self] selection in
                guard let `self` = self else { return }
                self.secureCoreExitSelectionChange(selection)
            }
            return annotation
        } as [CountryAnnotationViewModel]
        
        var scEntryCountries: [String: [String]] = [:]
        for group in serverManager.grouping(for: .secureCore) {
            for server in group.1 where server.isSecureCore {
                if scEntryCountries[server.entryCountryCode] != nil {
                    scEntryCountries[server.entryCountryCode]!.append(server.exitCountryCode)
                } else {
                    scEntryCountries[server.entryCountryCode] = [server.exitCountryCode]
                }
            }
        }
        
        let entryCountries = scEntryCountries.map {
            let annotation = SCEntryCountryAnnotationViewModel(appStateManager: appStateManager,
                                                                                   countryCode: $0,
                                                                              exitCountryCodes: $1,
                                                                                    coordinate: LocationUtility.coordinate(forCountry: $0))
            annotation.externalViewStateChange = { [weak self] selection in
                guard let `self` = self else { return }
                self.secureCoreEntrySelectionChange(selection)
            }
            return annotation
        } as [CountryAnnotationViewModel]
        
        return entryCountries + exitCountries
    }
    
    private func standardConnections() -> [ConnectionViewModel] {
        return annotations.filter({ (annotation) -> Bool in
            guard let annotation = annotation as? StandardCountryAnnotationViewModel else { return false }
            return annotation.isConnected
        }).map({ (annotation) -> ConnectionViewModel in
            return ConnectionViewModel(.connected, fromHomeTo: annotation)
        })
    }
    
    // swiftlint:disable cyclomatic_complexity
    private func secureCoreConnections() -> [ConnectionViewModel] {
        var secureCores = [SCEntryCountryAnnotationViewModel]()
        var selectedAnnotation: CountryAnnotationViewModel?
        var connectedAnnotation: CountryAnnotationViewModel?
        annotations.forEach { (annotation) in
            if let entryAnnotation = annotation as? SCEntryCountryAnnotationViewModel {
                secureCores.append(entryAnnotation)
                if entryAnnotation.state == .hovered {
                    selectedAnnotation = entryAnnotation
                }
            } else if let exitAnnotation = annotation as? SCExitCountryAnnotationViewModel {
                if exitAnnotation.isConnected {
                    connectedAnnotation = exitAnnotation
                }
                if exitAnnotation.state == .hovered {
                    selectedAnnotation = exitAnnotation
                }
            }
        }
        
        var connections = [ConnectionViewModel]()
        
        if let connectedAnnotation = connectedAnnotation {
            if let exitAnnotation = connectedAnnotation as? SCExitCountryAnnotationViewModel {
                annotations.forEach({ (annotation) in
                    if let annotation = annotation as? SCEntryCountryAnnotationViewModel,
                       annotation.isConnected {
                        connections.append(ConnectionViewModel(.connected, between: exitAnnotation, and: annotation))
                        connections.append(ConnectionViewModel(.connected, fromHomeTo: annotation))
                    }
                })
            }
        }
        if let selectedAnnotation = selectedAnnotation {
            if let entryAnnotation = selectedAnnotation as? SCEntryCountryAnnotationViewModel {
                connections.append(ConnectionViewModel(.proposed, fromHomeTo: entryAnnotation))
                
                entryAnnotation.exitCountryCodes.forEach({ (code) in
                    annotations.forEach({ (annotation) in
                        if let serverAnnotation = annotation as? SCExitCountryAnnotationViewModel,
                           serverAnnotation.matches(code) {
                            connections.append(ConnectionViewModel(.proposed, between: entryAnnotation, and: annotation))
                        }
                    })
                })
            } else if let exitAnnotation = selectedAnnotation as? SCExitCountryAnnotationViewModel {
                annotations.forEach({ (annotation) in
                    if let annotation = annotation as? SCEntryCountryAnnotationViewModel,
                       annotation.exitCountryCodes.contains(exitAnnotation.countryCode) {
                        connections.append(ConnectionViewModel(.proposed, between: exitAnnotation, and: annotation))
                        connections.append(ConnectionViewModel(.proposed, fromHomeTo: annotation))
                    }
                })
            }
        }
        
        if connectedAnnotation == nil && selectedAnnotation == nil {
            for (index, element) in secureCores.enumerated() {
                connections.append(ConnectionViewModel(.connected, between: element, and: secureCores[(index + 1) % secureCores.count]))
            }
        }
        
        return connections
    }
    // swiftlint:enable cyclomatic_complexity
    
}
