//
//  PopUpViewModel.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import AppKit
import Foundation
import LegacyCommon
import Strings
import VPNAppCore

final class PopUpViewModel: NSObject {
    let inAppLinkManager: InAppLinkManager?

    var title: String {
        // Don't show a title if the the description is using the alert's title
        if attributedDescription.string == alert.title {
            ""
        } else {
            alert.title ?? ""
        }
    }

    var confirmButtonTitle: String {
        action(0)?.title ?? Localizable.ok
    }

    var confirmationType: PrimaryActionType {
        action(0)?.style ?? .confirmative
    }

    var cancelButtonTitle: String? {
        action(1)?.title
    }

    var cancelType: PrimaryActionType {
        action(1)?.style ?? .cancel
    }

    var attributedDescription: NSAttributedString
    var showIcon = true
    var updateInterface: (() -> Void)?
    var dismissViewController: (() -> Void)?
    var dismissCompletion: (() -> Void)?

    let joinedTitleAndMessage: Bool

    private var alert: SystemAlert
    private var onConfirm: (() -> Void)? {
        action(0)?.handler
    }

    private var onCancel: (() -> Void)? {
        action(1)?.handler
    }

    convenience init(alert: SystemAlert, inAppLinkManager: InAppLinkManager? = nil) {
        let attributedDescription: NSAttributedString = if alert.joinedTitleAndMessage, let title = alert.title, let message = alert.message {
            [
                title.styled(.strong, font: .themeFont(.paragraph, bold: true), alignment: .natural),
                .lineSeparator(count: 2),
                message.styled(alignment: .natural),
            ].joined()
        } else {
            (alert.message ?? alert.title ?? Localizable.errorInternalError).styled(alignment: .natural)
        }
        self.init(alert: alert, attributedDescription: attributedDescription, inAppLinkManager: inAppLinkManager)
    }

    init(alert: SystemAlert, attributedDescription: NSAttributedString, inAppLinkManager: InAppLinkManager? = nil) {
        self.alert = alert
        self.attributedDescription = attributedDescription
        self.inAppLinkManager = inAppLinkManager
        joinedTitleAndMessage = alert.joinedTitleAndMessage
    }

    func confirm() {
        onConfirm?()
    }

    func cancel() {
        onCancel?()
    }

    func close() {
        dismissViewController?()
    }

    func cleanUp() {
        dismissCompletion?()
    }

    private func action(_ index: Array<Any>.Index) -> AlertAction? {
        alert.actions[optional: index]
    }
}

extension PopUpViewModel: NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let link = link as? String, let inAppLinkManager else { return true }

        do {
            try inAppLinkManager.openLink(link)
            close()
        } catch {
            log.error("Failed to open internal link", category: .user, metadata: ["error": "\(error)"])
        }

        return true
    }
}

// MARK: - Equatable

extension PopUpViewModel {
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PopUpViewModel else {
            return false
        }

        return title == other.title && attributedDescription.string == other.attributedDescription.string
    }
}
