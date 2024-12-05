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

/// Inserts dividers between each element, aligned to the leading edge of the first `Text` in each row. Much like
/// `List` does by default, according to platform conventions.
///
/// Useful when you want to render dividers between items, and you'd like to avoid the style restrictions and
/// additional behaviour that come with Lists (edge insets, tappable area, etc).
///
/// Uses `listRowSeparatorLeading` under the hood to align the dividers. Check "Custom Alignment" preview section below
/// for an example of how to define custom alignments.
///
/// Note: Since content is passed as an escaping closure, wrap the contents with `WithPerceptionTracking` if it relies
///  on a `Store`.
public struct DividedForEach<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    private let data: Data
    private let content: (Data.Element) -> Content

    public init(
        _ data: Data,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.element.self) { index, element in
                    VStack(alignment: .listRowSeparatorLeading, spacing: 0) {
                        content(element)

                        if shouldRenderDivider(at: index, of: data.count - 1) {
                            Divider()
                                .alignmentGuide(.leading) { $0[.listRowSeparatorLeading] }
                        }
                    }
                }
            }
        }
    }

    private func shouldRenderDivider(at index: Int, of lastIndex: Int) -> Bool {
        // render the divider if this is not the last element
        index < lastIndex
    }
}

#Preview("Default Alignment") {
    VStack(alignment: .leading) {
        DividedForEach(["goodbye,", "cruel", "world!"]) { item in
            HStack {
                Image(systemName: "globe")
                    .resizable()
                    .frame(width: CGFloat(item.count * 10), height: 32)
                Text("\(item)")
                    .padding()
            }
        }
    }
}

#Preview("Custom Alignment") {
    VStack(alignment: .leading) {
        DividedForEach(["hello,", "beautiful", "world"]) { item in
            let width = CGFloat(item.count * 10)
            HStack {
                Image(systemName: "globe")
                    .resizable()
                    .frame(width: width, height: 32)
                    .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                Text("\(item)")
                    .padding()
            }
        }
    }
}
