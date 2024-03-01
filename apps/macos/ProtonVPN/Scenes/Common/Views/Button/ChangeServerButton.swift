//
//  Created on 31/08/2023.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation
import LegacyCommon
import Cocoa
import ProtonCoreUIFoundations
import Strings
import Theme
import Ergonomics

/// Uses text fields and an image view to display the `unavailable` state, because I went mad trying to implement an
/// NSButton subclass with multiple strings aligned to different edges, with padding and an image
class ChangeServerView: NSView {

    @IBOutlet private weak var button: ChangeServerButton!
    @IBOutlet private weak var changeServerLabel: NSTextField!
    @IBOutlet private weak var hourglassImageView: NSImageView!
    @IBOutlet private weak var timerLabel: NSTextField!

    var handler: (() -> Void)?

    var state: ServerChangeViewState = .available {
        didSet {
            updateView()
            needsDisplay = true
        }
    }

    private func updateView() {
        hourglassImageView.image = IconProvider.hourglass
        hourglassImageView.contentTintColor = .color(.text, .normal)

        switch state {
        case .available:
            button.attributedTitle = Localizable.changeServer
                .styled(.normal, font: .themeFont(.heading4))
            changeServerLabel.attributedStringValue = .init()
            hourglassImageView.isHidden = true
            timerLabel.attributedStringValue = .init()

        case .unavailable(let duration):
            button.attributedTitle = .init()
            changeServerLabel.attributedStringValue = Localizable.changeServer
                .styled(.weak, font: .themeFont(.heading4))
            hourglassImageView.isHidden = false
            timerLabel.attributedStringValue = duration
                .styled(.normal, font: .themeFont(.heading4))
        }
    }

    @IBAction func onButtonTapped(_ sender: Any) {
        handler?()
    }
}
extension ChangeServerView: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .text:
            return .normal
        default:
            break
        }

        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}

class ChangeServerButton: HoverDetectionButton {
    override func viewWillDraw() {
        super.viewWillDraw()

        wantsLayer = true
        layer?.borderWidth = 2
        layer?.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        DarkAppearance {
            layer?.borderColor = self.cgColor(.border)
            layer?.backgroundColor = self.cgColor(.background)
        }
    }
}

extension ChangeServerButton: CustomStyleContext {
    func customStyle(context: AppTheme.Context) -> AppTheme.Style {
        switch context {
        case .background:
            return isHovered ? [.interactive, .hovered] : .transparent
        case .text:
            return .normal
        case .border:
            return isHovered ? AppTheme.Style.transparent : .normal
        default:
            break
        }

        log.assertionFailure("Context not handled: \(context)")
        return .normal
    }
}
