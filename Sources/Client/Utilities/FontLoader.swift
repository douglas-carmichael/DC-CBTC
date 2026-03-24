
import SwiftUI
import CoreText

struct FontLoader {
    static func registerFonts() {
        // List of fonts to register
        let fonts = ["VT323-Regular.ttf"]
        
        for font in fonts {
            // Check Main Bundle first (standard app structure)
            if let fontURL = Bundle.main.url(forResource: font, withExtension: nil) {
                registerFont(url: fontURL)
            } else {
                // Fallback: Check if we are running in a flat structure (like swift run) where resources might be in Sources/Resources/Fonts
                // This is tricky in a built app, but let's try a few known locations relative to bundle if needed.
                // For now, let's assume the build system copies resources to the bundle root or Resources folder.
                
                // Attempt to find in subdirectory "Fonts"
                if let fontURL = Bundle.main.url(forResource: "VT323-Regular", withExtension: "ttf", subdirectory: "Fonts") {
                    registerFont(url: fontURL)
                } else {
                    print("FontLoader: Could not find font \(font)")
                }
            }
        }
    }
    
    private static func registerFont(url: URL) {
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            print("FontLoader: Registered font from \(url.lastPathComponent)")
        } else {
            print("FontLoader: Failed to register font: \(error?.takeRetainedValue() ?? "Unknown error" as! CFError)")
        }
    }
}
