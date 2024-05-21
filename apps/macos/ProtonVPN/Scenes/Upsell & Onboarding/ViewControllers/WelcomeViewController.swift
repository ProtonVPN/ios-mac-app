//
//  WelcomeViewController.swift
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
import LocalFeatureFlags
import Theme
import Ergonomics
import Strings

final class WelcomeViewController: NSViewController {

    fileprivate enum Switch: Int {
        case usageData
        case crashReports
    }
    
    @IBOutlet weak var mapView: NSImageView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var noThanksButton: UpsellPrimaryActionButton!
    @IBOutlet weak var usageStatisticsLabel: NSTextField!
    @IBOutlet weak var crashReportsLabel: NSTextField!
    @IBOutlet weak var usageStatisticsButton: SwitchButton!
    @IBOutlet weak var crashReportsButton: SwitchButton!
    @IBOutlet weak var telemetryStackView: NSStackView!
    @IBOutlet weak var learnMore: InteractiveActionButton!

    let telemetrySettings: TelemetrySettings
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(telemetrySettings: TelemetrySettings) {
        self.telemetrySettings = telemetrySettings
        super.init(nibName: NSNib.Name("Welcome"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background, .weak)
        }
        
        if let mapImage = mapView.image {
            mapView.image = mapImage.colored(context: .background)
        }
        
        titleLabel.attributedStringValue = Localizable.welcomeTitle.styled(font: .themeFont(.title, bold: true))
        usageStatisticsLabel.attributedStringValue = Localizable.onboardingMacUsageStats.styled(font: .themeFont(.small), alignment: .left)
        crashReportsLabel.attributedStringValue = Localizable.onboardingMacCrashReports.styled(font: .themeFont(.small), alignment: .left)
        
        let description = NSMutableAttributedString(attributedString: Localizable.welcomeDescription.styled(font: .themeFont(.heading2)))
        let fullRange = (description.string as NSString).range(of: description.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6
        
        description.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        descriptionLabel.attributedStringValue = description
        
        noThanksButton.title = Localizable.continue

        setupTelemetry()
    }

    func setupTelemetry() {
        guard LocalFeatureFlags.isEnabled(TelemetryFeature.telemetryOptIn) else {
            telemetryStackView.isHidden = true
            return
        }

        learnMore.fontSize = .small
        learnMore.title = Localizable.learnMore
        learnMore.target = self
        learnMore.action = #selector(learnMoreClicked)

        usageStatisticsButton.delegate = self
        crashReportsButton.delegate = self

        // Telemetry and crash report is on by default
        telemetrySettings.updateTelemetryUsageData(isOn: true)
        telemetrySettings.updateTelemetryCrashReports(isOn: true)

        usageStatisticsButton.buttonView?.tag = Switch.usageData.rawValue
        usageStatisticsButton.setState(.on)
        crashReportsButton.buttonView?.tag = Switch.crashReports.rawValue
        crashReportsButton.setState(.on)

        DarkAppearance {
            usageStatisticsButton.maskColor = .cgColor(.background, .weak)
            crashReportsButton.maskColor = .cgColor(.background, .weak)
        }
    }

    @objc func learnMoreClicked() {
        SafariService().open(url: CoreAppConstants.ProtonVpnLinks.learnMoreTelemetry)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyInfoAppearance()
    }
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(nil)
    }
}
extension WelcomeViewController: SwitchButtonDelegate {
    func shouldToggle(_ button: NSButton, to value: ButtonState, completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func switchButtonClicked(_ button: NSButton) {
        switch button.tag {
        case Switch.crashReports.rawValue:
            telemetrySettings.updateTelemetryCrashReports(isOn: crashReportsButton.currentButtonState == .on)
        case Switch.usageData.rawValue:
            telemetrySettings.updateTelemetryUsageData(isOn: usageStatisticsButton.currentButtonState == .on)
        default:
            break
        }
    }
}
