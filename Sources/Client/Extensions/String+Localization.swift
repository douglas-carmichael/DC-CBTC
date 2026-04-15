import Foundation

extension String {
    /// Returns the localized string for the given key from Localizable.strings.
    static func loc(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
    
    /// Returns a formatted localized string.
    static func loc(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments: args)
    }
}
