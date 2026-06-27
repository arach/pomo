import SwiftUI

enum PomoAmpFace: String, CaseIterable, Codable, Identifiable {
    case classic
    case cassette
    case spectrum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .cassette: return "Cassette"
        case .spectrum: return "Spectrum"
        }
    }

    var next: PomoAmpFace {
        let all = PomoAmpFace.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var accent: Color {
        switch self {
        case .classic: return Color(hex: 0x7CF27A)
        case .cassette: return Color(hex: 0xFFB14A)
        case .spectrum: return Color(hex: 0x29F4FF)
        }
    }

    var secondary: Color {
        switch self {
        case .classic: return Color(hex: 0xE7EA7A)
        case .cassette: return Color(hex: 0xF06AAE)
        case .spectrum: return Color(hex: 0xFF45D6)
        }
    }

    var background: [Color] {
        switch self {
        case .classic:
            return [Color(hex: 0x20222A), Color(hex: 0x08090D)]
        case .cassette:
            return [Color(hex: 0x301D17), Color(hex: 0x0E0907)]
        case .spectrum:
            return [Color(hex: 0x071421), Color(hex: 0x050609)]
        }
    }
}
