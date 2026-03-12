import SwiftUI

// MARK: - App Font Names

enum AppFont {
    enum Display {
        static let bold           = "SquareSansDisplay-Bold"
        static let boldCondensed  = "SquareSansDisplay-BoldCondensed"
        static let boldExpanded   = "SquareSansDisplay-BoldExpanded"
        static let medium         = "SquareSansDisplay-Medium"
        static let regular        = "SquareSansDisplay-Regular"
    }

    enum Text {
        static let bold           = "SquareSansText-Bold"
        static let boldItalic     = "SquareSansText-BoldItalic"
        static let semiBold       = "SquareSansText-SemiBold"
        static let semiBoldItalic = "SquareSansText-SemiBoldItalic"
        static let medium         = "SquareSansText-Medium"
        static let mediumItalic   = "SquareSansText-MediumItalic"
        static let regular        = "SquareSansText-Regular"
        static let italic         = "SquareSansText-Italic"
    }
}

// MARK: - Figma Design Token Styles

extension Font {
    // Display — Square Sans Display
    static let display10 = Font.custom(AppFont.Display.bold,   size: 32) // Display/10
    static let heading30 = Font.custom(AppFont.Display.bold,   size: 25) // Heading/30
    static let heading20 = Font.custom(AppFont.Display.bold,   size: 19) // Heading/20

    // Text — Square Sans Text
    static let paragraphSemibold30 = Font.custom(AppFont.Text.semiBold, size: 16) // Paragraph/Semibold 30
    static let paragraphSemibold10 = Font.custom(AppFont.Text.semiBold, size: 12) // Paragraph/Semibold 10
    static let paragraphMedium30   = Font.custom(AppFont.Text.medium,   size: 16) // Paragraph/Medium 30
    static let paragraph30         = Font.custom(AppFont.Text.regular,  size: 16) // Paragraph/30
    static let paragraph20         = Font.custom(AppFont.Text.regular,  size: 14) // Paragraph/20
}
