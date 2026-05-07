import AppKit
import Carbon.HIToolbox

/// 使用 Carbon RegisterEventHotKey 注册全局快捷键。
final class GlobalHotkey {
    struct Modifiers: OptionSet {
        let rawValue: UInt32
        static let command = Modifiers(rawValue: UInt32(cmdKey))
        static let option  = Modifiers(rawValue: UInt32(optionKey))
        static let control = Modifiers(rawValue: UInt32(controlKey))
        static let shift   = Modifiers(rawValue: UInt32(shiftKey))
    }

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?
    private var eventHandlerRef: EventHandlerRef?

    // 静态回调需要一个全局表把 signature/id 映射到 handler
    private static var callbacks: [UInt32: () -> Void] = [:]
    private static var nextId: UInt32 = 1
    private static var installed = false

    func register(keyCode: UInt32, modifiers: Modifiers, handler: @escaping () -> Void) {
        unregister()

        Self.installHandlerIfNeeded()

        let signature: OSType = 0x4D544C52 // 'MTLR'
        let id = Self.nextId
        Self.nextId += 1
        Self.callbacks[id] = handler

        let hkID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers.rawValue, hkID, GetApplicationEventTarget(), 0, &ref)

        if status == noErr {
            self.hotKeyRef = ref
            self.handler = handler
        } else {
            print("[Hotkey] RegisterEventHotKey failed: \(status)")
            Self.callbacks.removeValue(forKey: id)
        }
        _ = hkID // silence warning
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        handler = nil
    }

    private static func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, eventRef, _) -> OSStatus in
            guard let eventRef = eventRef else { return noErr }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(eventRef,
                                        EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID),
                                        nil,
                                        MemoryLayout<EventHotKeyID>.size,
                                        nil,
                                        &hkID)
            if err == noErr, let cb = GlobalHotkey.callbacks[hkID.id] {
                DispatchQueue.main.async { cb() }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}
