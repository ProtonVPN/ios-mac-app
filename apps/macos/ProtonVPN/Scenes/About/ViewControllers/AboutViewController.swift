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
import LegacyCommon
import WebKit
import Theme
import Ergonomics
import Strings

class AboutViewController: NSViewController {
    
    typealias Factory = NavigationServiceFactory & UpdateManagerFactory
    public var factory: Factory!

    @IBOutlet weak var imageHeader: NSImageView!
    @IBOutlet weak var backgroundView: NSView!
    @IBOutlet weak var versionTitleLabel: PVPNTextField!
    @IBOutlet weak var versionLabel: PVPNTextField!
    @IBOutlet weak var dateTitleLabel: PVPNTextField!
    @IBOutlet weak var dateLabel: PVPNTextField!
    @IBOutlet weak var acknowledgementsButton: InteractiveActionButton!
    @IBOutlet weak var changelogLabel: PVPNTextField!
    @IBOutlet weak var webView: WKWebView!
    
    private lazy var updateManager: UpdateManager = factory.makeUpdateManager()
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
        DarkAppearance {
            backgroundView.layer?.backgroundColor = .cgColor(.background)
        }
    }
    
    private func setupComponents() {
        
        let versionString = NSMutableAttributedString()
        versionString.append(currentVersion.styled(font: .themeFont(bold: true), alignment: .left))
        versionString.append(" (\(currentBuild))".styled(.weak, font: .themeFont(bold: true), alignment: .left))

        imageHeader.image = Theme.Asset.vpnWordmarkAlwaysDark.image
        versionTitleLabel.attributedStringValue = Localizable.versionCurrent.styled(alignment: .left)
        versionLabel.attributedStringValue = versionString
                            
        dateTitleLabel.attributedStringValue = Localizable.releaseDate.styled(alignment: .left)
        dateLabel.attributedStringValue = currentVersionReleaseDate.styled(font: .themeFont(bold: true), alignment: .left)

        acknowledgementsButton.title = Localizable.acknowledgements
        
        changelogLabel.attributedStringValue = Localizable.changelog.styled(font: .themeFont(.heading3, bold: true), alignment: .left)

        DarkAppearance {
            webView.layer?.backgroundColor = .cgColor(.background)
        }
        webView.loadHTMLString(changelogHtml, baseURL: nil)
    }
        
    // MARK: - Texts
    
    private var currentVersion: String {
        return updateManager.currentVersion ?? Localizable.unavailable.lowercased()
    }
    
    private var currentBuild: String {
        return updateManager.currentBuild ?? Localizable.unavailable.lowercased()
    }
    
    private var currentVersionReleaseDate: String {
        guard let currentDate = updateManager.currentVersionReleaseDate else {
            return Localizable.unavailable.lowercased()
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
