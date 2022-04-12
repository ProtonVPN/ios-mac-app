//
//  Created on 12.04.2022.
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

import Cocoa
import vpncore

protocol CouponViewControllerDelegate: AnyObject {
    func userDidCloseCouponViewController()
}

final class CouponViewController: NSViewController {
    @IBOutlet private weak var closeButton: NSButton!

    weak var delegate: CouponViewControllerDelegate?

    private let viewModel: CouponViewModel

    init(viewModel: CouponViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "CouponViewController", bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupActions()
    }

    private func setupUI() {
        view.wantsLayer = true

        let shadow = NSShadow()
        shadow.shadowColor = .protonDarkGrey()
        shadow.shadowBlurRadius = 8
        view.shadow = shadow
        view.layer?.masksToBounds = false
        view.layer?.shadowRadius = 5
    }

    private func setupActions() {
        closeButton.target = self
        closeButton.action = #selector(close)
    }

    @objc private func close() {
        delegate?.userDidCloseCouponViewController()
    }
}
