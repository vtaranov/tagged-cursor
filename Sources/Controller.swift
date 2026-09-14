import AppKit
import ApplicationServices
import Carbon
import ServiceManagement

private let axCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else { return }
    let controller = Unmanaged<Controller>.fromOpaque(refcon).takeUnretainedValue()
    MainActor.assumeIsolated { controller.contextChanged() }
}

@MainActor
final class Controller: NSObject {
    private static let navigationKeys: Set<UInt16> = [53, 115, 116, 119, 121, 123, 124, 125, 126]
    private static let chromiumBrowsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary", "org.chromium.Chromium", "com.brave.Browser",
        "com.microsoft.edgemac", "company.thebrowser.Browser", "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera", "ru.yandex.desktop.yandex-browser",
    ]

    private let panel = FlagPanel()
    private var statusItem: NSStatusItem?
    private let diagItem = NSMenuItem(title: "Ожидание разрешения…", action: nil, keyEquivalent: "")
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var axEnabledPIDs = Set<pid_t>()
    private let pauseItem = NSMenuItem(title: "", action: #selector(editPause), keyEquivalent: ",")
    private let loginItem = NSMenuItem(title: "Запускать при входе в систему", action: #selector(toggleLoginItem), keyEquivalent: "")
    private var layoutLabel = Layout.current()?.label ?? "?"
    private var localLabel = Layout.current()?.label ?? "?"
    /// Раскладка управляющего компьютера при удалённом доступе, если она отличается от локальной.
    private var remoteLabel: String?
    private var lastRemoteCapsLock = Date.distantPast
    private var suppressed = false
    private var lastKeyDown = Date.distantPast
    private var lastDiag = ""
    private var tokens: [Any] = []

    func start() {
        setupStatusItem()
        setupLoginItem()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            activate()
            return
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            MainActor.assumeIsolated { self?.activate() }
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "Tagged Cursor")
        let menu = NSMenu()
        diagItem.isEnabled = false
        menu.addItem(diagItem)
        menu.addItem(.separator())
        pauseItem.target = self
        updatePauseTitle()
        menu.addItem(pauseItem)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let versionItem = NSMenuItem(title: "Tagged Cursor \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    /// При первом запуске из /Applications приложение само добавляется в автозапуск.
    private func setupLoginItem() {
        let key = "loginItemInitialized"
        if !UserDefaults.standard.bool(forKey: key), Bundle.main.bundlePath.hasPrefix("/Applications/") {
            UserDefaults.standard.set(true, forKey: key)
            try? SMAppService.mainApp.register()
        }
        updateLoginItemState()
    }

    private func updateLoginItemState() {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            log.error("login item: \(error.localizedDescription, privacy: .public)")
        }
        updateLoginItemState()
    }

    private func updatePauseTitle() {
        let ms = Settings.reshowAfterIdleMs
        pauseItem.title = ms > 0 ? "Повторный показ через \(ms) мс…" : "Повторный показ: выключен…"
    }

    @objc private func editPause() {
        let alert = NSAlert()
        alert.messageText = "Пауза перед повторным показом"
        alert.informativeText = "Через сколько миллисекунд без нажатий флаг появляется снова. 0 — только при смене окна, поля или раскладки."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 0
        formatter.maximum = 600_000
        field.formatter = formatter
        field.integerValue = Settings.reshowAfterIdleMs
        alert.accessoryView = field
        alert.addButton(withTitle: "Сохранить")
        alert.addButton(withTitle: "Отмена")
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        defer { NSApp.hide(nil) }
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Settings.reshowAfterIdleMs = field.integerValue
        updatePauseTitle()
    }

    private func activate() {
        if let t = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.keyDown(event) }
        }) { tokens.append(t) }
        if let t = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.flagsChanged(event) }
        }) { tokens.append(t) }
        if let t = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.contextChanged() }
        }) { tokens.append(t) }

        tokens.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.appActivated(app) }
        })
        // Без deliverImmediately Cocoa приостанавливает доставку, пока приложение неактивно.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(layoutNotification),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, suspensionBehavior: .deliverImmediately)

        if let app = NSWorkspace.shared.frontmostApplication { appActivated(app) }
        Timer.scheduledTimer(withTimeInterval: Config.trackInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func appActivated(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid != getpid() else { return }
        enableAccessibility(app)
        observe(pid)
        contextChanged()
    }

    /// Electron и Chromium строят дерево доступности только по запросу.
    private func enableAccessibility(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard axEnabledPIDs.insert(pid).inserted else { return }
        let el = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(el, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        if let id = app.bundleIdentifier, Self.chromiumBrowsers.contains(id) {
            AXUIElementSetAttributeValue(el, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }

    private func observe(_ pid: pid_t) {
        guard pid != observedPID else { return }
        if let old = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(old), .commonModes)
        }
        observer = nil
        observedPID = pid

        var created: AXObserver?
        guard AXObserverCreate(pid, axCallback, &created) == .success, let obs = created else { return }
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXFocusedUIElementChangedNotification, kAXFocusedWindowChangedNotification] {
            AXObserverAddNotification(obs, app, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        observer = obs
    }

    private func keyDown(_ event: NSEvent) {
        if !event.modifierFlags.intersection([.command, .control]).isEmpty { return }
        if Self.navigationKeys.contains(event.keyCode) { return }
        inferLayout(from: event)
        lastKeyDown = Date()
        suppressed = true
        panel.hide()
    }

    func contextChanged() {
        suppressed = false
        update()
    }

    @objc private func layoutNotification() {
        refreshLayout()
    }

    private func refreshLayout() {
        let local = Layout.current()?.label ?? "?"
        if local != localLabel {
            localLabel = local
            remoteLabel = nil
        }
        setLayout(remoteLabel ?? localLabel, show: true)
    }

    private func setLayout(_ label: String, show: Bool) {
        guard label != layoutLabel else { return }
        layoutLabel = label
        log.notice("layout \(label, privacy: .public) remote=\(self.remoteLabel ?? "-", privacy: .public)")
        if show { contextChanged() }
    }

    /// Screen Sharing присылает готовые символы раскладки управляющего компьютера,
    /// поэтому реальную раскладку видно по набранной букве.
    private func inferLayout(from event: NSEvent) {
        let typed = script(of: event.characters ?? "")
        guard typed != .other else { return }
        if Layout.current()?.script == typed {
            remoteLabel = nil
        } else if let match = Layout.enabled().first(where: { $0.script == typed }) {
            remoteLabel = match.label
        }
        setLayout(remoteLabel ?? localLabel, show: false)
    }

    /// Caps Lock с управляющего компьютера переключает раскладку там, а не здесь.
    private func flagsChanged(_ event: NSEvent) {
        guard event.keyCode == 57, isRemoteEvent(event) else { return }
        // Нажатие приходит парой событий подряд — считаем один раз.
        let now = Date()
        guard now.timeIntervalSince(lastRemoteCapsLock) > 0.15 else { return }
        lastRemoteCapsLock = now

        let layouts = Layout.enabled().map(\.label)
        guard layouts.count > 1 else { return }
        let index = layouts.firstIndex(of: layoutLabel) ?? -1
        let next = layouts[(index + 1) % layouts.count]
        remoteLabel = next == localLabel ? nil : next
        setLayout(next, show: true)
    }

    private func tick() {
        refreshLayout()
        if suppressed {
            let pause = TimeInterval(Settings.reshowAfterIdleMs) / 1000
            guard pause > 0, Date().timeIntervalSince(lastKeyDown) >= pause else { return }
            suppressed = false
        }
        update()
    }

    private func update() {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid() else {
            panel.hide()
            return
        }
        let probe = probeCaret(pid: app.processIdentifier, bundleID: app.bundleIdentifier)
        report(app, probe)
        if let anchor = probe.anchor {
            panel.show(text: layoutLabel, anchor: anchor)
        } else {
            panel.hide()
        }
    }

    private func report(_ app: NSRunningApplication, _ probe: Probe) {
        let diag = "\(app.localizedName ?? "?") · \(probe.role) · \(probe.anchor?.source.rawValue ?? "нет позиции")"
        guard diag != lastDiag else { return }
        lastDiag = diag
        diagItem.title = diag
        log.notice("\(app.bundleIdentifier ?? "?", privacy: .public) \(diag, privacy: .public)")
    }
}
