//
//  Created on 03.01.2022.
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

import Foundation
import UIKit

protocol TourViewControllerDelegate: AnyObject {
    func userDidRequestSkipTour()
}

final class TourViewController: UIViewController {

    // MARK: Outlets

    @IBOutlet private weak var skipButton: UIButton!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!

    // MARK: Properties

    weak var delegate: TourViewControllerDelegate?

    // MARK: Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        actionButton.setTitle(LocalizedString.onboardingNext, for: .normal)
        skipButton.setTitle(LocalizedString.onboardingSkip, for: .normal)

        let steps = TourStep.allCases.map { step -> UIView in
            let view = Bundle.module.loadNibNamed("TourStepView", owner: self, options: nil)?.first as! TourStepView
            view.step = step
            return view
        }
        setupScrollView(steps: steps)

        baseViewStyle(view)
        baseViewStyle(scrollView)
        actionButtonStyle(actionButton)
        textButtonStyle(skipButton)
    }

    private func setupScrollView(steps: [UIView]) {
        scrollView.contentSize = CGSize(width: scrollView.frame.width * CGFloat(steps.count), height: 0)

        for i in 0 ..< steps.count {
            steps[i].frame = CGRect(x: scrollView.frame.width * CGFloat(i), y: 0, width: scrollView.frame.width, height: scrollView.frame.size.height)
            if steps[i].superview == nil {
                scrollView.addSubview(steps[i])
            }
        }
    }

    private func scrollToIndex(index: CGFloat, animated: Bool) {
        scrollView.scrollRectToVisible(CGRect(x: index * scrollView.frame.width, y: 0, width: scrollView.frame.width, height: scrollView.frame.height), animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        setupScrollView(steps: scrollView.subviews.compactMap({ $0 as?  TourStepView }))
        let pageIndex = round(scrollView.contentOffset.x / view.frame.width)
        scrollToIndex(index: pageIndex, animated: true)
    }

    // MARK: Actions

    @IBAction private func skipTapped(_ sender: Any) {
        delegate?.userDidRequestSkipTour()
    }

    @IBAction private func nextTapped(_ sender: Any) {
        let pageIndex = round(scrollView.contentOffset.x / view.frame.width)
        guard pageIndex < CGFloat(TourStep.allCases.count) - 1 else {
            delegate?.userDidRequestSkipTour()
            return
        }

        scrollToIndex(index: pageIndex + 1, animated: true)
    }
}
