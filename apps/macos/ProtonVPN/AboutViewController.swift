//
//  AboutViewController.swift
//  ProtonVPN - Created on 27.06.19.
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

class AboutViewController: NSViewController {
    
    typealias Factory = NavigationServiceFactory
    public var factory: Factory!
    
    @IBOutlet weak var backgroundView: NSView!
    @IBOutlet weak var versionTitleLabel: PVPNTextField!
    @IBOutlet weak var versionLabel: PVPNTextField!
    @IBOutlet weak var dateTitleLabel: PVPNTextField!
    @IBOutlet weak var dateLabel: PVPNTextField!
    @IBOutlet weak var acknowledgementsButton: GreenHighlightButton!
    @IBOutlet weak var changelogLabel: PVPNTextField!
    @IBOutlet weak var webView: WKWebView!
    
    private lazy var updateManager: UpdateManager = UpdateManager.shared
    private lazy var bundle: Bundle = Bundle.main
    private lazy var navigationService = factory.makeNavigationService()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    required init() {
        super.init(nibName: NSNib.Name("About"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        setupComponents()
        updateManager.stateUpdated = { [weak self] in
            self?.setupComponents()
        }
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        updateManager.stateUpdated = nil
    }
    
    @IBAction func acknowledgementsPressed(_ sender: Any) {
        navigationService.openAcknowledgements()
    }
    
    private func setupView() {
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.protonGreyShade().cgColor
    }
    
    private func setupComponents() {
        
        let versionString = NSMutableAttributedString()
        versionString.append(currentVersion.attributed(withColor: .protonWhite(), fontSize: 14, bold: true, alignment: .left))
        versionString.append(" (\(currentBuild))".attributed(withColor: .protonGreyOutOfFocus(), fontSize: 14, bold: true, alignment: .left))
                
        versionTitleLabel.attributedStringValue = LocalizedString.versionCurrent.attributed(withColor: .protonWhite(), fontSize: 14, bold: false, alignment: .left)
        versionLabel.attributedStringValue = versionString
                            
        dateTitleLabel.attributedStringValue = LocalizedString.releaseDate.attributed(withColor: .protonWhite(), fontSize: 14, bold: false, alignment: .left)
        dateLabel.attributedStringValue = currentVersionReleaseDate.attributed(withColor: .protonWhite(), fontSize: 14, bold: true, alignment: .left)
        
        acknowledgementsButton.attributedTitle = LocalizedString.acknowledgements.attributed(withColor: .protonGreen(), fontSize: 14, bold: true, alignment: .left)
        
        changelogLabel.attributedStringValue = LocalizedString.changelog.attributed(withColor: .protonWhite(), fontSize: 18, bold: true, alignment: .left)
        webView.loadHTMLString(changelogHtml, baseURL: nil)
    }
        
    // MARK: - Texts
    
    private var currentVersion: String {
        return updateManager.currentVersion ?? LocalizedString.unavailable.lowercased()
    }
    
    private var currentBuild: String {
        return updateManager.currentBuild ?? LocalizedString.unavailable.lowercased()
    }
    
    private var currentVersionReleaseDate: String {
        guard let currentDate = updateManager.currentVersionReleaseDate else {
            return LocalizedString.unavailable.lowercased()
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: currentDate)
    }
    
    private var changelogHtml: String {
        guard let path = Bundle.main.path(forResource: "text-template", ofType: "html"), let htmlTemplate = try? String(contentsOfFile: path) else {
            return ""
        }
        guard let originalReleaseNotes = updateManager.releaseNotes else { return htmlTemplate }
        let htmlBody = originalReleaseNotes.map { extractHtmlBody($0) }.joined()
        let html = htmlTemplate.replacingOccurrences(of: "</body>", with: "\(htmlBody)</body>")
        return html
    }
    
    private func extractHtmlBody(_ input: String) -> String {
        var result = input.replacingOccurrences(of: "<![CDATA[", with: "")
        result = result.replacingOccurrences(of: "<!DOCTYPE html>", with: "")
        result = result.replacingOccurrences(of: "]]>", with: "")
        return result
    }
        
}
