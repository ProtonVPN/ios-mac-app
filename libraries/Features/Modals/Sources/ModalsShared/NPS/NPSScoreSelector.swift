//
//  Created on 2026-08-26 by Pawel Jurczyk.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Strings
import SwiftUI
import Theme

struct NPSScoreSelector: View {
    let selectedScore: Int?
    let onScoreTapped: (Int) -> Void

    private static let numberOfColumnsInCompactSize = 6

    @State private var columns = Self.numberOfColumnsInCompactSize

    private static let spacing: CGFloat = .themeSpacing4

    var widthThreshold: CGFloat = {
        let scoreCount = CGFloat(NPSModalFeature.scoreRange.count)
        let spaces = scoreCount - 1
        return scoreCount * NPSScoreCell.minWidth + spaces * spacing
    }()

    var body: some View {
        VStack(spacing: .themeSpacing4) {
            EqualWidthRowsLayout(columns: columns, spacing: Self.spacing) {
                ForEach(NPSModalFeature.scoreRange, id: \.self) { score in
                    NPSScoreCell(score: score, isSelected: score == selectedScore) {
                        onScoreTapped(score)
                    }
                }
            }

            NPSScaleHints()
        }.onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newValue in
            if newValue.width >= widthThreshold {
                columns = NPSModalFeature.scoreRange.count
            } else {
                columns = Self.numberOfColumnsInCompactSize
            }
        }
        #if os(iOS)
        .sensoryFeedback(.selection, trigger: selectedScore)
        #endif
    }
}

// MARK: - Subviews

private struct NPSScoreCell: View {
    let score: Int
    let isSelected: Bool
    let action: () -> Void

    static let minWidth: CGFloat = 51

    var body: some View {
        Button(action: action) {
            Text(score.formatted())
                .themeFont(.npsScore)
                .foregroundStyle(isSelected ? Color(.text, .primary) : Color(.text))
                .frame(minWidth: Self.minWidth, maxWidth: .infinity)
                .padding(.vertical, .themeSpacing12)
                .background(isSelected ? Color(.background, .interactive) : Color(.background, [.interactive, .weak]))
                .clipShape(.rect(cornerRadius: .themeRadius8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct NPSScaleHints: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .themeSpacing8) {
            Text(Localizable.npsModalScaleLowerBound)
            Spacer(minLength: .themeSpacing8)
            Text(Localizable.npsModalScaleUpperBound)
        }
        .font(.themeFont(.npsScaleHint))
        .foregroundStyle(Color(.text, .weak))
        .accessibilityHidden(true)
    }
}

private struct EqualWidthRowsLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard !subviews.isEmpty, columns > 0 else { return .zero }

        let totalWidth = proposal.replacingUnspecifiedDimensions().width
        let cellWidth = cellWidth(forTotalWidth: totalWidth)
        let rowHeight = subviews
            .map { $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height }
            .max() ?? 0
        let rows = numberOfRows(forCount: subviews.count)

        return CGSize(
            width: totalWidth,
            height: rowHeight * CGFloat(rows) + spacing * CGFloat(rows - 1)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard !subviews.isEmpty, columns > 0 else { return }

        let cellWidth = cellWidth(forTotalWidth: bounds.width)
        let rows = numberOfRows(forCount: subviews.count)
        let rowHeight = (bounds.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
        let cellProposal = ProposedViewSize(width: cellWidth, height: rowHeight)

        for row in 0 ..< rows {
            let indices = (row * columns) ..< min((row + 1) * columns, subviews.count)
            let rowWidth = cellWidth * CGFloat(indices.count) + spacing * CGFloat(indices.count - 1)
            var x = bounds.minX + (bounds.width - rowWidth) / 2
            let y = bounds.minY + (rowHeight + spacing) * CGFloat(row)

            for index in indices {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: cellProposal
                )
                x += cellWidth + spacing
            }
        }
    }

    private func cellWidth(forTotalWidth totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    private func numberOfRows(forCount count: Int) -> Int {
        (count + columns - 1) / columns
    }
}

#Preview {
    NPSScoreSelector(selectedScore: 1) { _ in }
        .frame(width: 600)
        .padding()
    Divider()

    NPSScoreSelector(selectedScore: 2) { _ in }
        .frame(width: 700)
        .padding()
        .background(.background)
        .colorScheme(.dark)
}
