//
//  Created on 07/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import XCTest
import SnapshotTesting
import ComposableArchitecture
@testable import tvOS

final class CodeExpiredFeatureSnapshotTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testCodeExpiredView() {
        let store = Store(initialState: CodeExpiredFeature.State()) {
            CodeExpiredFeature()
        }
        let codeExpiredView = CodeExpiredView(store: store)
            .frame(.rect(width: 1920, height: 1080))

        store.send(.generateNewCode)
//        isRecording = true

        let traitDarkMode = UITraitCollection(userInterfaceStyle: .dark)
        assertSnapshot(of: codeExpiredView, as: .image(traits: traitDarkMode))
        // assertSnapshot(of: codeExpiredView, as: .recursiveDescription(on: .tv))
      }
}
