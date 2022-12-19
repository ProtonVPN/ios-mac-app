//
//  Created on 28.03.2022.
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
import StoreKit

protocol ReviewPrompt: AnyObject {
    func show()
}

final class AppStoreReviewPrompt: ReviewPrompt {
    func show() {
#if os(iOS)
        /// The now deprecated implementation of `requestReview` didn't require a `windowScene` as a parameter, so we implemented it in a way where it's not that easy to retrieve.
        if let windowScene = UIApplication.shared.windows.first?.windowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
#else
        SKStoreReviewController.requestReview()
#endif
    }
}
