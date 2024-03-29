import Modals
import UIKit
import SwiftUI

public struct ModalsFactory {

    // MARK: Properties

    private let upsellStoryboard: UIStoryboard
    private let discourageStoryboard: UIStoryboard
    private let userAccountUpdateStoryboard: UIStoryboard
    private let freeConnectionsViewStoryboard: UIStoryboard

    public init() {
        upsellStoryboard = UIStoryboard(name: "UpsellViewController", bundle: Bundle.module)
        discourageStoryboard = UIStoryboard(name: "DiscourageSecureCoreViewController", bundle: Bundle.module)
        userAccountUpdateStoryboard = UIStoryboard(name: "UserAccountUpdateViewController", bundle: Bundle.module)
        freeConnectionsViewStoryboard = UIStoryboard(name: "FreeConnectionsViewController", bundle: Bundle.module)
   }

    public func upsellViewController(modalType: ModalType) -> UpsellViewController {
        let upsell = upsellStoryboard.instantiate(controllerType: UpsellViewController.self)
        upsell.modalType = modalType
        return upsell
    }

    public func whatsNewViewController() -> UIViewController {
        UIHostingController(rootView: WhatsNewView())
    }

    // This method uses the new `ModalView` and eventually all upsell modals should be migrated to this one
    // For now, only the welcome(plus/unlimited/fallback) modals use it.
    public func modalViewController(modalType: ModalType,
                                    primaryAction: (() -> Void)? = nil,
                                    dismissAction: (() -> Void)? = nil) -> UIViewController {
        UIHostingController(rootView: ModalView(modalType: modalType, primaryAction: primaryAction, dismissAction: dismissAction))
    }

    public func discourageSecureCoreViewController(onDontShowAgain: ((Bool) -> Void)?, onActivate: (() -> Void)?, onCancel: (() -> Void)?, onLearnMore: (() -> Void)?) -> UIViewController {
        let discourageSecureCoreViewController = discourageStoryboard.instantiate(controllerType: DiscourageSecureCoreViewController.self)
        discourageSecureCoreViewController.onDontShowAgain = onDontShowAgain
        discourageSecureCoreViewController.onActivate = onActivate
        discourageSecureCoreViewController.onCancel = onCancel
        discourageSecureCoreViewController.onLearnMore = onLearnMore
        return discourageSecureCoreViewController
    }

    public func userAccountUpdateViewController(viewModel: UserAccountUpdateViewModel, onPrimaryButtonTap: (() -> Void)?) -> UIViewController {
        let userAccountUpdateViewController = userAccountUpdateStoryboard.instantiate(controllerType: UserAccountUpdateViewController.self)
        userAccountUpdateViewController.viewModel = viewModel
        userAccountUpdateViewController.onPrimaryButtonTap = onPrimaryButtonTap
        return userAccountUpdateViewController
    }

    public func freeConnectionsViewController(countries: [(String, Modals.Image?)], upgradeAction: (() -> Void)?) -> UIViewController {
        let controller = freeConnectionsViewStoryboard.instantiate(controllerType: FreeConnectionsViewController.self)
        controller.onBannerPress = upgradeAction
        controller.countries = countries
        return controller
    }
}

extension UIStoryboard {
    func instantiate<T: UIViewController>(controllerType: T.Type) -> T {
        let name = "\(controllerType)".replacingOccurrences(of: "ViewController", with: "")
        let viewController = instantiateViewController(withIdentifier: name) as! T
        return viewController
    }
}
