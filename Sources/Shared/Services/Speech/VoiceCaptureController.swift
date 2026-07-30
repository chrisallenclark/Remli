import AVFoundation
import Foundation
import Observation
import Speech

/// Live microphone transcription, built on iOS 26's `SpeechAnalyzer`.
///
/// Everything runs on device. The audio is transcribed as it arrives and then thrown
/// away — Remli never writes a recording to disk and never uploads one.
///
/// The controller is deliberately forgiving. A failure to transcribe must never mean a
/// failure to capture: the capture UI keeps whatever text exists and lets the user save
/// it, and if transcription never started they can simply type instead.
@MainActor
@Observable
final class VoiceCaptureController {

    enum State: Equatable {
        case idle
        /// Permissions, model assets and audio session are being sorted out.
        case preparing
        case recording
        /// Microphone stopped; draining the last results out of the analyzer.
        case finishing
        case failed(String)
    }

    private(set) var state: State = .idle

    /// Text the analyzer has committed to.
    private(set) var finalizedText: String = ""

    /// The in-flight guess for what is currently being said. Rendered dimmed, and replaced
    /// wholesale as the analyzer changes its mind.
    private(set) var volatileText: String = ""

    /// Rough input level 0–1, for the waveform. Smoothed so it reads as breathing rather
    /// than jittering.
    private(set) var inputLevel: Double = 0

    var transcript: String {
        let joined = finalizedText + volatileText
        return joined.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isRunning: Bool {
        state == .recording || state == .preparing
    }

    // MARK: - Private state

    private let audioEngine = AVAudioEngine()
    private let converter = BufferConverter()

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?

    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func start() async {
        guard !isRunning else { return }

        finalizedText = ""
        volatileText = ""
        state = .preparing

        do {
            try await ensurePermissions()
            try await configureAnalyzer()
            try configureAudioSession()
            try startEngine()
            state = .recording
        } catch {
            await teardown()
            state = .failed(Self.message(for: error))
        }
    }

    /// Stops the microphone and waits for the analyzer to emit its final results, so the
    /// last few words are not lost.
    func stop() async {
        guard state == .recording || state == .preparing else { return }
        state = .finishing

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        inputBuilder?.finish()
        inputBuilder = nil

        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
        } catch {
            // The transcript captured so far is still perfectly usable, so a failure to
            // drain cleanly is not worth surfacing to the user.
        }

        await resultsTask?.value
        resultsTask = nil

        await teardown()
        state = .idle
    }

    /// Abandons the session without waiting to drain. Used when the sheet is dismissed.
    func cancel() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        inputBuilder?.finish()
        inputBuilder = nil
        resultsTask?.cancel()
        resultsTask = nil
        await analyzer?.cancelAndFinishNow()
        await teardown()
        state = .idle
        finalizedText = ""
        volatileText = ""
    }

    private func teardown() async {
        analyzer = nil
        transcriber = nil
        analyzerFormat = nil
        converter.reset()
        inputLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Permissions

    private func ensurePermissions() async throws {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw CaptureError.microphoneDenied
        }

        // Only ask for speech authorisation if the system has not already decided. The
        // first capture should involve as few dialogs as possible.
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            guard granted else { throw CaptureError.speechDenied }
        default:
            throw CaptureError.speechDenied
        }
    }

    // MARK: - Analyzer

    private func configureAnalyzer() async throws {
        let locale = Locale.current

        let supported = await SpeechTranscriber.supportedLocales
            .map { $0.identifier(.bcp47) }
        guard supported.contains(locale.identifier(.bcp47)) else {
            throw CaptureError.localeUnsupported(locale.identifier)
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            // Volatile results are what make the transcript appear as you speak rather
            // than in silent chunks.
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        self.transcriber = transcriber

        try await installAssetsIfNeeded(for: transcriber, locale: locale)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer
        self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

        let (sequence, builder) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputBuilder = builder

        consumeResults(from: transcriber)

        try await analyzer.start(inputSequence: sequence)
    }

    /// The speech model for a locale is downloaded on demand rather than shipped in the
    /// app. On a device that has never transcribed in this language this takes a moment,
    /// which is why the UI has a distinct "preparing" state.
    private func installAssetsIfNeeded(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let installed = await SpeechTranscriber.installedLocales
            .map { $0.identifier(.bcp47) }
        guard !installed.contains(locale.identifier(.bcp47)) else { return }

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    private func consumeResults(from transcriber: SpeechTranscriber) {
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    guard let self else { return }
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self.finalizedText += text
                        self.volatileText = ""
                    } else {
                        self.volatileText = text
                    }
                }
            } catch {
                guard let self else { return }
                // Keep whatever was transcribed; only report if nothing survived.
                if self.transcript.isEmpty {
                    self.state = .failed("Transcription stopped unexpectedly.")
                }
            }
        }
    }

    // MARK: - Audio

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // `.record` rather than `.playAndRecord`: Remli never plays audio back, and the
        // narrower category is less disruptive to whatever else is playing.
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startEngine() throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let level = Self.peakLevel(of: buffer)
            Task { @MainActor in
                self.ingest(buffer, level: level)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func ingest(_ buffer: AVAudioPCMBuffer, level: Double) {
        // Simple asymmetric smoothing: rise fast so the meter feels responsive, fall
        // slowly so it does not flicker between syllables.
        inputLevel += (level - inputLevel) * (level > inputLevel ? 0.6 : 0.15)

        guard let analyzerFormat, let inputBuilder else { return }
        do {
            let converted = try converter.convert(buffer, to: analyzerFormat)
            inputBuilder.yield(AnalyzerInput(buffer: converted))
        } catch {
            // Dropping an occasional buffer degrades the transcript slightly; tearing the
            // session down would lose it entirely.
        }
    }

    private nonisolated static func peakLevel(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var sum: Float = 0
        for index in stride(from: 0, to: count, by: 8) {
            sum += abs(channel[index])
        }
        let mean = sum / Float(max(1, count / 8))
        // Speech sits low in a linear scale, so lift it into a usable range.
        return min(1, Double(mean) * 12)
    }

    // MARK: - Errors

    enum CaptureError: Error {
        case microphoneDenied
        case speechDenied
        case localeUnsupported(String)
    }

    private static func message(for error: Error) -> String {
        switch error {
        case CaptureError.microphoneDenied:
            return "Remli needs microphone access. Enable it in Settings, or type your idea instead."
        case CaptureError.speechDenied:
            return "Remli needs speech recognition access. Enable it in Settings, or type your idea instead."
        case CaptureError.localeUnsupported(let identifier):
            return "Live transcription isn't available for \(identifier) yet. You can type your idea instead."
        default:
            return "Couldn't start recording. You can type your idea instead."
        }
    }
}
