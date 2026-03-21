import Foundation
import AVFoundation

/// Abstract base class for cloud TTS services (Google Cloud and Azure).
/// Handles text chunking, sequential chunk playback, stop/cancel logic,
/// and AVAudioPlayerDelegate. Subclasses implement only synthesiseChunk()
/// and maxChunkLength to provide the API-specific synthesis logic.
class BaseTTSService: NSObject, AVAudioPlayerDelegate, ObservableObject {

    // MARK: - Subclass interface (must override)

    /// Maximum characters per chunk. Override in each subclass.
    var maxChunkLength: Int { 4500 }

    /// Synthesise a single text chunk into raw MP3 audio data.
    /// Override in each subclass with the API-specific implementation.
    func synthesiseChunk(_ chunk: String, language: String, isFemale: Bool) async throws -> Data {
        fatalError("BaseTTSService subclasses must override synthesiseChunk(_:language:isFemale:)")
    }

    // MARK: - Shared state

    var player: AVAudioPlayer?
    var currentTask: Task<Void, Never>?
    var playbackContinuation: CheckedContinuation<Void, Never>?

    @Published private(set) var isSpeaking = false
    @Published private(set) var spokenCharacterCount: Int = 0
    var onSpeakingStarted: (() -> Void)?
    var onSpeakingCompleted: (() -> Void)?

    private var progressTimer: Timer?
    private var totalCharacters: Int = 0
    private var completedCharacters: Int = 0
    private var currentChunkLength: Int = 0
    private var hasReportedPlaybackStart = false

    // MARK: - Public API

    func speak(text: String, language: String = "en-US", isFemale: Bool = true, completion: (() -> Void)? = nil) {
        stop()
        let total = text.count
        Task { @MainActor in
            totalCharacters = total
            completedCharacters = 0
            currentChunkLength = 0
            hasReportedPlaybackStart = false
            spokenCharacterCount = 0
            isSpeaking = total > 0
        }
        currentTask = Task { [weak self] in
            await self?.speakChunks(text: text, language: language, isFemale: isFemale)
            await MainActor.run {
                guard let self else { return }
                self.stopProgressTimer()
                self.currentTask = nil
                self.completedCharacters = self.totalCharacters
                self.spokenCharacterCount = self.totalCharacters
                self.isSpeaking = false
                completion?()
                self.onSpeakingCompleted?()
            }
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        player?.stop()
        player = nil
        if let cont = playbackContinuation {
            playbackContinuation = nil
            cont.resume()
        }
        Task { @MainActor in
            stopProgressTimer()
            isSpeaking = false
        }
    }

    // MARK: - Shared implementation

    func splitIntoChunks(_ text: String) -> [String] {
        guard text.count > maxChunkLength else { return [text] }
        var chunks: [String] = []
        var remaining = text
        while remaining.count > maxChunkLength {
            let prefix = String(remaining.prefix(maxChunkLength))
            var splitAt = prefix.count
            if let idx = prefix.lastIndex(where: { ".!?\n".contains($0) }) {
                splitAt = prefix.distance(from: prefix.startIndex, to: idx) + 1
            }
            let splitIndex = remaining.index(remaining.startIndex, offsetBy: splitAt)
            chunks.append(String(remaining[..<splitIndex]).trimmingCharacters(in: .whitespaces))
            remaining = String(remaining[splitIndex...]).trimmingCharacters(in: .whitespaces)
        }
        if !remaining.isEmpty { chunks.append(remaining) }
        return chunks
    }

    func speakChunks(text: String, language: String, isFemale: Bool) async {
        let chunks = splitIntoChunks(text)
        for chunk in chunks {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                currentChunkLength = chunk.count
            }
            var data: Data?
            for attempt in 1...2 {
                if let d = try? await synthesiseChunk(chunk, language: language, isFemale: isFemale) {
                    data = d
                    break
                }
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                }
            }
            guard let audioData = data else { return }
            guard !Task.isCancelled else { return }
            await playAudioData(audioData)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                completedCharacters = min(completedCharacters + chunk.count, totalCharacters)
                spokenCharacterCount = completedCharacters
                currentChunkLength = 0
            }
        }
    }

    @MainActor
    func playAudioData(_ data: Data) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                                options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                let ap = try AVAudioPlayer(data: data)
                ap.delegate = self
                playbackContinuation = cont
                player = ap
                ap.play()
                if !self.hasReportedPlaybackStart {
                    self.hasReportedPlaybackStart = true
                    self.onSpeakingStarted?()
                }
                startProgressTimer()
            } catch {
                cont.resume()
            }
        }
    }

    @MainActor
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let player = self.player else { return }
            guard player.duration > 0 else { return }
            let ratio = min(max(player.currentTime / player.duration, 0), 1)
            let chunkChars = Int((Double(max(0, self.currentChunkLength)) * ratio).rounded(.down))
            let current = min(self.completedCharacters + chunkChars, self.totalCharacters)
            self.spokenCharacterCount = current
        }
        if let timer = progressTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @MainActor
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.stopProgressTimer()
            self?.player = nil
            let cont = self?.playbackContinuation
            self?.playbackContinuation = nil
            cont?.resume()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.stopProgressTimer()
            self?.player = nil
            let cont = self?.playbackContinuation
            self?.playbackContinuation = nil
            cont?.resume()
        }
    }
}
