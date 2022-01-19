//
//  Created on 2022-01-05.
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

import SwiftUI

/// Thirst step of Report Bug flow.
/// Asks user some questions to collect all the needed debug information.
@available(iOS 14.0, *)
struct FormView: View {
            
    @StateObject var viewModel: FormViewModel
        
    @Environment(\.colors) var colors: Colors
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
          
    var body: some View {
        VStack {
            StepProgress(step: 3, steps: 3, colorMain: colors.brand, colorSecondary: colors.brandLight40)
                .padding(.bottom)
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    ForEach($viewModel.fields) { $field in
                        switch field.inputField.type {
                        case .textSingleLine:
                            SingleLineTextInputView(field: field.inputField, value: $field.stringValue)
                        case .textMultiLine:
                            MultiLineTextInputView(field: field.inputField, value: $field.stringValue)
                                .frame(height: 155, alignment: .top)
                        case .switch:
                            SwitchInputView(field: field.inputField, value: $field.boolValue)
                        }
                    }
                    
                    if viewModel.showLogsInfo {
                        HStack(alignment: .top, spacing: 0) {
                            Image(Asset.icInfoCircle.name, bundle: Bundle.module)
                                .padding(0)
                            
                            Text(LocalizedString.br3LogsDisabled)
                                .font(.footnote)
                                .foregroundColor(colors.textSecondary)
                                .padding(.leading, 8)
                            
                        }
                        .padding(.horizontal)
                    }
                                        
                    Button(action: {
                        viewModel.sendTapped()
                    }, label: { Text(viewModel.isSending ? LocalizedString.br3ButtonSending : LocalizedString.br3ButtonSend) })
                        .disabled(!viewModel.canBeSent)
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal)
                }
            }
            
            NavigationLink(
                destination: ResultView(
                    error: viewModel.sendResultError,
                    finishCallback: { self.viewModel.finished() },
                    retryCallback: { self.viewModel.sendResult = nil },
                    troubleshootCallback: { self.viewModel.troubleshootingTapped() }
                ),
                isActive: $viewModel.shouldShowResultView) { EmptyView() }
        }
        // Custom Back button
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            self.presentationMode.wrappedValue.dismiss()
        }, label: {
            Image(systemName: "arrow.left")
                .foregroundColor(colors.textPrimary)
        }))
        .environment(\.isLoading, viewModel.isSending)
    }
}

// MARK: - Preview

@available(iOS 14.0, *)
struct FormView_Previews: PreviewProvider {
    static var previews: some View {
        let fields = [
            InputField(label: "Network type",
                       submitLabel: "network",
                       type: .textSingleLine,
                       isMandatory: true,
                       placeholder: "Home, work, Wifi, cellular, etc."),
            
            InputField(label: "What are you trying to do",
                       submitLabel: "What do you do",
                       type: .textMultiLine,
                       isMandatory: true,
                       placeholder: "Loerp ipsum"),
            
            InputField(label: "What is the speed you are getting?",
                       submitLabel: "Speed",
                       type: .textMultiLine,
                       isMandatory: true,
                       placeholder: "Loerp ipsum speed"),
        ]
        
        return FormView(viewModel: FormViewModel(fields: fields))
            .preferredColorScheme(.dark)
    }
}
