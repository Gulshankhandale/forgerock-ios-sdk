//
//  WebAuthnManager.swift
//  FRAuth
//
//  Copyright (c) 2021 ForgeRock. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import AuthenticationServices
import Foundation
import os

public protocol WebAuthnManagerDelegate: NSObject {
    func didFinishAuthorization()
    func didCompleteWithError(_ error: Error)
    func didCancelModalSheet()
}

@available(iOS 16, *)
public class WebAuthnManager: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    
    public weak var delegate: WebAuthnManagerDelegate?
    
    private var authenticationAnchor: ASPresentationAnchor?
    private var isPerformingModalReqest: Bool = false
    private var node: Node
    private let domain: String
    
    public init(domain: String, authenticationAnchor: ASPresentationAnchor?, node: Node) {
        self.domain = domain
        self.authenticationAnchor = authenticationAnchor
        self.node = node
        super.init()
    }
    
    public func signInWith(preferImmediatelyAvailableCredentials: Bool, challenge: Data, allowedCredentialsArray: [[UInt8]]) {
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
        var credentialsArray: [ASAuthorizationPlatformPublicKeyCredentialDescriptor] = []
        for credID in allowedCredentialsArray {
            credentialsArray.append(ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: Data(credID)))
        }
        assertionRequest.allowedCredentials = credentialsArray
        // Pass in any mix of supported sign-in request types.
        let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self

        if preferImmediatelyAvailableCredentials {
            // If credentials are available, presents a modal sign-in sheet.
            // If there are no locally saved credentials, no UI appears and
            // the system passes ASAuthorizationError.Code.canceled to call
            // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
            authController.performRequests(options: .preferImmediatelyAvailableCredentials)
        } else {
            // If credentials are available, presents a modal sign-in sheet.
            // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
            // passkey from a nearby device.
            authController.performRequests()
        }

        isPerformingModalReqest = true
    }
    
    public func signUpWith(userName: String, challenge: Data, userID: String) {
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)

        // Fetch the challenge from the server. The challenge needs to be unique for each request.
        // The userID is the identifier for the user's account.
        //let challenge = Data()
        let userID = Data(userID.utf8)
        
        let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge,
                                                                                                  name: userName, userID: userID)
        
        // Use only ASAuthorizationPlatformPublicKeyCredentialRegistrationRequests or
        // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
        let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
        authController.delegate = self
        authController.presentationContextProvider = self
    
        authController.performRequests()
        isPerformingModalReqest = true
    }
    
    //MARK: - ASAuthorizationControllerPresentationContextProviding
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return authenticationAnchor!
    }
    
    //MARK: - ASAuthorizationControllerDelegate
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        
        switch authorization.credential {
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            FRLog.i("A new passkey was registered: \(credentialRegistration)")
            // Verify the attestationObject and clientDataJSON with your service.
            // The attestationObject contains the user's new public key to store and use for subsequent sign-ins.
            let int8Arr = credentialRegistration.rawAttestationObject?.bytes.map { Int8(bitPattern: $0) }
            let attestationObject = self.convertInt8ArrToStr(int8Arr!)
            
            let clientDataJSON = String(data: credentialRegistration.rawClientDataJSON, encoding: .utf8)!
            
            let credID = base64ToBase64url(base64: credentialRegistration.credentialID.base64EncodedString())
            //  Expected AM result for successful attestation
            //  {clientDataJSON as String}::{attestation object in Int8 array}::{hashed credential identifier}
            let result = "\(clientDataJSON)::\(attestationObject)::\(credID)"
            // After the server verifies the registration and creates the user account, sign in the user with the new account.
            //didFinishSignIn()
            self.setWebAuthnOutcome(outcome: result)
            self.delegate?.didFinishAuthorization()
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            FRLog.i("A passkey was used to sign in: \(credentialAssertion)")
            // Verify the below signature and clientDataJSON with your service for the given userID.
            
            let signatureInt8 = credentialAssertion.signature.bytes.map { Int8(bitPattern: $0) }
            let signature = self.convertInt8ArrToStr(signatureInt8)
            let clientDataJSON = String(data: credentialAssertion.rawClientDataJSON, encoding: .utf8)!
            let authenticatorDataInt8 = credentialAssertion.rawAuthenticatorData.bytes.map { Int8(bitPattern: $0) }
            let authenticatorData = self.convertInt8ArrToStr(authenticatorDataInt8)
            let credID = base64ToBase64url(base64: credentialAssertion.credentialID.base64EncodedString())
            let userIDString = String(data: credentialAssertion.userID, encoding: .utf8)!
            //let userIDString = base64ToBase64url(base64: credentialAssertion.userID.base64EncodedString())
            //  Expected AM result for successful assertion
            
            //  {clientDataJSON as String}::{Int8 array of authenticatorData}::{Int8 array of signature}::{assertion identifier}::{user handle}
            let result = "\(clientDataJSON)::\(authenticatorData)::\(signature)::\(credID)::\(userIDString)"
            // After the server verifies the assertion, sign in the user.
            self.setWebAuthnOutcome(outcome: result)
            self.delegate?.didFinishAuthorization()
        default:
            fatalError("Received unknown authorization type.")
        }

        isPerformingModalReqest = false
    }

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let authorizationError = error as? ASAuthorizationError else {
            isPerformingModalReqest = false
            FRLog.e("Unexpected authorization error: \(error.localizedDescription)")
            self.delegate?.didCompleteWithError(error)
            return
        }

        if authorizationError.code == .canceled {
            // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
            // This is a good time to show a traditional login form, or ask the user to create an account.
            FRLog.i("Request canceled.")

            if isPerformingModalReqest {
                self.setWebAuthnOutcome(outcome: "ERROR::NotAllowedError:")
                self.delegate?.didCancelModalSheet()
            }
        } else {
            // Another ASAuthorization error.
            // Note: The userInfo dictionary contains useful information.
            self.delegate?.didCompleteWithError(error)
            FRLog.e("Error: \((error as NSError).userInfo)")
        }

        isPerformingModalReqest = false
    }
    
    // MARK: - Private Methods
    private func setWebAuthnOutcome(outcome: String) {
        for callback in node.callbacks {
            if let hiddenValueCallback = callback as? HiddenValueCallback, hiddenValueCallback.isWebAuthnOutcome {
                hiddenValueCallback.setValue(outcome)
                return
            }
        }
    }
    
    private func convertInt8ArrToStr(_ arr: [Int8]) -> String {
        var str = ""
        for (index, byte) in arr.enumerated() {
            str = str + "\(byte)"
            if index != (arr.count - 1) {
                str = str + ","
            }
        }
        return str
    }
    
    private func base64ToBase64url(base64: String) -> String {
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
}
fileprivate extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
