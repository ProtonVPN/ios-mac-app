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
import Foundation
import Testing

/// `MmapBuffer(readingPath:)`, the read-only sibling of the IPC initializer: it must map exactly the
/// file's bytes, never create or grow anything, and report the page-rounded size a whole-region adopter
/// (like a Metal no-copy buffer) must use.
@Suite("Mmap reading")
struct MmapReadingTests {
    private func temporaryFile(bytes: [UInt8]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mmap-\(UUID().uuidString).bin")
        try Data(bytes).write(to: url)
        return url
    }

    @Test("Maps the whole file")
    func mapsWholeFile() throws {
        let pattern = (0 ..< 10000).map { UInt8(($0 &* 31) & 0xFF) }
        let url = try temporaryFile(bytes: pattern)
        defer { try? FileManager.default.removeItem(at: url) }

        let mapping = try MmapBuffer(readingPath: url.path)
        #expect(mapping.totalSize == pattern.count)
        mapping.withUnsafeBytes { bytes in
            #expect(bytes.elementsEqual(pattern))
        }
    }

    @Test("Page-aligned size rounds up to whole pages")
    func pageAlignedSizeRoundsUpToWholePages() throws {
        let url = try temporaryFile(bytes: [UInt8](repeating: 1, count: 10000))
        defer { try? FileManager.default.removeItem(at: url) }
        let mapping = try MmapBuffer(readingPath: url.path)

        let page = Int(getpagesize())
        #expect(mapping.pageAlignedSize % page == 0)
        #expect(mapping.pageAlignedSize >= mapping.totalSize)
        #expect(mapping.pageAlignedSize - mapping.totalSize < page)
    }

    @Test("Mapping an empty file throws")
    func emptyFileThrows() throws {
        let url = try temporaryFile(bytes: [])
        defer { try? FileManager.default.removeItem(at: url) }
        // MmapBuffer is ~Copyable, so the throwing call's result is discarded in place rather than returned.
        let error = #expect(throws: MmapBufferError.self) {
            _ = try MmapBuffer(readingPath: url.path)
        }
        guard case .zeroSizePayload? = error else {
            Issue.record("expected zeroSizePayload, got \(String(describing: error))")
            return
        }
    }

    @Test("Mapping a missing file throws")
    func missingFileThrows() {
        let error = #expect(throws: MmapBufferError.self) {
            _ = try MmapBuffer(readingPath: "/nonexistent/\(UUID().uuidString)")
        }
        guard case .openFailed? = error else {
            Issue.record("expected openFailed, got \(String(describing: error))")
            return
        }
    }
}
