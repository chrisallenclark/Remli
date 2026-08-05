import AppIntents
import Foundation

/// Deep links into capture.
///
/// This file is deliberately the *only* shared code the widget extension compiles. It
/// imports nothing beyond Foundation and AppIntents, which keeps SwiftData, Speech,
/// EventKit and the whole services layer out of the extension binary.
enum CaptureRoute {
    static let scheme = "remli"
    static let voiceURL = URL(string: "remli://capture/voice")!
    static let textURL = URL(string: "remli://capture/text")!

    /// Returns whether the link asks for voice capture, or nil if it isn't a capture link.
    static func wantsVoice(_ url: URL) -> Bool? {
        guard url.scheme == scheme, url.host == "capture" else { return nil }
        return url.lastPathComponent == "voice"
    }
}

/// "Hey Siri, capture an idea" — and the action behind the Control Center control, which
/// is what makes the Action Button work.
///
/// Opens the app straight into a live recording. The whole premise is that the gap between
/// having a thought and capturing it must be near zero, so this skips every confirmation.
struct CaptureIdeaIntent: AppIntent {

    static var title: LocalizedStringResource = "Capture an idea"
    static var description = IntentDescription("Start recording an idea in Remli.")

    /// Recording needs the microphone and a foreground audio session, so this cannot run
    /// in the background.
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(CaptureRoute.voiceURL))
    }
}
