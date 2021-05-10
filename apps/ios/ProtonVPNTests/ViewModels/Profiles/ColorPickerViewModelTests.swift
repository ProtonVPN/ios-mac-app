//
//  ColorPickerViewModelTests.swift
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
import vpncore

class ColorPickerViewModelTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCorrectColorSelection() {
        let viewModel = ColorPickerViewModel()
        let newCorrectColor = ProfileConstants.profileColors.first
        viewModel.select(color: newCorrectColor)
        XCTAssertNotNil(viewModel.selectedColorIndex)
        XCTAssert(newCorrectColor == viewModel.colorAt(index: viewModel.selectedColorIndex!), "Correct color was not selected")
    }

    func testWrongColorSelection() {
        let viewModel = ColorPickerViewModel()
        let newWrongColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        viewModel.select(color: newWrongColor)
        XCTAssertNotNil(viewModel.selectedColorIndex)
        XCTAssertFalse(newWrongColor == viewModel.colorAt(index: viewModel.selectedColorIndex!), "Color not from the list was selected")
    }

}
