import Cocoa

class WaveformView: NSView {
    private let barCount = 5
    private let weights: [CGFloat] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var barLevels: [CGFloat] = [0, 0, 0, 0, 0]
    private var targetLevels: [CGFloat] = [0, 0, 0, 0, 0]
    private var animationTimer: Timer?
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let minBarHeight: CGFloat = 4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func updateLevel(_ rms: Float) {
        let normalized = min(max(CGFloat(rms) * 8.0, 0), 1.0)
        for i in 0..<barCount {
            let jitter = CGFloat.random(in: -0.04...0.04)
            targetLevels[i] = max(0, min(1, normalized * weights[i] + jitter))
        }
    }

    func startAnimating() {
        stopAnimating()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
        for i in 0..<barCount { targetLevels[i] = 0 }
        // Let it decay
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            var allZero = true
            for i in 0..<self.barCount {
                let diff = -self.barLevels[i]
                self.barLevels[i] += diff * 0.2
                if self.barLevels[i] > 0.01 { allZero = false }
            }
            self.needsDisplay = true
            if allZero {
                self.animationTimer?.invalidate()
                self.animationTimer = nil
            }
        }
    }

    func reset() {
        for i in 0..<barCount {
            targetLevels[i] = 0
            barLevels[i] = 0
        }
        needsDisplay = true
    }

    private func tick() {
        for i in 0..<barCount {
            let diff = targetLevels[i] - barLevels[i]
            let factor: CGFloat = targetLevels[i] > barLevels[i] ? 0.4 : 0.15
            barLevels[i] += diff * factor
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2

        ctx.setFillColor(NSColor.white.withAlphaComponent(0.9).cgColor)

        for i in 0..<barCount {
            let maxH = bounds.height - 8
            let barHeight = max(minBarHeight, barLevels[i] * maxH)
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = (bounds.height - barHeight) / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            path.fill()
        }
    }
}
