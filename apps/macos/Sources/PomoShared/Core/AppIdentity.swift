import Foundation

enum AppIdentity {
    static var productName: String {
        if let name = Bundle.main.object(forInfoDictionaryKey: "PomoProductName") as? String,
           !name.isEmpty {
            return name
        }
        return "Pomo"
    }

    static var supportDirectoryName: String {
        if let name = ProcessInfo.processInfo.environment["POMO_SUPPORT_DIR"],
           !name.isEmpty {
            return name
        }
        if let name = Bundle.main.object(forInfoDictionaryKey: "PomoSupportDirectory") as? String,
           !name.isEmpty {
            return name
        }
        return "Pomo"
    }

    static var isPomoAmp: Bool {
        let lowercasedName = productName.lowercased()
        return lowercasedName == "pomo amp" || lowercasedName == "pomoamp"
    }
}
