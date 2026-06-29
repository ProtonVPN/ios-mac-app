//
//  Created on 07.02.2022.
//
//  Copyright (c) 2022 Proton AG
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

import Connection
import Dependencies
import Domain
import ExtensionManager
import Foundation
import LegacyCommon
import Sharing
import Strings
import Theme
import UIKit
import VPNAppCore
import VPNShared

final class NetShieldSelectionViewModel {
    @Dependency(\.coreAlertService) private var alertService
    @Dependency(\.upsellManager) private var upsellManager
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider

    @SharedReader(.appliedFeatures) private var appliedFeatures: AgentTunnelFeatures?
    @SharedReader(.connectionState) private var connectionState: ConnectionState

    private var selectedFeature: NetShieldType

    let onSelect: (NetShieldType, @escaping (Bool) -> Void) -> Void

    var onDataChange: (() -> Void)?

    /// Called when screen has to be closed
    var onFinish: (() -> Void)?

    private let allFeatures: [NetShieldType]

    let title: String

    @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider
    lazy var netShieldTypeAuthorizer: ((NetShieldType) -> FeatureAuthorizationResult) = featureAuthorizerProvider.authorizer(forSubFeatureOf: NetShieldType.self)

    /// Note: This will also return true if the netshield feature flag is disabled.
    /// This is to prevent the upsell dialog from being displayed in that specific case.
    var userIsEligibleForNetShield: Bool {
        NetShieldType.allCases.allSatisfy { !netShieldTypeAuthorizer($0).requiresUpgrade }
    }

    init(
        title: String,
        allFeatures: [NetShieldType],
        selectedFeature: NetShieldType,
        onSelect: @escaping (NetShieldType, @escaping (Bool) -> Void) -> Void
    ) {
        self.title = title
        self.allFeatures = allFeatures
        self.selectedFeature = selectedFeature
        self.onSelect = onSelect

        AppEvent.sessionManagerDataReloaded.subscribe(self, selector: #selector(reload))
    }

    var tableViewData: [TableViewSection] {
        if userIsEligibleForNetShield {
            return [netShieldSelectionSection]
        }
        return [netShieldUpsellSection, netShieldSelectionSection]
    }

    private var netShieldUpsellSection: TableViewSection {
        let upsellCell = TableViewCellModel.imageSubtitle(
            title: Localizable.netshieldUpsellTitle,
            subtitle: Localizable.netshieldUpsellSubtitle,
            image: UIImage(resource: .netshieldSmall),
            handler: { [weak self] in
                self?.upsellManager.present(.netShield)
            }
        )

        return TableViewSection(title: "", showHeader: false, showSeparator: true, cells: [upsellCell])
    }

    private var netShieldSelectionSection: TableViewSection {
        let visibleFeatures = allFeatures.filter { !netShieldTypeAuthorizer($0).featureDisabled }
        let cells = visibleFeatures.map { cellModel(for: $0) }
            .appending({ [netShieldDescriptionCell] }, if: userIsEligibleForNetShield)
        return TableViewSection(title: "", showHeader: false, cells: cells)
    }

    private var netShieldDescriptionCell: TableViewCellModel {
        let attributedFeatureDescription = Localizable.netshieldFeatureDescription
            .attributed(withColor: UIColor.weakTextColor(), fontSize: 13)
        let cellText = NSMutableAttributedString(attributedString: attributedFeatureDescription)
            .add(link: Localizable.netshieldFeatureDescriptionAltLink, withUrl: VPNLink.netshieldSupport.urlString)
        return .attributedTooltip(text: cellText)
    }

    /// Only non-nil when the server reports a different value.
    private var appliedNetShieldOverride: NetShieldType? {
        guard case .connected = connectionState,
              let applied = appliedFeatures?.netshield,
              applied != selectedFeature
        else { return nil }
        return applied
    }

    private func cellModel(for netShieldType: NetShieldType) -> TableViewCellModel {
        .checkmarkStandard(
            title: netShieldType.name,
            checked: netShieldType == selectedFeature,
            enabled: netShieldTypeAuthorizer(netShieldType).isAllowed,
            isOverridden: netShieldType == appliedNetShieldOverride,
            handler: { [weak self] in
                self?.userSelected(feature: netShieldType)
                return true
            }
        )
    }

    private func userSelected(feature: NetShieldType) {
        onDataChange?() // Prevents two rows selected at a time
        onSelect(feature) { [weak self] shouldSelect in
            if shouldSelect {
                self?.selectedFeature = feature
                self?.onFinish?()
            }
        }
    }

    @objc
    private func reload() {
        onDataChange?()
    }
}
