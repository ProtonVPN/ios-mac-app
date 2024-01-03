//
//  Created on 2022-06-16.
//
//  Copyright (c) 2022 Proton AG
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
import PMLogger

class FileHandleMock: FileHandleWrapper {

    public let url: URL

    required init(forWritingTo url: URL) throws {
        self.url = url
    }

    @ThrowingFuncStub(FileHandleWrapper.seekToEnd, initialReturn: 0) var seekToEndCustomStub
    func seekToEnd() throws -> UInt64 {
        try seekToEndCustomStub()
    }

    @ThrowingFuncStub(FileHandleWrapper.write) var writeCustomStub
    func write(contentsOf data: Data) throws {
        try writeCustomStub(data)
    }

    @ThrowingFuncStub(FileHandleWrapper.synchronize) var synchronizeCustomStub
    func synchronize() throws {
        try synchronizeCustomStub()
    }

    @ThrowingFuncStub(FileHandleWrapper.close) var closeCustomStub
    func close() throws {
        try closeCustomStub()
    }
}
