import Foundation

enum Script: Equatable { case latin, cyrillic, other }

/// Письменность первой буквы: по ней видно реальную раскладку, когда символы
/// приходят с управляющего компьютера.
func script(of text: String) -> Script {
    for scalar in text.unicodeScalars {
        switch scalar.value {
        case 0x41...0x5A, 0x61...0x7A: return .latin
        case 0x0400...0x04FF: return .cyrillic
        default: continue
        }
    }
    return .other
}

struct LayoutInfo: Equatable {
    let label: String
    let script: Script

    init(id: String, language: String) {
        let lang = String(language.prefix(2))
        switch lang {
        case "ru", "uk", "be", "bg", "sr", "kk": script = .cyrillic
        case "": script = .other
        default: script = .latin
        }
        if id.contains("British") { label = "🇬🇧"; return }
        switch lang {
        case "ru": label = "🇷🇺"
        case "en": label = "🇺🇸"
        case "uk": label = "🇺🇦"
        case "de": label = "🇩🇪"
        case "fr": label = "🇫🇷"
        default: label = lang.isEmpty ? "?" : lang.uppercased()
        }
    }
}
