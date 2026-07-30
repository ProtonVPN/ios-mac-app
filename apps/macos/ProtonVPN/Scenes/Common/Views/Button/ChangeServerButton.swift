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

import Cocoa
import Ergonomics
import Foundation
import ProtonCoreUIFoundations
import SharedViews
import Strings
import Theme
import VPNAppCore

/// Uses text fields and an image view to display the `unavailable` state, because I went mad trying to implement an
/// NSButton subclass with multiple strings aligned to different edges, with padding and an image
class ChangeServerView: NSView {
    private lazy var button = ChangeServerButton(frame: .zero).with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.target = self
        $0.action = #selector(onButtonTapped(_:))
    }

    private let changeServerLabel = ChangeServerView.makeClickthroughLabel()
    private let hourglassImageView = NSImageView().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.imageScaling = .scaleProportionallyDown
        $0.setContentHuggingPriority(.init(251), for: .horizontal)
        $0.setContentHuggingPriority(.init(251), for: .vertical)
    }

    private let timerLabel = ChangeServerView.makeClickthroughLabel()

    var handler: (() -> Void)?

    var state: ServerChangeViewState = .available {
        didSet {
            updateView()
            needsDisplay = true
        }
    }

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    // MARK: - Layout

    private func setupLayout() {
        [button, changeServerLabel, hourglassImageView, timerLabel].forEach(addSubview)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Dimensions.height),

            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),

            changeServerLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            changeServerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Dimensions.horizontalInset),

            hourglassImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            hourglassImageView.widthAnchor.constraint(equalToConstant: Dimensions.hourglassSize),
            hourglassImageView.heightAnchor.constraint(equalToConstant: Dimensions.hourglassSize),
            hourglassImageView.trailingAnchor.constraint(equalTo: timerLabel.leadingAnchor, constant: -Dimensions.hourglassTimerSpacing),

            timerLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            timerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Dimensions.horizontalInset),
        ])
    }

    private static func makeClickthroughLabel() -> ClickthroughTextField {
        ClickthroughTextField().with {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isEditable = false
            $0.isSelectable = false
            $0.isBordered = false
            $0.drawsBackground = false
            $0.focusRingType = .none
            $0.usesSingleLineMode = true
            $0.lineBreakMode = .byClipping
            $0.cell?.isScrollable = false
            $0.isUserInteractive = false
            $0.setContentHuggingPriority(.init(251), for: .horizontal)
            $0.setContentHuggingPriority(.init(750), for: .vertical)
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

        case let .unavailable(duration):
            button.attributedTitle = .init()
            changeServerLabel.attributedStringValue = Localizable.changeServer
                .styled(.weak, font: .themeFont(.heading4))
            hourglassImageView.isHidden = false
            timerLabel.attributedStringValue = duration
                .styled(.normal, font: .themeFont(.heading4))
        }
    }

    @objc
    private func onButtonTapped(_: Any) {
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

    // VPNAPPL-3110: Tahoe workaround (similar to VPNAPPL-2874)
    // Without this override, the target/action is not invoked on Tahoe
    // swiftlint:disable:next unneeded_override
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
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

private extension ChangeServerView {
    enum Dimensions {
        static let height: CGFloat = 40
        static let horizontalInset: CGFloat = 24
        static let hourglassSize: CGFloat = 16
        static let hourglassTimerSpacing: CGFloat = 8
    }
}
