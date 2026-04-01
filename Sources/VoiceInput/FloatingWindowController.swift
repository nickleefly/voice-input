import Cocoa

class FloatingWindowController {
    private let panel: NSPanel
    private let visualEffectView: NSVisualEffectView
    private let waveformView: WaveformView
    private let label: NSTextField
    private let containerView: NSView

    private let windowHeight: CGFloat = 56
    private let cornerRadius: CGFloat = 28
    private let minWindowWidth: CGFloat = 160
    private let maxWindowWidth: CGFloat = 560
    private let waveformSize = NSSize(width: 44, height: 32)

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: minWindowWidth, height: windowHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.masksToBounds = true

        containerView = NSView()
        containerView.wantsLayer = true
        visualEffectView.addSubview(containerView)

        waveformView = WaveformView(frame: NSRect(x: 16, y: 0, width: waveformSize.width, height: waveformSize.height))
        waveformView.wantsLayer = true
        containerView.addSubview(waveformView)

        label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.wantsLayer = true
        containerView.addSubview(label)

        panel.contentView = visualEffectView
    }

    // MARK: - Show / Hide

    func show(text: String = "") {
        label.stringValue = text
        waveformView.reset()
        layoutViews(animate: false)

        // Initial state for spring animation
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
        panel.contentView?.layer?.opacity = 0
        panel.orderFrontRegardless()

        waveformView.startAnimating()

        // Spring entry animation
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.175, 0.885, 0.32, 1.1)
            ctx.allowsImplicitAnimation = true
            self.panel.contentView?.layer?.transform = CATransform3DIdentity
            self.panel.contentView?.layer?.opacity = 1.0
        })
    }

    func hide(completion: (() -> Void)? = nil) {
        waveformView.stopAnimating()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            self.panel.contentView?.layer?.transform = CATransform3DMakeScale(0.85, 0.85, 1.0)
            self.panel.contentView?.layer?.opacity = 0
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.panel.contentView?.layer?.transform = CATransform3DIdentity
            self.panel.contentView?.layer?.opacity = 1.0
            completion?()
        })
    }

    // MARK: - Updates

    func updateText(_ text: String) {
        guard panel.isVisible else { return }
        label.stringValue = text
        layoutViews(animate: true)
    }

    func updateAudioLevel(_ rms: Float) {
        waveformView.updateLevel(rms)
    }

    // MARK: - Layout

    private func layoutViews(animate: Bool) {
        let textSize = label.sizeThatFits(NSSize(width: maxWindowWidth - 80, height: windowHeight))
        let textWidth = min(max(textSize.width, 80), maxWindowWidth - 80)
        let capsuleWidth = min(max(16 + waveformSize.width + 12 + textWidth + 20, minWindowWidth), maxWindowWidth)
        let frame = centeredFrame(width: capsuleWidth)

        let containerFrame = NSRect(x: 0, y: 0, width: capsuleWidth, height: windowHeight)
        containerView.frame = containerFrame
        visualEffectView.frame = containerFrame

        waveformView.frame = NSRect(x: 16, y: (windowHeight - waveformSize.height) / 2, width: waveformSize.width, height: waveformSize.height)
        label.frame = NSRect(x: 16 + waveformSize.width + 12, y: (windowHeight - textSize.height) / 2, width: textWidth, height: textSize.height)

        if animate {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.panel.animator().setFrame(frame, display: true)
            })
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func centeredFrame(width: CGFloat) -> NSRect {
        guard let screen = NSScreen.main else {
            return NSRect(x: 0, y: 0, width: width, height: windowHeight)
        }
        let screenRect = screen.visibleFrame
        let x = screenRect.midX - width / 2
        let y = screenRect.minY + 28
        return NSRect(x: x, y: y, width: width, height: windowHeight)
    }
}
