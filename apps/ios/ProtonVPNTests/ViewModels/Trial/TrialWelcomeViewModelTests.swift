//
//  TrialWelcomeTest.swift
//  ProtonVPN - Created on 01.07.19.
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

class TrialWelcomeViewModelTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPlus1SecondTrial() {
        let nowPlus1Day = Date(timeInterval: 1 + 0.5, since: Date())
        let viewModel = TrialWelcomeViewModel(expiration: nowPlus1Day, planService: PlanServiceMock(), planChecker: PlanUpgradeCheckerEmptyStub())
        let actualString = viewModel.timeRemainingAttributedString().string
        let expectedString = "0 days, 0 hours, 0 minutes"
        
        XCTAssert(expectedString == actualString)
    }
    
    func testPlus1MinuteTrial() {
        let nowPlus1Day = Date(timeInterval: 60 + 0.5, since: Date())
        let viewModel = TrialWelcomeViewModel(expiration: nowPlus1Day, planService: PlanServiceMock(), planChecker: PlanUpgradeCheckerEmptyStub())
        let actualString = viewModel.timeRemainingAttributedString().string
        let expectedString = "0 days, 0 hours, 1 minute"
        
        XCTAssert(expectedString == actualString)
    }
    
    func testPlus1DayTrial() {
        let nowPlus1Day = Date(timeInterval: 60 * 60 * 24 + 0.5, since: Date())
        let viewModel = TrialWelcomeViewModel(expiration: nowPlus1Day, planService: PlanServiceMock(), planChecker: PlanUpgradeCheckerEmptyStub())
        let actualString = viewModel.timeRemainingAttributedString().string
        let expectedString = "1 day, 0 hours, 0 minutes"
        
        XCTAssert(expectedString == actualString)
    }
    
    func testPlus366DaysTrial() {
        let nowPlus1Day = Date(timeInterval: 60 * 60 * 24 * 366 + 0.5, since: Date())
        let viewModel = TrialWelcomeViewModel(expiration: nowPlus1Day, planService: PlanServiceMock(), planChecker: PlanUpgradeCheckerEmptyStub())
        let actualString = viewModel.timeRemainingAttributedString().string
        let expectedString = "366 days, 0 hours, 0 minutes"
        
        XCTAssert(expectedString == actualString)
    }
}
