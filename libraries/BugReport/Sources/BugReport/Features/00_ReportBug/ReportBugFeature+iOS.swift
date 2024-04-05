//
//  Created on 2023-05-11.
//
//  Copyright (c) 2023 Proton AG
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

#if os(iOS)
import Foundation
import ComposableArchitecture
import SwiftUI

@Reducer
struct ReportBugFeatureiOS: Reducer {

    struct State: Equatable {
        var whatsTheIssueState: WhatsTheIssueFeature.State
    }

    enum Action: Equatable {
        case whatsTheIssueAction(WhatsTheIssueFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.whatsTheIssueState, action: /Action.whatsTheIssueAction) {
            WhatsTheIssueFeature()
        }
    }

}

public struct ReportBugView: View {

    let store: StoreOf<ReportBugFeatureiOS>

    @StateObject var updateViewModel: UpdateViewModel = CurrentEnv.updateViewModel
    @Environment(\.colors) var colors: Colors

    public var body: some View {
        WithViewStore(self.store, observe: { $0 }, content: { viewStore in
            NavigationView {
                WhatsTheIssueView(store: self.store.scope(state: \.whatsTheIssueState, action: ReportBugFeatureiOS.Action.whatsTheIssueAction))
            }
            .navigationViewStyle(.stack)
        })
    }
}

struct ReportBugView_Previews: PreviewProvider {
    private static let bugReport = MockBugReportDelegate(model: .mock)

    static var previews: some View {
        CurrentEnv.bugReportDelegate = bugReport
        CurrentEnv.updateViewModel.updateIsAvailable = true

        let state = ReportBugFeatureiOS.State(whatsTheIssueState: WhatsTheIssueFeature.State(categories: bugReport.model.categories))
        let reducer = ReportBugFeatureiOS()

        return Group {
            ReportBugView(store: Store(initialState: state, reducer: { reducer }))
        }
    }
}

#endif
