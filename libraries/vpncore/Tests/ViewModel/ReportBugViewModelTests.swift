//
//  ReportBugViewModelTests.swift
//  vpncore - Created on 04/07/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import XCTest
import vpncore

class ReportBugViewModelTests: XCTestCase {
    
    var alertService: CoreAlertServiceMock!
    var propertiesManager: PropertiesManagerMock!
    
    override func setUp() {
        setUpNSCoding(withModuleName: "ProtonVPN")
        
        alertService = CoreAlertServiceMock()
        propertiesManager = PropertiesManagerMock()
    }

    override func tearDown() {
        alertService.alertAdded = nil
    }

    func testSendSuccessAndAlertDisplay() {
        let testDescription = "Test Description"
        let testEmail = "test@protonmail.com"
        let testCountry = "Testlandia"
        let testISP = "TestTelekom"
        
        let bundle = Bundle(for: type(of: self))
        let testFileToSend = bundle.url(forResource: "test_log_1", withExtension: "log")!
        let testFileToDelete = bundle.url(forResource: "test_log_2", withExtension: "log")!
        
        let expectationSuccess = XCTestExpectation(description: "Send report API endpoint is called")
        let expectationAlert = XCTestExpectation(description: "Success alert is shown")
        
        let alamofireWrapper = AlamofireWrapperMock()
        alamofireWrapper.nextUploadHandler = { request, params, files, success, failure in
            XCTAssert(params["Description"] == testDescription)
            XCTAssert(params["Email"] == testEmail)
            XCTAssert(params["Country"] == testCountry)
            XCTAssert(params["ISP"] == testISP)
            XCTAssert(files.contains(where: { $0.value == testFileToSend }))
            XCTAssert(!files.contains(where: { $0.value == testFileToDelete }))
            XCTAssert(files.count == 1)
            success(JSONDictionary())
        }
        
        alertService.alertAdded = {alert in
            XCTAssert(alert is BugReportSentAlert)
            alert.actions.first?.handler!()
            expectationAlert.fulfill()
        }
        
        let reportBugViewModel = ReportBugViewModel(os: "UnitTest", osVersion: "0.0.0", propertiesManager: propertiesManager, reportsApiService: ReportsApiService(alamofireWrapper: alamofireWrapper), alertService: alertService, vpnKeychain: VpnKeychainMock())
        
        XCTAssertFalse(reportBugViewModel.isSendingPossible)
        XCTAssert(reportBugViewModel.getEmail()!.isEmpty)
        
        reportBugViewModel.set(description: testDescription)
        reportBugViewModel.set(email: testEmail)
        reportBugViewModel.set(isp: testISP)
        reportBugViewModel.set(country: testCountry)
        
        reportBugViewModel.add(files: [testFileToDelete])
        reportBugViewModel.add(files: [testFileToSend])
        reportBugViewModel.remove(file: testFileToDelete)
        
        XCTAssert(reportBugViewModel.isSendingPossible)
        
        reportBugViewModel.send(success: {
            expectationSuccess.fulfill()
        }, error: {error in
            XCTAssert(false, "Error called while success was expected")
        })
        
        wait(for: [expectationAlert, expectationSuccess], timeout:2.0)
        
        XCTAssert(propertiesManager.reportBugEmail == testEmail)
        
        let reportBugViewModelWithPrefilledEmail = ReportBugViewModel(os: "UnitTest", osVersion: "0.0.0", propertiesManager: propertiesManager, reportsApiService: ReportsApiService(alamofireWrapper: alamofireWrapper), alertService: alertService, vpnKeychain: VpnKeychainMock())
        
        XCTAssertNotNil(reportBugViewModelWithPrefilledEmail.getEmail())
    }

    func testSendErrorFromAPI() {
        let expectationError = XCTestExpectation(description: "Error from API handler is called")
        
        let alamofireWrapper = AlamofireWrapperMock()
        alamofireWrapper.nextUploadHandler = { request, params, files, success, failure in
            XCTAssert(files.isEmpty)
            failure(ApiError.uknownError)
        }
        
        alertService.alertAdded = {alert in
            XCTAssert(false, "Alert shown")
        }
        
        let reportBugViewModel = ReportBugViewModel(os: "UnitTest", osVersion: "0.0.0", propertiesManager: propertiesManager, reportsApiService: ReportsApiService(alamofireWrapper: alamofireWrapper), alertService: alertService, vpnKeychain: VpnKeychainMock())
        
        reportBugViewModel.send(success: {
            XCTAssert(false, "Success called")
        }, error: {error in
            expectationError.fulfill()
        })
        
        wait(for: [expectationError], timeout:2.0)
    }
    
    func testCantAddFileTwice() {
        let reportBugViewModel = ReportBugViewModel(os: "UnitTest", osVersion: "0.0.0", propertiesManager: propertiesManager, reportsApiService: ReportsApiService(alamofireWrapper: AlamofireWrapperMock()), alertService: alertService, vpnKeychain: VpnKeychainMock())
        
        let bundle = Bundle(for: type(of: self))
        let testFile1 = bundle.url(forResource: "test_log_1", withExtension: "log")!
        let testFile2 = bundle.url(forResource: "test_log_2", withExtension: "log")!
        
        reportBugViewModel.add(files: [testFile1, testFile2])
        XCTAssert(reportBugViewModel.filesCount == 2)
        
        reportBugViewModel.add(files: [testFile1])
        XCTAssert(reportBugViewModel.filesCount == 2)        
    }
    
}
