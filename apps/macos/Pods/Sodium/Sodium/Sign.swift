import Foundation
import Clibsodium

public struct Sign {
    public let Bytes = Int(crypto_sign_bytes())
    public let Primitive = String(validatingUTF8: crypto_sign_primitive())
}

extension Sign {
    /**
     Signs a message with the sender's secret key

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The sender's secret key.

     - Returns: The signed message.
     */
    public func sign(message: Bytes, secretKey: SecretKey) -> Bytes? {
        guard secretKey.count == SecretKeyBytes else { return nil }
        var signedMessage = Array<UInt8>(count: message.count + Bytes)

        guard .SUCCESS == crypto_sign (
            &signedMessage,
            nil,
            message, UInt64(message.count),
            secretKey
        ).exitCode else { return nil }

        return signedMessage
    }

    /**
     Computes a detached signature for a message with the sender's secret key.

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The sender's secret key.

     - Returns: The computed signature.
     */
    public func signature(message: Bytes, secretKey: SecretKey) -> Bytes? {
        guard secretKey.count == SecretKeyBytes else { return nil }
        var signature = Array<UInt8>(count: Bytes)

        guard .SUCCESS == crypto_sign_detached (
            &signature,
            nil,
            message, UInt64(message.count),
            secretKey
        ).exitCode else { return nil }

        return signature
    }
}

extension Sign {
    /**
     Verifies a signed message with the sender's public key.

     - Parameter signedMessage: The signed message to verify.
     - Parameter publicKey: The sender's public key.

     - Returns: `true` if verification is successful.
     */
    public func verify(signedMessage: Bytes, publicKey: PublicKey) -> Bool {
        let signature = signedMessage[..<Bytes].bytes
        let message = signedMessage[Bytes...].bytes

        return verify(message: message, publicKey: publicKey, signature: signature)
    }

    /**
     Verifies the detached signature of a message with the sender's public key.

     - Parameter message: The message to verify.
     - Parameter publicKey: The sender's public key.
     - Parameter signature: The detached signature to verify.

     - Returns: `true` if verification is successful.
     */
    public func verify(message: Bytes, publicKey: PublicKey, signature: Bytes) -> Bool {
        guard publicKey.count == PublicKeyBytes else {
            return false
        }

        return .SUCCESS == crypto_sign_verify_detached (
            signature,
            message, UInt64(message.count),
            publicKey
        ).exitCode
    }
}

extension Sign {
    /**
     Extracts and returns the message data of a signed message if the signature is verified with the sender's secret key.

     - Parameter signedMessage: The signed message to open.
     - Parameter publicKey: The sender's public key.

     - Returns: The message data if verification is successful.
     */
    public func open(signedMessage: Bytes, publicKey: PublicKey) -> Bytes? {
        guard publicKey.count == PublicKeyBytes, signedMessage.count >= Bytes else {
            return nil
        }

        var message = Array<UInt8>(count: signedMessage.count - Bytes)
        var mlen: UInt64 = 0

        guard .SUCCESS == crypto_sign_open (
            &message, &mlen,
            signedMessage, UInt64(signedMessage.count),
            publicKey
        ).exitCode else { return nil }

        return message
    }
}

extension Sign: KeyPairGenerator {
    public typealias PublicKey = Bytes
    public typealias SecretKey = Bytes

    public var SeedBytes: Int { return Int(crypto_sign_seedbytes()) }
    public var PublicKeyBytes: Int { return Int(crypto_sign_publickeybytes()) }
    public var SecretKeyBytes: Int { return Int(crypto_sign_secretkeybytes()) }

    public static let newKeypair: (
        _ pk: UnsafeMutablePointer<UInt8>,
        _ sk: UnsafeMutablePointer<UInt8>
    ) -> Int32 = crypto_sign_keypair

    public static let keypairFromSeed: (
        _ pk: UnsafeMutablePointer<UInt8>,
        _ sk: UnsafeMutablePointer<UInt8>,
        _ seed: UnsafePointer<UInt8>
    ) -> Int32 = crypto_sign_seed_keypair

    public struct KeyPair: KeyPairProtocol {
        public typealias PublicKey = Sign.PublicKey
        public typealias SecretKey = Sign.SecretKey
        public let publicKey: PublicKey
        public let secretKey: SecretKey

        public init(publicKey: PublicKey, secretKey: SecretKey) {
            self.publicKey = publicKey
            self.secretKey = secretKey
        }
    }
}
