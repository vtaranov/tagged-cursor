import AppKit
import ApplicationServices

func axAttr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success ? value : nil
}

func axParamAttr(_ el: AXUIElement, _ name: String, _ param: CFTypeRef) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyParameterizedAttributeValue(el, name as CFString, param, &value) == .success ? value : nil
}

func axValue<T>(_ ref: CFTypeRef?, _ type: AXValueType, _ empty: T) -> T? {
    guard let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
    var result = empty
    return AXValueGetValue(ref as! AXValue, type, &result) ? result : nil
}

func axElement(_ ref: CFTypeRef?) -> AXUIElement? {
    guard let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
    return (ref as! AXUIElement)
}

/// AX отдаёт координаты от левого верхнего угла основного экрана, Cocoa — от левого нижнего.
func cocoaRect(fromAX r: CGRect) -> CGRect {
    let h = NSScreen.screens.first?.frame.height ?? 0
    return CGRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
}

func validCaret(_ axRect: CGRect?) -> CGRect? {
    guard let axRect, axRect.height >= 3, axRect.height <= 400, axRect.width <= 2000,
          !(axRect.minX == 0 && axRect.minY == 0) else { return nil }
    let r = cocoaRect(fromAX: axRect)
    let probe = r.insetBy(dx: -1, dy: -1)
    return NSScreen.screens.contains { $0.frame.intersects(probe) } ? r : nil
}
