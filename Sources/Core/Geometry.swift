import CoreGraphics

enum AnchorSource: String { case range, marker, metrics, field, mouse }

struct Anchor {
    var rect: CGRect // Cocoa coordinates
    var source: AnchorSource
}

struct Probe {
    var role: String
    var anchor: Anchor?
}

enum Geometry {
    /// AX отдаёт координаты от левого верхнего угла основного экрана, Cocoa — от левого нижнего.
    static func cocoaRect(fromAX r: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: mainScreenHeight - r.maxY, width: r.width, height: r.height)
    }

    /// Отсеивает заведомо не курсор: нулевые координаты, слишком большие рамки,
    /// прямоугольники за пределами всех экранов.
    static func validCaret(_ axRect: CGRect?, mainScreenHeight: CGFloat, screens: [CGRect]) -> CGRect? {
        guard let axRect, axRect.height >= 3, axRect.height <= 400, axRect.width <= 2000,
              !(axRect.minX == 0 && axRect.minY == 0) else { return nil }
        let r = cocoaRect(fromAX: axRect, mainScreenHeight: mainScreenHeight)
        let probe = r.insetBy(dx: -1, dy: -1)
        return screens.contains { $0.intersects(probe) } ? r : nil
    }

    /// Пустое поле с плейсхолдером в Chromium отдаёт вместо курсора всю строку.
    static func collapsed(_ r: CGRect) -> CGRect {
        r.width > 3 ? CGRect(x: r.minX, y: r.minY, width: 0, height: r.height) : r
    }

    /// Excel на любой диапазон отдаёт рамку всего поля — это не позиция курсора.
    static func looksLikeFieldFrame(_ rect: CGRect, axFrame: CGRect?) -> Bool {
        guard let axFrame else { return false }
        return rect.width > 20 && abs(rect.minX - axFrame.minX) < 2 && abs(rect.width - axFrame.width) < 2
    }

    /// Флаг стоит над курсором; у верхнего края экрана — под ним. Для полей без
    /// известной позиции курсора (`field`) — слева от поля.
    static func flagOrigin(anchor: Anchor, flagSize: CGSize, gap: CGFloat, screenMaxY: CGFloat?) -> CGPoint {
        if anchor.source == .field {
            return CGPoint(x: anchor.rect.minX - flagSize.width - gap,
                           y: anchor.rect.midY - flagSize.height / 2)
        }
        var origin = CGPoint(x: anchor.rect.maxX - flagSize.width / 2, y: anchor.rect.maxY + gap)
        if let screenMaxY, origin.y + flagSize.height > screenMaxY {
            origin.y = anchor.rect.minY - flagSize.height - gap
        }
        return origin
    }
}
