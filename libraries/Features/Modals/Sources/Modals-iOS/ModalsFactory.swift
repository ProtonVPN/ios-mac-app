import ModalsShared
import SwiftUI
import UIKit

// TODO: Migrate to @MainActor once overall codebase is ready for it
public final class ModalsFactory {
    public init() {}

    // MARK: Properties

    private lazy var userAccountUpdateStoryboard: UIStoryboard = .init(name: "UserAccountUpdateViewController", bundle: Bundle.module)

    private lazy var freeConnectionsViewStoryboard: UIStoryboard = .init(name: "FreeConnectionsViewController", bundle: Bundle.module)

    public func whatsNewViewController(variant: WhatsNewView.PlanVariant) -> UIViewController {
        WhatsNewView(variant: variant).hostingController()
    }

    // This method uses the new `ModalView` and eventually all upsell modals should be migrated to this one
    // For now, only the welcome(plus/unlimited/fallback) modals use it.
    public func modalViewController(
        modalType: ModalType,
        primaryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil,
        onFeatureUpdate: ((Feature) -> Void)? = nil
    ) -> UIViewController {
        ModalView(
            modalType: modalType,
            primaryAction: primaryAction,
            dismissAction: dismissAction,
            onFeatureUpdate: onFeatureUpdate
        ).hostingController()
    }

    public func discourageSecureCoreViewController(
        onActivate: (() -> Void)?,
        onCancel: (() -> Void)?
    ) -> UIViewController {
        DiscourageSecureCoreViewController(
            onActivate: onActivate,
            onCancel: onCancel
        )
    }

    public func userAccountUpdateViewController(viewModel: UserAccountUpdateViewModel, onPrimaryButtonTap: (() -> Void)?) -> UIViewController {
        let userAccountUpdateViewController = userAccountUpdateStoryboard.instantiate(controllerType: UserAccountUpdateViewController.self)
        userAccountUpdateViewController.viewModel = viewModel
        userAccountUpdateViewController.onPrimaryButtonTap = onPrimaryButtonTap
        return userAccountUpdateViewController
    }

    public func freeConnectionsViewController(countries: [(String, ModalsShared.ImageAsset.Image?)], upgradeAction: (() -> Void)?) -> UIViewController {
        let controller = freeConnectionsViewStoryboard.instantiate(controllerType: FreeConnectionsViewController.self)
        controller.onBannerPress = upgradeAction
        controller.countries = countries
        return controller
    }
}

extension UIStoryboard {
    func instantiate<T: UIViewController>(controllerType: T.Type) -> T {
        let name = "\(controllerType)".replacingOccurrences(of: "ViewController", with: "")
        return instantiateViewController(withIdentifier: name) as! T
    }
}

extension View {
    func hostingController() -> UIHostingController<Self> {
        UIHostingController(rootView: self)
    }
}
