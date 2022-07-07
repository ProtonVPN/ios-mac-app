import Modals
import UIKit

public struct ModalsFactory {

    // MARK: Properties

    private let upsellStoryboard: UIStoryboard
    private let discourageStoryboard: UIStoryboard
    private let newBrandStoryboard: UIStoryboard
    private let userAccountUpdateStoryboard: UIStoryboard
    private let informativeStoryboard: UIStoryboard

    public init(colors: ModalsColors) {
        upsellStoryboard = UIStoryboard(name: "UpsellViewController", bundle: Bundle.module)
        discourageStoryboard = UIStoryboard(name: "DiscourageSecureCoreViewController", bundle: Bundle.module)
        newBrandStoryboard = UIStoryboard(name: "NewBrandViewController", bundle: Bundle.module)
        userAccountUpdateStoryboard = UIStoryboard(name: "UserAccountUpdateViewController", bundle: Bundle.module)
        informativeStoryboard = UIStoryboard(name: "InformativeViewController", bundle: Bundle.module)
        Modals_iOS.colors = colors
    }

    public func upsellViewController(upsellType: UpsellType) -> UpsellViewController {
        let upsell = upsellStoryboard.instantiate(controllerType: UpsellViewController.self)
        upsell.upsellType = upsellType
        return upsell
    }

    public func discourageSecureCoreViewController(onDontShowAgain: ((Bool) -> Void)?, onActivate: (() -> Void)?, onCancel: (() -> Void)?, onLearnMore: (() -> Void)?) -> UIViewController {
        let discourageSecureCoreViewController = discourageStoryboard.instantiate(controllerType: DiscourageSecureCoreViewController.self)
        discourageSecureCoreViewController.onDontShowAgain = onDontShowAgain
        discourageSecureCoreViewController.onActivate = onActivate
        discourageSecureCoreViewController.onCancel = onCancel
        discourageSecureCoreViewController.onLearnMore = onLearnMore
        return discourageSecureCoreViewController
    }

    public func newBrandViewController(icons: NewBrandIcons, onDismiss: (() -> Void)?, onReadMore: (() -> Void)?) -> UIViewController {
        let newBrandViewController = newBrandStoryboard.instantiate(controllerType: NewBrandViewController.self)
        newBrandViewController.onReadMore = onReadMore
        newBrandViewController.onDismiss = onDismiss
        newBrandViewController.modalTransitionStyle = .crossDissolve
        newBrandViewController.modalPresentationStyle = .overFullScreen
        newBrandViewController.icons = icons
        return newBrandViewController
    }

    public func userAccountUpdateViewController(viewModel: UserAccountUpdateViewModel, onPrimaryButtonTap: (() -> Void)?) -> UIViewController {
        let userAccountUpdateViewController = userAccountUpdateStoryboard.instantiate(controllerType: UserAccountUpdateViewController.self)
        userAccountUpdateViewController.viewModel = viewModel
        userAccountUpdateViewController.onPrimaryButtonTap = onPrimaryButtonTap
        return userAccountUpdateViewController
    }

    public func informativeViewController(onPrimaryButtonTap: (() -> Void)?) -> InformativeViewController {
        let informativeViewController = informativeStoryboard.instantiate(controllerType: InformativeViewController.self)
        informativeViewController.onPrimaryButtonTap = onPrimaryButtonTap
        return informativeViewController
    }
}

extension UIStoryboard {
    func instantiate<T: UIViewController>(controllerType: T.Type) -> T {
        let name = "\(controllerType)".replacingOccurrences(of: "ViewController", with: "")
        let viewController = instantiateViewController(withIdentifier: name) as! T
        return viewController
    }
}
