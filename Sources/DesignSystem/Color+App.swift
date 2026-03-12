import SwiftUI

// MARK: - Figma Gray Scale

/// The five brand grays, taken directly from the "Grays" frame in Figma.
/// Every gray used anywhere in the app must be one of these five values.
///
/// Swatch reference (darkest → lightest):
///   gray900  #1a1a1a   primary text, dark fills
///   gray500  #737373   secondary text, inactive labels
///   gray300  #b2b2b2   tertiary text, borders
///   gray100  #ebedef   subtle fills, dividers, selected-pill backgrounds
///   gray50   #f7f7f7   page/screen backgrounds
extension Color {
    static let gray900 = Color(red: 26  / 255, green: 26  / 255, blue: 26  / 255) // #1a1a1a
    static let gray500 = Color(red: 115 / 255, green: 115 / 255, blue: 115 / 255) // #737373
    static let gray300 = Color(red: 178 / 255, green: 178 / 255, blue: 178 / 255) // #b2b2b2
    static let gray100 = Color(red: 235 / 255, green: 237 / 255, blue: 239 / 255) // #ebedef
    static let gray50  = Color(red: 247 / 255, green: 247 / 255, blue: 247 / 255) // #f7f7f7
}
