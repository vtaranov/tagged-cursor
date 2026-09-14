import AppKit
import Carbon
import Darwin

enum Script { case latin, cyrillic, other }

struct Layout: Equatable {
    let label: String
    let script: Script

    init(_ src: TISInputSource) {
        let id = tisProperty(src, kTISPropertyInputSourceID) as? String ?? ""
        let lang = String(((tisProperty(src, kTISPropertyInputSourceLanguages) as? [String])?.first ?? "").prefix(2))
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

    static func current() -> Layout? {
        TISCopyCurrentKeyboardInputSource().map { Layout($0.takeRetainedValue()) }
    }

    static func enabled() -> [Layout] {
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
                      kTISPropertyInputSourceIsSelectCapable: true] as CFDictionary
        let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        var result: [Layout] = []
        for layout in list.map(Layout.init) where !result.contains(layout) { result.append(layout) }
        return result
    }
}

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

/// Процессы удалённого доступа, через которые приходит ввод с другого компьютера.
private let remoteAgents: Set<String> = ["ScreensharingAgent", "AnyDesk"]

func isRemoteEvent(_ event: NSEvent) -> Bool {
    guard let pid = event.cgEvent?.getIntegerValueField(.eventSourceUnixProcessID), pid > 0 else { return false }
    var name = [CChar](repeating: 0, count: 256)
    guard proc_name(pid_t(pid), &name, UInt32(name.count)) > 0 else { return false }
    return remoteAgents.contains(String(cString: name))
}

private func tisProperty(_ src: TISInputSource, _ key: CFString) -> AnyObject? {
    guard let ptr = TISGetInputSourceProperty(src, key) else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
}
