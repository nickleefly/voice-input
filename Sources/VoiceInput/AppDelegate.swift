import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibility()
        statusBarController = StatusBarController()
    }

    private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Voice Input needs Accessibility access to monitor the Fn key.\n\nPlease grant access in System Settings → Privacy & Security → Accessibility, then restart the app."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
