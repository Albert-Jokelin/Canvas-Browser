import SwiftUI
import Speech
import AVFoundation
import Combine

@MainActor
class VoiceControlService: ObservableObject {
    // MARK: - Published State

    @Published var isListening = false
    @Published var isAuthorized = false
    @Published var currentTranscription = ""
    @Published var lastCommandFeedback = ""
    @Published var audioLevel: Float = 0
    @Published var errorMessage: String?

    // MARK: - Settings

    @AppStorage("voiceControlEnabled") var voiceControlEnabled = true
    @AppStorage("voiceActivationMode") var voiceActivationMode = "toggleOnOff"
    @AppStorage("showTranscriptionOverlay") var showTranscriptionOverlay = true

    // MARK: - Dependencies

    let parser = VoiceCommandParser()
    let dispatcher = VoiceCommandDispatcher()

    // MARK: - Private

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceWorkItem: DispatchWorkItem?
    private var feedbackDismissTask: Task<Void, Never>?
    private var isRestarting = false
    private var hasProcessedCurrentUtterance = false

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch status {
                case .authorized:
                    self.isAuthorized = true
                    self.errorMessage = nil
                case .denied:
                    self.isAuthorized = false
                    self.errorMessage = "Speech recognition permission denied. Enable in System Settings > Privacy > Speech Recognition."
                case .restricted:
                    self.isAuthorized = false
                    self.errorMessage = "Speech recognition is restricted on this device."
                case .notDetermined:
                    self.isAuthorized = false
                @unknown default:
                    self.isAuthorized = false
                }
            }
        }

        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor [weak self] in
                if !granted {
                    self?.isAuthorized = false
                    self?.errorMessage = "Microphone access denied. Enable in System Settings > Privacy > Microphone."
                }
            }
        }
    }

    // MARK: - Listening Control

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard voiceControlEnabled else {
            errorMessage = "Voice control is disabled. Enable it in Settings."
            return
        }
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        guard speechRecognizer?.isAvailable == true else {
            errorMessage = "Speech recognition is not available."
            return
        }

        // Stop any existing session
        stopListening()

        do {
            try startRecognitionSession()
            isListening = true
            errorMessage = nil
            currentTranscription = ""
        } catch {
            errorMessage = "Failed to start: \(error.localizedDescription)"
            isListening = false
        }
    }

    func stopListening() {
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        isRestarting = false

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        isListening = false
        audioLevel = 0
    }

    // MARK: - Recognition Session

    private func startRecognitionSession() throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.recognitionRequest = request
        self.hasProcessedCurrentUtterance = false

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            Task { @MainActor [weak self] in
                self?.updateAudioLevel(buffer: buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let result = result {
                    self.currentTranscription = result.bestTranscription.formattedString
                    self.resetSilenceTimer()

                    if result.isFinal {
                        self.processTranscription()
                    }
                }

                if let error = error {
                    // Skip errors during intentional restart
                    if self.isRestarting { return }

                    // Ignore cancellation errors
                    let nsError = error as NSError
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        return
                    }
                    // Also ignore error 1110 (no speech detected) - just restart
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                        if self.isListening {
                            self.restartRecognitionSession()
                        }
                        return
                    }

                    self.errorMessage = error.localizedDescription
                    if self.isListening {
                        self.stopListening()
                    }
                }
            }
        }
    }

    // MARK: - Audio Level

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(max(frameLength, 1)))
        // Normalize to 0-1 range with some amplification
        let normalized = min(rms * 5, 1.0)
        self.audioLevel = normalized
    }

    // MARK: - Silence Detection

    private func resetSilenceTimer() {
        silenceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.processTranscription()
            }
        }
        silenceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    // MARK: - Processing

    private func processTranscription() {
        guard !hasProcessedCurrentUtterance else { return }
        let text = currentTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        hasProcessedCurrentUtterance = true
        silenceWorkItem?.cancel()
        silenceWorkItem = nil

        if let command = parser.parse(text) {
            lastCommandFeedback = command.feedbackDescription
            feedbackDismissTask?.cancel()

            if case .stopListening = command {
                stopListening()
                return
            } else {
                dispatcher.dispatch(command)
            }

            feedbackDismissTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if !Task.isCancelled {
                    lastCommandFeedback = ""
                }
            }
        }

        currentTranscription = ""

        // Restart recognition for continuous listening
        if isListening {
            restartRecognitionSession()
        }
    }

    private func restartRecognitionSession() {
        isRestarting = true

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        isRestarting = false

        do {
            try startRecognitionSession()
        } catch {
            errorMessage = "Failed to restart: \(error.localizedDescription)"
            stopListening()
        }
    }
}
