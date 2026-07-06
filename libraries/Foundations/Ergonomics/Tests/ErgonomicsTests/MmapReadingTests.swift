//
//  Created on 06.07.2026 by John Biggs.
//
//  Copyright (c) 2026 Proton AG
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

import Darwin
import Ergonomics
import XCTest

/// `MmapBuffer(readingPath:)`, the read-only sibling of the IPC initializer: it must map exactly the
/// file's bytes, never create or grow anything, and report the page-rounded size a whole-region adopter
/// (like a Metal no-copy buffer) must use.
final class MmapReadingTests: XCTestCase {
    private func temporaryFile(bytes: [UInt8]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mmap-\(UUID().uuidString).bin")
        try Data(bytes).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testMapsWholeFile() throws {
        let pattern = (0 ..< 10000).map { UInt8(($0 &* 31) & 0xFF) }
        let url = try temporaryFile(bytes: pattern)

        let mapping = try MmapBuffer(readingPath: url.path)
        XCTAssertEqual(mapping.totalSize, pattern.count)
        mapping.withUnsafeBytes { bytes in
            XCTAssertTrue(bytes.elementsEqual(pattern))
        }
    }

    func testPageAlignedSizeRoundsUpToWholePages() throws {
        let url = try temporaryFile(bytes: [UInt8](repeating: 1, count: 10000))
        let mapping = try MmapBuffer(readingPath: url.path)

        let page = Int(getpagesize())
        XCTAssertEqual(mapping.pageAlignedSize % page, 0)
        XCTAssertGreaterThanOrEqual(mapping.pageAlignedSize, mapping.totalSize)
        XCTAssertLessThan(mapping.pageAlignedSize - mapping.totalSize, page)
    }

    func testEmptyFileThrows() throws {
        // Not XCTAssertThrowsError: its generic result requires Copyable, which MmapBuffer is not.
        let url = try temporaryFile(bytes: [])
        do {
            _ = try MmapBuffer(readingPath: url.path)
            XCTFail("mapping an empty file should throw")
        } catch {
            XCTAssertEqual(error as? MmapBufferError, .zeroSizePayload)
        }
    }

    func testMissingFileThrows() {
        do {
            _ = try MmapBuffer(readingPath: "/nonexistent/\(UUID().uuidString)")
            XCTFail("mapping a missing file should throw")
        } catch {
            guard case .openFailed = error as? MmapBufferError else {
                return XCTFail("expected openFailed, got \(error)")
            }
        }
    }
}
