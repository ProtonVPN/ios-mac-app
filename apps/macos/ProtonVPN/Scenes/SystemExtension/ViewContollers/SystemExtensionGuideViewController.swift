//
//  Created on 06/03/2023.
//
//  Copyright (c) 2023 Proton AG
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
import Combine
import SwiftUI

import Domain
import LegacyCommon
import VPNAppCore

class SystemExtensionGuideViewController: NSViewController {
    private var cancellables = Set<AnyCancellable>()

    weak var windowService: WindowService?

    var finishedTour: Bool = false

    var cancelledHandler: () -> Void

    let origin: SystemExtensionTourAlert.Origin

    init(origin: SystemExtensionTourAlert.Origin, cancelledHandler: @escaping () -> Void) {
        self.origin = origin
        self.cancelledHandler = cancelledHandler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isSequoiaOrNewer = if #available(macOS 15, *) {
        true
    } else {
        false
    }

    override func loadView() {
        let tutorialView = SystemExtensionsTutorialView(
            isSequoiaOrNewer: isSequoiaOrNewer,
            origin: origin
        )
        .preferredColorScheme(.dark)
        view = NSHostingView(rootView: tutorialView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppEvent.systemExtensionsAllInstalled.publisher
            .sink(receiveValue: { [weak self] _ in
                self?.allExtensionsInstalled()
            })
            .store(in: &cancellables)
    }

    func allExtensionsInstalled() {
        finishedTour = true
        view.window?.close()
    }

    func userWillCloseWindow() {
        if !finishedTour {
            cancelledHandler()
        }
    }
}

extension SystemExtensionGuideViewController: WindowControllerDelegate {
    func windowCloseRequested(_ sender: WindowController) {
        windowService?.windowCloseRequested(sender)
    }

    func windowWillClose(_ sender: WindowController) {
        userWillCloseWindow()
        windowService?.windowWillClose(sender)
    }
}
