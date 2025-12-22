//
//  FeatureTableViewCell.swift
//  ProtonVPN - Created on 21.04.21.
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

import UIKit

import Dependencies

import ProtonCoreUIFoundations

import LegacyCommon
import VPNAppCore

import Strings

class FeatureTableViewCell: UITableViewCell {
    private let iconIV: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        return imageView
    }()

    private let titleLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.612, green: 0.627, blue: 0.667, alpha: 1.0)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let learnMoreBtn: UIButton = {
        var config = UIButton.Configuration.plain()
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20)

        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        button.contentHorizontalAlignment = .leading
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(UIColor.textAccent(), for: .normal)
        button.tintColor = UIColor.textAccent()
        button.setImage(IconProvider.arrowOutSquare, for: .normal)
        return button
    }()

    private let loadLowView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Dimensions.LoadIndicator.cornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let loadLowLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.612, green: 0.627, blue: 0.667, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadMediumView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Dimensions.LoadIndicator.cornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let loadMediumLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.612, green: 0.627, blue: 0.667, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let loadHighView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Dimensions.LoadIndicator.cornerRadius
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let loadHighLbl: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.612, green: 0.627, blue: 0.667, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var loadStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Dimensions.LoadStackView.spacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var topStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Dimensions.MainStackView.spacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Dimensions.ContentStackView.spacing
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var bottomStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Dimensions.MainStackView.spacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Dimensions.MainStackView.spacing
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .backgroundColor()
        contentView.backgroundColor = .clear

        NSLayoutConstraint.activate([
            iconIV.widthAnchor.constraint(equalToConstant: Dimensions.Icon.width),
            iconIV.heightAnchor.constraint(equalToConstant: Dimensions.Icon.width),
        ])
        [iconIV, titleLbl].forEach(topStackView.addArrangedSubview)

        // Build load indicator stack (horizontal: [dot + label, dot + label, dot + label])
        let loadLowStack = createLoadIndicatorStack(dot: loadLowView, label: loadLowLbl)
        let loadMediumStack = createLoadIndicatorStack(dot: loadMediumView, label: loadMediumLbl)
        let loadHighStack = createLoadIndicatorStack(dot: loadHighView, label: loadHighLbl)
        [loadLowStack, loadMediumStack, loadHighStack].forEach(loadStackView.addArrangedSubview)

        // Build content stack (vertical: [description, loadStack, learnMoreBtn])
        [descriptionLbl, loadStackView, learnMoreBtn].forEach(contentStackView.addArrangedSubview)

        let dummyView = UIView()
        NSLayoutConstraint.activate([
            dummyView.widthAnchor.constraint(equalToConstant: Dimensions.Icon.width),
            dummyView.heightAnchor.constraint(equalToConstant: Dimensions.Icon.width),
        ])

        [dummyView, contentStackView].forEach(bottomStackView.addArrangedSubview)

        // Build horizontal stack (vertical: [icon + title, contentStack])
        [topStackView, bottomStackView].forEach(mainStackView.addArrangedSubview)

        contentView.addSubview(mainStackView)
    }

    private func createLoadIndicatorStack(dot: UIView, label: UILabel) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Dimensions.LoadIndicator.labelSpacing
        stack.alignment = .center
        stack.addArrangedSubview(dot)
        stack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: Dimensions.LoadIndicator.size),
            dot.heightAnchor.constraint(equalToConstant: Dimensions.LoadIndicator.size),
        ])

        return stack
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStackView.leadingAnchor
                .constraint(equalTo: contentView.leadingAnchor, constant: Dimensions.MainStackView.leading),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Dimensions.MainStackView.trailing),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Dimensions.MainStackView.bottom),
        ])
    }

    private func setupActions() {
        learnMoreBtn.addTarget(self, action: #selector(didTapLearnMore), for: .touchUpInside)
    }

    var viewModel: FeatureCellViewModel! {
        didSet {
            titleLbl.text = viewModel.title
            switch viewModel.icon {
            case let .image(image):
                iconIV.image = image
            case let .url(url):
                if let url {
                    iconIV.af.setImage(withURL: url)
                }
            }

            descriptionLbl.text = viewModel.description
            learnMoreBtn.setTitle(Localizable.learnMore, for: .normal)

            if viewModel.displayLoads {
                loadStackView.isHidden = false
                loadLowLbl.text = Localizable.performanceLoadLow
                loadLowView.backgroundColor = .notificationOKColor()
                loadMediumLbl.text = Localizable.performanceLoadMedium
                loadMediumView.backgroundColor = .notificationWarningColor()
                loadHighLbl.text = Localizable.performanceLoadHigh
                loadHighView.backgroundColor = .notificationErrorColor()
            } else {
                loadStackView.isHidden = true
            }
        }
    }

    // MARK: - Actions

    @objc
    private func didTapLearnMore() {
        guard let urlContact = viewModel.urlContact else { return }
        @Dependency(\.linkOpener) var linkOpener
        linkOpener.open(urlContact)
    }
}

extension FeatureTableViewCell {
    private enum Dimensions {
        enum Icon {
            static let width: CGFloat = 24
        }

        enum LoadStackView {
            static let spacing: CGFloat = 16
        }

        enum ContentStackView {
            static let spacing: CGFloat = 8
            static let loadViewToButtonSpacing: CGFloat = 4
        }

        enum MainStackView {
            static let spacing: CGFloat = 8
            static let leading: CGFloat = 16
            static let trailing: CGFloat = 16
            static let bottom: CGFloat = 16
        }

        enum LoadIndicator {
            static let size: CGFloat = 8
            static let cornerRadius: CGFloat = 4
            static let labelSpacing: CGFloat = 8
        }
    }
}
