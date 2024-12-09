//
//  Created on 05/12/2024.
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

/// Inserts dividers between each element, with the option to also include one under the last element.
///
/// Useful when you want to render dividers between items, and you'd like to avoid the style restrictions and
/// additional behaviour that come with Lists (edge insets, tappable area, etc).
///
/// Note: Since content is passed as an escaping closure, wrap the contents with `WithPerceptionTracking` if it relies
/// on a `Store`.
public struct DividedForEach<Data: RandomAccessCollection, Content: View>: View where Data.Index: Hashable {
    private let data: Data
    private let showDividerUnderLastElement: Bool
    private let content: (Data.Element) -> Content

    public init(
        _ data: Data,
        showDividerUnderLastElement: Bool = false,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.showDividerUnderLastElement = showDividerUnderLastElement
        self.content = content
    }

    // Improvement: align to the leading edge of the first `Text` in each row, ine line with platform convention
    // `List` does this by default, using `listRowSeparatorLeading` under the hood
    // I got this almost working, with the Divider aligned with the text, but could not find a way to reduce its width
    // The following snippet is a good start (you may have to wrap it in a GeometryReader)
    // VStack(alignment: .leading, spacing: 0) {
    //     ForEach(Array(data.enumerated()), id: \.element.self) { index, element in
    //         VStack(alignment: .listRowSeparatorLeading, spacing: 0) {
    //             content(element)
    //
    //             if shouldRenderDivider(at: index, of: data.count - 1) {
    //                 Divider()
    //                     .alignmentGuide(.leading) { $0[.listRowSeparatorLeading] }
    //             }
    //         }
    //     }
    // }
    public var body: some View {
        let lastIndex = data.index(before: data.endIndex)
        return ForEach(data.indices, id: \.self) { index in
            VStack(alignment: .leading, spacing: 0) {
                content(data[index])
                if shouldRenderDivider(at: index, last: lastIndex) {
                    Divider()
                }
            }
        }
    }

    private func shouldRenderDivider(at index: Data.Index, last: Data.Index) -> Bool {
        if index < last {
            return true
        }

        return showDividerUnderLastElement
    }
}

#if DEBUG && compiler(>=6)
@available(iOS 18, *)
#Preview {
    let elements = [
        "globe",
        "externaldrive.fill.badge.plus",
        "speaker.zzz",
        "exclamationmark.triangle"
    ]

    VStack(alignment: .leading) {
        VStack {
            DividedForEach(elements) { item in
                HStack {
                    Image(systemName: item)
                    Text(item)
                    Spacer()
                }
            }
        }

        Spacer()

        Text("With Divider Under Last Element:")
            .padding()
        VStack {
            DividedForEach(elements, showDividerUnderLastElement: true) { item in
                HStack {
                    Image(systemName: item)
                    Text(item)
                    Spacer()
                }
            }
        }

        Spacer()

        Text("Edge Case (empty)")
            .padding()
        VStack {
            DividedForEach([], showDividerUnderLastElement: true) { item in
                HStack { }
            }
        }
    }
    .padding()
}
#endif
