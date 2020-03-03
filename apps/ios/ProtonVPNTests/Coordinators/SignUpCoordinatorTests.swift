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

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPlanSelectionIsFirstOption() {
        var planSelectionOpened = false
        
        let loginService = LoginServiceMock()
        let planService = PlanServiceMock()
        planService.callbackPresentPlanSelection = {
            planSelectionOpened = true
        }
        let appSessionManager = AppSessionManagerMock(sessionStatus: .notEstablished, loggedIn: false, sessionChanged: Notification.Name("sessionChanged"))
        let factory = CoordinatorFactory(appSessionManager: appSessionManager, loginService: loginService, planService: planService)
        let coordinator = SignUpCoordinator(factory: factory)
        
        XCTAssertFalse(planSelectionOpened)
        coordinator.start()
        XCTAssertTrue(planSelectionOpened, "Plan selection was not opened")
    }

}

fileprivate class CoordinatorFactory: SignUpCoordinator.Factory {
    
    var appSessionManager: AppSessionManager
    var loginService: LoginService
    var planService: PlanService

    init(appSessionManager: AppSessionManager, loginService: LoginService, planService: PlanService) {
        self.appSessionManager = appSessionManager
        self.loginService = loginService
        self.planService = planService
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
        return SignUpFormViewModelMock()
    }
    
    func makeCoreAlertService() -> CoreAlertService {
        return AlertServiceEmptyStub()
    }
}
