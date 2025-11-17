//
//  Created on 10/09/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import AuthenticationServices

import ProtonCoreAuthentication
import ProtonCoreLogin
import ProtonCoreServices

import Domain

@Observable
@MainActor
final class AnyTwoFactorViewModel: NSObject {
    enum Error {
        case missingAuthenticationOptions
        case unknownAuthorizationCredentials
        case authenticationServicesFailure(any Swift.Error)
        case wrapped(ProtonVPNError)
    }

    enum Event {
        case securityKeyPublicKey(Fido2Signature)
        case platformPublicKey(Fido2Signature)
        case error(ProtonVPNError)
    }

    let loginViewModel: LoginViewModel

    var authenticationOptions: AuthenticationOptions?

    private(set) weak var twoFactorDelegate: TwoFactorDelegate?

    var twoFactorError: Error?
    var showErrorAlert = false

    let stream: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation

    init(loginViewModel: LoginViewModel, twoFactorDelegate: TwoFactorDelegate) {
        self.loginViewModel = loginViewModel
        self.twoFactorDelegate = twoFactorDelegate
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        self.stream = stream
        self.continuation = continuation
        super.init()
    }

    func presentAuthController() {
        guard let authenticationOptions else {
            continuation.yield(.error(Error.missingAuthenticationOptions))
            return
        }
        let controller = makeAuthController(
            relyingPartyIdentifier: authenticationOptions.relyingPartyIdentifier,
            challenge: authenticationOptions.challenge,
            allowedCredentials: authenticationOptions.allowedCredentialIds
        )
        controller.performRequests()
    }

    func makeAuthController(
        relyingPartyIdentifier: String,
        challenge: Data,
        allowedCredentials: [Data]
    ) -> ASAuthorizationController {
        let fido2Provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyIdentifier)

        let fido2Request = fido2Provider.createCredentialAssertionRequest(challenge: challenge)
        fido2Request.allowedCredentials = allowedCredentials.map {
            ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(
                credentialID: $0,
                transports: ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.allSupported
            )
        }

        let passkeyProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: relyingPartyIdentifier)

        let passkeyRequest = passkeyProvider.createCredentialAssertionRequest(challenge: challenge)
        passkeyRequest.allowedCredentials = allowedCredentials.map {
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0)
        }

        let controller = ASAuthorizationController(authorizationRequests: [fido2Request, passkeyRequest])
        controller.presentationContextProvider = self
        controller.delegate = self
        return controller
    }

    func handleNewAnyTwoFactorViewModelEvent(_ event: AnyTwoFactorViewModel.Event) {
        switch event {
        case let .securityKeyPublicKey(signature), let .platformPublicKey(signature):
            loginViewModel.provideFido(signature: signature)
        case let .error(error):
            showErrorAlert = true
            twoFactorError = .wrapped(error)
        }
    }

    func provide2FACode(code: String) {
        twoFactorDelegate?.twoFactorButtonAction(code: code)
    }

    func backAction() {
        twoFactorDelegate?.backAction()
    }

    func keychainHelpAction() {
        twoFactorDelegate?.keychainHelpAction()
    }
}

extension AnyTwoFactorViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let authenticationOptions else {
            continuation.yield(.error(Error.missingAuthenticationOptions))
            return
        }

        switch authorization.credential {
        case let credentialAssertion as ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
            let signature = Fido2Signature(credentialAssertion: credentialAssertion, authenticationOptions: authenticationOptions)
            continuation.yield(.securityKeyPublicKey(signature))
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            let signature = Fido2Signature(credentialAssertion: credentialAssertion, authenticationOptions: authenticationOptions)
            continuation.yield(.platformPublicKey(signature))
        default:
            continuation.yield(.error(Error.unknownAuthorizationCredentials))
        }
    }

    func authorizationController(
        controller _: ASAuthorizationController,
        didCompleteWithError error: any Swift.Error
    ) {
        log.error("Authorization controller didCompleteWithError: \(error.localizedDescription)")
        continuation.yield(.error(Error.authenticationServicesFailure(error)))
    }
}

extension AnyTwoFactorViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow
        guard let window else {
            fatalError("Trying to display an authorization controller without any window")
        }
        return window
    }
}

extension AnyTwoFactorViewModel.Error: ProtonVPNError {
    var recoverySuggestion: String? {
        "An error occured (\(errorCodeString)). Please retry."
    }

    var errorDescription: String? {
        switch self {
        case .missingAuthenticationOptions:
            "Missing authentication options"
        case .unknownAuthorizationCredentials:
            "Unknown authorization credentials"
        case .authenticationServicesFailure:
            "Authentication Services failure"
        case let .wrapped(error):
            error.localizedDescription
        }
    }

    var underlyingError: (any Error)? {
        switch self {
        case let .authenticationServicesFailure(error):
            error
        case let .wrapped(protonVPNError):
            protonVPNError
        case .missingAuthenticationOptions, .unknownAuthorizationCredentials:
            nil
        }
    }

    var charCode: FourCharCode {
        switch self {
        case .missingAuthenticationOptions:
            "TFAO"
        case .unknownAuthorizationCredentials:
            "TFUC"
        case .authenticationServicesFailure:
            "TFAF"
        case .wrapped:
            "TFWE"
        }
    }
}

extension Fido2Signature {
    init(credentialAssertion: ASAuthorizationPublicKeyCredentialAssertion, authenticationOptions: AuthenticationOptions) {
        self = .init(
            signature: credentialAssertion.signature,
            credentialID: credentialAssertion.credentialID,
            authenticatorData: credentialAssertion.rawAuthenticatorData,
            clientData: credentialAssertion.rawClientDataJSON,
            authenticationOptions: authenticationOptions
        )
    }
}
