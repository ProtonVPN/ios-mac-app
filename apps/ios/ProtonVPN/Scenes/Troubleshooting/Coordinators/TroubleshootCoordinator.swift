//
//  TroubleshootCoordinator.swift
//  ProtonVPN - Created on 2020-04-24.
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
import LegacyCommon

protocol TroubleshootCoordinatorFactory {
    func makeTroubleshootCoordinator() -> TroubleshootCoordinator
}

extension DependencyContainer: TroubleshootCoordinatorFactory {
    func makeTroubleshootCoordinator() -> TroubleshootCoordinator {
        return TroubleshootCoordinatorImplementation(self)
    }
}

protocol TroubleshootCoordinator: Coordinator {
}

class TroubleshootCoordinatorImplementation: TroubleshootCoordinator {
    
    typealias Factory = WindowServiceFactory & TroubleshootViewModelFactory
    private let factory: Factory
    
    private lazy var windowService: WindowService = factory.makeWindowService()
    
    init(_ factory: Factory) {
        self.factory = factory
    }
    
    func start() {
        let troubleshootViewModel: TroubleshootViewModel = factory.makeTroubleshootViewModel()
        troubleshootViewModel.cancelled = {
            // *Strong* self, but as view model is released together with a view controller, this object is released too.
            // Has to be strong, because this coordinator is started from iOSAlertService which does not retain it.
            self.windowService.dismissModal { }
        }
        let controller = TroubleshootViewController(troubleshootViewModel)
        windowService.present(modal: controller)
    }
    
}
