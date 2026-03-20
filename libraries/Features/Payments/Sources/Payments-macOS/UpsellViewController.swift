//
//  Created on 09/03/2026 by Max Kupetskyi.
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

import AppKit
import Dependencies
import Ergonomics
import PaymentsShared
import Strings
import SwiftUI
import Theme

public struct UpsellViewController: View {
    public let modalType: UpsellModalType
    public let upgradeAction: (() -> Void)?
    public let continueAction: (() -> Void)?
    public let showsCloseButton: Bool

    @Dependency(\.date) private var date
    @Dependency(\.continuousClock) private var clock
    @Environment(\.dismiss) private var dismiss
    @State private var now: Date?

    public init(
        modalType: UpsellModalType,
        upgradeAction: (() -> Void)?,
        continueAction: (() -> Void)?,
        showsCloseButton: Bool = true
    ) {
        self.modalType = modalType
        self.upgradeAction = upgradeAction
        self.continueAction = continueAction
        self.showsCloseButton = showsCloseButton
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: .themeRadius12)
                .fill(Color(.background, .strong))

            LinearGradient(
                colors: [
                    Color(red: 35.0 / 255.0, green: 132.0 / 255.0, blue: 136.0 / 255.0),
                    Color(red: 26.0 / 255.0, green: 49.0 / 255.0, blue: 93.0 / 255.0),
                    Color(red: 14.0 / 255.0, green: 14.0 / 255.0, blue: 30.0 / 255.0),
                ],
                startPoint: .top,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: .themeRadius12))

            VStack(spacing: .themeSpacing8) {
                modalType.artImage()
                    .frame(width: Dimensions.artWidth, height: Dimensions.artHeight)
                    .padding(.top, Dimensions.artTopPadding)

                Text(modalType.title)
                    .themeFont(.title1())
                    .foregroundStyle(Color(.text))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("TitleLabel")

                if let subtitle = subtitleText {
                    Text(subtitle)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("DescriptionLabel")
                }

                if !modalType.features().isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: .themeSpacing8) {
                            ForEach(modalType.features()) { feature in
                                HStack(alignment: .top, spacing: .themeSpacing12) {
                                    if let image = feature.image {
                                        image.swiftUIImage
                                            .renderingMode(.template)
                                            .resizable()
                                            .foregroundStyle(Color(.icon, [.interactive, .active]))
                                            .frame(width: Dimensions.featureIconSize, height: Dimensions.featureIconSize)
                                            .padding(.top, .themeSpacing2)
                                    }
                                    Text(feature.title())
                                        .themeFont(.title3())
                                        .foregroundStyle(Color(.text))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.vertical, .themeSpacing16)
                        .padding(.horizontal, .themeSpacing24)
                        .overlay(
                            RoundedRectangle(cornerRadius: .themeRadius12)
                                .stroke(Color.white.opacity(0.15), lineWidth: Dimensions.featuresBoxBorderWidth)
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, .themeSpacing24)
                }

                Spacer(minLength: 0)

                UpsellPrimaryActionButton(title: buttonTitle, action: onPrimaryAction)
                    .accessibilityIdentifier("ModalUpgradeButton")
                    .padding(.top, .themeSpacing32)
            }
            .padding(.horizontal, Dimensions.horizontalPadding)
            .padding(.bottom, Dimensions.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: Dimensions.modalWidth, height: Dimensions.modalHeight)
        .overlay(alignment: .topTrailing) {
            if showsCloseButton {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.callout())
                        .foregroundStyle(Color(.text, .weak))
                        .frame(width: Dimensions.closeButtonIconSize, height: Dimensions.closeButtonIconSize)
                        .background(Color.black.opacity(0.2), in: Circle())
                }
                .buttonStyle(.plain)
                .padding([.top, .trailing], .themeSpacing12)
            }
        }
        .background(Color(.background))
        .task {
            guard case .cantSkip = modalType else { return }
            now = date.now
            for await _ in clock.timer(interval: .seconds(1)) {
                now = date.now
            }
        }
    }

    private var isCantSkipCooldownActive: Bool {
        guard case let .cantSkip(before, _, _) = modalType else { return false }
        return (now ?? date.now) < before
    }

    private var buttonTitle: String {
        if case .cantSkip = modalType {
            return isCantSkipCooldownActive
                ? Localizable.modalsGetPlus
                : Localizable.upsellSpecificLocationChangeServerButtonTitle
        }
        return Localizable.modalsGetPlus
    }

    private var subtitleText: AttributedString? {
        guard let subtitle = modalType.subtitleModel else { return nil }
        let nsAttributedSubtitle = subtitle.text.attributedString(
            size: 17,
            color: .color(.text, .weak),
            boldStrings: subtitle.boldText,
            alignment: .center
        )
        return try? AttributedString(nsAttributedSubtitle, including: \.appKit)
    }

    private func onPrimaryAction() {
        if case .cantSkip = modalType {
            if isCantSkipCooldownActive {
                upgradeAction?()
            } else {
                continueAction?()
            }
            return
        }
        upgradeAction?()
    }
}

extension UpsellViewController {
    private enum Dimensions {
        static let artTopPadding: CGFloat = 72
        static let artWidth: CGFloat = 400
        static let artHeight: CGFloat = 184

        static let featureIconSize: CGFloat = 16
        static let featuresBoxBorderWidth: CGFloat = 1

        static let horizontalPadding: CGFloat = 60
        static let bottomPadding: CGFloat = 72
        static let modalWidth: CGFloat = 520
        static let modalHeight: CGFloat = 590
        static let closeButtonIconSize: CGFloat = 22
    }
}

#Preview {
    UpsellViewController(
        modalType: .allCountries(numberOfServers: 111, numberOfCountries: 4444),
        upgradeAction: {},
        continueAction: {}
    )
    .preferredColorScheme(.dark)
}

public final class UpsellHostingViewController: NSHostingController<UpsellViewController> {
    public init(
        modalType: UpsellModalType,
        upgradeAction: (() -> Void)?,
        continueAction: (() -> Void)?,
        showsCloseButton: Bool = true
    ) {
        super.init(rootView: UpsellViewController(
            modalType: modalType,
            upgradeAction: upgradeAction,
            continueAction: continueAction,
            showsCloseButton: showsCloseButton
        ))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyUpsellModalAppearance()
        view.window?.styleMask.remove(.fullSizeContentView)
    }
}
