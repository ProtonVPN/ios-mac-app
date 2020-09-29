//
//  NetshieldSelectionViewModel.swift
//  ProtonVPN - Created on 2020-09-09.
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
import vpncore

class NetshieldSelectionViewModel {
    
    typealias Factory = VpnKeychainFactory & PlanServiceFactory
    private var factory: Factory
    
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var planService: PlanService = factory.makePlanService()
    
    /// Type currently selected or that was pre-set during creation
    public var selectedType: NetShieldType {
        didSet {
            onTypeChange(selectedType)
            onFinish?()
        }
    }
    
    /// Callback to watch for changes in selecd type
    public let onTypeChange: TypeChangeCallback
    typealias TypeChangeCallback = ((NetShieldType) -> Void)
    
    /// Used to approve selected type before setting it (for example when user has to be asked if she agrees to reconnect after change)
    public let shouldSelectNewValue: ApproveCallback
    public typealias ApproveCallback = ((NetShieldType, @escaping () -> Void) -> Void)
    
    /// Callback called when table has to be reloaded
    public var onDataChange: (() -> Void)?
    
    /// Called when screen has to be closed
    public var onFinish: (() -> Void)?
    
    public init(selectedType: NetShieldType, factory: Factory, shouldSelectNewValue: @escaping ApproveCallback, onTypeChange: @escaping TypeChangeCallback) {
        self.factory = factory
        self.selectedType = selectedType
        self.shouldSelectNewValue = shouldSelectNewValue
        self.onTypeChange = onTypeChange
    }
    
    var tableViewData: [TableViewSection] {
        let cells: [TableViewCellModel] = NetShieldType.allCases.map { type in
            if type.isUserTierTooLow(userTier) {
                return .invertedKeyValue(key: type.name, value: LocalizedString.upgrade, handler: { [weak self] in
                    self?.planService.presentPlanSelection()
                })
            }
            return .checkmarkStandard(title: type.name, checked: type == selectedType, handler: { [weak self] in
                self?.userSelected(type: type)
            })
        }
        return [TableViewSection(title: "", cells: cells)]
    }
 
    private func userSelected(type: NetShieldType) {
        onDataChange?() // Prevents two rows selected at a time
        shouldSelectNewValue(type) {
            self.selectedType = type
        }
    }
    
    private var userTier: Int {
        let tier: Int
        do {
            tier = try vpnKeychain.fetch().maxTier
        } catch {
            tier = CoreAppConstants.VpnTiers.free
        }
        return tier
    }
    
}
