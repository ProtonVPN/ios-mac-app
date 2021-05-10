import Foundation
import Clibsodium

public struct KeyExchange {
    public let SessionKeyBytes = Int(crypto_kx_sessionkeybytes())
}

extension KeyExchange {
    public struct SessionKeyPair {
        public let rx: Bytes
        public let tx: Bytes

        public init(rx: Bytes, tx: Bytes) {
            self.rx = rx
            self.tx = tx
        }
    }
}

extension KeyExchange {
    public enum Side {
        case CLIENT
        case SERVER

        var sessionKeys: (
            _ rx: UnsafeMutablePointer<UInt8>,
            _ tx: UnsafeMutablePointer<UInt8>,
            _ client_pk: UnsafePointer<UInt8>,
            _ client_sk: UnsafePointer<UInt8>,
            _ server_pk: UnsafePointer<UInt8>
        ) -> Int32 {
            switch self {
            case .CLIENT: return crypto_kx_client_session_keys
            case .SERVER: return crypto_kx_server_session_keys
            }
        }
    }
}

extension KeyExchange {
    /**
     Using this function, two parties can securely compute a set of shared keys using their peer's public key and their own secret key.
     See [libsodium.org/doc/key_exchange](https://download.libsodium.org/doc/key_exchange) for more details.

     - Parameter publicKey: The public key used for the key exchange
     - Parameter secretKey: The secret key to used for the key exchange
     - Parameter otherPublicKey: The peer's public key for the key exchange
     - Parameter side: Side (`client` or `host`) on which the key exchange is run

     - Returns: A `SessionKeyPair` consisting of a receive (`rx`) key and a transmit (`tx`) key

     - Note: `rx` on client side equals `tx` on server side and vice versa.
     */
    public func sessionKeyPair(publicKey: PublicKey, secretKey: SecretKey, otherPublicKey: PublicKey, side: Side) -> SessionKeyPair? {
        guard publicKey.count == PublicKeyBytes,
              secretKey.count == SecretKeyBytes,
              otherPublicKey.count == PublicKeyBytes
        else { return nil }

        var rx = Bytes(count: SessionKeyBytes)
        var tx = Bytes(count: SessionKeyBytes)

        guard .SUCCESS == side.sessionKeys (
            &rx,
            &tx,
            publicKey,
            secretKey,
            otherPublicKey
        ).exitCode else { return nil }

        return SessionKeyPair(rx: rx, tx: tx)
    }
}

extension KeyExchange: KeyPairGenerator {
    public typealias PublicKey = Bytes
    public typealias SecretKey = Bytes

    public var SeedBytes: Int { return Int(crypto_kx_seedbytes()) }
    public var PublicKeyBytes: Int { return Int(crypto_kx_publickeybytes()) }
    public var SecretKeyBytes: Int { return Int(crypto_kx_secretkeybytes()) }

    public static let newKeypair: (
        _ pk: UnsafeMutablePointer<UInt8>,
        _ sk: UnsafeMutablePointer<UInt8>
    ) -> Int32 = crypto_kx_keypair

    public static let keypairFromSeed: (
        _ pk: UnsafeMutablePointer<UInt8>,
        _ sk: UnsafeMutablePointer<UInt8>,
        _ seed: UnsafePointer<UInt8>
    ) -> Int32 = crypto_kx_seed_keypair

    public struct KeyPair: KeyPairProtocol {
        public typealias PublicKey = KeyExchange.PublicKey
        public typealias SecretKey = KeyExchange.SecretKey
        public let publicKey: PublicKey
        public let secretKey: SecretKey

        public init(publicKey: PublicKey, secretKey: SecretKey) {
            self.publicKey = publicKey
            self.secretKey = secretKey
        }
    }
}
