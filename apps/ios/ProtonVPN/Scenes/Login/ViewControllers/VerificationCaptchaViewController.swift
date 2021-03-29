//
//  VerificationCaptchaViewController.swift
//  ProtonVPN - Created on 24/10/2019.
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

import GSMessages
import UIKit
import vpncore

class VerificationCaptchaViewController: UIViewController {
    
    @IBOutlet weak var webView: UIWebView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var logoVerticalConstraint: NSLayoutConstraint!
        
    var viewModel: VerificationCaptchaViewModel!
    
    var captchaToken: String {
        return viewModel.captchaToken
    }
    
    private lazy var captchaUrl = "https://\(ApiConstants.captchaHost)/captcha/captcha.html?client=ios&host=\(ApiConstants.baseHost)&token=\(captchaToken)"
    private let captchaExpiredUrl = "https://\(ApiConstants.captchaHost)/expired_recaptcha_response://"
    private let captchaResponseUrl = "https://\(ApiConstants.captchaHost)/captcha/recaptcha_response://"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .protonPlansGrey()
        webView.backgroundColor = .protonPlansGrey()
        
        logoVerticalConstraint.constant = UIDevice.current.hasNotch ? 20 : 10        
        setupWebView()
    }
    
    private func setupWebView() {
        webView.delegate = self
        webView.scrollView.isScrollEnabled = UIDevice.current.isSmallIphone
        let recaptcha = URL(string: captchaUrl)!
        let requestObj = URLRequest(url: recaptcha)
        viewModel.captchaLoadingStarted()
        webView.loadRequest(requestObj)
    }
    
}

extension VerificationCaptchaViewController: UIWebViewDelegate {
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        PMLog.D("\(request)")
        let urlString = request.url?.absoluteString

        activityIndicator.startAnimating()
        
        if urlString?.range(of: captchaExpiredUrl) != nil {
            webView.reload()
            return false
        }
        
        if urlString?.range(of: captchaResponseUrl) != nil {
            if let token = urlString?.replacingOccurrences(of: captchaResponseUrl, with: "", options: NSString.CompareOptions.widthInsensitive, range: nil) {
                viewModel.setCaptchaToken(token)
            }
            return false
        }
        
        return true
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        activityIndicator.stopAnimating()
    }
}
