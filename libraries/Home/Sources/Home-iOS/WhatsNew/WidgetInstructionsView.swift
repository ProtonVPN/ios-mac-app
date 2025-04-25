//
//  Created on 2025-04-24 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
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

import SwiftUI
import Strings

struct WidgetInstructionsView: View {

    private let instructionsFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    let backgroundColor: Color

    var body: some View {
        VStack(alignment: .leading) {
            instructionsHeader
            VStack(alignment: .leading, spacing: .themeSpacing24) {
                instructionView(sequence: 1, text: Localizable.widgetAdoptionModalInstruction1)
                instructionView(sequence: 2, text: Localizable.widgetAdoptionModalInstruction2)
                instructionView(sequence: 3, text: Localizable.widgetAdoptionModalInstruction3)
                instructionView(sequence: 4, text: Localizable.widgetAdoptionModalInstruction4)
            }
            .padding(.vertical, .themeSpacing24)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: .themeRadius16))
            .transition(.opacity)
        }
    }

    private var instructionsHeader: some View {
        Text(Localizable.widgetAdoptionModalInstructionsHeader)
            .font(.body2(emphasised: true))
            .foregroundStyle(Color(.text, .weak))
            .padding(.vertical, .themeSpacing12)
    }

    private func instructionView(sequence: UInt, text: String) -> some View {
        HStack(alignment: .top, spacing: .themeSpacing12) {
            Text(instructionsFormatter.string(for: sequence)!)
                .themeFont(.body3(emphasised: false))
            Text(LocalizedStringKey(text))
                .themeFont(.body2(emphasised: false))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, .themeSpacing16)
    }
}
