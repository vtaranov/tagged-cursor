import AppKit
import ApplicationServices

/// Стенд для probeCaret: окно с полями AppKit, позиция курсора в которых известна
/// из самих полей (NSTextInputClient). Запуск — ./test-caret.sh, результат в stdout
/// и в коде выхода. WebKit и Electron так не проверить: AX-запросы к собственному
/// процессу не доходят до их внепроцессного содержимого (см. #012).
@MainActor
final class Harness: NSObject, NSApplicationDelegate {
    private let window = NSWindow(contentRect: NSRect(x: 100, y: 200, width: 700, height: 420),
                                  styleMask: [.titled], backing: .buffered, defer: false)
    private let field = NSTextField(frame: NSRect(x: 20, y: 360, width: 400, height: 24))
    private let secureField = NSSecureTextField(frame: NSRect(x: 440, y: 360, width: 200, height: 24))
    private let textView = NSTextView(frame: NSRect(x: 20, y: 200, width: 620, height: 140))
    private let checker = Checker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AXIsProcessTrusted() else {
            print("нет разрешения Универсального доступа для CaretHarness.app — выдайте и запустите снова")
            exit(2)
        }
        buildWindow()
        Task { await run() }
    }

    private func buildWindow() {
        field.stringValue = "abc def ghij"
        secureField.stringValue = "secret"
        textView.string = "первая строка\nвторая строка подлиннее"
        textView.isRichText = false
        window.contentView?.addSubview(field)
        window.contentView?.addSubview(secureField)
        window.contentView?.addSubview(textView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func run() async {
        guard await waitUntilActive() else {
            print("окно стенда не стало активным — проверки не запускались")
            exit(2)
        }
        await checkTextField()
        await checkTextView()
        await checkSecureField()
        report()
    }

    /// Пока окно не активно, фокус и позиция курсора читаются неверно.
    private func waitUntilActive() async -> Bool {
        for _ in 0..<40 {
            if NSApp.isActive && window.isKeyWindow { return true }
            NSApp.activate(ignoringOtherApps: true)
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    /// AX-дерево обновляется асинхронно — даём системе дойти до нового состояния.
    private func settle() async {
        try? await Task.sleep(for: .milliseconds(250))
    }

    private func fieldEditor(for view: NSView) -> NSTextView? {
        window.fieldEditor(false, for: view) as? NSTextView
    }

    private func checkTextField() async {
        window.makeFirstResponder(field)
        for index in [0, 4, 12] {
            fieldEditor(for: field)?.setSelectedRange(NSRange(location: index, length: 0))
            await settle()
            guard let editor = fieldEditor(for: field) else { continue }
            checker.checkCaret("NSTextField, позиция \(index)",
                               expected: expectedCaret(in: editor, at: index),
                               sources: [.range, .marker])
        }
    }

    private func checkTextView() async {
        window.makeFirstResponder(textView)
        // Вторая строка проверяет, что берётся нужная строка, а не только колонка.
        for index in [0, 6, 20] {
            textView.setSelectedRange(NSRange(location: index, length: 0))
            await settle()
            checker.checkCaret("NSTextView, позиция \(index)",
                               expected: expectedCaret(in: textView, at: index),
                               sources: [.range, .marker])
        }
    }

    private func checkSecureField() async {
        window.makeFirstResponder(secureField)
        fieldEditor(for: secureField)?.setSelectedRange(NSRange(location: 3, length: 0))
        await settle()
        checker.check("поле пароля без флага") {
            let probe = probeCaret(pid: getpid(), bundleID: Bundle.main.bundleIdentifier)
            return (probe.anchor == nil, probe.anchor.map { "показан \($0.source.rawValue)" } ?? "скрыт")
        }
    }

    private func report() {
        for result in checker.results {
            print("\(result.passed ? "✔" : "✘") \(result.name) — \(result.detail)")
        }
        let failed = checker.failed
        print(failed == 0 ? "\nВсе \(checker.results.count) проверок прошли"
                          : "\nПровалено \(failed) из \(checker.results.count)")
        exit(failed == 0 ? 0 : 1)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let harness = Harness()
    app.delegate = harness
    app.setActivationPolicy(.regular)
    withExtendedLifetime(harness) { app.run() }
}
