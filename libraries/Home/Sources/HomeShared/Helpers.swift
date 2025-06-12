//
//  Created on 22/01/2025.
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

import Clocks
import Combine
import ComposableArchitecture

extension Effect {
    package static func onChange<Value>(
        of shared: SharedReader<Value>,
        on scheduler: AnySchedulerOf<UIScheduler> = .shared,
        reinject transform: @escaping (Value) -> Action
    ) -> Self {
        listen(to: shared.publisher, on: scheduler, reinjecting: transform)
    }

    package static func onChange<Value>(
        of shared: SharedReader<Value?>,
        on scheduler: AnySchedulerOf<UIScheduler> = .shared,
        reinject transform: @escaping (Value) -> Action
    ) -> Self {
        listen(to: shared.publisher, on: scheduler, reinjecting: transform)
    }

    package static func listen<Output>(
        to publisher: some Publisher<Output, Never>,
        on scheduler: AnySchedulerOf<UIScheduler> = .shared,
        reinjecting transform: @escaping (Output) -> Action
    ) -> Self {
        self.publisher { publisher.receive(on: scheduler).map(transform) }
    }

    package static func listen<Output>(
        to publisher: some Publisher<Output?, Never>,
        on scheduler: AnySchedulerOf<UIScheduler> = .shared,
        reinjecting transform: @escaping (Output) -> Action
    ) -> Self {
        self.publisher { publisher.receive(on: scheduler).compactMap({ $0 }).map(transform) }
    }
}
