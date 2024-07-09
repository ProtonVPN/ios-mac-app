//
//  Created on 08/07/2024.
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

import Foundation
import protocol GoLibs.LocalAgentNativeClientProtocol
import class GoLibs.LocalAgentStatusMessage
@testable import LocalAgent

class MockLocalAgentClient: NSObject, LocalAgentClient {
    func log(_ text: String?) { }
    func onError(_ code: Int, description: String?) { }
    func onState(_ state: String?) { }
    func onStatusUpdate(_ status: LocalAgentStatusMessage?) { }
    func onTlsSessionEnded() { }
    func onTlsSessionStarted() { }

    var didSetDelegate: ((LocalAgentClientDelegate?) -> Void)?

    var delegate: LocalAgentClientDelegate? {
        didSet {
            didSetDelegate?(delegate)
        }
    }
}
