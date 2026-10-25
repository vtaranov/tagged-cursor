import Foundation

/// Какую раскладку показывать. Локальную даёт система (TIS); при работе через
/// Screen Sharing она не меняется, поэтому раскладка управляющего компьютера
/// отслеживается отдельно — по Caps Lock и по письменности набранных букв.
struct LayoutState {
    var enabled: [LayoutInfo] = []
    private(set) var local = "?"
    private(set) var localScript: Script = .other
    private(set) var remote: String?

    var label: String { remote ?? local }

    /// Смена локальной раскладки отменяет удалённую коррекцию.
    mutating func setLocal(_ layout: LayoutInfo?) {
        localScript = layout?.script ?? .other
        let label = layout?.label ?? "?"
        guard label != local else { return }
        local = label
        remote = nil
    }

    mutating func typed(_ typedScript: Script) {
        guard typedScript != .other else { return }
        if localScript == typedScript {
            remote = nil
        } else if let match = enabled.first(where: { $0.script == typedScript }) {
            remote = match.label
        }
    }

    /// Caps Lock с управляющего компьютера переключает раскладку там, а не здесь.
    mutating func cycleRemote() {
        let labels = enabled.map(\.label)
        guard labels.count > 1 else { return }
        let index = labels.firstIndex(of: label) ?? -1
        remote = labels[(index + 1) % labels.count]
        if remote == local { remote = nil }
    }
}
