import SwiftUI

// MARK: - Figma Gray Scale

/// The five brand grays, taken directly from the "Grays" frame in Figma.
/// Every gray used anywhere in the app must be one of these five values.
///
/// Swatch reference (darkest → lightest):
///   gray1  #1a1a1a   primary text, dark fills
///   gray2  #737373   secondary text, inactive labels
///   gray3  #b2b2b2   tertiary text, borders
///   gray4  #dee0e2   subtle fills, dividers, selected-pill backgrounds
///   gray5  #f7f7f7   page/screen backgrounds
extension Color {
    static let gray1 = Color(red: 26  / 255, green: 26  / 255, blue: 26  / 255) // #1a1a1a
    static let gray2 = Color(red: 115 / 255, green: 115 / 255, blue: 115 / 255) // #737373
    static let gray3 = Color(red: 178 / 255, green: 178 / 255, blue: 178 / 255) // #b2b2b2
    static let gray4 = Color(red: 222 / 255, green: 224 / 255, blue: 226 / 255) // #dee0e2
    static let gray5 = Color(red: 247 / 255, green: 247 / 255, blue: 247 / 255) // #f7f7f7
}

// MARK: - Figma Green Scale

/// Five greens from the Figma color palette. Every green used in the app must be one of these.
///
/// Swatch reference (darkest → lightest):
///   green1  #009933   primary text/icon, fills
///   green2  #33C162   medium fill
///   green3  #64D188   lighter fill
///   green4  #A1EFBB   very light tint
///   green5  #CCFFDD   background tint
extension Color {
    static let green1 = Color(red:   0 / 255, green: 153 / 255, blue:  51 / 255) // #009933
    static let green2 = Color(red:  51 / 255, green: 193 / 255, blue:  98 / 255) // #33C162
    static let green3 = Color(red: 100 / 255, green: 209 / 255, blue: 136 / 255) // #64D188
    static let green4 = Color(red: 161 / 255, green: 239 / 255, blue: 187 / 255) // #A1EFBB
    static let green5 = Color(red: 204 / 255, green: 255 / 255, blue: 221 / 255) // #CCFFDD
}

// MARK: - Figma Blue Scale

/// Five blues from the Figma color palette. Every blue used in the app must be one of these.
///
/// Swatch reference (darkest → lightest):
///   blue1  #005AD9   darkest blue
///   blue2  #006AFF   primary link / interactive blue (nav subtitle, text links)
///   blue3  #3C8DFF   medium blue
///   blue4  #7BB2FF   light blue
///   blue5  #C1DBFF   background tint
extension Color {
    static let blue1 = Color(red:   0 / 255, green:  90 / 255, blue: 217 / 255) // #005AD9
    static let blue2 = Color(red:   0 / 255, green: 106 / 255, blue: 255 / 255) // #006AFF
    static let blue3 = Color(red:  60 / 255, green: 141 / 255, blue: 255 / 255) // #3C8DFF
    static let blue4 = Color(red: 123 / 255, green: 178 / 255, blue: 255 / 255) // #7BB2FF
    static let blue5 = Color(red: 193 / 255, green: 219 / 255, blue: 255 / 255) // #C1DBFF
}

// MARK: - Figma Red Scale

/// Five reds from the Figma color palette. Every red used in the app must be one of these.
///
/// Swatch reference (darkest → lightest):
///   red1  #99001A   darkest red
///   red2  #CC0023   primary fill / notification badges
///   red3  #E0667B   medium
///   red4  #EB99A7   light
///   red5  #FFCCD5   background tint
///   red6  #FFDFE5   lightest tint
extension Color {
    static let red1 = Color(red: 153 / 255, green:   0 / 255, blue:  26 / 255) // #99001A
    static let red2 = Color(red: 204 / 255, green:   0 / 255, blue:  35 / 255) // #CC0023
    static let red3 = Color(red: 224 / 255, green: 102 / 255, blue: 123 / 255) // #E0667B
    static let red4 = Color(red: 235 / 255, green: 153 / 255, blue: 167 / 255) // #EB99A7
    static let red5 = Color(red: 255 / 255, green: 204 / 255, blue: 213 / 255) // #FFCCD5
    static let red6 = Color(red: 255 / 255, green: 223 / 255, blue: 229 / 255) // #FFDFE5
}
