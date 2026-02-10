//
//  Created on 09/10/2024.
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

/// As of Xcode 16.0 and tvOS 18, putting a long, multiline `Text` inside a `ScrollView` does not make it scrollable.
/// This is a workaround that splits the given text into individually focusable text chunks.
/// Adjust `linesPerChunk` until each press of the up and down buttons results in some scrolling.
///
/// Note that this assumes text is split by the new line character into roughly equal length lines, not paragraphs.
struct ScrollableTextView: View {
    let text: String
    let linesPerChunk: Int
    let alignment: HorizontalAlignment

    var chunks: [String] {
        let lines = text.components(separatedBy: "\n")
        guard linesPerChunk > 0, !lines.isEmpty else { return [] }
        let chunkCount = max(0, (lines.count - 1) / linesPerChunk)

        return Range(0 ... chunkCount).compactMap { chunkIndex in
            let startIndex = linesPerChunk * chunkIndex
            let endIndex = min(linesPerChunk * (chunkIndex + 1) - 1, lines.count - 1)

            guard startIndex <= endIndex else { return nil }
            return lines[startIndex ... endIndex]
                .joined(separator: "\n")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: alignment) {
                Color.clear
                    .frame(height: 1)
                    .focusable()
                ForEach(Array(chunks.enumerated()), id: \.offset) { _, chunk in
                    Text(chunk)
                        .focusable()
                }
            }
            .padding()
        }
    }
}
