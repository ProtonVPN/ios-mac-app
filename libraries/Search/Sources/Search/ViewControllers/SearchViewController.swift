//
//  Created on 02.03.2022.
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

final class SearchViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var noResultsView: NoResultsView!
    @IBOutlet private weak var noResultsBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var placeholderViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var activityIndicatorCenterYConstraint: NSLayoutConstraint!
    @IBOutlet private weak var placeholderView: PlaceholderView!

    // MARK: Properties

    var viewModel: SearchViewModel!

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupData()
        setupNotifications()
    }

    private func setupUI() {
        baseViewStyle(view)
        baseViewStyle(tableView)
        baseViewStyle(searchBar)

        title = LocalizedString.searchTitle
    }

    private func setupData() {
        viewModel.delegate = self

        statusDidChange(status: viewModel.status)
    }

    // MARK: Keyboard

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }

        adjustForKeyboard(height: keyboardSize.height)
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        adjustForKeyboard(height: 0)
    }

    private func adjustForKeyboard(height: CGFloat) {
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height, right: 0)
        noResultsBottomConstraint.constant = height
        placeholderViewBottomConstraint.constant = height
        activityIndicatorCenterYConstraint.constant = height

        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: Delegate

extension SearchViewController: SearchViewModelDelegate {
    func statusDidChange(status: SearchStatus) {
        placeholderView.isHidden = status != .placeholder
        activityIndicator.isHidden = status != .searching
        noResultsView.isHidden = status != .noResults
    }
}
