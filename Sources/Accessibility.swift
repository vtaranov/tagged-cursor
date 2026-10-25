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

private var screenFrames: [CGRect] { NSScreen.screens.map(\.frame) }
private var mainScreenHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

func cocoaRect(fromAX r: CGRect) -> CGRect {
    Geometry.cocoaRect(fromAX: r, mainScreenHeight: mainScreenHeight)
}

func validCaret(_ axRect: CGRect?) -> CGRect? {
    Geometry.validCaret(axRect, mainScreenHeight: mainScreenHeight, screens: screenFrames)
}
