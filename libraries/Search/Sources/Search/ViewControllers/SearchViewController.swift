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

protocol SearchViewControllerDelegate: AnyObject {
    func userDidSelectCountry(model: CountryViewModel)
    func userDidRequestPlanPurchase()
}

final class SearchViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noResultsView: NoResultsView!
    @IBOutlet weak var noResultsBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var placeholderViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var placeholderView: PlaceholderView!

    // MARK: Properties

    var viewModel: SearchViewModel!
    weak var delegate: SearchViewControllerDelegate?

    lazy var recentSearchesHeaderView: RecentSearchesHeaderView = {
        let view = Bundle.module.loadNibNamed("RecentSearchesHeaderView", owner: self, options: nil)?.first as! RecentSearchesHeaderView
        view.delegate = self
        return view
    }()

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
        searchBarStyle(searchBar)

        title = LocalizedString.searchTitle
        searchBar.placeholder = LocalizedString.searchBarPlaceholder
        placeholderView.onlyCountries = viewModel.mode == .secureCore
    }

    private func setupData() {
        viewModel.delegate = self
        searchBar.delegate = self

        tableView.register(RecentSearchCell.nib, forCellReuseIdentifier: RecentSearchCell.identifier)
        tableView.register(CountryCell.nib, forCellReuseIdentifier: CountryCell.identifier)
        tableView.register(ServerCell.nib, forCellReuseIdentifier: ServerCell.identifier)
        tableView.register(UpsellCell.nib, forCellReuseIdentifier: UpsellCell.identifier)
        tableView.register(SearchSectionHeaderView.nib, forHeaderFooterViewReuseIdentifier: SearchSectionHeaderView.identifier)
        tableView.dataSource = self
        tableView.delegate = self

        statusDidChange(status: viewModel.status)
    }

    // MARK: Keyboard

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard viewIfLoaded?.window != nil else {
            return
        }

        animateWithKeyboard(notification: notification) { [weak self] keyboardFrame in
            self?.adjustForKeyboard(height: keyboardFrame.height - (self?.tabBarController?.tabBar.frame.height ?? 0))
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        guard viewIfLoaded?.window != nil else {
            return
        }

        if let searchText = searchBar.text, !searchText.isEmpty {
            viewModel.saveSearch(searchText: searchText)
        }

        animateWithKeyboard(notification: notification) { [weak self] keyboardFrame in
            self?.adjustForKeyboard(height: keyboardFrame.height)
        }
    }

    private func adjustForKeyboard(height: CGFloat) {
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height, right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
        noResultsBottomConstraint.constant = height
        placeholderViewBottomConstraint.constant = height
    }
}

// MARK: View Model delegate

extension SearchViewController: SearchViewModelDelegate {
    func statusDidChange(status: SearchStatus) {
        tableView.isHidden = true
        placeholderView.isHidden = true
        noResultsView.isHidden = true

        switch status {
        case .placeholder:
            placeholderView.isHidden = false
        case .noResults:
            noResultsView.isHidden = false
        case .results:
            tableView.isHidden = false
            tableView.reloadData()
        case .recentSearches:
            tableView.isHidden = false
            tableView.reloadData()
        }
    }
}
