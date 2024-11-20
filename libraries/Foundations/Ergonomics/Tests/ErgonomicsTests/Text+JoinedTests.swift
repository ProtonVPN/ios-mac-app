//
//  Created on 20/11/2024.
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

import SwiftUI
import XCTest
import Ergonomics

final class TextJoiningTests: XCTestCase {

    func testJoiningEmptyArrayReturnsNil() throws {
        let textArrayWithNoElements: [Text] = []
        let joinedText = textArrayWithNoElements.joined(separator: Text("+"))
        XCTAssertEqual(joinedText, nil)
    }

    func testJoiningOneTextReturnsTextUnchanged() throws {
        let text = Text("Hello")
        let joinedText = [text].joined(separator: Text("+"))
        XCTAssertEqual(joinedText, text)
    }

    func testJoiningMultipleTextsReturnsTextJoinedBySeparator() throws {
        let strings = ["Hello", "World"]
        let joinedStrings = strings.joined(separator: "+")

        let joinedText = strings
            .map { MockText($0) }
            .joined(separator: MockText("+"))

        XCTAssertEqual(joinedText, MockText(joinedStrings))
    }
}

private struct MockText: Joinable, Equatable {
    let content: String

    init(_ content: String) {
        self.content = content
    }

    func joined(to other: MockText, with separator: MockText) -> MockText {
        let joinedContents = self.content + separator.content + other.content
        return MockText(joinedContents)
    }
}
