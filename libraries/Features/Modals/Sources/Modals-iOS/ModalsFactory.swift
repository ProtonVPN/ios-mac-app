import ModalsShared
import SwiftUI
import UIKit

// TODO: Migrate to @MainActor once overall codebase is ready for it
public final class ModalsFactory {
    public init() {}

    // MARK: Properties

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
}

extension View {
    func hostingController() -> UIHostingController<Self> {
        UIHostingController(rootView: self)
    }
}
