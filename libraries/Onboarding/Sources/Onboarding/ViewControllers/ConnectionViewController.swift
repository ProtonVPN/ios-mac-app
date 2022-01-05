//
//  Created on 04.01.2022.
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

import Foundation
import UIKit

protocol ConnectionViewControllerDelegate: AnyObject {
    func userDidRequestConnection(completion: @escaping (Result<Country, Error>) -> Void)
}

final class ConnectionViewController: UIViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var noteLabel: UILabel!
    @IBOutlet private weak var connectButton: UIButton!
    @IBOutlet private weak var purchaseButon: UIButton!

    weak var delegate: ConnectionViewControllerDelegate?

    private lazy var activityView: UIActivityIndicatorView = {
        let activityView = UIActivityIndicatorView()
        activityView.translatesAutoresizingMaskIntoConstraints = false
        activityView.color = colors.text
        activityView.hidesWhenStopped = true
        return activityView
    }()

    private var isConnecting: Bool = false {
        didSet {
            if isConnecting {
                activityView.startAnimating()
            } else {
                activityView.stopAnimating()
            }
            view.isUserInteractionEnabled = !isConnecting
            connectButton.backgroundColor = isConnecting ? colors.activeBrandButton : colors.brand
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        baseViewStyle(view)
        titleStyle(titleLabel)
        centeredTextStyle(subtitleLabel)
        textNoteStyle(noteLabel)
        actionButtonStyle(connectButton)
        actionTextButtonStyle(purchaseButon)

        titleLabel.text = LocalizedString.onboardingEstablishTitle
        subtitleLabel.text = LocalizedString.onboardingEstablishSubtitle
        noteLabel.text = LocalizedString.onboardingEstablishNote
        connectButton.setTitle(LocalizedString.onboardingEstablishConnectNow, for: .normal)
        purchaseButon.setTitle(LocalizedString.onboardingEstablishAccessAll, for: .normal)

        connectButton.addSubview(activityView)
        NSLayoutConstraint.activate([
            activityView.trailingAnchor.constraint(equalTo: connectButton.trailingAnchor, constant: -16),
            activityView.centerYAnchor.constraint(equalTo: connectButton.centerYAnchor)
        ])
    }

    @IBAction private func connectTapped(_ sender: Any) {
        isConnecting = true

        delegate?.userDidRequestConnection { [weak self] _ in
            self?.isConnecting = false
        }
    }

    @IBAction private func purchaseTapped(_ sender: Any) {

    }
}
