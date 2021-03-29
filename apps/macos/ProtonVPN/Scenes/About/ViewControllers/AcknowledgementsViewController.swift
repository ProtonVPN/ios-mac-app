//
//  AcknowledgementsViewController.swift
//  ProtonVPN - Created on 2019-11-11.
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

import Cocoa
import vpncore
import WebKit

class AcknowledgementsViewController: NSViewController {

    @IBOutlet weak var webView: WKWebView!
    
    private lazy var bundle: Bundle = Bundle.main
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required init() {
        super.init(nibName: NSNib.Name("Acknowledgements"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        setupComponents()
    }
    
    private func setupComponents() {        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private var html: String {
        guard let path = Bundle.main.path(forResource: "text-template", ofType: "html"), let htmlTemplate = try? String(contentsOfFile: path) else {
            return ""
        }
        guard let path2 = Bundle.main.path(forResource: "Pods-ProtonVPN-metadata", ofType: "plist"),
            let metadata = NSDictionary(contentsOfFile: path2),
            let libraries = metadata["specs"] as? [NSDictionary]
        else {
           return htmlTemplate
        }
        
        let htmlBody = libraries.map {
            let title = $0["name"] as? String ?? ""
            var description = $0["licenseText"] as? String ?? ""
            description = description.replacingOccurrences(of: "\n", with: "<br />")
            return "<h2>\(title)</h2> <p class=\"license-text\">\(description)</p>"
        }.joined()
        let html = htmlTemplate.replacingOccurrences(of: "</body>", with: "\(htmlBody)</body>")
        return html
    }
    
}
