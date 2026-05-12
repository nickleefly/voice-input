import Cocoa

final class FnKeyMonitor {
    var onFnKeyDown: (() -> Void)?
    var onFnKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnPressed = false
    private var fnUpWorkItem: DispatchWorkItem?
    private var eventCount = 0

    private static let fnUpDebounce: TimeInterval = 0.15

    private static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".voiceinput-debug.log")

    private static let fnKeyCode: CGKeyCode = 63

    private static func writeLog(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(ts)] \(msg)\n"
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    static func clearLog() {
        try? FileManager.default.removeItem(at: logURL)
    }

    func start() -> Bool {
        let flagsMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let keyDownMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let keyUpMask = CGEventMask(1 << CGEventType.keyUp.rawValue)
        let mask = flagsMask | keyDownMask | keyUpMask

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        Self.writeLog("start() called, creating event tap...")
        Self.writeLog("Binary: \(CommandLine.arguments[0])")

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<FnKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            Self.writeLog("ERROR: CGEvent.tapCreate returned nil")
            Self.writeLog("→ Accessibility permission may not be granted for this binary")
            Self.writeLog("→ Go to System Settings → Privacy & Security → Accessibility")
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Self.writeLog("SUCCESS: Event tap created and enabled. Press Fn key to test.")
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Self.writeLog("WARNING: Tap disabled (\(type == .tapDisabledByTimeout ? "timeout" : "userInput")), re-enabling")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // Log first 30 events for diagnostics
        if eventCount < 30 {
            eventCount += 1
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags.rawValue
            Self.writeLog("event #\(self.eventCount): type=\(type.rawValue) keyCode=\(keyCode) flags=\(flags)")
        }

        switch type {
        case .flagsChanged:
            return handleFlagsChanged(event)
        case .keyDown, .keyUp:
            return handleKeyEvent(type: type, event: event)
        default:
            return Unmanaged.passRetained(event)
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let fnDown = event.flags.contains(.maskSecondaryFn)

        if fnDown && !fnPressed {
            fnUpWorkItem?.cancel()
            fnUpWorkItem = nil
            Self.writeLog("Fn DOWN via flagsChanged (maskSecondaryFn)")
            fnPressed = true
            DispatchQueue.main.async { [weak self] in self?.onFnKeyDown?() }
            return nil
        } else if !fnDown && fnPressed {
            Self.writeLog("Fn UP via flagsChanged (debouncing)")
            fnPressed = false
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.fnPressed else { return }
                Self.writeLog("Fn UP confirmed after debounce")
                self.onFnKeyUp?()
            }
            fnUpWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.fnUpDebounce, execute: item)
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func handleKeyEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Self.fnKeyCode else {
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown && !fnPressed {
            fnUpWorkItem?.cancel()
            fnUpWorkItem = nil
            Self.writeLog("Fn DOWN via keyDown (keyCode=63)")
            fnPressed = true
            DispatchQueue.main.async { [weak self] in self?.onFnKeyDown?() }
            return nil
        } else if type == .keyUp && fnPressed {
            Self.writeLog("Fn UP via keyUp (keyCode=63, debouncing)")
            fnPressed = false
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, !self.fnPressed else { return }
                Self.writeLog("Fn UP confirmed after debounce (keyUp)")
                self.onFnKeyUp?()
            }
            fnUpWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.fnUpDebounce, execute: item)
            return nil
        }

        return Unmanaged.passRetained(event)
    }
}
