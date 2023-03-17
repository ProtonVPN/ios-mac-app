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
import vpncore

@available(macOS 11.0, *)
class SystemExtensionGuideViewController: NSViewController {

    private var cancellables = Set<AnyCancellable>()

    weak var windowService: WindowService?

    var finishedTour: Bool = false

    var cancelledHandler: () -> Void

    init(cancelledHandler: @escaping () -> Void) {
        self.cancelledHandler = cancelledHandler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSHostingView(rootView: SystemExtensionTutorialView())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default
            .publisher(for: SystemExtensionManager.allExtensionsInstalled)
            .sink(receiveValue: allExtensionsInstalled)
            .store(in: &cancellables)
    }

    func allExtensionsInstalled(_ notification: Notification) {
        finishedTour = true
        self.view.window?.close()
    }

    func userWillCloseWindow() {
        if !finishedTour {
            cancelledHandler()
        }
    }
}

@available(macOS 11.0, *)
extension SystemExtensionGuideViewController: WindowControllerDelegate {
    func windowCloseRequested(_ sender: WindowController) {
        windowService?.windowCloseRequested(sender)
    }

    func windowWillClose(_ sender: WindowController) {
        self.userWillCloseWindow()
        windowService?.windowWillClose(sender)
    }
}
