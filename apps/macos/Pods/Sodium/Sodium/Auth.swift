import Foundation
import Clibsodium

public struct Auth {
    public let Bytes = Int(crypto_auth_bytes())
    public typealias SecretKey = Key
}

extension Auth {
    /**
     Computes an authentication tag for a message using a key

     - Parameter message: The message to authenticate.
     - Parameter secretKey: The key required to create and verify messages.

     - Returns: The computed authentication tag.
     */
    public func tag(message: Bytes, secretKey: SecretKey) -> Bytes? {
        guard secretKey.count == KeyBytes else { return nil }

        var tag = Array<UInt8>(count: Bytes)
        guard .SUCCESS == crypto_auth (
            &tag,
            message, UInt64(message.count),
            secretKey
        ).exitCode else { return nil }

        return tag
    }

    /**
     Verifies that an authentication tag is valid for a message and a key

     - Parameter message: The message to verify.
     - Parameter secretKey: The key required to create and verify messages.
     - Parameter tag: The authentication tag.

     - Returns: `true` if the verification is successful.
     */
    public func verify(message: Bytes, secretKey: SecretKey, tag: Bytes) -> Bool {
        guard secretKey.count == KeyBytes else {
            return false
        }
        return .SUCCESS == crypto_auth_verify (
            tag,
            message, UInt64(message.count),
            secretKey
        ).exitCode
    }
}

extension Auth: SecretKeyGenerator {
    public var KeyBytes: Int { return Int(crypto_auth_keybytes()) }
    public typealias Key = Bytes

    public static let keygen: (_ k: UnsafeMutablePointer<UInt8>) -> Void = crypto_auth_keygen
}
