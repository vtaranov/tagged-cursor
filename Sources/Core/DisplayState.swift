import Foundation

/// Когда флаг виден: он прячется с первой набранной клавишей и возвращается
/// при смене контекста либо после паузы в наборе.
struct DisplayState {
    private static let navigationKeys: Set<UInt16> = [53, 115, 116, 119, 121, 123, 124, 125, 126]

    private(set) var suppressed = false
    private(set) var lastKeyDown = Date.distantPast

    /// Esc, стрелки и сочетания с Cmd/Ctrl текст не вводят — флаг не прячем.
    static func isTypingKey(code: UInt16, hasCommandOrControl: Bool) -> Bool {
        !hasCommandOrControl && !navigationKeys.contains(code)
    }

    mutating func keyDown(at time: Date) {
        suppressed = true
        lastKeyDown = time
    }

    mutating func contextChanged() {
        suppressed = false
    }

    /// Показывать ли флаг сейчас. `pauseMs` = 0 — только при смене контекста.
    mutating func shouldShow(now: Date, pauseMs: Int) -> Bool {
        guard suppressed else { return true }
        let pause = TimeInterval(pauseMs) / 1000
        guard pause > 0, now.timeIntervalSince(lastKeyDown) >= pause else { return false }
        suppressed = false
        return true
    }
}
