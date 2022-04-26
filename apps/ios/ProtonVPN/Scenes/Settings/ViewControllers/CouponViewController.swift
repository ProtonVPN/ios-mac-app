//
//  Created on 05.04.2022.
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
import vpncore
import ProtonCore_UIFoundations

final class CouponViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var textField: PMTextField!
    @IBOutlet private weak var applyButton: UIButton!

    private let viewModel: CouponViewModel
    private var banner: PMBanner?

    // MARK: Setup

    init(viewModel: CouponViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "CouponViewController", bundle: nil)

        viewModel.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupNotifications()
    }

    private func setupUI() {
        title = LocalizedString.useCoupon
        view.backgroundColor = UIColor.backgroundColor()

        textField.autocapitalizationType = .allCharacters
        textField.allowOnlyUppercase = true
        textField.title = LocalizedString.useCoupon

        applyButton.setTitle(LocalizedString.applyCoupon, for: .normal)
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        _ = textField.becomeFirstResponder()
    }

    // MARK: Actions

    @objc private func applyTapped() {
        viewModel.applyPromoCode(code: textField.value) { [weak self] result in
            switch result {
            case let .failure(error):
                self?.showErrorBanner(error: error)
            case let .success(message):
                guard let navigationController = self?.navigationController else {
                    return
                }

                navigationController.popViewController(animated: true) {
                    let banner = PMBanner(message: message, style: PMBannerNewStyle.success)
                    banner.show(at: .top, on: navigationController)
                }
            }
        }
    }

    private func showErrorBanner(error: Error) {
        banner?.dismiss()
        banner = PMBanner(message: error.localizedDescription, style: PMBannerNewStyle.error, dismissDuration: Double.infinity)
        banner?.addButton(text: LocalizedString.ok) { [weak self] _ in
            self?.banner?.dismiss()
        }
        banner?.show(at: .top, on: self)
    }

    // MARK: Keyboard

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        animateWithKeyboard(notification: notification) { [weak self] keyboardFrame in
            self?.adjustForKeyboard(height: keyboardFrame.height - (self?.tabBarController?.tabBar.frame.height ?? 0))
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        animateWithKeyboard(notification: notification) { [weak self] _ in
            self?.adjustForKeyboard(height: 0)
        }
    }

    private func adjustForKeyboard(height: CGFloat) {
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height, right: 0)
        scrollView.scrollIndicatorInsets = scrollView.contentInset
    }
}

// MARK: CouponViewModelDelegate

extension CouponViewController: CouponViewModelDelegate {
    func errorDidChange(isError: Bool) {
        textField.isError = isError

        if !isError {
            banner?.dismiss()
        }
    }

    func loadingDidChange(isLoading: Bool) {
        applyButton.isSelected = isLoading
        view.isUserInteractionEnabled = !isLoading
    }
}
