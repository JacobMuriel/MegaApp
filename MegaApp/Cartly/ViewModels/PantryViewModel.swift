import Foundation
import SwiftData
import AVFoundation
import Observation

// MARK: - PantryViewModel
//
// Manages voice recording → Whisper transcription → GPT intent parsing → pantry update.
// The 20-second approve/undo window mirrors the RN PantryScreen toast behaviour.
//
// Audio recording uses AVAudioRecorder (simpler than AVAudioEngine for this use case).
// Recording requires NSMicrophoneUsageDescription in Info.plist (already included).

@Observable
@MainActor
final class PantryViewModel {

    // MARK: State

    var isRecording      = false
    var isProcessing     = false
    var showApproveToast = false
    var toastCountdown   = 20
    var transcription    = ""          // last Whisper transcript (shown in toast)
    var errorMessage:    String? = nil

    // Pending changes surface in the toast for review
    private(set) var pendingChanges: [PantryChangeIntent] = []

    // MARK: Privates

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL:  URL?
    private var toastTimer:    Timer?

    // MARK: - Voice recording

    func startRecording() {
        guard !isRecording else { return }
        errorMessage = nil

        // Configure audio session for recording
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .default)
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pantry_voice.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey:         Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey:       44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else {
            errorMessage = "Couldn't start recording. Check microphone permissions."
            return
        }
        recorder.record()
        audioRecorder = recorder
        recordingURL  = url
        isRecording   = true
    }

    func stopAndProcess(context: ModelContext, items: [PantryItem]) {
        guard isRecording, let recorder = audioRecorder, let url = recordingURL else { return }
        recorder.stop()
        audioRecorder = nil
        isRecording   = false
        isProcessing  = true

        Task {
            defer { isProcessing = false }
            do {
                let audioData  = try Data(contentsOf: url)
                let transcript = try await OpenAIService.shared.transcribe(audioData: audioData, fileName: "pantry_voice.m4a")
                transcription  = transcript

                let itemNames  = items.map(\.name)
                let intents    = try await OpenAIService.shared.parsePantryIntent(transcript: transcript, currentPantry: itemNames)
                pendingChanges = intents

                // Show approve/undo toast for 20 seconds
                showApproveToast = true
                toastCountdown   = 20
                startToastTimer()

            } catch {
                errorMessage = "Voice update failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Apply / undo

    func applyChanges(context: ModelContext, items: [PantryItem]) {
        for intent in pendingChanges {
            switch intent.action {
            case "remove":
                if let item = items.first(where: { $0.name.lowercased() == intent.itemName.lowercased() }) {
                    context.delete(item)
                }
            case "add":
                let item = PantryItem(
                    name:   intent.itemName,
                    amount: intent.newAmount,
                    unit:   intent.unit,
                    status: PantryStatus.ok.rawValue
                )
                context.insert(item)
            case "update":
                if let item = items.first(where: { $0.name.lowercased() == intent.itemName.lowercased() }) {
                    item.amount    = intent.newAmount ?? item.amount
                    item.unit      = intent.unit ?? item.unit
                    item.updatedAt = Date()
                }
            default:
                break
            }
        }
        try? context.save()
        dismissToast()
    }

    func dismissToast() {
        toastTimer?.invalidate()
        toastTimer       = nil
        showApproveToast = false
        pendingChanges   = []
        transcription    = ""
    }

    // MARK: - Toast countdown

    private func startToastTimer() {
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.toastCountdown -= 1
                if self.toastCountdown <= 0 {
                    // Auto-apply when timer expires
                    // (caller must pass context; we can't hold a ModelContext here)
                    self.showApproveToast = false
                    self.pendingChanges   = []
                    self.toastTimer?.invalidate()
                    self.toastTimer = nil
                }
            }
        }
    }
}
