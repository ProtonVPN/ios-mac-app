//
//  Created on 20/06/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ProtonCoreDoh
import ProtonCoreNetworking
import ProtonCoreServices

import CommonNetworking
import Dependencies
import UIKit
import WebKit

final class PaymentsWebViewController: UIViewController {
    private let url: URL
    private let completionHandler: () -> Void

    private let closeButton: UIButton = {
        let button = UIButton.closeButton()
        button.tintColor = .black
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let webViewConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        // alternative routing
        @Dependency(\.dohConfiguration) var doh
        let requestInterceptor = AlternativeRoutingRequestInterceptor(
            headersGetter: doh.getAccountHeaders,
            cookiesSynchronization: doh.synchronizeCookies(with:requestHeaders:completion:),
            cookiesStorage: doh.currentlyUsedCookiesStorage
        ) { challenge, challengeCompletionHandler in
            handleAuthenticationChallenge(
                didReceive: challenge,
                noTrustKit: PMAPIService.noTrustKit,
                trustKit: PMAPIService.trustKit,
                challengeCompletionHandler: challengeCompletionHandler
            )
        }
        requestInterceptor.setup(webViewConfiguration: configuration)

        return configuration
    }()

    private lazy var webView: WKWebView = {
        let webview = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webview.navigationDelegate = self
        webview.translatesAutoresizingMaskIntoConstraints = false
        return webview
    }()

    // MARK: - Life cycle

    init(url: URL, completionHandler: @escaping () -> Void) {
        self.url = url
        self.completionHandler = completionHandler

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        webView.load(URLRequest(url: url))
    }

    // MARK: - Private

    private func setupViews() {
        view.backgroundColor = .white

        let layoutGuide = view.safeAreaLayoutGuide

        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: layoutGuide.topAnchor),
            closeButton.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: Constants.CloseButton.width),
            closeButton.heightAnchor.constraint(equalToConstant: Constants.CloseButton.width),
        ])
        closeButton.addTarget(self, action: #selector(closeWebView), for: .touchUpInside)

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: closeButton.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc
    private func closeWebView(withCompletion: Bool = false) {
        dismiss(animated: true, completion: { [weak self] in
            if withCompletion {
                self?.completionHandler()
            }
        })
    }
}

extension PaymentsWebViewController: WKNavigationDelegate {
    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.request.url?.absoluteString.starts(with: Constants.refreshAccount) == true {
            closeWebView(withCompletion: true)
        }
        decisionHandler(.allow)
    }
}

extension PaymentsWebViewController {
    enum Constants {
        static let refreshAccount = "protonvpn://refresh"

        enum CloseButton {
            static let width: CGFloat = 40
        }
    }
}
