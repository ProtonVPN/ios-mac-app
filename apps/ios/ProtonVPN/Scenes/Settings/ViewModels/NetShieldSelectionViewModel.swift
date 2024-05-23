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

import Dependencies

import Domain
import Strings
import Theme

import LegacyCommon
import VPNShared

final class NetShieldSelectionViewModel {
    typealias Factory = PlanServiceFactory & AppSessionManagerFactory & CoreAlertServiceFactory & NetShieldPropertyProviderFactory
    private var factory: Factory

    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()

    private var selectedFeature: NetShieldType

    let onSelect: ((NetShieldType, @escaping (Bool) -> Void) -> Void)

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

    public init(
        title: String,
        allFeatures: [NetShieldType],
        selectedFeature: NetShieldType,
        factory: Factory,
        onSelect: @escaping (NetShieldType, @escaping (Bool) -> Void) -> Void
    ) {
        self.factory = factory
        self.onSelect = onSelect
        self.allFeatures = allFeatures
        self.title = title
        self.selectedFeature = selectedFeature

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: factory.makeAppSessionManager().dataReloaded, object: nil)
    }

    var tableViewData: [TableViewSection] {
        if userIsEligibleForNetShield {
            return [netShieldSelectionSection]
        }
        return [netShieldUpsellSection, netShieldSelectionSection]
    }

    private var netShieldUpsellSection: TableViewSection {
        @Dependency(\.credentialsProvider) var credentialsProvider
        let upsellCell: TableViewCellModel
        if credentialsProvider.planName.isBusinessWithoutNetShield {
            upsellCell = TableViewCellModel.imageSubtitleImage(
                title: Localizable.netshieldBusinessUpsellTitle,
                subtitle: Localizable.netshieldBusinessUpsellSubtitle,
                leadingImage: Asset.netshieldSmall.image,
                trailingImage: Theme.Asset.icVpnBusinessBadge.image,
                handler: { }
            )
        } else {
            upsellCell = TableViewCellModel.imageSubtitle(
                title: Localizable.netshieldUpsellTitle,
                subtitle: Localizable.netshieldUpsellSubtitle,
                image: Asset.netshieldSmall.image,
                handler: { [weak self] in
                    self?.alertService.push(alert: NetShieldUpsellAlert())
                }
            )
        }
        return TableViewSection(title: "", showHeader: false, showSeparator: true, cells: [upsellCell])
    }

    private var netShieldSelectionSection: TableViewSection {
        let cells = allFeatures.map { cellModel(for: $0) }
            .appending({ [netShieldDescriptionCell] }, if: userIsEligibleForNetShield)
        return TableViewSection(title: "", showHeader: false, cells: cells)
    }

    private var netShieldDescriptionCell: TableViewCellModel {
        let attributedFeatureDescription = Localizable.netshieldFeatureDescription
            .attributed(withColor: UIColor.weakTextColor(), fontSize: 13)
        let cellText = NSMutableAttributedString(attributedString: attributedFeatureDescription)
            .add(link: Localizable.netshieldFeatureDescriptionAltLink, withUrl: CoreAppConstants.ProtonVpnLinks.netshieldSupport)
        return .attributedTooltip(text: cellText)
    }

    private func cellModel(for netShieldType: NetShieldType) -> TableViewCellModel {
        .checkmarkStandard(
            title: netShieldType.name,
            checked: netShieldType == selectedFeature,
            enabled: netShieldTypeAuthorizer(netShieldType).isAllowed,
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

    @objc private func reload() {
        onDataChange?()
    }
}
