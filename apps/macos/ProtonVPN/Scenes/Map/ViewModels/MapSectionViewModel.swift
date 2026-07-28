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

import Combine
import CommonNetworking
import ComposableArchitecture
import Connection
import CoreLocation
import Dependencies
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Localization
import MapKit
import Persistence
import Sharing
import Strings
import VPNAppCore

// Refactor annotation O(n^2) grouping logic when number of secure core servers ever exceed this value
private let maximumSecureCoreServerCount = 512

struct AnnotationChange {
    let oldAnnotations: [CountryAnnotationViewModel]
    let newAnnotations: [CountryAnnotationViewModel]
}

class MapSectionViewModel {
    private let countrySelected = Notification.Name("MapSectionViewModelCountrySelected")
    private let scEntryCountrySelected = Notification.Name("MapSectionViewModelScEntryCountrySelected")
    private let scExitCountrySelected = Notification.Name("MapSectionViewModelScExitCountrySelected")
    @Dependency(\.credentialsProvider) private var credentialsProvider
    @SharedReader(.secureCoreToggle) private var secureCoreToggle: Bool
    @SharedReader(.connectionState) private var connectionState: ConnectionState
    @SharedReader(.connectionProtocol) private var connectionProtocol: ConnectionProtocol
    private var cancellables = Set<AnyCancellable>()

    var contentChanged: ((AnnotationChange) -> Void)?
    var connectionsChanged: (([ConnectionViewModel]) -> Void)?

    private var activeView: ServerType = .standard

    var annotations: [CountryAnnotationViewModel] = []
    var connections: [ConnectionViewModel] = []

    init() {
        $connectionState
            .publisher
            .sink { [weak self] state in
                self?.connectionStateChanged(state)
            }
            .store(in: &cancellables)
        $secureCoreToggle
            .publisher
            .sink { [weak self] isSecureCore in
                guard let self else { return }
                setView(isSecureCore ? .secureCore : .standard)
            }
            .store(in: &cancellables)
        $connectionProtocol.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.resetCurrentState() }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self, selector: #selector(resetCurrentState), name: ServerListUpdateNotification.name, object: nil)

        self.activeView = ServerType.current
        self.annotations = annotations(forView: activeView)
        self.connections = connections(forView: activeView)
    }

    // MARK: - Private functions

    private func connectionStateChanged(_ state: ConnectionState) {
        if let serverType = connectedServerType(for: state), serverType != activeView {
            setView(serverType)
        }

        for annotation in annotations {
            annotation.appStateChanged(to: state)
        }

        updateConnections()
    }

    private func connectedServerType(for state: ConnectionState) -> ServerType? {
        guard case let .connected(tunnelConfig, connectionData) = state else {
            return nil
        }
        let server = connectionData.currentPeer

        if server.logical.feature.contains(.secureCore) {
            return .secureCore
        }
        if server.logical.feature.contains(.tor) {
            return .tor
        }
        if server.logical.feature.contains(.p2p) {
            return .p2p
        }

        let spec = tunnelConfig.connectionSpec
        if case .secureCore = spec.location {
            return .secureCore
        }
        if spec.features.contains(.tor) {
            return .tor
        }
        if spec.features.contains(.p2p) {
            return .p2p
        }

        return .standard
    }

    @objc
    private func resetCurrentState() {
        executeOnUIThread {
            self.setView(self.activeView)
            self.updateConnections()
        }
    }

    private func updateConnections() {
        connections = connections(forView: activeView)

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            connectionsChanged?(connections)
        }
    }

    private func setView(_ newView: ServerType) {
        let oldAnnotations = annotations
        activeView = newView
        annotations = annotations(forView: activeView)
        let contentChange = AnnotationChange(oldAnnotations: oldAnnotations, newAnnotations: annotations)

        connections = connections(forView: activeView)

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            contentChanged?(contentChange)
        }
    }

    private func annotations(forView viewType: ServerType) -> [CountryAnnotationViewModel] {
        let userTier = credentialsProvider.tier

        return switch viewType {
        case .standard, .p2p, .tor, .unspecified:
            standardAnnotations(userTier)
        case .secureCore:
            secureCoreAnnotations(userTier)
        }
    }

    private func connections(forView viewType: ServerType) -> [ConnectionViewModel] {
        switch viewType {
        case .standard, .p2p, .tor, .unspecified:
            standardConnections()
        case .secureCore:
            secureCoreConnections()
        }
    }

    private func standardAnnotations(_ userTier: VpnTier) -> [CountryAnnotationViewModel] {
        @Dependency(\.serverRepository) var repository
        let isCountry = VPNServerFilter.kind(.country)
        let isNotSecureCore = VPNServerFilter.features(.standard)
        let countryGroups = repository.getGroups(filteredBy: [isCountry, isNotSecureCore], groupedBy: .serverType)
        return countryGroups.compactMap { group in
            guard case let .country(code) = group.kind else {
                assertionFailure("Gateways should have been filtered out but we got: \(group.kind)")
                return nil
            }
            return StandardCountryAnnotationViewModel(
                countryCode: code,
                minTier: group.minTier,
                userTier: userTier,
                coordinate: LocationUtility.coordinate(forCountry: code)
            )
        }
    }

    private func secureCoreEntrySelectionChange(_ selection: SCEntryCountrySelection) {
        for annotation in annotations {
            if let annotation = annotation as? SCEntryCountryAnnotationViewModel {
                if annotation.countryCode != selection.countryCode {
                    annotation.secureCoreSelected(selection)
                }
            }
        }

        updateConnections()
    }

    private func secureCoreExitSelectionChange(_ selection: SCExitCountrySelection) {
        for annotation in annotations {
            if let annotation = annotation as? SCEntryCountryAnnotationViewModel {
                if annotation.countryCode != selection.countryCode {
                    annotation.countrySelected(selection)
                }
            }
        }

        updateConnections()
    }

    private func fetchSecureCoreServers() -> [ServerInfo] {
        @Dependency(\.serverRepository) var repository
        let isSecureCore = VPNServerFilter.features(.secureCore)
        let isCountry = VPNServerFilter.kind(.country)
        return repository.getServers(filteredBy: [isSecureCore, isCountry], orderedBy: .none)
    }

    /// Let's refactor this during the redesign, or when we trigger the secure core server count assertion.
    private func secureCoreAnnotations(_ userTier: VpnTier) -> [CountryAnnotationViewModel] {
        let secureCoreServers = fetchSecureCoreServers()
        assert(secureCoreServers.count < maximumSecureCoreServerCount, "Refactor O(n^2) grouping algorithm")

        let exitCountryCodes = secureCoreServers.map(\.logical.exitCountryCode).uniqued
        let entryCountryCodes = secureCoreServers.map(\.logical.entryCountryCode).uniqued

        let exitCountryAnnotations: [CountryAnnotationViewModel] = exitCountryCodes.map { exitCountryCode in
            let servers = secureCoreServers.filter { $0.logical.exitCountryCode == exitCountryCode }

            let annotation = SCExitCountryAnnotationViewModel(
                countryCode: exitCountryCode,
                minTier: servers.map(\.logical.tier).min() ?? .free,
                servers: servers,
                userTier: userTier,
                coordinate: LocationUtility.coordinate(forCountry: exitCountryCode)
            )
            annotation.externalViewStateChange = { [weak self] selection in
                self?.secureCoreExitSelectionChange(selection)
            }
            return annotation
        }

        // e.g [CH: [CA, UK, US], IS: [DE, LT]]
        let entryToExitCountryCodeMap = entryCountryCodes.reduce(into: [:]) { map, entryCode in
            map[entryCode] = secureCoreServers
                .filter { $0.logical.entryCountryCode == entryCode }
                .map(\.logical.exitCountryCode)
        }

        let entryCountryAnnotations: [CountryAnnotationViewModel] = entryToExitCountryCodeMap.map { entry, exits in
            let annotation = SCEntryCountryAnnotationViewModel(
                countryCode: entry,
                exitCountryCodes: exits,
                coordinate: LocationUtility.coordinate(forCountry: entry)
            )
            annotation.externalViewStateChange = { [weak self] selection in
                self?.secureCoreEntrySelectionChange(selection)
            }
            return annotation
        }

        return entryCountryAnnotations + exitCountryAnnotations
    }

    private func standardConnections() -> [ConnectionViewModel] {
        annotations.filter { annotation -> Bool in
            guard let annotation = annotation as? StandardCountryAnnotationViewModel else { return false }
            return annotation.isConnected
        }.map { annotation -> ConnectionViewModel in
            return ConnectionViewModel(.connected, fromHomeTo: annotation)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func secureCoreConnections() -> [ConnectionViewModel] {
        var secureCores = [SCEntryCountryAnnotationViewModel]()
        var selectedAnnotation: CountryAnnotationViewModel?
        var connectedAnnotation: CountryAnnotationViewModel?
        for annotation in annotations {
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

        if let connectedAnnotation {
            if let exitAnnotation = connectedAnnotation as? SCExitCountryAnnotationViewModel {
                for annotation in annotations {
                    if let annotation = annotation as? SCEntryCountryAnnotationViewModel,
                       annotation.isConnected {
                        connections.append(ConnectionViewModel(.connected, between: exitAnnotation, and: annotation))
                        connections.append(ConnectionViewModel(.connected, fromHomeTo: annotation))
                    }
                }
            }
        }
        if let selectedAnnotation {
            if let entryAnnotation = selectedAnnotation as? SCEntryCountryAnnotationViewModel {
                connections.append(ConnectionViewModel(.proposed, fromHomeTo: entryAnnotation))

                for code in entryAnnotation.exitCountryCodes {
                    for annotation in annotations {
                        if let serverAnnotation = annotation as? SCExitCountryAnnotationViewModel,
                           serverAnnotation.matches(code) {
                            connections.append(ConnectionViewModel(.proposed, between: entryAnnotation, and: annotation))
                        }
                    }
                }
            } else if let exitAnnotation = selectedAnnotation as? SCExitCountryAnnotationViewModel {
                for annotation in annotations {
                    if let annotation = annotation as? SCEntryCountryAnnotationViewModel,
                       annotation.exitCountryCodes.contains(exitAnnotation.countryCode) {
                        connections.append(ConnectionViewModel(.proposed, between: exitAnnotation, and: annotation))
                        connections.append(ConnectionViewModel(.proposed, fromHomeTo: annotation))
                    }
                }
            }
        }

        if connectedAnnotation == nil, selectedAnnotation == nil {
            for (index, element) in secureCores.enumerated() {
                connections.append(ConnectionViewModel(.connected, between: element, and: secureCores[(index + 1) % secureCores.count]))
            }
        }

        return connections
    }
    // swiftlint:enable cyclomatic_complexity
}

enum LocationUtility {
    static func coordinate(forCountry countryCode: String) -> CLLocationCoordinate2D {
        guard let coordinate = MapConstants.countryCoordinates[countryCode.uppercased()] else {
            log.warning("Missing map coordinate for country code: \(countryCode)")
            SentryHelper.shared?.log(message: "Missing map coordinate for country code: \(countryCode)")
            return CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0)
        }
        return coordinate
    }
}
