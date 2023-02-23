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

import Foundation
import UIKit
import vpncore
import VPNShared

final class NetShieldSelectionViewModel {

    typealias Factory = VpnKeychainFactory & PlanServiceFactory & AppSessionManagerFactory & CoreAlertServiceFactory & NetShieldPropertyProviderFactory
    private var factory: Factory

    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()

    var selectedFeature: NetShieldType {
        didSet {
            onFeatureChange(selectedFeature)
            onFinish?()
        }
    }

    let onFeatureChange: ((NetShieldType) -> Void)

    let shouldSelectNewValue: ((NetShieldType, @escaping () -> Void) -> Void)

    var onDataChange: (() -> Void)?

    /// Called when screen has to be closed
    var onFinish: (() -> Void)?

    private let allFeatures: [NetShieldType]

    let title: String

    public init(title: String, allFeatures: [NetShieldType], selectedFeature: NetShieldType, factory: Factory, shouldSelectNewValue: @escaping (NetShieldType, @escaping () -> Void) -> Void, onFeatureChange: @escaping (NetShieldType) -> Void) {
        self.factory = factory
        self.selectedFeature = selectedFeature
        self.shouldSelectNewValue = shouldSelectNewValue
        self.onFeatureChange = onFeatureChange
        self.allFeatures = allFeatures
        self.title = title

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: factory.makeAppSessionManager().dataReloaded, object: nil)
    }

    var tableViewData: [TableViewSection] {
        if netShieldPropertyProvider.isUserEligibleForNetShield {
            return [netShieldSelectionSection]
        }
        return [netShieldUpsellSection, netShieldSelectionSection]
    }

    private var netShieldUpsellSection: TableViewSection {
        let upsellCell = TableViewCellModel.imageSubtitle(
            title: LocalizedString.netshieldUpsellTitle,
            subtitle: LocalizedString.netshieldUpsellSubtitle,
            image: UIImage(named: "netshield-small")!,
            handler: { [weak self] in self?.alertService.push(alert: NetShieldUpsellAlert()) }
        )
        return TableViewSection(title: "", showHeader: false, showSeparator: true, cells: [upsellCell])
    }

    private var netShieldSelectionSection: TableViewSection {
        let cells = allFeatures.map { cellModel(for: $0) }
            .appending({ [netShieldDescriptionCell] }, if: netShieldPropertyProvider.isUserEligibleForNetShield)
        return TableViewSection(title: "", showHeader: false, cells: cells)
    }

    private var netShieldDescriptionCell: TableViewCellModel {
        let attributedFeatureDescription = LocalizedString.netshieldFeatureDescription
            .attributed(withColor: UIColor.weakTextColor(), fontSize: 13)
        let cellText = NSMutableAttributedString(attributedString: attributedFeatureDescription)
            .add(link: LocalizedString.netshieldFeatureDescriptionAltLink, withUrl: CoreAppConstants.ProtonVpnLinks.netshieldSupport)
        return .attributedTooltip(text: cellText)
    }

    private func cellModel(for netShieldType: NetShieldType) -> TableViewCellModel {
        .checkmarkStandard(
            title: netShieldType.name,
            checked: netShieldType == selectedFeature,
            enabled: !netShieldType.isUserTierTooLow(userTier),
            handler: { [weak self] in
                self?.userSelected(feature: netShieldType)
                return true
            }
        )
    }

    private func userSelected(feature: NetShieldType) {
        onDataChange?() // Prevents two rows selected at a time
        shouldSelectNewValue(feature) {
            self.selectedFeature = feature
        }
    }

    private var userTier: Int {
        let tier: Int
        do {
            tier = try vpnKeychain.fetchCached().maxTier
        } catch {
            tier = CoreAppConstants.VpnTiers.free
        }
        return tier
    }

    @objc private func reload() {
        onDataChange?()
    }
}
