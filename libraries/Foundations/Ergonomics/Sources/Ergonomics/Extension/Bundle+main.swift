import Foundation

extension Bundle {
    public static var atlasSecret: String? {
        #if DEBUG
        let key = "ATLAS_SECRET"
        return ProcessInfo.processInfo.firstArgumentValue(forKey: key) ?? Bundle.main.infoDictionary?[key] as? String
        #else
        return nil
        #endif
    }

    public static var dynamicDomain: String? {
        #if DEBUG
        let key = "DYNAMIC_DOMAIN"
        let value = ProcessInfo.processInfo.firstArgumentValue(forKey: key) ?? Bundle.main.infoDictionary?[key] as? String
        return "https://\(value)"
        #else
        return nil
        #endif
    }
}
