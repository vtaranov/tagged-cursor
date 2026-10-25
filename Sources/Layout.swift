import AppKit
import Carbon
import Darwin

enum TIS {
    static func current() -> LayoutInfo? {
        TISCopyCurrentKeyboardInputSource().map { info($0.takeRetainedValue()) }
    }

    static func enabled() -> [LayoutInfo] {
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
                      kTISPropertyInputSourceIsSelectCapable: true] as CFDictionary
        let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        var result: [LayoutInfo] = []
        for layout in list.map(info) where !result.contains(layout) { result.append(layout) }
        return result
    }

    private static func info(_ src: TISInputSource) -> LayoutInfo {
        LayoutInfo(id: property(src, kTISPropertyInputSourceID) as? String ?? "",
                   language: (property(src, kTISPropertyInputSourceLanguages) as? [String])?.first ?? "")
    }

    private static func property(_ src: TISInputSource, _ key: CFString) -> AnyObject? {
        guard let ptr = TISGetInputSourceProperty(src, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue()
    }
}

/// Процессы удалённого доступа, через которые приходит ввод с другого компьютера.
private let remoteAgents: Set<String> = ["ScreensharingAgent", "AnyDesk"]

func isRemoteEvent(_ event: NSEvent) -> Bool {
    guard let pid = event.cgEvent?.getIntegerValueField(.eventSourceUnixProcessID), pid > 0 else { return false }
    var name = [CChar](repeating: 0, count: 256)
    guard proc_name(pid_t(pid), &name, UInt32(name.count)) > 0 else { return false }
    return remoteAgents.contains(String(cString: name))
}
