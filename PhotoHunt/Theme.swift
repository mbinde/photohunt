import SwiftUI

struct Theme {
    // Main background color (227, 217, 245)
    static let background = Color(red: 227/255, green: 217/255, blue: 245/255)

    // Lavender accents (for buttons, icons, decorative elements)
    static let lavender = Color(red: 0.7, green: 0.5, blue: 0.9)
    static let lavenderLight = Color(red: 0.9, green: 0.85, blue: 0.97)
    static let lavenderPastel = Color(red: 0.96, green: 0.94, blue: 0.99)

    // Text colors (readable!)
    static let textPrimary = Color.black
    static let textSecondary = Color(red: 0.4, green: 0.4, blue: 0.45)
    static let textOnLavender = Color(red: 0.3, green: 0.2, blue: 0.4)

    // Accent colors
    static let accentPink = Color(red: 0.9, green: 0.5, blue: 0.65)
    static let accentMint = Color(red: 0.3, green: 0.7, blue: 0.6)

    // Completion colors
    static let found = Color(red: 0.3, green: 0.75, blue: 0.55)
}
