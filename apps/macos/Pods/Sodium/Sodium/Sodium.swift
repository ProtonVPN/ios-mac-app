import Foundation
import Clibsodium

public struct Sodium {
    public let box = Box()
    public let secretBox = SecretBox()
    public let genericHash = GenericHash()
    public let pwHash = PWHash()
    public let randomBytes = RandomBytes()
    public let shortHash = ShortHash()
    public let sign = Sign()
    public let utils = Utils()
    public let keyExchange = KeyExchange()
    public let auth = Auth()
    public let stream = Stream()
    public let keyDerivation = KeyDerivation()
    public let secretStream = SecretStream()
    public let aead = Aead()

    public init() {
        _ = Sodium.once
    }
}

extension Sodium {
    private static let once: Void = {
        guard sodium_init() >= 0 else {
            fatalError("Failed to initialize libsodium")
        }
    }()
}
