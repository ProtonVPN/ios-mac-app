//
//  Created on 24.02.2022.
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

import Cocoa
import vpncore

final class AdvancedSettingsViewController: NSViewController, ReloadableViewController {

    @IBOutlet private weak var alternativeRoutingLabel: PVPNTextField!
    @IBOutlet private weak var alternativeRoutingButton: SwitchButton!
    @IBOutlet private weak var alternativeRoutingSeparator: NSBox!
    @IBOutlet private weak var alternativeRoutingInfoIcon: NSImageView!

    @IBOutlet private weak var natTypeView: NSView!
    @IBOutlet private weak var natTypeLabel: PVPNTextField!
    @IBOutlet private weak var natTypeSeparator: NSBox!
    @IBOutlet private weak var natTypeInfoIcon: NSImageView!
    @IBOutlet private weak var natTypeButton: SwitchButton!

    @IBOutlet private weak var safeModeView: NSView!
    @IBOutlet private weak var safeModeLabel: PVPNTextField!
    @IBOutlet private weak var safeModeSeparator: NSBox!
    @IBOutlet private weak var safeModeInfoIcon: NSImageView!
    @IBOutlet private weak var safeModeButton: SwitchButton!

    private var viewModel: AdvancedSettingsViewModel

    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }

    required init(viewModel: AdvancedSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("AdvancedSettings"), bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.reloadNeeded = { [weak self] in
            self?.reloadView()
        }
        reloadView()
    }

    private func setupView() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.protonGrey().cgColor
    }

    private func setupAlternativeRoutingItem() {
        alternativeRoutingLabel.attributedStringValue = LocalizedString.troubleshootItemAltTitle.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        alternativeRoutingInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        let tooltip = LocalizedString.troubleshootItemAltDescription
            .replacingOccurrences(of: LocalizedString.troubleshootItemAltLink1, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        alternativeRoutingInfoIcon.toolTip = String(tooltip)

        alternativeRoutingButton.setState(viewModel.alternativeRouting ? .on : .off)
        alternativeRoutingButton.delegate = self

        alternativeRoutingSeparator.fillColor = .protonLightGrey()
    }

    private func setupNatTypeItem() {
        natTypeView.isHidden = !viewModel.isNATTypeFeatureEnabled
        natTypeLabel.attributedStringValue = LocalizedString.moderateNatTitle.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        natTypeInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        let tooltip = LocalizedString.moderateNatExplanation
            .replacingOccurrences(of: LocalizedString.moderateNatExplanationLink, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        natTypeInfoIcon.toolTip = String(tooltip)
        natTypeSeparator.fillColor = .protonLightGrey()

        natTypeButton.setState(viewModel.natType == .moderateNAT ? .on : .off)
        natTypeButton.delegate = self
    }

    private func setupSafeModeItem() {
        safeModeView.isHidden = !viewModel.isSafeModeFeatureEnabled
        safeModeLabel.attributedStringValue = LocalizedString.nonStandardPortsTitle.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
        safeModeInfoIcon.image = NSImage(named: NSImage.Name("info_green"))
        let tooltip = LocalizedString.nonStandardPortsExplanation
            .replacingOccurrences(of: LocalizedString.nonStandardPortsExplanationLink, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        safeModeInfoIcon.toolTip = String(tooltip)
        safeModeSeparator.fillColor = .protonLightGrey()

        safeModeButton.setState(viewModel.safeMode ? .off : .on)
        safeModeButton.delegate = self
    }

    // MARK: - ReloadableViewController

    func reloadView() {
        setupView()
        setupAlternativeRoutingItem()
        setupNatTypeItem()
        setupSafeModeItem()
    }
}

extension AdvancedSettingsViewController: SwitchButtonDelegate {
    func shouldToggle(_ button: NSButton, to value: ButtonState, completion: @escaping (Bool) -> Void) {
        switch button.superview {
        case natTypeButton:
            viewModel.setNatType(natType: value == .on ? .moderateNAT : .strictNAT, completion: completion)
        case safeModeButton:
            viewModel.setSafeMode(safeMode: value == .off, completion: completion)
        default:
            completion(true)
        }
    }

    func switchButtonClicked(_ button: NSButton) {
        switch button.superview {
        case alternativeRoutingButton:
            viewModel.setAlternatveRouting(alternativeRoutingButton.currentButtonState == .on)

        default:
            break // Do nothing
        }
    }
}
