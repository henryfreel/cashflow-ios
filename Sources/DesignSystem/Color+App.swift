import SwiftUI

// MARK: - Figma Gray Scale

/// Seven brand grays from the Figma color palette (darkest → lightest).
///
/// Swatch reference:
///   gray1  #1a1a1a   primary text, dark fills
///   gray2  #515151   dark gray
///   gray3  #737373   secondary text, inactive labels
///   gray4  #b2b2b2   tertiary text, borders
///   gray5  #dedede   subtle fills, dividers
///   gray6  #F0F0F0   light gray
///   gray7  #f7f7f7   page/screen backgrounds
extension Color {
    static let gray1 = Color(red: 26/255, green: 26/255, blue: 26/255)   // #1a1a1a
    static let gray2 = Color(red: 81/255, green: 81/255, blue: 81/255)   // #515151
    static let gray3 = Color(red: 115/255, green: 115/255, blue: 115/255) // #737373
    static let gray4 = Color(red: 178/255, green: 178/255, blue: 178/255) // #b2b2b2
    static let gray5 = Color(red: 222/255, green: 222/255, blue: 222/255) // #dedede
    static let gray6 = Color(red: 240/255, green: 240/255, blue: 240/255) // #f0f0f0
    static let gray7 = Color(red: 247/255, green: 247/255, blue: 247/255) // #f7f7f7
}

// MARK: - Figma Green Scale

/// Seven greens from the Figma color palette (darkest → lightest).
///
/// Swatch reference:
///   green1  #007D2A   darkest
///   green2  #009933
///   green3  #00B23B   primary text/icon, fills
///   green4  #33C162   medium fill
///   green5  #64D188   lighter fill
///   green6  #A1EFBB   very light tint
///   green7  #E6FFEA   background tint
extension Color {
    static let green1 = Color(red: 0/255, green: 125/255, blue: 42/255)    // #007D2A
    static let green2 = Color(red: 0/255, green: 153/255, blue: 51/255)   // #009933
    static let green3 = Color(red: 0/255, green: 178/255, blue: 59/255)   // #00B23B
    static let green4 = Color(red: 51/255, green: 193/255, blue: 98/255)  // #33c162
    static let green5 = Color(red: 100/255, green: 209/255, blue: 136/255) // #64d188
    static let green6 = Color(red: 161/255, green: 239/255, blue: 187/255) // #a1efbb
    static let green7 = Color(red: 230/255, green: 255/255, blue: 234/255) // #E6FFEA
}

// MARK: - Figma Blue Scale

/// Seven blues from the Figma color palette (darkest → lightest).
///
/// Swatch reference:
///   blue1  #0046C5   darkest
///   blue2  #0059D5   dark blue
///   blue3  #006AFF   primary link / interactive blue
///   blue4  #3C8DFF   medium blue
///   blue5  #7BB2FF   light blue
///   blue6  #A2C9FF   lighter
///   blue7  #CCE1FF   background tint
///   blue8  #E5F0FF   pill/badge background
extension Color {
    static let blue1 = Color(red: 0/255, green: 70/255, blue: 197/255)    // #0046c5
    static let blue2 = Color(red: 0/255, green: 89/255, blue: 213/255)     // #0059d5
    static let blue3 = Color(red: 0/255, green: 106/255, blue: 255/255)   // #006aff
    static let blue4 = Color(red: 60/255, green: 141/255, blue: 255/255)  // #3c8dff
    static let blue5 = Color(red: 123/255, green: 178/255, blue: 255/255) // #7bb2ff
    static let blue6 = Color(red: 162/255, green: 201/255, blue: 255/255) // #a2c9ff
    static let blue7 = Color(red: 204/255, green: 225/255, blue: 255/255) // #cce1ff
    static let blue8 = Color(red: 229/255, green: 240/255, blue: 255/255) // #e5f0ff
}

// MARK: - Figma Red Scale

/// Seven reds from the Figma color palette (darkest → lightest).
///
/// Swatch reference:
///   red1  #BF0120   darkest
///   red2  #99001A   dark red
///   red3  #CC0023   primary fill / notification badges
///   red4  #E0667B   medium
///   red5  #FDA2B2   light
///   red6  #FFCCD5   lighter
///   red7  #FFE5EA   background tint
extension Color {
    static let red1 = Color(red: 191/255, green: 1/255, blue: 32/255)      // #BF0120
    static let red2 = Color(red: 153/255, green: 0/255, blue: 26/255)    // #99001a
    static let red3 = Color(red: 204/255, green: 0/255, blue: 35/255)   // #CC0023
    static let red4 = Color(red: 224/255, green: 102/255, blue: 123/255) // #e0667b
    static let red5 = Color(red: 253/255, green: 162/255, blue: 178/255) // #fda2b2
    static let red6 = Color(red: 255/255, green: 204/255, blue: 213/255)  // #ffccd5
    static let red7 = Color(red: 255/255, green: 229/255, blue: 234/255)  // #FFE5EA
}

// MARK: - Bar chart colour palette
//
// Single source of truth shared by PLYearBarChart (all three chart modes) and
// ProfitLossDetailView (indicator dots).  Change a value here and every consumer
// updates automatically.
//
//   barRevPrimary   — darker green: category segment, net-profit overlay, indicator dot
//   barRevSecondary — lighter green: background tint on the non-category portion
//   barExpPrimary   — darker red:  category segment, net-profit overlay, indicator dot
//   barExpSecondary — lighter red:  background tint on the non-category portion
extension Color {
    static let barRevPrimary:   Color = .green3  // #00B23B  darker — overlay / category
    static let barRevSecondary: Color = .green7  // #E6FFEA  lighter — background tint
    static let barExpPrimary:   Color = .red3    // #CC0023  darker — overlay / category
    static let barExpSecondary: Color = .red7    // #FFE5EA  lighter — background tint
}

// MARK: - Device Corner Radius

import UIKit

extension UIScreen {
    /// The physical display corner radius, obtained via private API with a safe fallback.
    var displayCornerRadius: CGFloat {
        (value(forKey: "_displayCornerRadius") as? CGFloat) ?? 44
    }
}
