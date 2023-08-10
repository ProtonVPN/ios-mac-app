//
//  SSOWebViewController.swift
//  ProtonVPN - Created on 30.06.23.
//
//  Copyright (c) 2023 Proton Technologies AG
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

import Cocoa
import WebKit
import ProtonCoreCoreTranslation
import ProtonCoreNetworking
import ProtonCoreObservability
import ProtonCoreUIFoundations

protocol SSOWebViewControllerDelegate: AnyObject {
    func didDismissViewController()
    func identifyAndProcessSSOResponseToken(from: URL?) -> Bool
}

final class SSOWebViewController: NSViewController {
    
    private var webView: WKWebView?
    
    @IBOutlet private weak var progressIndicator: NSProgressIndicator?
    
    private let request: URLRequest
    private let viewModel: LoginViewModel
    private weak var delegate: SSOWebViewControllerDelegate?
    
    init(request: URLRequest, delegate: SSOWebViewControllerDelegate, viewModel: LoginViewModel) {
        self.request = request
        self.delegate = delegate
        self.viewModel = viewModel
        super.init(nibName: "SSOWebViewController", bundle: .main)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = CoreString._ls_sign_in_with_sso_title
        let webViewConfiguration = WKWebViewConfiguration()
        webViewConfiguration.websiteDataStore = .nonPersistent()
        webViewConfiguration.defaultWebpagePreferences.preferredContentMode = .desktop
        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = self
        self.webView = webView
        view.addSubview(webView, positioned: .below, relativeTo: progressIndicator)
        webView.translatesAutoresizingMaskIntoConstraints = false
        let layoutGuide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor),
            webView.topAnchor.constraint(equalTo: layoutGuide.topAnchor)
        ])
        webView.load(request)
        progressIndicator?.set(tintColor: ColorProvider.InteractionNorm)
        startProgressIndicator()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.styleMask = [.closable, .titled, .resizable]
        view.window?.minSize = NSSize(width: 300, height: 500)
        view.window?.maxSize = NSSize(width: 800, height: 1200)
    }
    
    private func startProgressIndicator() {
        progressIndicator?.startAnimation(self)
        progressIndicator?.isHidden = false
    }
    
    private func stopProgressIndicator() {
        progressIndicator?.stopAnimation(self)
        progressIndicator?.isHidden = true
    }
}

extension SSOWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let delegate, delegate.identifyAndProcessSSOResponseToken(from: navigationAction.request.url) {
            decisionHandler(.cancel)
            dismiss(self)
        } else {
            decisionHandler(.allow)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish nav: WKNavigation!) {
        stopProgressIndicator()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.isHidden = false
        stopProgressIndicator()
    }

    func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        webView.isHidden = false
        stopProgressIndicator()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        if let response = navigationResponse.response as? HTTPURLResponse {
            handleNetworkResponse(response: response)
        }

        decisionHandler(.allow)
    }
    
    private func handleNetworkResponse(response: HTTPURLResponse) {
        let isProtonPage = viewModel.isProtonPage(url: response.url)
        switch ObservabilityEvent.ssoWebPageLoadCountTotal(responseStatusCode: response.statusCode,
                                                           isProtonPage: isProtonPage) {
        case .left(let event)?:
            ObservabilityEnv.report(event)
        case .right(let event)?:
            ObservabilityEnv.report(event)
        case nil:
            break
        }
    }
}

extension SSOWebViewController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        ObservabilityEnv.report(.ssoIdentityProviderLoginResult(status: .canceled))
        delegate?.didDismissViewController()
    }
}
