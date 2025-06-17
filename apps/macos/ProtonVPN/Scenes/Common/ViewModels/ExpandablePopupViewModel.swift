//
//  ExpandablePopupViewModel.swift
//  ProtonVPN - Created on 21/09/2020.
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

import Foundation
import LegacyCommon
import Strings
import VPNAppCore

class ExpandablePopupViewModel: NSObject {
    private let alert: ExpandableSystemAlert

    init(_ alert: ExpandableSystemAlert) {
        self.alert = alert
        super.init()
    }

    var dismissViewController: (() -> Void)?

    var title: String {
        alert.title ?? ""
    }

    var hiddenInfo: String {
        alert.expandableInfo ?? ""
    }

    var message: String {
        alert.message ?? ""
    }

    var extraInfo: String {
        alert.footInfo ?? ""
    }

    var actionButtonTitle: String {
        action(0)?.title ?? Localizable.ok
    }

    func action() {
        onAction?()
        dismissViewController?()
    }

    func close() {
        onAction?()
        dismissViewController?()
    }

    private var onAction: (() -> Void)? {
        action(0)?.handler
    }

    private func action(_ index: Array<Any>.Index) -> AlertAction? {
        alert.actions[optional: index]
    }
}
