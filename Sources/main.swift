import AppKit

MainActor.assumeIsolated {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    let controller = Controller()
    controller.start()
    withExtendedLifetime(controller) { application.run() }
}
