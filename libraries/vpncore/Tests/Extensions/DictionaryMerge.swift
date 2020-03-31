//
//  DictionaryMerge.swift
//  vpncore - Created on 2020-03-31.
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
//

import XCTest

class DictionaryMerge: XCTestCase {

    func testMerge() {
        let first = [
            "key1" : "value1"
        ]
        let second = [
            "key2" : "value2"
        ]
        let result = first + second
        
        XCTAssert(result["key1"] == first["key1"])
        XCTAssert(result["key2"] == second["key2"])
    }
    
    func testRightValueOverwritesLeft() {
        let first = [
            "key1" : "value1"
        ]
        let second = [
            "key1" : "value2"
        ]
        
        let result = first + second
        XCTAssert(result["key1"] == second["key1"])
        
        let resultOther = second + first
        XCTAssert(resultOther["key1"] == first["key1"])
        
    }
    
}
