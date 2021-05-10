import Foundation
import Clibsodium

public struct SecretBox {
    public let MacBytes = Int(crypto_secretbox_macbytes())
    public typealias MAC = Bytes
}

extension SecretBox {
    /**
     Encrypts a message with a shared secret key.

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The shared secret key.

     - Returns: A `Bytes` object containing the nonce and authenticated ciphertext.
     */
    public func seal(message: Bytes, secretKey: Key) -> Bytes? {
        guard let (authenticatedCipherText, nonce): (Bytes, Nonce) = seal(
            message: message,
            secretKey: secretKey
        ) else { return nil }
        return nonce + authenticatedCipherText
    }

    /**
     Encrypts a message with a shared secret key.

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The shared secret key.

     - Returns: The authenticated ciphertext and encryption nonce.
     */
    public func seal(message: Bytes, secretKey: Key) -> (authenticatedCipherText: Bytes, nonce: Nonce)? {
        let nonce = self.nonce()

        guard let authenticatedCipherText = seal(message: message, secretKey: secretKey, nonce: nonce) else {
            return nil
        }

        return (authenticatedCipherText: authenticatedCipherText, nonce: nonce)
    }

    /**
     Encrypts a message with a shared secret key and a user-provided nonce.

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The shared secret key.
     - Parameter nonce: The encryption nonce.

     - Returns: The authenticated ciphertext.
     */
    public func seal(message: Bytes, secretKey: Key, nonce: Nonce) -> Bytes? {
        guard secretKey.count == KeyBytes else { return nil }
        var authenticatedCipherText = Bytes(count: message.count + MacBytes)

        guard .SUCCESS == crypto_secretbox_easy (
            &authenticatedCipherText,
            message, UInt64(message.count),
            nonce,
            secretKey
        ).exitCode else { return nil }

        return authenticatedCipherText
    }

    /**
     Encrypts a message with a shared secret key (detached mode).

     - Parameter message: The message to encrypt.
     - Parameter secretKey: The shared secret key.

     - Returns: The encrypted ciphertext, encryption nonce, and authentication tag.
     */
    public func seal(message: Bytes, secretKey: Key) -> (cipherText: Bytes, nonce: Nonce, mac: MAC)? {
        guard secretKey.count == KeyBytes else { return nil }

        var cipherText = Bytes(count: message.count)
        var mac = Bytes(count: MacBytes)
        let nonce = self.nonce()

        guard .SUCCESS == crypto_secretbox_detached (
            &cipherText,
            &mac,
            message, UInt64(message.count),
            nonce,
            secretKey
        ).exitCode else { return nil }

        return (cipherText: cipherText, nonce: nonce, mac: mac)
    }
}

extension SecretBox {
    /**
     Decrypts a message with a shared secret key.

     - Parameter nonceAndAuthenticatedCipherText: A `Bytes` object containing the nonce and authenticated ciphertext.
     - Parameter secretKey: The shared secret key.

     - Returns: The decrypted message.
     */
    public func open(nonceAndAuthenticatedCipherText: Bytes, secretKey: Key) -> Bytes? {
        guard nonceAndAuthenticatedCipherText.count >= MacBytes + NonceBytes else { return nil }
        let nonce = nonceAndAuthenticatedCipherText[..<NonceBytes].bytes as Nonce
        let authenticatedCipherText = nonceAndAuthenticatedCipherText[NonceBytes...].bytes

        return open(authenticatedCipherText: authenticatedCipherText, secretKey: secretKey, nonce: nonce)
    }

    /**
     Decrypts a message with a shared secret key and encryption nonce.

     - Parameter authenticatedCipherText: The authenticated ciphertext.
     - Parameter secretKey: The shared secret key.
     - Parameter nonce: The encryption nonce.

     - Returns: The decrypted message.
     */
    public func open(authenticatedCipherText: Bytes, secretKey: Key, nonce: Nonce) -> Bytes? {
        guard authenticatedCipherText.count >= MacBytes else { return nil }
        var message = Bytes(count: authenticatedCipherText.count - MacBytes)

        guard .SUCCESS == crypto_secretbox_open_easy (
            &message,
            authenticatedCipherText, UInt64(authenticatedCipherText.count),
            nonce,
            secretKey
        ).exitCode else { return nil }

        return message
    }

    /**
     Decrypts a message with a shared secret key, encryption nonce, and authentication tag.

     - Parameter cipherText: The encrypted ciphertext.
     - Parameter secretKey: The shared secret key.
     - Parameter nonce: The encryption nonce.

     - Returns: The decrypted message.
     */
    public func open(cipherText: Bytes, secretKey: Key, nonce: Nonce, mac: MAC) -> Bytes? {
        guard nonce.count == NonceBytes,
              mac.count == MacBytes,
              secretKey.count == KeyBytes
        else { return nil }

        var message = Bytes(count: cipherText.count)

        guard .SUCCESS == crypto_secretbox_open_detached (
            &message,
            cipherText,
            mac,
            UInt64(cipherText.count),
            nonce,
            secretKey
        ).exitCode else { return nil }

        return message
    }
}

extension SecretBox: NonceGenerator {
    public var NonceBytes: Int { return Int(crypto_secretbox_noncebytes()) }
    public typealias Nonce = Bytes
}

extension SecretBox: SecretKeyGenerator {
    public typealias Key = Bytes
    public var KeyBytes: Int { return Int(crypto_secretbox_keybytes()) }

    public static let keygen: (_ k: UnsafeMutablePointer<UInt8>) -> Void = crypto_secretbox_keygen
}
