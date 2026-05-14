import Cocoa
import Speech

enum RecognitionLanguage: String, CaseIterable {
    case simplifiedChinese = "zh-CN"
    case english = "en-US"
    case traditionalChinese = "zh-TW"
    case japanese = "ja-JP"
    case korean = "ko-KR"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    case russian = "ru-RU"

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .russian: return "Русский"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }
}

class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let fnKeyMonitor = FnKeyMonitor()
    private let speechManager: SpeechRecognitionManager
    private let floatingWindow = FloatingWindowController()
    private let textInjector = TextInjector()
    private let settingsWindowController = SettingsWindowController()

    private var currentText = ""
    private var isRecording = false
    private var isRefining = false

    private var selectedLanguage: RecognitionLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: "recognition_language") ?? "zh-CN"
            return RecognitionLanguage(rawValue: raw) ?? .simplifiedChinese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "recognition_language")
        }
    }

    override init() {
        // Get saved language preference before initializing speechManager
        let raw = UserDefaults.standard.string(forKey: "recognition_language") ?? "zh-CN"
        let language = RecognitionLanguage(rawValue: raw) ?? .simplifiedChinese

        speechManager = SpeechRecognitionManager(locale: language.locale)
        super.init()
        setupStatusItem()
        setupMenu()
        setupSpeechManager()
        setupFnKeyMonitor()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice Input")
        button.image?.size = NSSize(width: 18, height: 18)
    }

    private func setRecordingUI(_ recording: Bool) {
        guard let button = statusItem.button else { return }
        if recording {
            button.contentTintColor = .systemRed
        } else {
            button.contentTintColor = nil
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

        // Language submenu
        let langMenu = NSMenu()
        let langMenuItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        langMenuItem.submenu = langMenu

        for lang in RecognitionLanguage.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(languageSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.rawValue
            item.state = lang.rawValue == selectedLanguage.rawValue ? .on : .off
            langMenu.addItem(item)
        }
        menu.addItem(langMenuItem)

        // LLM submenu
        let llmMenu = NSMenu()
        let llmMenuItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        llmMenuItem.submenu = llmMenu

        let toggleItem = NSMenuItem(title: "Enable", action: #selector(llmToggleClicked(_:)), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = LLMRefiner.shared.isEnabled ? .on : .off
        llmMenu.addItem(toggleItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(llmSettingsClicked), keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)
        menu.addItem(llmMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func languageSelected(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let lang = RecognitionLanguage(rawValue: raw) else { return }
        selectedLanguage = lang
        speechManager.setLocale(lang.locale)

        // Update checkmarks
        if let menu = statusItem.menu, let langMenu = menu.items.first?.submenu {
            for item in langMenu.items {
                item.state = item.representedObject as? String == raw ? .on : .off
            }
        }
    }

    @objc private func llmToggleClicked(_ sender: NSMenuItem) {
        LLMRefiner.shared.isEnabled = !LLMRefiner.shared.isEnabled
        sender.state = LLMRefiner.shared.isEnabled ? .on : .off
    }

    @objc private func llmSettingsClicked() {
        settingsWindowController.show()
    }

    // MARK: - Speech Manager

    private func setupSpeechManager() {
        speechManager.onPartialResult = { [weak self] text in
            guard let self = self, self.isRecording else { return }
            self.currentText = text
            self.floatingWindow.updateText(text)
        }

        speechManager.onFinalResult = { [weak self] text in
            guard let self = self else { return }
            self.currentText = text
            self.handleRecordingFinished()
        }

        speechManager.onAudioLevel = { [weak self] level in
            guard let self = self, self.isRecording else { return }
            self.floatingWindow.updateAudioLevel(level)
        }

        speechManager.onError = { [weak self] error in
            guard let self = self else { return }
            print("Speech error: \(error)")
            self.floatingWindow.updateText("Error: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.floatingWindow.hide()
            }
            self.stopRecording()
        }
    }

    // MARK: - Fn Key

    private func setupFnKeyMonitor() {
        fnKeyMonitor.onFnKeyDown = { [weak self] in
            self?.startRecording()
        }
        fnKeyMonitor.onFnKeyUp = { [weak self] in
            self?.stopRecording()
        }
        let ok = fnKeyMonitor.start()
        if !ok {
            print("[StatusBarController] Fn key monitor failed to start!")
            print("[StatusBarController] → Grant Accessibility permission and restart the app.")
            let alert = NSAlert()
            alert.messageText = "Fn Key Monitor Failed"
            alert.informativeText = "Could not create event tap for Fn key.\n\nPlease grant Accessibility permission in:\nSystem Settings → Privacy & Security → Accessibility\n\nThen restart VoiceInput."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    // MARK: - Recording Flow

    private func startRecording() {
        guard !isRecording && !isRefining else { return }
        isRecording = true
        currentText = ""
        setRecordingUI(true)
        floatingWindow.show(text: "")
        speechManager.setLocale(selectedLanguage.locale)
        speechManager.start()
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        setRecordingUI(false)
        speechManager.stop()

        // If no final result yet, wait briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, !self.isRefining else { return }
            if self.currentText.isEmpty {
                self.floatingWindow.hide()
            }
        }
    }

    private func handleRecordingFinished() {
        guard !isRefining else { return }

        if currentText.isEmpty {
            floatingWindow.hide()
            return
        }

        let llm = LLMRefiner.shared
        if llm.isEnabled && llm.isConfigured {
            isRefining = true
            floatingWindow.updateText("Refining...")
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    let refined = try await llm.refine(self.currentText)
                    self.currentText = refined
                } catch {
                    print("LLM refinement failed: \(error)")
                }
                self.isRefining = false
                self.floatingWindow.hide {
                    self.textInjector.inject(self.currentText)
                }
            }
        } else {
            floatingWindow.hide { [weak self] in
                guard let self = self else { return }
                self.textInjector.inject(self.currentText)
            }
        }
    }

    deinit {
        fnKeyMonitor.stop()
    }
}
