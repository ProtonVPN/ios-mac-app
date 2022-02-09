import UIKit

public struct ModalsFactory {

    // MARK: Properties

    private let storyboard: UIStoryboard

    public init(colors: ModalsColors) {
        storyboard = UIStoryboard(name: "UpsellViewController", bundle: Bundle.module)
        Modals.colors = colors
    }

    public func upsellViewController(constants: UpsellConstantsProtocol) -> UpsellViewController {
        let upsell = storyboard.instantiate(controllerType: UpsellViewController.self)
        upsell.constants = constants
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
