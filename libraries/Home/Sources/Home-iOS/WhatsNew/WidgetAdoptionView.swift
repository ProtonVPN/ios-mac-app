//
//  Created on 21/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

import HomeShared
import Lottie
import SharedViews
import Strings

struct WidgetAdoptionView: View {

    let primaryAction: () -> Void

    init(primaryAction: @escaping () -> Void) {
        self.primaryAction = primaryAction
    }

    private static let lottieAnimationViewHeight: CGFloat = 192.0
    private static let closeIconSize: CGFloat = 40.0

    private let instructionsFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        content
    }

    private var titleView: some View {
        HStack(alignment: .center) {
            Text(Localizable.widgetAdoptionModalTitle)
                .font(.body1(.semibold))

            Spacer(minLength: 0)

            Button {
                primaryAction()
            } label: {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .frame(width: Self.closeIconSize, height: Self.closeIconSize)
            .padding(.vertical, .themeSpacing8)
            .foregroundStyle(Color(.icon, .weak))
        }
        .padding(.top, .themeSpacing24)
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

    private var instructionsView: some View {
        VStack(alignment: .leading) {
            instructionsHeader
            VStack(alignment: .leading, spacing: .themeSpacing24) {
                instructionView(sequence: 1, text: Localizable.widgetAdoptionModalInstruction1)
                instructionView(sequence: 2, text: Localizable.widgetAdoptionModalInstruction2)
                instructionView(sequence: 3, text: Localizable.widgetAdoptionModalInstruction3)
            }
            .padding(.vertical, .themeSpacing24)
            .background(Color(.background, .weak))
            .clipShape(RoundedRectangle(cornerRadius: .themeRadius16))
            .transition(.opacity)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleView
            ScrollView() {
                VStack(alignment: .leading, spacing: .themeSpacing24) {
                    LottieView(animation: .widgetAdoption)
                        .playing(loopMode: .loop)
                        .frame(height: Self.lottieAnimationViewHeight)
                        .background(Color(.background, .weak))
                        .clipShape(RoundedRectangle(cornerRadius: .themeRadius16))

                    Text(Localizable.widgetAdoptionModalSubtitle)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.body2(emphasised: false))

                    instructionsView
                }
            }

            Button(Localizable.widgetAdoptionModalInstructionButton) {
                primaryAction()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.vertical, .themeSpacing16)
        }
        .padding(.horizontal, .themeSpacing16)
    }
}

// MARK: - Preview

#Preview {
    Text("Preview Background").sheet(isPresented: .constant(true)) {
        WidgetAdoptionView(primaryAction: {})
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }
}
