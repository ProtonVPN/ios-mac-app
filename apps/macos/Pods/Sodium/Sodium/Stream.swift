import Foundation
import Clibsodium

public struct Stream {
    public let Primitive = String(validatingUTF8: crypto_stream_primitive())
}

extension Stream {
    /**
     XOR the input with a key stream derived from a secret key and a nonce.
     Applying the same operation twice outputs the original input.
     No authentication tag is added to the output. The data can be tampered with; an adversary can flip arbitrary bits.
     In order to encrypt data using a secret key, the SecretBox class is likely to be what you are looking for.
     In order to generate a deterministic stream out of a seed, the RandomBytes.deterministic_rand() function is likely to be what you need.

     - Parameter input: Input data
     - Parameter nonce: Nonce
     - Parameter secretKey: The secret key

     -  Returns: input XOR keystream(secretKey, nonce)
     */
    public func xor(input: Bytes, nonce: Nonce, secretKey: Key) -> Bytes? {
        guard secretKey.count == KeyBytes, nonce.count == NonceBytes else { return nil }

        var output = Bytes(count: input.count)
        guard .SUCCESS == crypto_stream_xor (
            &output,
            input, UInt64(input.count),
            nonce,
            secretKey
        ).exitCode else { return nil }

        return output
    }

    /**
     XOR the input with a key stream derived from a secret key and a random nonce.
     Applying the same operation twice outputs the original input.
     No authentication tag is added to the output. The data can be tampered with; an adversary can flip arbitrary bits.
     In order to encrypt data using a secret key, the SecretBox class is likely to be what you are looking for.
     In order to generate a deterministic stream out of a seed, the RandomBytes.deterministic_rand() function is likely to be what you need.

     - Parameter input: Input data
     - Parameter nonce: Nonce
     - Parameter secretKey: The secret key

     -  Returns: (input XOR keystream(secretKey, nonce), nonce)
     */
    public func xor(input: Bytes, secretKey: Key) -> (output:Bytes, nonce: Nonce)? {
        let nonce = self.nonce()

        guard let output: Bytes = xor(
            input: input,
            nonce: nonce,
            secretKey: secretKey
        ) else { return nil }

        return (output: output, nonce: nonce)
    }
}

extension Stream: NonceGenerator {
    public typealias Nonce = Bytes
    public var NonceBytes: Int { return Int(crypto_secretbox_noncebytes()) }
}

extension Stream: SecretKeyGenerator {
    public typealias Key = Bytes
    public var KeyBytes: Int { return Int(crypto_secretbox_keybytes()) }

    public static let keygen: (_ k: UnsafeMutablePointer<UInt8>) -> Void = crypto_stream_keygen
}
