//
//  Created on 2022-06-17.
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

/// Creates `FileManager` mock and adds `FileHandleMock` from `SizeWatchingFileHandleMockFactory` so
/// files that are used via `FileHandler` track theirs sizes and can return creation date.
///
/// Expectations can be set in case they are needed for async testing.
class FileSystemMock {

    let fileManager = FileManagerMock()
    let handlerMockFactory = SizeWatchingFileHandleMockFactory()

    // Callbacks
    var createFileCallback: (() -> Void)?
    var removeFileCallback: (() -> Void)?
    var moveFileCallback: (() -> Void)?

    init() {
        fileManager.createFileStub.addToBody { _, path, _, _ in
            _ = try? self.handlerMockFactory.handler(for: URL(string: path)!) // Adds file to the list of created files in the factory
            self.createFileCallback?()
            return true
        }
        fileManager.fileExistsStub.addToBody { _, path in
            return self.handlerMockFactory.exists(at: URL(string: path)!)
        }
        fileManager.removeItemStub.addToBody { _, url in
            self.removeFileCallback?()
            self.handlerMockFactory.delete(for: url)
        }
        fileManager.createFileHandleStub.addToBody { _, url in
            return try self.handlerMockFactory.handler(for: url)
        }
        fileManager.moveItemStub.addToBody { _, from, to in
            self.moveFileCallback?()
            self.handlerMockFactory.move(from: from, to: to)
        }
        fileManager.contentsOfDirectoryStub.addToBody { _, folderUrl, keys, mask in
            return self.handlerMockFactory.files.filter { element in
                return element.key.path.hasPrefix(folderUrl.path)
            }.map { $0.key }
        }
        fileManager.attributesOfItemStub.addToBody { _, path in
            return [FileAttributeKey.creationDate: self.handlerMockFactory.creationDate(for: URL(string: path)!) as Any]
        }
    }

}

/// Creates FileHandleMocks and tracks their size by adding the size of written data to its curent size counter.
/// It also keeps track of URLs and returns the same instanse for the same URL.
class SizeWatchingFileHandleMockFactory {

    var files = [URL: (FileHandleMock, Date)]()

    func handler(for url: URL) throws -> FileHandleMock {
        if let existing = files[url] {
            return existing.0
        }

        var currentSize: UInt64 = 0

        let mock = try FileHandleMock(forWritingTo: url)
        mock.seekToEndCustomStub.addToBody { _ in
            return currentSize
        }
        mock.writeCustomStub.addToBody { _, data in
            currentSize += UInt64(data.count)
        }

        files[url] = (mock, Date())
        return mock
    }

    func exists(at url: URL) -> Bool {
        return files.contains { $0.key.path == url.path }
    }

    func delete(for url: URL) {
        files.removeValue(forKey: url)
    }

    func move(from: URL, to: URL) {
        files[to] = files[from]
        delete(for: from)
    }

    func creationDate(for url: URL) -> Date? {
        return files[url]?.1
    }

}
