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
///   gray6  #f2f2f2   light gray
///   gray7  #f7f7f7   page/screen backgrounds
extension Color {
    static let gray1 = Color(red: 26/255, green: 26/255, blue: 26/255)   // #1a1a1a
    static let gray2 = Color(red: 81/255, green: 81/255, blue: 81/255)   // #515151
    static let gray3 = Color(red: 115/255, green: 115/255, blue: 115/255) // #737373
    static let gray4 = Color(red: 178/255, green: 178/255, blue: 178/255) // #b2b2b2
    static let gray5 = Color(red: 222/255, green: 222/255, blue: 222/255) // #dedede
    static let gray6 = Color(red: 242/255, green: 242/255, blue: 242/255) // #f2f2f2
    static let gray7 = Color(red: 247/255, green: 247/255, blue: 247/255) // #f7f7f7
}

// MARK: - Figma Green Scale

/// Seven greens from the Figma color palette (darkest → lightest).
///
/// Swatch reference:
///   green1  #006414   darkest
///   green2  #007828
///   green3  #009933   primary text/icon, fills
///   green4  #33C162   medium fill
///   green5  #64D188   lighter fill
///   green6  #A1EFBB   very light tint
///   green7  #CCFFDD   background tint
extension Color {
    static let green1 = Color(red: 0/255, green: 100/255, blue: 20/255)    // #006414
    static let green2 = Color(red: 0/255, green: 120/255, blue: 40/255)   // #007828
    static let green3 = Color(red: 0/255, green: 153/255, blue: 51/255)   // #009933
    static let green4 = Color(red: 51/255, green: 193/255, blue: 98/255)  // #33c162
    static let green5 = Color(red: 100/255, green: 209/255, blue: 136/255) // #64d188
    static let green6 = Color(red: 161/255, green: 239/255, blue: 187/255) // #a1efbb
    static let green7 = Color(red: 204/255, green: 255/255, blue: 221/255) // #ccffdd
}

// MARK: - Figma Blue Scale

/// Seven blues from the Figma color palette (darkest → lightest).
///
/// Swatch reference:
///   blue1  #0046c5   darkest
///   blue2  #005AD9   dark blue
///   blue3  #006AFF   primary link / interactive blue
///   blue4  #3C8DFF   medium blue
///   blue5  #7BB2FF   light blue
///   blue6  #C1DBFF   lighter
///   blue7  #DDEBFF   background tint
extension Color {
    static let blue1 = Color(red: 0/255, green: 70/255, blue: 197/255)    // #0046c5
    static let blue2 = Color(red: 0/255, green: 90/255, blue: 217/255)     // #005ad9
    static let blue3 = Color(red: 0/255, green: 106/255, blue: 255/255)   // #006aff
    static let blue4 = Color(red: 60/255, green: 141/255, blue: 255/255)  // #3c8dff
    static let blue5 = Color(red: 123/255, green: 178/255, blue: 255/255) // #7bb2ff
    static let blue6 = Color(red: 193/255, green: 219/255, blue: 255/255) // #c1dbff
    static let blue7 = Color(red: 221/255, green: 235/255, blue: 255/255)  // #ddebff
}

// MARK: - Figma Red Scale

/// Seven reds from the Figma color palette (darkest → lightest).
///
/// Swatch reference:
///   red1  #850006   darkest
///   red2  #99001A   dark red
///   red3  #D2001D   primary fill / notification badges
///   red4  #E0667B   medium
///   red5  #FDA2B2   light
///   red6  #FFCCD5   lighter
///   red7  #FFE1E6   background tint
extension Color {
    static let red1 = Color(red: 133/255, green: 0/255, blue: 6/255)      // #850006
    static let red2 = Color(red: 153/255, green: 0/255, blue: 26/255)    // #99001a
    static let red3 = Color(red: 210/255, green: 0/255, blue: 29/255)   // #d2001d
    static let red4 = Color(red: 224/255, green: 102/255, blue: 123/255) // #e0667b
    static let red5 = Color(red: 253/255, green: 162/255, blue: 178/255) // #fda2b2
    static let red6 = Color(red: 255/255, green: 204/255, blue: 213/255)  // #ffccd5
    static let red7 = Color(red: 255/255, green: 225/255, blue: 230/255)  // #ffe1e6
}

