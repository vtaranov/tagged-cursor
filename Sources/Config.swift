import Foundation
import os

enum Config {
    static let flagFontSize: CGFloat = 15
    static let gap: CGFloat = 2
    static let trackInterval: TimeInterval = 0.12
    static let smallFieldMaxHeight: CGFloat = 60
    static let axTimeout: Float = 0.15
}

enum Settings {
    private static let reshowKey = "reshowAfterIdleMs"

    /// Пауза без нажатий, после которой флаг появляется снова. 0 — только при смене контекста.
    static var reshowAfterIdleMs: Int {
        get { UserDefaults.standard.object(forKey: reshowKey) as? Int ?? 2000 }
        set { UserDefaults.standard.set(max(0, newValue), forKey: reshowKey) }
    }
}

let log = Logger(subsystem: "local.tagged-cursor", category: "caret")
