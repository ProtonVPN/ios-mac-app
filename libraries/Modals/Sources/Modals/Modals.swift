import UIKit

public struct Modals {

    // MARK: Properties

    private let storyboard: UIStoryboard

    public init() {
        storyboard = UIStoryboard(name: "UpsellViewController", bundle: Bundle.module)
    }

    public func upsellViewController() -> UpsellViewController {
        let upsell = storyboard.instantiate(controllerType: UpsellViewController.self)

        return upsell
    }
}

extension UIStoryboard {
    func instantiate<T: UIViewController>(controllerType: T.Type) -> T {
        let name = "\(controllerType)".replacingOccurrences(of: "ViewController", with: "")
        let viewController = instantiateViewController(withIdentifier: name) as! T
        return viewController
    }
}
