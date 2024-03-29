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
import LegacyCommon
import Ergonomics
import Strings

final class AdvancedSettingsViewController: NSViewController, ReloadableViewController {

    @IBOutlet private weak var alternativeRoutingView: SettingsTickboxView!
    @IBOutlet private weak var natTypeView: SettingsTickboxView!
    @IBOutlet private weak var safeModeView: SettingsTickboxView!
    @IBOutlet private weak var usageDataView: SettingsTickboxView!
    @IBOutlet private weak var crashReportsView: SettingsTickboxView!

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
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background, .weak)
        }
    }

    private func setupAlternativeRoutingItem() {
        let tooltip = Localizable.troubleshootItemAltDescription
            .replacingOccurrences(of: Localizable.troubleshootItemAltLink1, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let model = SettingsTickboxView.ViewModel(labelText: Localizable.troubleshootItemAltTitle, buttonState: viewModel.alternativeRouting, toolTip: String(tooltip))

        alternativeRoutingView.setupItem(model: model, delegate: self)
    }

    private func setupNatTypeItem() {
        let featureState = viewModel.natDisplayState
        natTypeView.isHidden = !viewModel.isNATTypeFeatureEnabled
        let tooltip = Localizable.moderateNatExplanation
            .replacingOccurrences(of: Localizable.moderateNatExplanationLink, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let model = SettingsTickboxView.ViewModel(
            labelText: Localizable.moderateNatTitle,
            state: featureState,
            toolTip: String(tooltip)
        )

        natTypeView.setupItem(model: model, delegate: self)
    }

    private func setupUsageDataTypeItem() {
        usageDataView.isHidden = !viewModel.isTelemetryFeatureEnabled
        let tooltip = Localizable.settingsMacUsageStatsTooltip
        let model = SettingsTickboxView.ViewModel(labelText: Localizable.settingsMacUsageStatsTitle,
                                                  buttonState: viewModel.usageData,
                                                  toolTip: String(tooltip))

        usageDataView.setupItem(model: model, delegate: self)
    }

    private func setupCrashReportsTypeItem() {
        crashReportsView.isHidden = !viewModel.isTelemetryFeatureEnabled
        let tooltip = Localizable.settingsMacCrashReportsTooltip
        let model = SettingsTickboxView.ViewModel(labelText: Localizable.settingsMacCrashReportsTitle,
                                                  buttonState: viewModel.crashReports,
                                                  toolTip: String(tooltip))

        crashReportsView.setupItem(model: model, delegate: self)
    }

    private func setupSafeModeItem() {
        safeModeView.isHidden = !viewModel.isSafeModeFeatureEnabled
        let tooltip = Localizable.nonStandardPortsExplanation
            .replacingOccurrences(of: Localizable.nonStandardPortsExplanationLink, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Non-standars ports are enabled when Safe Mode is disabled
        let model = SettingsTickboxView.ViewModel(labelText: Localizable.nonStandardPortsTitle, buttonState: !viewModel.safeMode, toolTip: String(tooltip))

        safeModeView.setupItem(model: model, delegate: self)
    }

    // MARK: - ReloadableViewController

    func reloadView() {
        setupView()
        setupAlternativeRoutingItem()
        setupNatTypeItem()
        setupSafeModeItem()
        setupUsageDataTypeItem()
        setupCrashReportsTypeItem()
    }
}

extension AdvancedSettingsViewController: TickboxViewDelegate {
    func toggleTickbox(_ tickboxView: SettingsTickboxView, to value: ButtonState) {
        switch tickboxView {
        case natTypeView:
            viewModel.setNatType(natType: value == .on ? .moderateNAT : .strictNAT) { [weak self] _ in
                self?.setupNatTypeItem()
            }
        case safeModeView:
            viewModel.setSafeMode(safeMode: value == .off) { [weak self] _ in
                self?.setupSafeModeItem()
            }
        case alternativeRoutingView:
            viewModel.setAlternatveRouting(value == .on)
            setupAlternativeRoutingItem()
        case usageDataView:
            viewModel.usageData = value == .on
        case crashReportsView:
            viewModel.crashReports = value == .on
        default:
            break
        }
    }

    func upsellTapped(_ tickboxView: SettingsTickboxView) {
        switch tickboxView {
        case natTypeView:
            viewModel.showNATUpsell()
        case safeModeView:
            viewModel.showSafeModeUpsell()
        default:
            break
        }
    }
}
