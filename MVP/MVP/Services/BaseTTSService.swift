import Foundation
import AVFoundation

/// Abstract base class for cloud TTS services (Google Cloud and Azure).
/// Handles text chunking, sequential chunk playback, stop/cancel logic,
/// and AVAudioPlayerDelegate. Subclasses implement only synthesiseChunk()
/// and maxChunkLength to provide the API-specific synthesis logic.
class BaseTTSService: NSObject, AVAudioPlayerDelegate {

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

    var isSpeaking: Bool { player?.isPlaying == true }

    // MARK: - Public API

    func speak(text: String, language: String = "en-US", isFemale: Bool = true, completion: (() -> Void)? = nil) {
        stop()
        currentTask = Task { [weak self] in
            await self?.speakChunks(text: text, language: language, isFemale: isFemale)
            await MainActor.run { completion?() }
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
            } catch {
                cont.resume()
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.player = nil
            let cont = self?.playbackContinuation
            self?.playbackContinuation = nil
            cont?.resume()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.player = nil
            let cont = self?.playbackContinuation
            self?.playbackContinuation = nil
            cont?.resume()
        }
    }
}
