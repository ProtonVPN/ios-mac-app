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
import NetShield
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

    func reloadOptions()
    func updateNetshieldStats()
}

class QuickSettingDetailViewController2: NSViewController, QuickSettingsDetailViewControllerProtocol {
    var arrowIV: NSImageView = .init().with {
        $0.image = Asset.qsDetailTriangle.image
        $0.contentTintColor = NSColor(rgbHex: 0x43444D)
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.animates = true
        $0.cell?.setAccessibilityElement(false)
    }

    lazy var arrowHorizontalConstraint: NSLayoutConstraint = arrowIV.centerXAnchor.constraint(equalTo: contentBox.centerXAnchor)
    var contentBox: NSBox = .init().with {
        $0.boxType = .custom
        $0.cornerRadius = 4
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
        $0.font = NSFont.systemFont(ofSize: 16)
        $0.textColor = .labelColor
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setAccessibilityIdentifier("QSTitle")
    }

    var dropdownDescription: NSTextField = .init().with {
        $0.isEditable = false
        $0.isSelectable = false
        $0.isBezeled = false
        $0.drawsBackground = false
        $0.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        $0.textColor = .labelColor
        $0.cell?.wraps = true
        $0.translatesAutoresizingMaskIntoConstraints = false
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

    var dropdownNote: NSTextField = .init().with {
        $0.isEditable = false
        $0.isSelectable = false
        $0.isBezeled = false
        $0.drawsBackground = false
        $0.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        $0.textColor = .labelColor
        $0.cell?.wraps = true
        $0.translatesAutoresizingMaskIntoConstraints = false
        $0.setAccessibilityIdentifier("QSNote")
    }

    private var dropdownOptionsView: NSView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    private lazy var dropdownOptionsBottomViewConstraint: NSLayoutConstraint = dropdownOptionsView.bottomAnchor.constraint(greaterThanOrEqualTo: contentBox.bottomAnchor, constant: -16)
    private lazy var noteTopConstraint: NSLayoutConstraint = dropdownNote.topAnchor.constraint(equalTo: dropdownOptionsView.bottomAnchor, constant: 16)
    private lazy var upgradeTopConstraint: NSLayoutConstraint = dropdownUpgradeButton.topAnchor.constraint(equalTo: dropdownOptionsView.bottomAnchor, constant: 16)
    private lazy var upgradeBottomConstraint: NSLayoutConstraint = dropdownNote.topAnchor.constraint(equalTo: dropdownUpgradeButton.bottomAnchor, constant: 20)

    // Move to netshield class
    private var netShieldStatsContainer: NSView = .init().with {
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

    let presenter: QuickSettingDropdownPresenterProtocol
    var netShieldStatsView = NSHostingView(rootView: NetShieldStatsView())

    private var detailBox: NSBox = .init().with {
        $0.boxType = .custom
        $0.borderType = .noBorder
        $0.cornerRadius = 4
        $0.titlePosition = .noTitle
        $0.fillColor = NSColor(white: 1, alpha: 0.0)
        $0.translatesAutoresizingMaskIntoConstraints = false
    }

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
        shadow.shadowBlurRadius = 8

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
        setupNetShieldStatsContainer() // TODO: move to netshield class controller

        presenter.viewDidLoad()
        reloadOptions()
    }

    // MARK: - Setup Views

    private func setupViews() {
        // Detail box (outer container)
        view.addSubview(detailBox)

        // Arrow image view
        detailBox.addSubview(arrowIV)

        // Content box
        detailBox.addSubview(contentBox)

        // Title text field
        contentBox.addSubview(dropdownTitle)

        // NetShield stats container
        contentBox.addSubview(netShieldStatsContainer)

        // Description text field
        contentBox.addSubview(dropdownDescription)

        // Learn more button
        contentBox.addSubview(dropdownLearnMore)

        // Options view
        contentBox.addSubview(dropdownOptionsView)

        // Upgrade button
        contentBox.addSubview(dropdownUpgradeButton)

        // Note text field
        contentBox.addSubview(dropdownNote)
    }

    // MARK: - Setup Constraints

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Detail box constraints
            detailBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detailBox.topAnchor.constraint(equalTo: view.topAnchor),
            detailBox.widthAnchor.constraint(equalTo: view.widthAnchor),
            detailBox.heightAnchor.constraint(equalTo: view.heightAnchor),

            // Arrow image view constraints
            arrowIV.topAnchor.constraint(equalTo: detailBox.topAnchor, constant: 4),
            arrowIV.widthAnchor.constraint(equalToConstant: 30),
            arrowIV.heightAnchor.constraint(equalTo: arrowIV.widthAnchor, multiplier: 6 / 18),

            // Content box constraints
            contentBox.topAnchor.constraint(equalTo: arrowIV.bottomAnchor, constant: -1),
            contentBox.leadingAnchor.constraint(equalTo: detailBox.leadingAnchor, constant: 20),
            contentBox.trailingAnchor.constraint(equalTo: detailBox.trailingAnchor, constant: -20),
            contentBox.bottomAnchor.constraint(lessThanOrEqualTo: detailBox.bottomAnchor, constant: -7),

            // Title text field constraints
            dropdownTitle.topAnchor.constraint(equalTo: contentBox.topAnchor, constant: 24),
            dropdownTitle.leadingAnchor.constraint(equalTo: contentBox.leadingAnchor, constant: 16),
            dropdownTitle.trailingAnchor.constraint(equalTo: contentBox.trailingAnchor, constant: -16),

            // NetShield stats container constraints
            netShieldStatsContainer.topAnchor.constraint(equalTo: dropdownTitle.bottomAnchor, constant: 16),
            netShieldStatsContainer.leadingAnchor.constraint(equalTo: dropdownTitle.leadingAnchor),
            netShieldStatsContainer.trailingAnchor.constraint(equalTo: dropdownTitle.trailingAnchor),
            netShieldStatsContainer.heightAnchor.constraint(equalToConstant: 72),

            // Description text field constraints
            dropdownDescription.topAnchor.constraint(equalTo: netShieldStatsContainer.bottomAnchor, constant: 16),
            dropdownDescription.leadingAnchor.constraint(equalTo: dropdownTitle.leadingAnchor),
            dropdownDescription.trailingAnchor.constraint(equalTo: dropdownTitle.trailingAnchor),

            // Learn more button constraints
            dropdownLearnMore.topAnchor.constraint(equalTo: dropdownDescription.bottomAnchor, constant: 4),
            dropdownLearnMore.leadingAnchor.constraint(equalTo: dropdownTitle.leadingAnchor),
            dropdownLearnMore.heightAnchor.constraint(equalToConstant: 15),

            // Options view constraints
            dropdownOptionsView.topAnchor.constraint(equalTo: dropdownLearnMore.bottomAnchor, constant: 12),
            dropdownOptionsView.leadingAnchor.constraint(equalTo: dropdownLearnMore.leadingAnchor),
            dropdownOptionsView.trailingAnchor.constraint(equalTo: dropdownTitle.trailingAnchor),
            dropdownOptionsBottomViewConstraint,

            // Upgrade button constraints
            dropdownUpgradeButton.centerXAnchor.constraint(equalTo: contentBox.centerXAnchor),

            // Note text field constraints
            dropdownNote.leadingAnchor.constraint(equalTo: dropdownTitle.leadingAnchor),
            dropdownNote.trailingAnchor.constraint(equalTo: dropdownTitle.trailingAnchor),
            dropdownNote.bottomAnchor.constraint(equalTo: contentBox.bottomAnchor, constant: -16),
        ])

        // Arrow horizontal constraint
        arrowHorizontalConstraint.isActive = true

        // Note top constraint
        noteTopConstraint.priority = NSLayoutConstraint.Priority(750)

        // Alternative description constraint
        let alternativeDescriptionConstraint = dropdownDescription.topAnchor.constraint(equalTo: dropdownTitle.bottomAnchor, constant: 16)
        alternativeDescriptionConstraint.priority = NSLayoutConstraint.Priority(999)
        alternativeDescriptionConstraint.isActive = true
    }

    // MARK: - Utils

    private func setupNetShieldStatsContainer() {
        guard let netShieldPresenter = presenter as? NetshieldDropdownPresenter,
              netShieldPresenter.isNetShieldStatsEnabled else {
            netShieldStatsContainer.removeFromSuperview()
            return
        }
        netShieldStatsView.translatesAutoresizingMaskIntoConstraints = false
        netShieldStatsContainer.addSubview(netShieldStatsView)
        NSLayoutConstraint.activate([
            netShieldStatsContainer.topAnchor.constraint(equalTo: netShieldStatsView.topAnchor),
            netShieldStatsContainer.bottomAnchor.constraint(equalTo: netShieldStatsView.bottomAnchor),
            netShieldStatsContainer.leadingAnchor.constraint(equalTo: netShieldStatsView.leadingAnchor),
            netShieldStatsContainer.trailingAnchor.constraint(equalTo: netShieldStatsView.trailingAnchor),
        ])
    }

    func updateNetshieldStats() {
        if let model = (presenter as? NetshieldDropdownPresenter)?.netShieldViewModel {
            netShieldStatsView.rootView.viewModel = model
        }
    }

    func reloadOptions() {
        var needsUpgrade = false
        let views: [QuickSettingsDropdownOption] = presenter.options.enumerated().map { _, presenter in
            let thisNeedsUpgrade = presenter.requiresUpdate ?? false
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

        upgradeTopConstraint.isActive = needsUpgrade
        upgradeBottomConstraint.isActive = needsUpgrade

        noteTopConstraint.isActive = dropdownNote.attributedStringValue.length > 0
        dropdownOptionsBottomViewConstraint.isActive = dropdownNote.attributedStringValue.length < 1

        dropdownUpgradeButton.isHidden = !needsUpgrade
        dropdownOptionsView.subviews.forEach { $0.removeFromSuperview() }
        dropdownOptionsView.fillVertically(withViews: views)
        dropdownOptionsView.wantsLayer = true
        dropdownOptionsView.layer?.masksToBounds = false
    }
}

extension NSObject: With {}
