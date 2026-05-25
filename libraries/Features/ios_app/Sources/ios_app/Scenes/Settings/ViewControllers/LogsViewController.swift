//
//  LogsViewController.swift
//  ProtonVPN - Created on 01.07.19.
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

import ComposableArchitecture
import Ergonomics
import LegacyCommon
import UIKit

final class LogsViewController: UIViewController {
    private let textView = UITextView().with {
        $0.backgroundColor = .clear
        $0.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        $0.textColor = .normalTextColor()
        $0.text = ""
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let loadingIndicator = UIActivityIndicatorView(style: .large).with {
        $0.hidesWhenStopped = true
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private let store: StoreOf<LogsViewFeature>
    private var renderedLogs = ""

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(store: StoreOf<LogsViewFeature>) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLayout()
        view.backgroundColor = .backgroundColor()

        observeState()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share(_:)))
        store.send(.onViewDidLoad)
    }

    private func observeState() {
        observe { [weak self] in
            guard let self else { return }

            navigationItem.title = store.title

            if store.isLoading {
                loadingIndicator.startAnimating()
            } else {
                loadingIndicator.stopAnimating()
            }

            if renderedLogs != store.logs {
                renderedLogs = store.logs
                textView.text = store.logs
                scrollToBottom(animated: false)
            }
        }
    }

    private func setupLayout() {
        view.addSubview(textView)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func scrollToBottom(animated: Bool) {
        guard !textView.text.isEmpty else { return }
        let lastCharRange = NSRange(location: textView.text.utf16.count - 1, length: 1)
        if animated {
            textView.scrollRangeToVisible(lastCharRange)
        } else {
            UIView.performWithoutAnimation {
                textView.scrollRangeToVisible(lastCharRange)
            }
        }
    }

    @objc
    private func share(_: UIBarButtonItem) {
        store.send(.shareTapped)
    }
}
