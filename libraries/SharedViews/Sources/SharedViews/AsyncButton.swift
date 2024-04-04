//
//  Created on 08/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

import SwiftUI

// TODO: Provide an API to be able to customize the disabled look
public struct AsyncButton<Label> : View where Label : View {
    let role: ButtonRole?
    let taskPriority: TaskPriority?
    let disableWhileInProgress: Bool
    let action: @MainActor () async -> Void
    @ViewBuilder
    let label: () -> Label

    @State private var taskHandle: Task<Void, Never>?
    @State private var taskInProgress: Bool = false

    public init(
        role: ButtonRole? = nil,
        taskPriority: TaskPriority? = nil,
        disableWhileInProgress: Bool = true,
        action: @MainActor @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.taskPriority = taskPriority
        self.disableWhileInProgress = disableWhileInProgress
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(
            role: role,
            action: {
                if taskInProgress {
                    cancel()
                }

                taskHandle = Task(priority: taskPriority) {
                    taskInProgress = true
                    await action()
                    taskInProgress = false
                }
            },
            label: label
        )
        .disabled(disableWhileInProgress && taskInProgress)
    }

    private func cancel() {
        taskHandle?.cancel()
        taskHandle = nil
        taskInProgress = false
    }
}
