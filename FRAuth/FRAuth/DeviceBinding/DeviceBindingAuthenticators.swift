//
//  DeviceBindingAuthenticators.swift
//  FRAuth
//
//  Copyright (c) 2022 ForgeRock. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Security
import Foundation
import FRCore
import JOSESwift


/// Protiocol  to override keypair generation, authentication, signing and access control
public protocol DeviceAuthenticator {
    
    /// Generate  public and private key pair
    func generateKeys() throws -> KeyPair
    
    /// Display authentication  prompt for authentication type if needed
    /// - Parameter timeout: Timeout for teh authentication prompt
    /// - Parameter completion: Completion block for Device binding result callback
    func authenticate(timeout: Int, completion: @escaping DeviceBindingResultCallback)
    
    /// Sign the challenge sent from the server and generate signed JWT
    /// - Parameter keyPair: Public and private key pair
    /// - Parameter kid: Generated key id
    /// - Parameter userId: user Id received from server
    /// - Parameter challenge: challenge received from server
    /// - Returns: compact serialized jws
    func sign(keyPair: KeyPair, kid: String, userId: String, challenge: String) throws -> String
    
    /// Check if  authentication is supported
    func isSupported() -> Bool
    
    /// Access Control for the authetication type
    func accessControl() -> SecAccessControl?
}


extension DeviceAuthenticator {
    
    /// Default implemention
    /// Sign the challenge sent from the server and generate signed JWT
    /// - Parameter keyPair: Public and private key pair
    /// - Parameter kid: Generated key id
    /// - Parameter userId: user Id received from server
    /// - Parameter challenge: challenge received from server
    /// - Returns: compact serialized jws
    func sign(keyPair: KeyPair, kid: String, userId: String, challenge: String) throws -> String {
        
        let jwk = try RSAPublicKey(publicKey: keyPair.publicKey, additionalParameters: ["use": "sig", "alg": "RS512"])
        let jwkWithKeyId = try  jwk.withThumbprintAsKeyId()
        
        //create header
        var header = JWSHeader(algorithm: .RS512)
        header.kid = kid
        header.typ = "JWS"
        header.jwkTyped = jwkWithKeyId
        
        //create payload
        let params: [String: Any] = ["sub": userId, "challenge": challenge, "exp": (Int(Date().addingTimeInterval(30).timeIntervalSince1970))]
        let message = try JSONSerialization.data(withJSONObject: params, options: [])
        let payload = Payload(message)
        
        //create signer
        guard let signer = Signer(signingAlgorithm: .RS512, key: keyPair.privateKey) else {
            throw DeviceBindingStatus.unsupported(errorMessage: "Cannot creat a signer for jws")
        }
        
        //create jws
        let jws = try JWS(header: header, payload: payload, signer: signer)
        
        return jws.compactSerializedString
    }
    
}


/// DeviceAuthenticator adoption for  biometric only authentication
internal struct BiometricOnly: DeviceAuthenticator {
    
    /// biometric handler for autentication
    var biometricInterface: BiometricHandler
    /// keyAware for key pair generation
    var keyAware: KeyAware
    
    
    /// Initializer for BiometricOnly
    /// - Parameter biometricInterfcae: biometric handler for autentication
    /// - Parameter keyAware: keyAware for key pair generation
    init(biometricInterfcae: BiometricHandler, keyAware: KeyAware) {
        self.biometricInterface = biometricInterfcae
        self.keyAware = keyAware
    }
    
    
    /// Generate  public and private key pair
    func generateKeys() throws -> KeyPair {
        var keyBuilderQuery = keyAware.keyBuilderQuery()
        keyBuilderQuery[String(kSecAttrAccessControl)] = accessControl()
        return try keyAware.createKeyPair(builderQuery: keyBuilderQuery) 
    }
    
    
    /// Display authentication  prompt for authentication type if needed
    /// - Parameter timeout: Timeout for teh authentication prompt
    /// - Parameter completion: Completion block for Device binding result callback
    func authenticate(timeout: Int, completion: @escaping DeviceBindingResultCallback) {
        biometricInterface.authenticate(timeout: timeout, completion: completion)
    }
    
    
    /// Check if  authentication is supported
    func isSupported() -> Bool {
        biometricInterface.isSupported(policy: .deviceOwnerAuthenticationWithBiometrics)
    }
    
    /// Access Control for the authetication type
    func accessControl() -> SecAccessControl? {
#if !targetEnvironment(simulator)
        return SecAccessControlCreateWithFlags(kCFAllocatorDefault,  kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, SecAccessControlCreateFlags.biometryCurrentSet, nil)!
#else
        return nil
#endif
    }
    
}


/// DeviceAuthenticator adoption for  biometric and Device Credential  authentication
internal struct BiometricAndDeviceCredential: DeviceAuthenticator {
    
    /// biometric handler for autentication
    var biometricInterface: BiometricHandler
    /// keyAware for key pair generation
    var keyAware: KeyAware
    
    
    /// Initializer for BiometricAndDeviceCredential
    /// - Parameter biometricInterfcae: biometric handler for autentication
    /// - Parameter keyAware: keyAware for key pair generation
    init(biometricInterfcae: BiometricHandler, keyAware: KeyAware) {
        self.biometricInterface = biometricInterfcae
        self.keyAware = keyAware
    }

    
    /// Generate  public and private key pair
    func generateKeys() throws -> KeyPair {
        var keyBuilderQuery = keyAware.keyBuilderQuery()
        keyBuilderQuery[String(kSecAttrAccessControl)] = accessControl()
        return try keyAware.createKeyPair(builderQuery: keyBuilderQuery)
    }
    
    
    /// Display authentication  prompt for authentication type if needed
    /// - Parameter timeout: Timeout for teh authentication prompt
    /// - Parameter completion: Completion block for Device binding result callback
    func authenticate(timeout: Int, completion: @escaping DeviceBindingResultCallback) {
        biometricInterface.authenticate(timeout: timeout, completion: completion)
    }
    
    
    /// Check if  authentication is supported
    func isSupported() -> Bool {
        biometricInterface.isSupported(policy: .deviceOwnerAuthentication)
    }
    
    
    /// Access Control for the authetication type
    func accessControl() -> SecAccessControl? {
#if !targetEnvironment(simulator)
        return SecAccessControlCreateWithFlags(kCFAllocatorDefault,  kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,  SecAccessControlCreateFlags.userPresence, nil)!
#else
        return nil
#endif
    }
    
}


internal struct None: DeviceAuthenticator {
    
    /// keyAware for key pair generation
    var keyAware: KeyAware
    
    
    /// Initializer for None
    /// - Parameter keyAware: keyAware for key pair generation
    init(keyAware: KeyAware) {
        self.keyAware = keyAware
    }
    
    
    /// Generate  public and private key pair
    func generateKeys() throws -> KeyPair {
        let keyBuilderQuery = keyAware.keyBuilderQuery()
        return try keyAware.createKeyPair(builderQuery: keyBuilderQuery)
    }
    
    
    /// Display authentication  prompt for authentication type if needed
    /// - Parameter timeout: Timeout for teh authentication prompt
    /// - Parameter completion: Completion block for Device binding result callback
    func authenticate(timeout: Int, completion : @escaping DeviceBindingResultCallback) {
        completion(.success)
    }
    
    
    /// Check if  authentication is supported
    func isSupported() -> Bool {
        return true
    }
    
    
    /// Access Control for the authetication type
    func accessControl() -> SecAccessControl? {
        return nil
    }
    
}


///Public and private keypair struct
public struct KeyPair {
    /// The  Private key
    var privateKey: SecKey
    /// The Private key
    var publicKey: SecKey
    ///  Alias for the key
    var keyAlias: String
}


/// AuthenticatorFactory to create the authentication type.
internal struct AuthenticatorFactory {
    
    /// Static method to create and return the correct type of authenticator
    static func getAuthenticator(userId: String,
                        authentication: DeviceBindingAuthenticationType,
                        title: String,
                        subtitle: String,
                        description: String,
                        keyAware: KeyAware?) -> DeviceAuthenticator {
        let newKeyAware = keyAware ?? KeyAware(userId: userId)
        switch authentication {
        case .biometricOnly:
            return BiometricOnly(biometricInterfcae: BiometricBindingHandler(title: title, subtitle: subtitle, description: description, policy: .deviceOwnerAuthenticationWithBiometrics), keyAware: newKeyAware)
        case .biometricAllowFallback:
            return BiometricAndDeviceCredential(biometricInterfcae: BiometricBindingHandler(title: title, subtitle: subtitle, description: description, policy: .deviceOwnerAuthentication), keyAware: newKeyAware)
        case .none:
            return None(keyAware: newKeyAware)
            
        }
    }
}





