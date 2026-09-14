import AppKit

final class FlagPanel: NSPanel {
    private let box = NSView()
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 20, height: 20),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        box.wantsLayer = true
        box.layer?.cornerRadius = 4
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 2
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
        label.shadow = shadow
        box.addSubview(label)
        contentView = box
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(text: String, anchor: Anchor) {
        if label.stringValue != text { configure(text) }
        let size = frame.size
        var origin: CGPoint
        if anchor.source == .field {
            origin = CGPoint(x: anchor.rect.minX - size.width - Config.gap, y: anchor.rect.midY - size.height / 2)
        } else {
            origin = CGPoint(x: anchor.rect.maxX - size.width / 2, y: anchor.rect.maxY + Config.gap)
            let screen = NSScreen.screens.first { $0.frame.contains(anchor.rect.origin) }?.visibleFrame
            if let screen, origin.y + size.height > screen.maxY {
                origin.y = anchor.rect.minY - size.height - Config.gap
            }
        }
        if frame.origin != origin { setFrameOrigin(origin) }
        if !isVisible { orderFrontRegardless() }
    }

    func hide() {
        if isVisible { orderOut(nil) }
    }

    private func configure(_ text: String) {
        let emoji = !text.allSatisfy(\.isASCII)
        label.stringValue = text
        label.font = emoji ? .systemFont(ofSize: Config.flagFontSize) : .boldSystemFont(ofSize: 10)
        label.textColor = emoji ? .labelColor : .white
        box.layer?.backgroundColor = emoji ? NSColor.clear.cgColor : NSColor.systemBlue.cgColor
        label.sizeToFit()
        let pad: CGFloat = emoji ? 0 : 4
        let size = CGSize(width: ceil(label.frame.width) + pad * 2, height: ceil(label.frame.height) + (emoji ? 0 : 2))
        setContentSize(size)
        label.setFrameOrigin(CGPoint(x: pad, y: (size.height - label.frame.height) / 2))
    }
}
