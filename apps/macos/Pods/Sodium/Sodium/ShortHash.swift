import Foundation
import Clibsodium

public struct ShortHash {
    public let Bytes = Int(crypto_shorthash_bytes())
}

extension ShortHash {
    /**
     Computes short but unpredictable (without knowing the secret key) values suitable for picking a list in a hash table for a given key.

     - Parameter message: The data to be hashed.
     - Parameter key: The hash key.  Must be of length `KeyBytes`. Can be created using `RandomBytes.buf()`.

     - Returns: The computed fingerprint.
     */
    public func hash(message: Bytes, key: Bytes) -> Bytes? {
        guard key.count == KeyBytes else { return nil }
        var output = Array<UInt8>(count: Bytes)

        guard .SUCCESS == crypto_shorthash (
            &output,
            message, UInt64(message.count),
            key
        ).exitCode else { return nil }

        return output
    }
}

extension ShortHash: SecretKeyGenerator {
    public var KeyBytes: Int { return Int(crypto_shorthash_keybytes()) }
    public typealias Key = Bytes

    public static var keygen: (UnsafeMutablePointer<UInt8>) -> Void = crypto_shorthash_keygen
}
