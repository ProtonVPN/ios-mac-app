//
//  Created on 2025-01-02.
//
//  Copyright (c) 2025 Proton AG
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

import Combine
import CombineSchedulers
import Dependencies

public extension DependencyValues {
    var debounceScheduler: AnySchedulerOf<UIScheduler> {
        get { self[DebounceScheduler.self] }
        set { self[DebounceScheduler.self] = newValue }
    }

    enum DebounceScheduler: DependencyKey {
        public static let liveValue = UIScheduler.shared.eraseToAnyScheduler()
        public static let testValue = UIScheduler.immediate.eraseToAnyScheduler()
    }
}
