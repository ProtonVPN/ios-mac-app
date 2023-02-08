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
import vpncore

class WelcomeViewController: NSViewController {

    fileprivate enum Switch: Int {
        case usageData
        case crashReports
    }
    
    @IBOutlet weak var mapView: NSImageView!
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var noThanksButton: NSButton!
    @IBOutlet weak var takeTourButton: UpsellPrimaryActionButton!
    @IBOutlet weak var usageStatisticsLabel: NSTextField!
    @IBOutlet weak var crashReportsLabel: NSTextField!
    @IBOutlet weak var usageStatisticsButton: SwitchButton!
    @IBOutlet weak var crashReportsButton: SwitchButton!

    let navService: NavigationService
    let telemetrySettings: TelemetrySettings
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(navService: NavigationService, telemetrySettings: TelemetrySettings) {
        self.navService = navService
        self.telemetrySettings = telemetrySettings
        super.init(nibName: NSNib.Name("Welcome"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.wantsLayer = true
        view.layer?.backgroundColor = .cgColor(.background, .weak)
        
        if let mapImage = mapView.image {
            mapView.image = mapImage.colored(context: .background)
        }
        
        titleLabel.attributedStringValue = LocalizedString.welcomeTitle.styled(font: .themeFont(.title, bold: true))
        
        let description = NSMutableAttributedString(attributedString: LocalizedString.welcomeDescription.styled(font: .themeFont(.heading2)))
        let fullRange = (description.string as NSString).range(of: description.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6
        
        description.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        descriptionLabel.attributedStringValue = description
        
        noThanksButton.title = LocalizedString.noThanks
        takeTourButton.title = LocalizedString.takeTour

        usageStatisticsButton.delegate = self
        crashReportsButton.delegate = self

        // By default, set the telemetry to true
        telemetrySettings.updateTelemetryCrashReports(isOn: true)
        telemetrySettings.updateTelemetryUsageData(isOn: true)

        usageStatisticsButton.buttonView?.tag = Switch.usageData.rawValue
        usageStatisticsButton.setState(.on)
        usageStatisticsButton.maskColor = .cgColor(.background, .weak)
        crashReportsButton.buttonView?.tag = Switch.crashReports.rawValue
        crashReportsButton.setState(.on)
        crashReportsButton.maskColor = .cgColor(.background, .weak)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.applyInfoAppearance()
    }
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(nil)
    }
    
    @IBAction func takeTour(_ sender: Any) {
        dismiss(nil)
        navService.presentGuidedTour()
    }
}
extension WelcomeViewController: SwitchButtonDelegate {
    func shouldToggle(_ button: NSButton, to value: ButtonState, completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func switchButtonClicked(_ button: NSButton) {
        Task {
            switch button.tag {
            case Switch.crashReports.rawValue:
                telemetrySettings.updateTelemetryCrashReports(isOn: button.state == .on)
            case Switch.usageData.rawValue:
                telemetrySettings.updateTelemetryUsageData(isOn: button.state == .on)
            default:
                break
            }
        }
    }
}
