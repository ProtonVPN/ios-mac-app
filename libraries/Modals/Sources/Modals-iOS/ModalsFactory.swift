import Modals
import UIKit
import SwiftUI

// TODO: Migrate to @MainActor once overall codebase is ready for it
public final class ModalsFactory {

    public init() {}

    // MARK: Properties

    private lazy var upsellStoryboard: UIStoryboard = {
        UIStoryboard(name: "UpsellViewController", bundle: Bundle.module)
    }()
    private lazy var discourageStoryboard: UIStoryboard = {
        UIStoryboard(name: "DiscourageSecureCoreViewController", bundle: Bundle.module)
    }()
    private lazy var userAccountUpdateStoryboard: UIStoryboard = {
        UIStoryboard(name: "UserAccountUpdateViewController", bundle: Bundle.module)
    }()
    private lazy var freeConnectionsViewStoryboard: UIStoryboard = {
        UIStoryboard(name: "FreeConnectionsViewController", bundle: Bundle.module)
    }()

    public func whatsNewViewController() -> UIViewController {
        WhatsNewView().hostingController()
    }

    public func upsellViewController(modalType: ModalType) -> UpsellViewController {
        let upsell = self.upsellStoryboard.instantiate(controllerType: UpsellViewController.self)
        upsell.modalType = modalType
        return upsell
    }

    public func upsellViewController(
        modalType: ModalType,
        client: PlansClient,
        dismissAction: (() -> Void)? = nil
    ) -> UIViewController {
        PlanOptionsView(
            viewModel: .init(client: client),
            modalType: modalType,
            displayBodyFeatures: !modalType.hasNewUpsellScreen,
            dismissAction: dismissAction
        )
        .hostingController()
    }

    // This method uses the new `ModalView` and eventually all upsell modals should be migrated to this one
    // For now, only the welcome(plus/unlimited/fallback) modals use it.
    public func modalViewController(
        modalType: ModalType,
        primaryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) -> UIViewController {
        ModalView(modalType: modalType, primaryAction: primaryAction, dismissAction: dismissAction).hostingController()
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

extension View {
    func hostingController() -> UIHostingController<Self> {
        UIHostingController(rootView: self)
    }
}
