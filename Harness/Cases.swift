import AppKit

/// Насколько результат probeCaret может отличаться от эталона, px.
let tolerance: CGFloat = 3

struct CaseResult {
    let name: String
    let passed: Bool
    let detail: String
}

@MainActor
final class Checker {
    private(set) var results: [CaseResult] = []

    func check(_ name: String, _ body: () -> (Bool, String)) {
        let (passed, detail) = body()
        results.append(CaseResult(name: name, passed: passed, detail: detail))
    }

    /// Курсор найден точным способом и совпадает с эталонной позицией.
    func checkCaret(_ name: String, expected: CGRect, sources: Set<AnchorSource>) {
        check(name) {
            let probe = probeCaret(pid: getpid(), bundleID: Bundle.main.bundleIdentifier)
            guard let anchor = probe.anchor else {
                return (false, "позиция не найдена, роль \(probe.role)")
            }
            let dx = abs(anchor.rect.minX - expected.minX)
            let dy = abs(anchor.rect.minY - expected.minY)
            let detail = "\(anchor.source.rawValue) x±\(Int(dx)) y±\(Int(dy))"
            guard sources.contains(anchor.source) else {
                return (false, "источник \(anchor.source.rawValue), ожидался \(sources.map(\.rawValue).sorted().joined(separator: "/"))")
            }
            return (dx <= tolerance && dy <= tolerance, detail)
        }
    }

    var failed: Int { results.filter { !$0.passed }.count }
}

/// Эталон для полей AppKit: NSTextInputClient отдаёт прямоугольник курсора
/// в экранных координатах — ровно то, что должен найти probeCaret.
func expectedCaret(in client: NSTextInputClient, at index: Int) -> CGRect {
    client.firstRect(forCharacterRange: NSRange(location: index, length: 0), actualRange: nil)
}

