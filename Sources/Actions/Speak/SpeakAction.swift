import Foundation
import AVFoundation
import ControlPlaneSDK

public final class SpeakAction: BaseAction {

    public override var pluginIdentifier: String  { "com.controlplane.action.speak" }
    public override var pluginDisplayName: String { "Speak Text" }
    public override var pluginVersion: String     { "1.0.0" }

    public override func execute(
        trigger: ActionTrigger,
        profile: Profile,
        config: [String: String]
    ) async throws {
        guard let text = config["text"], !text.isEmpty else {
            throw SpeakActionError.missingText
        }
        let voiceIdentifier = config["voice"]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let synthesizer = AVSpeechSynthesizer()
            let delegate = SpeakActionDelegate(continuation: continuation)
            synthesizer.delegate = delegate

            synthesizer.stopSpeaking(at: .immediate)

            let utterance = AVSpeechUtterance(string: text)
            if let voiceID = voiceIdentifier, !voiceID.isEmpty {
                utterance.voice = AVSpeechSynthesisVoice(identifier: voiceID)
            }

            // Keep strong references until the delegate fires.
            delegate.synthesizer = synthesizer
            synthesizer.speak(utterance)
        }
    }

    public override func configurationDescriptors() -> [ActionConfigDescriptor] {
        [
            ActionConfigDescriptor(
                key: "text",
                label: "Text",
                description: "Text to speak aloud.",
                required: true
            ),
            ActionConfigDescriptor(
                key: "voice",
                label: "Voice",
                description: "AVSpeechSynthesisVoice identifier. Uses system default if absent.",
                required: false
            ),
        ]
    }
}

private final class SpeakActionDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var continuation: CheckedContinuation<Void, Error>?
    /// Retained so the synthesizer is not deallocated before the callback fires.
    var synthesizer: AVSpeechSynthesizer?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        continuation?.resume()
        continuation = nil
        self.synthesizer = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        continuation?.resume()
        continuation = nil
        self.synthesizer = nil
    }
}

public enum SpeakActionError: LocalizedError {
    case missingText

    public var errorDescription: String? {
        switch self {
        case .missingText:
            return "SpeakAction: no text in config"
        }
    }
}
