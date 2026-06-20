import SwiftUI

enum AppTheme {
    // MARK: - Sanzo Wada source
    //
    // Single brand accent: Dark Medici Blue (#417777). A quiet teal-slate
    // chosen for its instrument-panel composure. The previous direction was
    // saturated navy (Deep Indigo + Vandar Poel's Blue); this pass shifts to
    // a desaturated blue-green that reads as a serious local-first utility
    // and pairs cleanly with a bone-paper neutral background.

    enum SanzoWada {
        static let darkMediciBlue = rgb(65, 119, 119) // #417777
    }

    struct Palette {
        let background: Color
        let surface: Color
        let surfaceBorder: Color
        let divider: Color

        let textPrimary: Color
        let textSecondary: Color
        let textMuted: Color

        let accent: Color
    }

    // Single premium light theme.
    // - background: a calm bone-paper snow
    // - surface:    pure white for subtle elevation
    // - text ink:   near-black with the faintest cool cast so it sits next to the accent
    // - hairlines:  desaturated cool grays
    static let light = Palette(
        background:    rgb(247, 247, 245),
        surface:       rgb(255, 255, 255),
        surfaceBorder: rgb(225, 228, 228),
        divider:       rgb(228, 230, 230),
        textPrimary:   rgb( 23,  31,  34),
        textSecondary: rgb( 86,  96, 100),
        textMuted:     rgb(140, 150, 154),
        accent:        SanzoWada.darkMediciBlue
    )

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(.sRGB,
              red: Double(r) / 255.0,
              green: Double(g) / 255.0,
              blue: Double(b) / 255.0,
              opacity: 1.0)
    }
}
