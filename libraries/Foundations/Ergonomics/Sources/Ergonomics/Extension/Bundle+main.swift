import Foundation

extension Bundle {
    public static var atlasSecret: String? {
        let key = "ProtonVPNAtlasSecret"
        let arguments = ProcessInfo.processInfo.arguments

        if let firstIndex = arguments.firstIndex(of: "-\(key)"),
           arguments.count > firstIndex + 1 {
            return arguments[firstIndex + 1]
        }

#if !RELEASE
        return Bundle.main.infoDictionary?[key] as? String
#endif
    }
}
