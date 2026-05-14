import Speech
import AVFoundation

class SpeechRecognitionManager {
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private(set) var currentLocale: Locale

    var onPartialResult: ((String) -> Void)?
    var onFinalResult: ((String) -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    var onError: ((Error) -> Void)?

    init(locale: Locale = Locale(identifier: "zh-CN")) {
        self.currentLocale = locale
        // Only request authorization if not already determined
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { _ in }
        }
    }

    func setLocale(_ locale: Locale) {
        currentLocale = locale
    }

    func start() {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .authorized else {
            onError?(NSError(domain: "VoiceInput", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]))
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.startRecognition()
        }
    }

    private func startRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil

        guard let speechRecognizer = SFSpeechRecognizer(locale: currentLocale), speechRecognizer.isAvailable else {
            onError?(NSError(domain: "VoiceInput", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available for \(currentLocale.identifier). Download the language in System Settings → Keyboard → Dictation."]))
            return
        }

        let requestedLang = currentLocale.identifier.replacingOccurrences(of: "-", with: "_")
        let actualLang = speechRecognizer.locale.identifier.replacingOccurrences(of: "-", with: "_")
        if actualLang != requestedLang {
            onError?(NSError(domain: "VoiceInput", code: 3, userInfo: [NSLocalizedDescriptionKey: "\(currentLocale.identifier) not installed. Download it in System Settings → Keyboard → Dictation."]))
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 14, *) {
            request.requiresOnDeviceRecognition = false
        }
        self.recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async {
                    // Cancel error is expected when we stop
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        // Cancellation - ignore
                        return
                    }
                    self?.onError?(error)
                }
                return
            }
            if let result = result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    DispatchQueue.main.async { self?.onFinalResult?(text) }
                } else {
                    DispatchQueue.main.async { self?.onPartialResult?(text) }
                }
            }
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += channelData[i] * channelData[i]
            }
            let rms = sqrt(sum / Float(max(frameLength, 1)))
            DispatchQueue.main.async { self?.onAudioLevel?(rms) }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            onError?(error)
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
