import Cocoa

class SettingsWindowController {
    private var window: NSWindow?
    private var apiBaseURLField: NSTextField!
    private var apiKeyField: NSSecureTextField!
    private var modelField: NSTextField!
    private var statusLabel: NSTextField!

    func show() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "LLM Settings"
        w.isReleasedWhenClosed = false

        let contentView = w.contentView!
        let refiner = LLMRefiner.shared

        // API Base URL
        let urlLabel = NSTextField(labelWithString: "API Base URL:")
        urlLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        apiBaseURLField = NSTextField()
        apiBaseURLField.placeholderString = "https://api.openai.com/v1"
        apiBaseURLField.stringValue = refiner.apiBaseURL
        apiBaseURLField.font = NSFont.systemFont(ofSize: 13)

        // API Key
        let keyLabel = NSTextField(labelWithString: "API Key:")
        keyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        apiKeyField = NSSecureTextField()
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.stringValue = refiner.apiKey
        apiKeyField.font = NSFont.systemFont(ofSize: 13)

        // Model
        let modelLabel = NSTextField(labelWithString: "Model:")
        modelLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        modelField = NSTextField()
        modelField.placeholderString = "gpt-4o-mini"
        modelField.stringValue = refiner.model
        modelField.font = NSFont.systemFont(ofSize: 13)

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        // Buttons
        let testButton = NSButton(title: "Test", target: self, action: #selector(testClicked))
        testButton.bezelStyle = .rounded
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.addView(testButton, in: .leading)
        buttonStack.addView(saveButton, in: .leading)

        // Layout
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.setHuggingPriority(.defaultHigh, for: .horizontal)

        let fields: [(NSTextField, NSTextField)] = [
            (urlLabel, apiBaseURLField),
            (keyLabel, apiKeyField),
            (modelLabel, modelField)
        ]
        for (label, field) in fields {
            let row = NSStackView()
            row.orientation = .vertical
            row.spacing = 3
            row.addView(label, in: .leading)
            row.addView(field, in: .leading)
            field.widthAnchor.constraint(equalToConstant: 420).isActive = true
            stack.addView(row, in: .leading)
        }

        stack.addView(statusLabel, in: .leading)
        stack.addView(buttonStack, in: .trailing)

        stack.setFrameSize(NSSize(width: 480, height: 260))
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])

        self.window = w
        NSApp.activate(ignoringOtherApps: true)
        w.center()
        w.makeKeyAndOrderFront(nil)
    }

    @objc private func testClicked() {
        let refiner = LLMRefiner.shared
        refiner.apiBaseURL = apiBaseURLField.stringValue
        refiner.apiKey = apiKeyField.stringValue
        refiner.model = modelField.stringValue

        guard refiner.isConfigured else {
            statusLabel.stringValue = "Please fill in all fields."
            statusLabel.textColor = .systemRed
            return
        }

        statusLabel.stringValue = "Testing..."
        statusLabel.textColor = .secondaryLabelColor

        Task { @MainActor in
            do {
                let result = try await refiner.refine("配森是最好的编程语言")
                statusLabel.stringValue = "Success: \(result)"
                statusLabel.textColor = .systemGreen
            } catch {
                statusLabel.stringValue = "Error: \(error.localizedDescription)"
                statusLabel.textColor = .systemRed
            }
        }
    }

    @objc private func saveClicked() {
        let refiner = LLMRefiner.shared
        refiner.apiBaseURL = apiBaseURLField.stringValue
        refiner.apiKey = apiKeyField.stringValue
        refiner.model = modelField.stringValue

        statusLabel.stringValue = "Saved."
        statusLabel.textColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.window?.close()
        }
    }
}
