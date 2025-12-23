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

import BugReport
import Dependencies
import Foundation
import LegacyCommon

protocol TroubleshootCoordinatorFactory {
    func makeTroubleshootCoordinator() -> TroubleshootCoordinator
}

extension DependencyContainer: TroubleshootCoordinatorFactory {
    func makeTroubleshootCoordinator() -> TroubleshootCoordinator {
        TroubleshootCoordinatorImplementation()
    }
}

protocol TroubleshootCoordinator: Coordinator {}

class TroubleshootCoordinatorImplementation: TroubleshootCoordinator {
    @Dependency(\.windowService) private var windowService

    public init() {}

    func start() {
        let controller = TroubleshootHostingViewController()
        windowService.present(modal: controller)
    }
}
