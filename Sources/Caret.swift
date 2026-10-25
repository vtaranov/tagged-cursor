import AppKit
import ApplicationServices

private let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
private let systemWide = AXUIElementCreateSystemWide()

/// Приложения, где расчёт по ширине текста слишком неточен — флаг ставится у начала поля.
private let noMetricsApps: Set<String> = ["com.microsoft.Excel"]

func probeCaret(pid: pid_t, bundleID: String?) -> Probe {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, Config.axTimeout)
    guard let el = axElement(axAttr(app, kAXFocusedUIElementAttribute))
            ?? axElement(axAttr(systemWide, kAXFocusedUIElementAttribute)) else {
        return Probe(role: "no-focus", anchor: nil)
    }
    AXUIElementSetMessagingTimeout(el, Config.axTimeout)

    let role = axAttr(el, kAXRoleAttribute) as? String ?? "?"
    let subrole = axAttr(el, kAXSubroleAttribute) as? String
    if subrole == "AXSecureTextField" { return Probe(role: role, anchor: nil) }

    let rangeRef = axAttr(el, kAXSelectedTextRangeAttribute)
    let markerRef = axAttr(el, "AXSelectedTextMarkerRange")
    guard isTextInput(el, role: role, hasSelection: rangeRef != nil || markerRef != nil) else {
        return Probe(role: role, anchor: nil)
    }

    let axFrame = axValue(axAttr(el, kAXPositionAttribute), .cgPoint, CGPoint.zero).flatMap { pos in
        axValue(axAttr(el, kAXSizeAttribute), .cgSize, CGSize.zero).map { CGRect(origin: pos, size: $0) }
    }
    // Monaco схлопывает поле ввода, когда курсор уходит за пределы видимой области.
    if let axFrame, axFrame.height < 3 { return Probe(role: role, anchor: nil) }

    if let r = caretByRange(el, rangeRef, axFrame: axFrame) { return Probe(role: role, anchor: Anchor(rect: r, source: .range)) }
    if let markerRef, let r = validCaret(axValue(axParamAttr(el, "AXBoundsForTextMarkerRange", markerRef), .cgRect, CGRect.zero)) {
        return Probe(role: role, anchor: Anchor(rect: Geometry.collapsed(r), source: .marker))
    }
    guard let axFrame, let frame = visibleFrame(axFrame) else { return Probe(role: role, anchor: nil) }
    if frame.height <= Config.smallFieldMaxHeight {
        if !noMetricsApps.contains(bundleID ?? ""), let r = caretByTextMetrics(el, rangeRef, axFrame: axFrame) {
            return Probe(role: role, anchor: Anchor(rect: r, source: .metrics))
        }
        return Probe(role: role, anchor: Anchor(rect: frame, source: .field))
    }
    let m = NSEvent.mouseLocation
    return Probe(role: role, anchor: Anchor(rect: CGRect(x: m.x + 10, y: m.y - 26, width: 0, height: 16), source: .mouse))
}

private func visibleFrame(_ axRect: CGRect) -> CGRect? {
    let r = cocoaRect(fromAX: axRect)
    return NSScreen.screens.contains { $0.frame.intersects(r) } ? r : nil
}

private func isTextInput(_ el: AXUIElement, role: String, hasSelection: Bool) -> Bool {
    if textRoles.contains(role) { return true }
    guard hasSelection, role != "AXWebArea" else { return false }
    var settable: DarwinBoolean = false
    let valueSettable = AXUIElementIsAttributeSettable(el, kAXValueAttribute as CFString, &settable) == .success && settable.boolValue
    return valueSettable || axAttr(el, "AXEditableAncestor") != nil
}

/// Для полей без координат символов (омнибокс Chrome): ширина текста до курсора системным шрифтом.
/// Прокрутку длинного текста не учитывает — курсор прижимается к правому краю поля.
private func caretByTextMetrics(_ el: AXUIElement, _ rangeRef: CFTypeRef?, axFrame: CGRect) -> CGRect? {
    guard let range = axValue(rangeRef, .cfRange, CFRange()) else { return nil }
    let loc = range.location + range.length

    var prefixText = ""
    if loc > 0 {
        var r = CFRange(location: 0, length: loc)
        if let param = AXValueCreate(.cfRange, &r), let str = axParamAttr(el, kAXStringForRangeParameterizedAttribute, param) as? String {
            prefixText = str
        } else if let value = axAttr(el, kAXValueAttribute) as? String {
            prefixText = (value as NSString).substring(to: min(loc, (value as NSString).length))
        } else {
            return nil
        }
    }
    // Для многострочного текста считаем только последнюю строку.
    let lastLine = prefixText.components(separatedBy: .newlines).last ?? ""
    let width = (lastLine as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 14)]).width
    let x = min(axFrame.minX + width, axFrame.maxX)
    return validCaret(CGRect(x: x, y: axFrame.minY, width: 0, height: min(axFrame.height, 20)))
}

private func caretByRange(_ el: AXUIElement, _ rangeRef: CFTypeRef?, axFrame: CGRect?) -> CGRect? {
    guard let range = axValue(rangeRef, .cfRange, CFRange()) else { return nil }
    let loc = range.location + range.length

    func bounds(_ location: Int, _ length: Int) -> CGRect? {
        var r = CFRange(location: location, length: length)
        guard let param = AXValueCreate(.cfRange, &r),
              let rect = axValue(axParamAttr(el, kAXBoundsForRangeParameterizedAttribute, param), .cgRect, CGRect.zero) else { return nil }
        return Geometry.looksLikeFieldFrame(rect, axFrame: axFrame) ? nil : rect
    }

    if let r = validCaret(bounds(loc, 0)) { return Geometry.collapsed(r) }
    if let r = validCaret(bounds(loc, 1)) { return CGRect(x: r.minX, y: r.minY, width: 0, height: r.height) }
    if loc > 0, let r = validCaret(bounds(loc - 1, 1)) { return CGRect(x: r.maxX, y: r.minY, width: 0, height: r.height) }
    return nil
}
