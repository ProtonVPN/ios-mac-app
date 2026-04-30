//
//  Created on 09/03/2022.
//
//  Copyright (c) 2022 Proton AG
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

import AppKit
import ComposableArchitecture
import ModalsShared
import SwiftUI

final class DiscourageSecureCoreViewController: NSHostingController<DiscourageSecureCoreView> {
    init(
        onActivate: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        let initialStore = Store(initialState: DiscourageSecureCoreFeature.State()) {
            DiscourageSecureCoreFeature()
        }
        super.init(rootView: DiscourageSecureCoreView(store: initialStore, dismissOnAction: false))
        preferredContentSize = .init(width: Dimensions.sheetWidth, height: Dimensions.sheetHeight)

        let store = Store(initialState: DiscourageSecureCoreFeature.State()) {
            DiscourageSecureCoreFeature(
                onActivate: { [weak self] in
                    onActivate?()
                    Task { @MainActor [weak self] in
                        self?.close()
                    }
                },
                onCancel: { [weak self] in
                    onCancel?()
                    Task { @MainActor [weak self] in
                        self?.close()
                    }
                }
            )
        }
        rootView = DiscourageSecureCoreView(store: store, dismissOnAction: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.setContentSize(.init(width: Dimensions.sheetWidth, height: Dimensions.sheetHeight))
        view.window?.applyUpsellModalAppearance()
    }

    @MainActor
    private func close() {
        if presentingViewController != nil {
            dismiss(nil)
        } else {
            view.window?.close()
        }
    }
}

private extension DiscourageSecureCoreViewController {
    enum Dimensions {
        static let sheetWidth: CGFloat = 520
        static let sheetHeight: CGFloat = 600
    }
}
