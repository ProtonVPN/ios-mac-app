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

    private lazy var recentSearchesHeaderView: RecentSearchesHeaderView = {
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
        indicatorStyle(activityIndicator)

        title = LocalizedString.searchTitle
        searchBar.placeholder = LocalizedString.searchBarPlaceholder
    }

    private func setupData() {
        viewModel.delegate = self
        searchBar.delegate = self

        tableView.register(UINib(nibName: "RecentSearchCell", bundle: Bundle.module), forCellReuseIdentifier: RecentSearchCell.reuseIdentifier)
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
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }

        adjustForKeyboard(height: keyboardSize.height)
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        if let searchText = searchBar.text, !searchText.isEmpty {
            viewModel.saveSearch(searchText: searchText)
        }

        adjustForKeyboard(height: 0)
    }

    private func adjustForKeyboard(height: CGFloat) {
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: height, right: 0)
        noResultsBottomConstraint.constant = height
        placeholderViewBottomConstraint.constant = height
        activityIndicatorCenterYConstraint.constant = -height / 2

        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: View Model delegate

extension SearchViewController: SearchViewModelDelegate {
    func statusDidChange(status: SearchStatus) {
        placeholderView.isHidden = status != .placeholder
        activityIndicator.isHidden = status != .searching
        noResultsView.isHidden = status != .noResults

        tableView.reloadData()
    }
}

// MARK: Table view delegate

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch viewModel.status {
        case .searching, .noResults, .placeholder, .results:
            return 0
        case .recentSearches:
            return viewModel.recentSearches.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.status {
        case .searching, .noResults, .placeholder, .results:
            fatalError("Invalid usage")
        case .recentSearches:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: RecentSearchCell.reuseIdentifier)  as? RecentSearchCell else {
                fatalError("Invalid configuration")
            }
            cell.title = viewModel.recentSearches[indexPath.row]
            return cell
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        switch viewModel.status {
        case .searching, .noResults, .placeholder, .results:
            return 0
        case .recentSearches:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch viewModel.status {
        case .searching, .noResults, .placeholder, .results:
            return nil
        case .recentSearches:
            recentSearchesHeaderView.count = viewModel.recentSearches.count
            return recentSearchesHeaderView
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch viewModel.status {
        case .searching, .noResults, .placeholder, .results:
            break
        case .recentSearches:
            tableView.deselectRow(at: indexPath, animated: true)
            searchBar.text = viewModel.recentSearches[indexPath.row]
            viewModel.search(searchText: viewModel.recentSearches[indexPath.row])
        }
    }
}

// MARK: Recent searches delegate

extension SearchViewController: RecentSearchesHeaderViewDelegate {
    func userDidRequestClear() {
        let alert = UIAlertController(title: nil, message: LocalizedString.searchRecentClearTitle, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LocalizedString.searchRecentClearCancel, style: .default))
        alert.addAction(UIAlertAction(title: LocalizedString.searchRecentClearContinue, style: .default) { [weak self] _ in
            self?.viewModel.clearRecentSearches()
        })

        present(alert, animated: true, completion: nil)
    }
}

// MARK: Search bar delegate

extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.search(searchText: searchText)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
        _ = searchBar.resignFirstResponder()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        _ = searchBar.resignFirstResponder()
    }
}
