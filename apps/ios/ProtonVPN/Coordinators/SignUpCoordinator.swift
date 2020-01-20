//
//  SignUpCoordinator.swift
//  ProtonVPN - Created on 06/09/2019.
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

import UIKit
import vpncore

protocol SignUpCoordinatorFactory {
    func makeSignUpCoordinator() -> SignUpCoordinator
}

extension DependencyContainer: SignUpCoordinatorFactory {
    func makeSignUpCoordinator() -> SignUpCoordinator {
        return SignUpCoordinator(factory: self)
    }
}

class SignUpCoordinator: Coordinator {
    
    var finished: ((_ loggedIn: Bool) -> Void)?
    var cancelled: (() -> Void)?
    
    typealias Factory = PlanSelectionViewModelFactory & LoginServiceFactory & PlanServiceFactory & SignUpFormViewModelFactory
    private let factory: Factory
    private lazy var loginService: LoginService = factory.makeLoginService()
    private lazy var planService: PlanService = factory.makePlanService()
    
    private var plan: AccountPlan?
    
    init(factory: Factory) {
        self.factory = factory
    }
    
    func start() {
        let viewModel = factory.makePlanSelectionSimpleViewModel(isDismissalAllowed: true, planSelectionFinished: { plan in
            debugPrint("plan selected!", plan)
            self.selected(plan: plan)
        })
        viewModel.cancelled = {
            self.cancel()
        }
        planService.presentPlanSelection(viewModel: viewModel)
    }
        
    func cancel() {
        cancelled?()
    }
    
    private func selected(plan: AccountPlan) {
        self.plan = plan
        var viewModel = factory.makeSignUpFormViewModel(plan: plan)
        viewModel.loginRequested = {
            self.loginService.presentLogin()
        }
        viewModel.registrationCancelled = {
            self.cancel()
        }
        viewModel.registrationFinished = { loggedIn in
            self.finished?(loggedIn)
        }
        loginService.presentRegistrationForm(viewModel: viewModel)
    }
    
}
