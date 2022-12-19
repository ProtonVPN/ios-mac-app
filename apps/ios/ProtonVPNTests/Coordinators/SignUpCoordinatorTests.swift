//
//  SignUpCoordinatortests.swift
//  ProtonVPN - Created on 10/09/2019.
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

import XCTest
import vpncore

class SignUpCoordinatorTests: XCTestCase {

    func testPlanSelectionIsFirstOption() {
        var planSelectionOpened = false
        var signupOpened = false
        
        let loginService = LoginServiceMock()
        loginService.callbackPresentSignup = { _ in
            signupOpened = true
        }
        let planService = PlanServiceMock()
        planService.callbackPresentPlanSelection = {
            planSelectionOpened = true
        }
        let appSessionManager = AppSessionManagerMock(sessionStatus: .notEstablished, loggedIn: false, sessionChanged: Notification.Name("sessionChanged"))
        let factory = CoordinatorFactory(appSessionManager: appSessionManager, loginService: loginService, planService: planService, storeKitStateChecker: StoreKitStateCheckerMock())
        let coordinator = SignUpCoordinator(factory: factory)
        
        XCTAssertFalse(planSelectionOpened)
        XCTAssertFalse(signupOpened)
        coordinator.start()
        XCTAssertTrue(planSelectionOpened, "Plan selection was not opened")
        XCTAssertFalse(signupOpened, "Signup was opened")
    }

    func testPlanPreselectedIfPaidBefore() {
        var planSelectionOpened = false
        var signupOpened = false
        var accountPlan: AccountPlan?
        
        let loginService = LoginServiceMock()
        loginService.callbackPresentRegistrationForm = { viewModel in
            signupOpened = true
            accountPlan = (viewModel as! SignUpFormViewModelMock).accountPlan
        }
        let planService = PlanServiceMock()
        planService.callbackPresentPlanSelection = {
            planSelectionOpened = true
        }
        let appSessionManager = AppSessionManagerMock(sessionStatus: .notEstablished, loggedIn: false, sessionChanged: Notification.Name("sessionChanged"))
        let stateChecker = StoreKitStateCheckerMock()
        stateChecker.accountPlan = .plus
        stateChecker.buyProcessRunning = true
        let factory = CoordinatorFactory(appSessionManager: appSessionManager, loginService: loginService, planService: planService, storeKitStateChecker: stateChecker)
        let coordinator = SignUpCoordinator(factory: factory)
        
        XCTAssertFalse(planSelectionOpened)
        XCTAssertFalse(signupOpened)
        coordinator.start()
        XCTAssertFalse(planSelectionOpened, "Plan selection was opened when it shouldn't")
        XCTAssertTrue(signupOpened, "Signup was not opened")
        XCTAssertTrue(accountPlan == .plus, "Wrong account plan selected")
    }

}

fileprivate class CoordinatorFactory: SignUpCoordinator.Factory {
    
    var appSessionManager: AppSessionManager
    var loginService: LoginService
    var planService: PlanService
    var storeKitStateChecker: StoreKitStateChecker

    init(appSessionManager: AppSessionManager, loginService: LoginService, planService: PlanService, storeKitStateChecker: StoreKitStateChecker) {
        self.appSessionManager = appSessionManager
        self.loginService = loginService
        self.planService = planService
        self.storeKitStateChecker = storeKitStateChecker
    }

    func makePlanSelectionSimpleViewModel(isDismissalAllowed: Bool, alertService: AlertService, planSelectionFinished: @escaping (AccountPlan) -> Void) -> PlanSelectionViewModel {
        return PlanSelectionSimpleViewModel(isDismissalAllowed: isDismissalAllowed, servicePlanDataService: ServicePlanDataServiceMock(), planSelectionFinished: planSelectionFinished, storeKitManager: StoreKitManagerMock(), alertService: alertService)
    }
    
    func makePlanSelectionWithPurchaseViewModel() -> PlanSelectionViewModel {
        return PlanSelectionWithPurchaseViewModel(appSessionManager: appSessionManager, planService: planService, alertService: AlertServiceEmptyStub(), servicePlanDataService: ServicePlanDataServiceMock(), storeKitManager: StoreKitManagerMock())
    }
    
    func makeLoginService() -> LoginService {
        return loginService
    }
    
    func makePlanService() -> PlanService {
        return planService
    }
    
    func makeSignUpFormViewModel(plan: AccountPlan) -> SignUpFormViewModel {
        let mock = SignUpFormViewModelMock()
        mock.accountPlan = plan
        return mock
    }
    
    func makeCoreAlertService() -> CoreAlertService {
        return AlertServiceEmptyStub()
    }
    
    func makeStoreKitManager() -> StoreKitManager {
        return StoreKitManagerMock()
    }
    
    func makeStoreKitStateChecker() -> StoreKitStateChecker {
        return storeKitStateChecker
    }
}

fileprivate class StoreKitStateCheckerMock: StoreKitStateChecker {
    
    public var buyProcessRunning = false
    public var accountPlan: AccountPlan?
    
    func isBuyProcessRunning() -> Bool {
        return buyProcessRunning
    }
    
    func planBuyStarted() -> AccountPlan? {
        return accountPlan
    }
        
}
