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

final class PaidFeatureSelectionViewModel<T> where T: PaidFeature {

    typealias Factory = VpnKeychainFactory & PlanServiceFactory & AppSessionManagerFactory
    private var factory: Factory

    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var planService: PlanService = factory.makePlanService()

    var selectedFeature: T {
        didSet {
            onFeatureChange(selectedFeature)
            onFinish?()
        }
    }

    let onFeatureChange: FeatureChangeCallback
    typealias FeatureChangeCallback = ((T) -> Void)

    let shouldSelectNewValue: ApproveCallback
    typealias ApproveCallback = ((T, @escaping () -> Void) -> Void)

    var onDataChange: (() -> Void)?

    /// Called when screen has to be closed
    var onFinish: (() -> Void)?

    private let allFeatures: [T]

    let title: String

    public init(title: String, allFeatures: [T], selectedFeature: T, factory: Factory, shouldSelectNewValue: @escaping ApproveCallback, onFeatureChange: @escaping FeatureChangeCallback) {
        self.factory = factory
        self.selectedFeature = selectedFeature
        self.shouldSelectNewValue = shouldSelectNewValue
        self.onFeatureChange = onFeatureChange
        self.allFeatures = allFeatures
        self.title = title

        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: factory.makeAppSessionManager().dataReloaded, object: nil)
    }

    var tableViewData: [TableViewSection] {
        let cells: [TableViewCellModel] = allFeatures.map { feature in
            if feature.isUserTierTooLow(userTier) {
                return .attributedKeyValue(key: feature.name.attributed(withColor: .normalTextColor(), font: UIFont.systemFont(ofSize: 17)), value: LocalizedString.upgrade.attributed(withColor: .brandColor(), font: UIFont.systemFont(ofSize: 17)), handler: { [weak self] in
                    self?.planService.presentPlanSelection()
                })
            }
            return .checkmarkStandard(title: feature.name, checked: feature == selectedFeature, handler: { [weak self] in
                self?.userSelected(feature: feature)
                return true
            })
        }
        return [TableViewSection(title: "", showHeader: false, cells: cells)]
    }

    private func userSelected(feature: T) {
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
