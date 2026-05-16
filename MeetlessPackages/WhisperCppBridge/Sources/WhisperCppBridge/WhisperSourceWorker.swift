import Foundation
import whisper

actor WhisperSourceWorker {
    let source: RecordingSourceKind

    private let assets: WhisperBridgeAssets
    private var language: TranscriptionLanguage
    private var selectedModelURL: URL?
    private var contextHandle: WhisperContextHandle?
    private var loadedModelURL: URL?

    init(
        source: RecordingSourceKind,
        assets: WhisperBridgeAssets = WhisperBridgeAssets(),
        language: TranscriptionLanguage = .defaultLanguage
    ) {
        self.source = source
        self.assets = assets
        self.language = language
    }

    func setLanguage(_ language: TranscriptionLanguage) {
        self.language = language
    }

    func setModelURL(_ url: URL) {
        selectedModelURL = url
    }

    func prepareBundledModel() throws -> String {
        let modelURL = try assets.bundledModelURL()
        try prepareModel(at: modelURL)
        return modelURL.lastPathComponent
    }

    func prepareSelectedModel() throws -> String {
        let modelURL = try selectedModelURL ?? assets.bundledModelURL()
        try prepareModel(at: modelURL)
        return modelURL.lastPathComponent
    }

    private func prepareModel(at modelURL: URL) throws {
        if loadedModelURL == modelURL, contextHandle != nil {
            return
        }

        try loadModel(at: modelURL)
    }

    func transcribeBundledSmokeSample() async throws -> WhisperSmokeTranscription {
        let sampleURL = try assets.bundledSmokeSampleURL()
        return try await transcribeWaveFile(sampleURL)
    }

    func transcribeIncrementalWindow(samples: [Float]) async throws -> String {
        guard !samples.isEmpty else {
            throw WhisperBridgeError.emptyTranscription
        }

        _ = try prepareSelectedModel()
        let threadCount = preferredThreadCount()
        return try transcribe(samples: samples, threadCount: threadCount, language: language)
    }

    func unloadModel() {
        contextHandle = nil
        loadedModelURL = nil
    }

    private func transcribeWaveFile(_ url: URL) async throws -> WhisperSmokeTranscription {
        let modelName = try prepareSelectedModel()
        let samples = try decodePCM16WaveFile(url)
        let threadCount = preferredThreadCount()
        let text = try transcribe(samples: samples, threadCount: threadCount, language: language)

        return WhisperSmokeTranscription(
            source: source,
            modelName: modelName,
            sampleName: url.lastPathComponent,
            text: text,
            sampleCount: samples.count,
            threadCount: threadCount
        )
    }

    private func loadModel(at url: URL) throws {
        unloadModel()

        var params = whisper_context_default_params()
#if targetEnvironment(simulator)
        params.use_gpu = false
#else
        params.use_gpu = true
        params.flash_attn = true
#endif

        let context = url.path.withCString { whisper_init_from_file_with_params($0, params) }
        guard let context else {
            throw WhisperBridgeError.failedToInitializeModel(path: url.path)
        }

        contextHandle = WhisperContextHandle(opaquePointer: context)
        loadedModelURL = url
    }

    private func transcribe(
        samples: [Float],
        threadCount: Int,
        language: TranscriptionLanguage
    ) throws -> String {
        guard let contextHandle else {
            throw WhisperBridgeError.noLoadedModel(source: source)
        }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.n_threads = Int32(threadCount)
        params.offset_ms = 0
        params.no_context = true
        params.single_segment = false

        let text = try language.whisperCode.withCString { languageCode in
            params.language = languageCode
            whisper_reset_timings(contextHandle.opaquePointer)

            let result = samples.withUnsafeBufferPointer { buffer in
                whisper_full(contextHandle.opaquePointer, params, buffer.baseAddress, Int32(buffer.count))
            }

            guard result == 0 else {
                throw WhisperBridgeError.transcriptionFailed(code: result)
            }

            let segmentCount = whisper_full_n_segments(contextHandle.opaquePointer)
            var transcription = ""
            for index in 0..<segmentCount {
                transcription += String(cString: whisper_full_get_segment_text(contextHandle.opaquePointer, index))
            }

            return transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !text.isEmpty else {
            throw WhisperBridgeError.emptyTranscription
        }

        return text
    }

    private func preferredThreadCount() -> Int {
        max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
    }
}
