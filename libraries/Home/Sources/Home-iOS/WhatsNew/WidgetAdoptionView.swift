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

import Home
import Lottie
import SharedViews
import Strings

@available(iOS 17, *)
struct WidgetAdoptionView: View {
    @Binding var selectedDetent: PresentationDetent

    let primaryAction: () -> Void

    init(selectedDetent: Binding<PresentationDetent>, primaryAction: @escaping () -> Void) {
        self._selectedDetent = selectedDetent
        self.primaryAction = primaryAction
    }

    private static let lottieAnimationViewHeight: CGFloat = 192.0
    private static let closeIconSize: CGFloat = 40.0

    @State private var viewHeight: CGFloat = .zero

    // We want to have simple boolean statements & SwiftUI view structure based on this property.
    // We leverage `nonmutating set` feature since we do not need `isExpanded` a stored property
    // and we'll base its behaviour on the `selectedDetent` binding.
    private var isExpanded: Bool {
        get {
            return selectedDetent == .large
        }
        nonmutating set {
            selectedDetent = newValue ? .large : .height(viewHeight)
        }
    }

    var body: some View {
        content
            .readHeight()
            .onPreferenceChange(HeightPreferenceKey.self) { height in
                guard selectedDetent != .large else { return }
                height.map {
                    viewHeight = $0
                    selectedDetent = .height($0)
                }
            }
    }

    private var titleView: some View {
        HStack {
            Text(Localizable.widgetAdoptionModalTitle)
                .font(.body1(.semibold))
                .padding(.vertical, .themeSpacing12)

            Spacer()

            Button {
                primaryAction()
            } label: {
                Label("Close", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .frame(width: Self.closeIconSize, height: Self.closeIconSize)
            .foregroundStyle(Color(.icon, .weak))
        }
        .padding(.vertical)
    }

    private var instructionsButton: some View {
        Button {
            withAnimation { isExpanded.toggle() }
        } label: {
            HStack {
                Text(Localizable.widgetAdoptionModalInstructionsHeader)
                    .font(.body2(emphasised: true))
                    .foregroundStyle(Color(.text, .weak))
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(Color(.icon, .weak))
            }
        }
        .padding(.vertical, .themeSpacing12)
    }

    private var instructionsView: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Text(Localizable.widgetAdoptionModalInstruction1)
                Text(Localizable.widgetAdoptionModalInstruction1Content)
                    .padding(.leading, .themeSpacing12)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.vertical, .themeSpacing12)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top) {
                Text(Localizable.widgetAdoptionModalInstruction2)
                Text(Localizable.widgetAdoptionModalInstruction2Content)
                    .padding(.leading, .themeSpacing12)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.vertical, .themeSpacing12)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top) {
                Text(Localizable.widgetAdoptionModalInstruction3)
                Text(Localizable.widgetAdoptionModalInstruction3Content)
                    .padding(.leading, .themeSpacing12)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.vertical, .themeSpacing12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, .themeSpacing8)
        .padding(.bottom, .themeSpacing16)
        .background(Color(.background, .weak))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.opacity)
    }

    private var content: some View {
        VStack {
            titleView

            LottieView(animation: .widgetAdoption)
                .playing(loopMode: .loop)
                .frame(height: Self.lottieAnimationViewHeight)
                .padding(.vertical, .themeSpacing12)

            Text(Localizable.widgetAdoptionModalSubtitle)
                .font(.body2(emphasised: false))
                .padding(.vertical, .themeSpacing12)

            instructionsButton

            if isExpanded {
                instructionsView
            }

            Button(Localizable.widgetAdoptionModalInstructionButton) {
                primaryAction()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, .themeSpacing16)
    }
}

// MARK: - Sizing information helpers

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat?

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        guard let nextValue = nextValue() else { return }
        value = nextValue
    }
}

private struct ReadHeightModifier: ViewModifier {
    private var sizeView: some View {
        GeometryReader { geometry in
            Color.clear.preference(key: HeightPreferenceKey.self, value: geometry.size.height)
        }
    }

    func body(content: Content) -> some View {
        content.background(sizeView)
    }
}

private extension View {
    func readHeight() -> some View {
        self.modifier(ReadHeightModifier())
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
#Preview {
    @Previewable
    @State var selectedDetent: PresentationDetent = .medium

    Text("Preview Background").sheet(isPresented: .constant(true)) {
        WidgetAdoptionView(selectedDetent: $selectedDetent, primaryAction: {})
            .presentationDetents([.medium, .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
    }
}
