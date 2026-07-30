//
//  Created on 06/07/2026 by Max Kupetskyi.
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
import Ergonomics
import Strings
import Theme

/// Banner shown at the top of the login form while Advanced kill switch is blocking internet access. Reboot / session
/// expiry can leave the user logged out while Advanced KS still blocks, so the login screen can't reach the auth
/// servers. This allows the user to tap "Disable" so that they can log in.
///
/// Two states:
/// - `.blocking`: warning style + a "Disable" action button.
/// - `.disabled`: success style + a dismiss (X) button, shown after the user disables KS.
final class KillSwitchLoginBanner: NSView {
    private let iconView = NSImageView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let messageLabel = PVPNTextField().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.isEditable = false
        $0.isBordered = false
        $0.drawsBackground = false
        $0.maximumNumberOfLines = 0
        $0.lineBreakMode = .byWordWrapping
    }

    private lazy var actionButton = InteractiveActionButton().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.target = self
        $0.action = #selector(actionTapped)
    }

    private var actionHandler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    /// Advanced KS is blocking: warning border + "Disable" action. A nil action means the teardown it starts is already
    /// running, leaving the same message with an inert button.
    func configureBlocking(onDisable: (() -> Void)?) {
        isHidden = false
        actionHandler = onDisable
        actionButton.isEnabled = actionHandler != nil // actionHandler is nil when logging out/quitting.
        applyStyle(.warning)
        iconView.image = Theme.Asset.Icons.exclamationTriangleFilled.image
        iconView.contentTintColor = .color(.icon, .warning)
        messageLabel.attributedStringValue = Localizable.killSwitchLoginBlocking
            .styled(.normal, font: .themeFont(.small), alignment: .natural)
        actionButton.title = Localizable.killSwitchDisable
    }

    /// KS has been disabled: success border + dismiss (X).
    func configureDisabled(onDismiss: @escaping () -> Void) {
        isHidden = false
        actionHandler = onDismiss
        actionButton.isEnabled = actionHandler != nil
        applyStyle(.success)
        iconView.image = Theme.Asset.Icons.checkmarkCircleFilled.image
        iconView.contentTintColor = .color(.icon, .success)
        messageLabel.attributedStringValue = Localizable.killSwitchDisabledConfirmation
            .styled(.normal, font: .themeFont(.small), alignment: .natural)
        actionButton.title = Localizable.close
    }

    // MARK: - Setup

    private func setupSubviews() {
        wantsLayer = true
        layer?.cornerRadius = AppTheme.CornerRadius.radius8.rawValue
        layer?.borderWidth = 1

        addSubview(iconView)
        addSubview(messageLabel)
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: .themeSpacing12),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: .themeSpacing12),
            iconView.widthAnchor.constraint(equalToConstant: .themeSpacing16),
            iconView.heightAnchor.constraint(equalToConstant: .themeSpacing16),

            messageLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: .themeSpacing8),
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: .themeSpacing12),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.themeSpacing12),

            actionButton.leadingAnchor.constraint(equalTo: messageLabel.trailingAnchor, constant: .themeSpacing8),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -.themeSpacing12),
            actionButton.topAnchor.constraint(equalTo: topAnchor, constant: .themeSpacing12),
            actionButton.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
        ])
    }

    private func applyStyle(_ style: AppTheme.Style) {
        layer?.backgroundColor = NSColor.color(.background, .weak).cgColor
        layer?.borderColor = NSColor.color(.border, style).cgColor
    }

    @objc
    private func actionTapped() {
        actionHandler?()
    }
}
