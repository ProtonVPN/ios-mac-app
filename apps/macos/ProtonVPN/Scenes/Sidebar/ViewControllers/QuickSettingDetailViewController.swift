//
//  Created on 23/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Cocoa
import SwiftUI

import Ergonomics
import LegacyCommon
import Strings
import Theme

protocol QuickSettingsDetailViewControllerProtocol: AnyObject {
    var arrowIV: NSImageView { get }
    var arrowHorizontalConstraint: NSLayoutConstraint { get }
    var contentBox: NSBox { get }
    var dropdownTitle: NSTextField { get }
    var dropdownDescription: NSTextField { get }
    var dropdownLearnMore: InteractiveActionButton { get }
    var dropdownUpgradeButton: PrimaryActionButton { get }
    var dropdownNote: NSTextField { get }
    var dropdownNoteImageView: NSImageView { get }
    var dropdownNoteStackView: NSStackView { get }

    func reloadOptions()
    func updateNetshieldStats()
    func updatePortForwardingContainer(with state: PortForwardingVCState)
}

class QuickSettingDetailViewController: NSViewController, QuickSettingsDetailViewControllerProtocol {
    var arrowIV: NSImageView = .init().with {
        $0.image = Asset.qsDetailTriangle.image
        $0.contentTintColor = NSColor(rgbHex: 0x43444D)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.animates = true
        $0.cell?.setAccessibilityElement(false)
        $0.imageScaling = .scaleAxesIndependently
    }

    lazy var arrowHorizontalConstraint: NSLayoutConstraint = arrowIV.centerXAnchor.constraint(equalTo: contentBox.centerXAnchor)

    var contentBox: NSBox = .init().with {
        $0.boxType = .custom
        $0.cornerRadius = .themeRadius4
        $0.titlePosition = .noTitle
        $0.borderColor = .color(.border, .weak)
        $0.fillColor = .color(.background)
        $0.borderWidth = 1
        $0.cornerRadius = AppTheme.ButtonConstants.cornerRadius
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    var dropdownTitle: NSTextField = .init().with {
        $0.isEditable = false
        $0.isSelectable = false
        $0.isBezeled = false
        $0.drawsBackground = false
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.preferredMaxLayoutWidth = Dimensions.maxTextFieldWidth
        $0.setAccessibilityIdentifier("QSTitle")
    }

    var dropdownDescription: NSTextField = .init().with {
        $0.isEditable = false
        $0.isSelectable = false
        $0.isBezeled = false
        $0.drawsBackground = false
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.preferredMaxLayoutWidth = Dimensions.maxTextFieldWidth
        $0.setAccessibilityIdentifier("QSDescription")
    }

    var dropdownLearnMore: InteractiveActionButton = .init().with {
        $0.bezelStyle = .regularSquare
        $0.alignment = .left
        $0.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        $0.fontSize = .small
        $0.title = Localizable.learnMore
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setAccessibilityIdentifier("LearnMoreButton")
    }

    var titleHeaderStackView: NSStackView = .init().with {
        $0.orientation = .vertical
        $0.alignment = .leading
        $0.spacing = .themeSpacing16
        $0.distribution = .fillProportionally
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.wantsLayer = true
        $0.layer?.masksToBounds = false
    }

    var dropdownUpgradeButton: PrimaryActionButton = .init(frame: .zero).with {
        $0.bezelStyle = .rounded
        $0.alignment = .center
        $0.contentTintColor = NSColor.white
        $0.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.title = Localizable.upgrade
        $0.actionType = .confirmative
        $0.fontSize = .paragraph
        $0.setAccessibilityIdentifier("UpgradeButton")
    }

    var dropdownNoteImageView: NSImageView = .init().with {
        $0.image = AppTheme.Icon.infoCircleFilled
        $0.wantsLayer = true
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.imageScaling = .scaleProportionallyUpOrDown
        $0.isHidden = true
        $0.setContentHuggingPriority(.required, for: .horizontal)
        $0.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    var dropdownNote: NSTextField = .init().with {
        $0.isEditable = false
        $0.isSelectable = false
        $0.isBezeled = false
        $0.drawsBackground = false
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.preferredMaxLayoutWidth = Dimensions.maxTextFieldWidth
        $0.setAccessibilityIdentifier("QSNote")
    }

    var dropdownNoteStackView: NSStackView = .init().with {
        $0.orientation = .horizontal
        $0.alignment = .top
        $0.spacing = .themeSpacing8
        $0.distribution = .fillProportionally
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private var dropdownOptionsView: NSStackView = .init().with {
        $0.orientation = .vertical
        $0.alignment = .width
        $0.spacing = .themeSpacing8
        $0.distribution = .fillEqually
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.wantsLayer = true
        $0.layer?.masksToBounds = false
    }

    var buttonsAndNoteView: NSStackView = .init().with {
        $0.orientation = .vertical
        $0.alignment = .centerX
        $0.spacing = .themeSpacing16
        $0.distribution = .fillProportionally
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    let presenter: QuickSettingDropdownPresenterProtocol

    // MARK: - Life cycle

    init(_ presenter: QuickSettingDropdownPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.presenter.viewController = self
    }

    override func loadView() {
        super.loadView()
        // Main view
        let shadow = NSShadow()
        shadow.shadowColor = .color(.background)
        shadow.shadowBlurRadius = .themeRadius8

        view = NSView()
        view.frame = NSRect(x: 0, y: 0, width: 400, height: 414)
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        view.shadow = shadow
        view.layer?.shadowRadius = 5
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()

        presenter.viewDidLoad()
        reloadOptions()
    }

    // MARK: - Setup Views

    private func setupViews() {
        // Arrow image view
        view.addSubview(arrowIV)

        // Content box
        view.addSubview(contentBox)

        [dropdownTitle, dropdownDescription, dropdownLearnMore].forEach(titleHeaderStackView.addArrangedSubview)

        contentBox.addSubview(titleHeaderStackView)

        // Note text field
        [dropdownNoteImageView, dropdownNote].forEach(dropdownNoteStackView.addArrangedSubview)

        // Options view + note
        [dropdownOptionsView, dropdownUpgradeButton, dropdownNoteStackView].forEach(buttonsAndNoteView.addArrangedSubview)
        contentBox.addSubview(buttonsAndNoteView)
    }

    // MARK: - Setup Constraints

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Arrow image view constraints
            arrowIV.topAnchor.constraint(equalTo: view.topAnchor, constant: Dimensions.Arrow.topOffset),
            arrowIV.widthAnchor.constraint(equalToConstant: Dimensions.Arrow.width),
            arrowIV.heightAnchor
                .constraint(equalTo: arrowIV.widthAnchor, multiplier: Dimensions.Arrow.heightToWidthRatio),

            // Content box constraints
            contentBox.topAnchor.constraint(equalTo: arrowIV.bottomAnchor, constant: Dimensions.ContentBox.topOffset),
            contentBox.leadingAnchor
                .constraint(equalTo: view.leadingAnchor, constant: Dimensions.ContentBox.horizontalOffset),
            contentBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Dimensions.ContentBox.horizontalOffset),
            contentBox.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: Dimensions.ContentBox.bottomOffset),

            // Title text field constraints
            titleHeaderStackView.topAnchor
                .constraint(equalTo: contentBox.topAnchor, constant: Dimensions.TitleHeaderView.topOffset),
            titleHeaderStackView.leadingAnchor
                .constraint(equalTo: contentBox.leadingAnchor, constant: Dimensions.TitleHeaderView.horizontalOffset),
            titleHeaderStackView.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -Dimensions.TitleHeaderView.horizontalOffset),

            // Dropdown icon size
            dropdownNoteImageView.heightAnchor.constraint(equalToConstant: Dimensions.DropdownNoteImage.height),
            dropdownNoteImageView.widthAnchor.constraint(equalToConstant: Dimensions.DropdownNoteImage.width),

            // Options view constraints
            buttonsAndNoteView.topAnchor
                .constraint(equalTo: titleHeaderStackView.bottomAnchor, constant: Dimensions.ButtonsAndNote.topOffset),
            buttonsAndNoteView.leadingAnchor.constraint(equalTo: titleHeaderStackView.leadingAnchor),
            buttonsAndNoteView.trailingAnchor.constraint(equalTo: titleHeaderStackView.trailingAnchor),
            buttonsAndNoteView.bottomAnchor
                .constraint(equalTo: contentBox.bottomAnchor, constant: Dimensions.ButtonsAndNote.bottomOffset),

            // Upgrade button constraints
            dropdownUpgradeButton.heightAnchor.constraint(equalToConstant: Dimensions.UpgradeButton.height),

            dropdownOptionsView.widthAnchor.constraint(equalTo: buttonsAndNoteView.widthAnchor),
            dropdownNoteStackView.widthAnchor.constraint(equalTo: buttonsAndNoteView.widthAnchor),
        ])

        // Arrow horizontal constraint
        arrowHorizontalConstraint.isActive = true
    }

    // MARK: - Utils

    func updateNetshieldStats() {}

    func updatePortForwardingContainer(with _: PortForwardingVCState) {}

    func reloadOptions() {
        var needsUpgrade = false
        let views: [QuickSettingsDropdownOption] = presenter.options.enumerated().map { _, presenter in
            let thisNeedsUpgrade = presenter.requiresUpdate
            defer { needsUpgrade = thisNeedsUpgrade || needsUpgrade }

            let view: QuickSettingsDropdownOption? = QuickSettingsDropdownOption.loadViewFromNib()
            view?.titleLabel.stringValue = presenter.title
            view?.optionIconIV.image = presenter.icon
            if thisNeedsUpgrade {
                view?.blockedStyle()
                view?.action = { [weak self] in
                    presenter.selectCallback {
                        self?.presenter.dismiss?()
                    }
                }
            } else {
                if presenter.active {
                    view?.selectedStyle()
                } else {
                    view?.disabledStyle()
                    view?.action = { [weak self] in
                        presenter.selectCallback {
                            self?.presenter.dismiss?()
                        }
                    }
                }
            }
            return view!
        }

        dropdownOptionsView.subviews.forEach { $0.removeFromSuperview() }
        for view in views {
            dropdownOptionsView.addArrangedSubview(view)
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalTo: dropdownOptionsView.widthAnchor),
            ])
        }

        dropdownUpgradeButton.isHidden = !needsUpgrade
        dropdownNoteStackView.isHidden = dropdownNote.attributedStringValue.length < 1
    }
}

private extension QuickSettingDetailViewController {
    enum Dimensions {
        enum Arrow {
            static let topOffset: CGFloat = 4
            static let width: CGFloat = 30
            static let heightToWidthRatio: CGFloat = 6 / 18
        }

        enum ContentBox {
            static let topOffset: CGFloat = -1
            static let horizontalOffset: CGFloat = 20
            static let bottomOffset: CGFloat = -7
        }

        enum TitleHeaderView {
            static let topOffset: CGFloat = 24
            static let horizontalOffset: CGFloat = 16
        }

        enum DropdownNoteImage {
            static let height: CGFloat = 16
            static let width: CGFloat = 16
        }

        enum ButtonsAndNote {
            static let topOffset: CGFloat = 12
            static let bottomOffset: CGFloat = -16
        }

        enum UpgradeButton {
            static let height: CGFloat = 33
        }

        static let maxTextFieldWidth: CGFloat = AppConstants.Windows.loginWidth - ContentBox.horizontalOffset * 2 - TitleHeaderView.horizontalOffset * 2
    }
}
