import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var selectedScreen: AppScreen = .home
    @Published private(set) var selectedSessionID: String?
    @Published private(set) var selectedSessionDirectoryURL: URL?

    private let sessionRepository: SessionRepository
    private let geminiSessionNotesOrchestrator: any GeminiSessionNotesOrchestrating
    private var selectedSessionBundle: PersistedSessionBundle?

    let homeViewModel = HomeViewModel()
    let historyViewModel = HistoryViewModel()
    let sessionDetailViewModel = SessionDetailViewModel()
    let geminiSettingsViewModel: GeminiSettingsViewModel
    let recordingViewModel: RecordingViewModel

    init(
        sessionRepository: SessionRepository = SessionRepository(),
        recordingCoordinator: (any RecordingCoordinating)? = nil,
        geminiAPIKeyStore: any GeminiAPIKeyStoring = KeychainGeminiAPIKeyStore(),
        openAIAPIKeyStore: any OpenAIAPIKeyStoring = KeychainOpenAIAPIKeyStore(),
        googleTranslateAPIKeyStore: any GoogleTranslateAPIKeyStoring = KeychainGoogleTranslateAPIKeyStore(),
        transcriptionSettingsStore: any TranscriptionSettingsStoring = UserDefaultsTranscriptionSettingsStore(),
        geminiSessionNotesOrchestrator: (any GeminiSessionNotesOrchestrating)? = nil
    ) {
        self.sessionRepository = sessionRepository
        self.geminiSessionNotesOrchestrator = geminiSessionNotesOrchestrator
            ?? GeminiSessionNotesOrchestrator(
                apiKeyStore: geminiAPIKeyStore,
                sessionRepository: sessionRepository
        )
        self.geminiSettingsViewModel = GeminiSettingsViewModel(
            apiKeyStore: geminiAPIKeyStore,
            openAIAPIKeyStore: openAIAPIKeyStore,
            googleTranslateAPIKeyStore: googleTranslateAPIKeyStore,
            transcriptionSettingsStore: transcriptionSettingsStore,
            transcriptionModelLibrary: TranscriptionModelLibrary(bundle: .main)
        )
        self.recordingViewModel = RecordingViewModel(
            coordinator: recordingCoordinator
                ?? MeetlessRecordingCoordinator(
                    geminiAPIKeyStore: geminiAPIKeyStore,
                    openAIAPIKeyStore: openAIAPIKeyStore,
                    googleTranslateAPIKeyStore: googleTranslateAPIKeyStore,
                    transcriptionSettingsStore: transcriptionSettingsStore
                )
        )

        Task {
            await refreshSavedSessions()
            geminiSettingsViewModel.refreshStatus()
        }
    }

    func show(_ screen: AppScreen) {
        selectedScreen = screen

        switch screen {
        case .history:
            Task {
                await refreshSavedSessions()
            }
        case .sessionDetail:
            sessionDetailViewModel.updateGeminiConfiguration(geminiSettingsViewModel.isConfigured)
            if selectedSessionID == nil {
                sessionDetailViewModel.showNoSelection()
            }
        case .settings:
            geminiSettingsViewModel.refreshStatus()
        case .home:
            break
        }
    }

    func openSessionDetail(for row: HistoryViewModel.Row) {
        selectedSessionID = row.id
        selectedSessionDirectoryURL = row.directoryURL
        selectedSessionBundle = nil
        selectedScreen = .sessionDetail
        sessionDetailViewModel.showLoading(title: row.title)

        Task {
            await loadSessionDetail(sessionID: row.id, directoryURL: row.directoryURL)
        }
    }

    func deleteSession(_ row: HistoryViewModel.Row) {
        Task {
            await deleteSession(
                sessionID: row.id,
                directoryURL: row.directoryURL,
                title: row.title
            )
        }
    }

    func deleteSelectedSession() {
        guard let selectedSessionID, let selectedSessionDirectoryURL else {
            return
        }

        Task {
            await deleteSession(
                sessionID: selectedSessionID,
                directoryURL: selectedSessionDirectoryURL,
                title: sessionDetailViewModel.title
            )
        }
    }

    func generateNotesForSelectedSession() {
        guard let selectedSessionID, let selectedSessionDirectoryURL, let selectedSessionBundle else {
            sessionDetailViewModel.showGenerationFailure(SessionDetailViewModel.GenerateFailure.noSelectedSession)
            return
        }

        guard geminiSettingsViewModel.isConfigured else {
            sessionDetailViewModel.showGenerationFailure(SessionDetailViewModel.GenerateFailure.missingAPIKey)
            return
        }

        guard sessionDetailViewModel.canGenerateNotes else {
            return
        }

        sessionDetailViewModel.beginGeneratingNotes()

        Task {
            do {
                _ = try await geminiSessionNotesOrchestrator.generateNotes(for: selectedSessionBundle)
                guard self.selectedSessionID == selectedSessionID else {
                    return
                }

                await loadSessionDetail(
                    sessionID: selectedSessionID,
                    directoryURL: selectedSessionDirectoryURL
                )
            } catch {
                guard self.selectedSessionID == selectedSessionID else {
                    return
                }

                sessionDetailViewModel.showGenerationFailure(error)
            }
        }
    }

    func refreshSavedSessions() async {
        historyViewModel.showLoading()

        do {
            let sessions = try await sessionRepository.listSavedSessions()
            historyViewModel.showSessions(sessions)
        } catch {
            historyViewModel.showLoadFailure(error)
        }
    }

    private func loadSessionDetail(sessionID: String, directoryURL: URL) async {
        do {
            let detail = try await sessionRepository.loadSavedSessionDetail(at: directoryURL)
            guard selectedSessionID == sessionID else {
                return
            }

            selectedSessionBundle = PersistedSessionBundle(
                id: detail.id,
                directoryURL: detail.directoryURL,
                startedAt: detail.startedAt,
                title: detail.title
            )
            sessionDetailViewModel.showDetail(detail)
            sessionDetailViewModel.updateGeminiConfiguration(geminiSettingsViewModel.isConfigured)
        } catch {
            guard selectedSessionID == sessionID else {
                return
            }

            selectedSessionBundle = nil
            sessionDetailViewModel.showLoadFailure(title: nil, error: error)
        }
    }

    private func deleteSession(sessionID: String, directoryURL: URL, title: String) async {
        do {
            try await sessionRepository.deleteSavedSession(at: directoryURL)

            if selectedSessionID == sessionID {
                clearSelectedSession()
                selectedScreen = .history
            }

            await refreshSavedSessions()
        } catch {
            if selectedSessionID == sessionID && selectedScreen == .sessionDetail {
                sessionDetailViewModel.showDeleteFailure(title: title, error: error)
            } else {
                historyViewModel.showDeleteFailure(title: title, error: error)
            }
        }
    }

    private func clearSelectedSession() {
        selectedSessionID = nil
        selectedSessionDirectoryURL = nil
        selectedSessionBundle = nil
        sessionDetailViewModel.showNoSelection()
    }
}

protocol TranscriptionSettingsStoring: AnyObject {
    var transcriptionLanguage: TranscriptionLanguage { get set }
    var transcriptionModelID: String { get set }
    var transcriptOutputLanguage: TranscriptOutputLanguage { get set }
    var transcriptTranslationProvider: TranscriptTranslationProvider { get set }
    var transcriptTranslationDomain: TranscriptTranslationDomain { get set }
    func translationModel(for provider: TranscriptTranslationProvider) -> String
    func setTranslationModel(_ model: String, for provider: TranscriptTranslationProvider)
    func translationBaseURL(for provider: TranscriptTranslationProvider) -> URL
    func setTranslationBaseURL(_ baseURL: URL, for provider: TranscriptTranslationProvider)
}

final class UserDefaultsTranscriptionSettingsStore: TranscriptionSettingsStoring {
    private let userDefaults: UserDefaults
    private let languageKey: String
    private let transcriptionModelKey: String
    private let outputLanguageKey: String
    private let providerKey: String
    private let translationDomainKey: String

    init(
        userDefaults: UserDefaults = .standard,
        languageKey: String = "meetless.transcriptionLanguage",
        transcriptionModelKey: String = "meetless.transcriptionModelID",
        outputLanguageKey: String = "meetless.transcriptOutputLanguage",
        providerKey: String = "meetless.transcriptTranslationProvider",
        translationDomainKey: String = "meetless.transcriptTranslation.domain"
    ) {
        self.userDefaults = userDefaults
        self.languageKey = languageKey
        self.transcriptionModelKey = transcriptionModelKey
        self.outputLanguageKey = outputLanguageKey
        self.providerKey = providerKey
        self.translationDomainKey = translationDomainKey
    }

    var transcriptionLanguage: TranscriptionLanguage {
        get {
            TranscriptionLanguage(storedValue: userDefaults.string(forKey: languageKey))
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: languageKey)
        }
    }

    var transcriptionModelID: String {
        get {
            TranscriptionModelPreset(storedValue: userDefaults.string(forKey: transcriptionModelKey)).id
        }
        set {
            let preset = TranscriptionModelPreset(storedValue: newValue)
            userDefaults.set(preset.id, forKey: transcriptionModelKey)
        }
    }

    var transcriptOutputLanguage: TranscriptOutputLanguage {
        get {
            TranscriptOutputLanguage(storedValue: userDefaults.string(forKey: outputLanguageKey))
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: outputLanguageKey)
        }
    }

    var transcriptTranslationProvider: TranscriptTranslationProvider {
        get {
            TranscriptTranslationProvider(storedValue: userDefaults.string(forKey: providerKey))
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: providerKey)
        }
    }

    var transcriptTranslationDomain: TranscriptTranslationDomain {
        get {
            TranscriptTranslationDomain(storedValue: userDefaults.string(forKey: translationDomainKey))
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: translationDomainKey)
        }
    }

    func translationModel(for provider: TranscriptTranslationProvider) -> String {
        let storedModel = userDefaults.string(forKey: modelKey(for: provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let storedModel, !storedModel.isEmpty else {
            return provider.defaultModel
        }

        return storedModel
    }

    func setTranslationModel(_ model: String, for provider: TranscriptTranslationProvider) {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        userDefaults.set(
            trimmedModel.isEmpty ? provider.defaultModel : trimmedModel,
            forKey: modelKey(for: provider)
        )
    }

    func translationBaseURL(for provider: TranscriptTranslationProvider) -> URL {
        guard
            let storedValue = userDefaults.string(forKey: baseURLKey(for: provider))?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !storedValue.isEmpty,
            let url = URL(string: storedValue),
            url.scheme != nil,
            url.host != nil
        else {
            return provider.defaultBaseURL
        }

        return url
    }

    func setTranslationBaseURL(_ baseURL: URL, for provider: TranscriptTranslationProvider) {
        userDefaults.set(baseURL.absoluteString, forKey: baseURLKey(for: provider))
    }

    private func modelKey(for provider: TranscriptTranslationProvider) -> String {
        "meetless.transcriptTranslation.\(provider.rawValue).model"
    }

    private func baseURLKey(for provider: TranscriptTranslationProvider) -> String {
        "meetless.transcriptTranslation.\(provider.rawValue).baseURL"
    }
}

struct TranscriptionModelPreset: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let qualityLabel: String
    let diskSizeLabel: String
    let resourceLabel: String
    let languageLabel: String
    let recommendation: String
    let filename: String
    let isBundled: Bool
    let downloadURL: URL?

    static let defaultID = "base"
    static let baseDownloadURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main")!

    static let allPresets: [TranscriptionModelPreset] = [
        make(
            "tiny",
            displayName: "Tiny",
            qualityLabel: "Fastest",
            diskSizeLabel: "75 MiB",
            resourceLabel: "Very low",
            languageLabel: "Multilingual",
            recommendation: "Quick checks and low-resource machines."
        ),
        make(
            "tiny.en",
            displayName: "Tiny English",
            qualityLabel: "Fastest English-only",
            diskSizeLabel: "75 MiB",
            resourceLabel: "Very low",
            languageLabel: "English only",
            recommendation: "Fast English notes where accuracy is less critical."
        ),
        make(
            "base",
            displayName: "Base",
            qualityLabel: "Balanced default",
            diskSizeLabel: "142 MiB",
            resourceLabel: "Low",
            languageLabel: "Multilingual",
            recommendation: "Default local model for mixed languages and meetings.",
            isBundled: true
        ),
        make(
            "base.en",
            displayName: "Base English",
            qualityLabel: "Balanced English-only",
            diskSizeLabel: "142 MiB",
            resourceLabel: "Low",
            languageLabel: "English only",
            recommendation: "English meetings with better speed than larger models."
        ),
        make(
            "small",
            displayName: "Small",
            qualityLabel: "Higher accuracy",
            diskSizeLabel: "466 MiB",
            resourceLabel: "Medium",
            languageLabel: "Multilingual",
            recommendation: "Better accuracy while staying practical on most Macs."
        ),
        make(
            "small.en",
            displayName: "Small English",
            qualityLabel: "Higher accuracy English-only",
            diskSizeLabel: "466 MiB",
            resourceLabel: "Medium",
            languageLabel: "English only",
            recommendation: "English-heavy meetings with clearer transcripts."
        ),
        make(
            "medium",
            displayName: "Medium",
            qualityLabel: "High accuracy",
            diskSizeLabel: "1.5 GiB",
            resourceLabel: "High",
            languageLabel: "Multilingual",
            recommendation: "Accuracy-focused multilingual recordings on stronger Macs."
        ),
        make(
            "medium.en",
            displayName: "Medium English",
            qualityLabel: "High accuracy English-only",
            diskSizeLabel: "1.5 GiB",
            resourceLabel: "High",
            languageLabel: "English only",
            recommendation: "Accuracy-focused English recordings on stronger Macs."
        ),
        make(
            "large-v3-turbo",
            displayName: "Large v3 Turbo",
            qualityLabel: "Best multilingual speed",
            diskSizeLabel: "1.5 GiB",
            resourceLabel: "High",
            languageLabel: "Multilingual",
            recommendation: "Best quality-speed balance when the machine can spare resources."
        ),
        make(
            "large-v3-turbo-q5_0",
            displayName: "Large v3 Turbo Q5",
            qualityLabel: "Smaller large model",
            diskSizeLabel: "547 MiB",
            resourceLabel: "Medium-high",
            languageLabel: "Multilingual, quantized",
            recommendation: "Large-model quality with lower storage and memory pressure."
        )
    ]

    static var defaultPreset: TranscriptionModelPreset {
        preset(id: defaultID) ?? allPresets[0]
    }

    init(
        id: String,
        displayName: String,
        qualityLabel: String,
        diskSizeLabel: String,
        resourceLabel: String,
        languageLabel: String,
        recommendation: String,
        filename: String,
        isBundled: Bool,
        downloadURL: URL?
    ) {
        self.id = id
        self.displayName = displayName
        self.qualityLabel = qualityLabel
        self.diskSizeLabel = diskSizeLabel
        self.resourceLabel = resourceLabel
        self.languageLabel = languageLabel
        self.recommendation = recommendation
        self.filename = filename
        self.isBundled = isBundled
        self.downloadURL = downloadURL
    }

    init(storedValue: String?) {
        self = storedValue.flatMap(Self.preset(id:)) ?? Self.defaultPreset
    }

    static func preset(id: String) -> TranscriptionModelPreset? {
        allPresets.first { $0.id == id }
    }

    private static func make(
        _ id: String,
        displayName: String,
        qualityLabel: String,
        diskSizeLabel: String,
        resourceLabel: String,
        languageLabel: String,
        recommendation: String,
        isBundled: Bool = false
    ) -> TranscriptionModelPreset {
        let filename = "ggml-\(id).bin"
        return TranscriptionModelPreset(
            id: id,
            displayName: displayName,
            qualityLabel: qualityLabel,
            diskSizeLabel: diskSizeLabel,
            resourceLabel: resourceLabel,
            languageLabel: languageLabel,
            recommendation: recommendation,
            filename: filename,
            isBundled: isBundled,
            downloadURL: isBundled ? nil : baseDownloadURL.appendingPathComponent(filename, isDirectory: false)
        )
    }
}

struct TranscriptionModelStatus: Identifiable, Equatable {
    enum Availability: Equatable {
        case bundled
        case installed
        case missing
        case downloading(Double)
        case failed(String)
    }

    let preset: TranscriptionModelPreset
    let availability: Availability
    let isSelected: Bool

    var id: String { preset.id }

    var canSelect: Bool {
        switch availability {
        case .bundled, .installed:
            return true
        case .missing, .downloading, .failed:
            return false
        }
    }

    var canDownload: Bool {
        switch availability {
        case .missing, .failed:
            return !preset.isBundled
        case .bundled, .installed, .downloading:
            return false
        }
    }

    var canRemove: Bool {
        !preset.isBundled && availability == .installed
    }

    var statusText: String {
        switch availability {
        case .bundled:
            return "Bundled"
        case .installed:
            return "Installed"
        case .missing:
            return "Not downloaded"
        case .downloading(let progress):
            return "Downloading \(Int(progress * 100))%"
        case .failed:
            return "Download failed"
        }
    }
}

protocol TranscriptionModelDownloading: AnyObject {
    func download(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws
}

final class URLSessionTranscriptionModelDownloader: NSObject, TranscriptionModelDownloading, URLSessionDownloadDelegate, @unchecked Sendable {
    private final class DownloadState: @unchecked Sendable {
        let destinationURL: URL
        let progressHandler: @Sendable (Double) -> Void
        var continuation: CheckedContinuation<Void, Error>?
        var didMoveDownloadedFile = false

        init(
            destinationURL: URL,
            progressHandler: @escaping @Sendable (Double) -> Void,
            continuation: CheckedContinuation<Void, Error>
        ) {
            self.destinationURL = destinationURL
            self.progressHandler = progressHandler
            self.continuation = continuation
        }
    }

    private final class DownloadTaskBox: @unchecked Sendable {
        private let lock = NSLock()
        private var task: URLSessionDownloadTask?

        func set(_ task: URLSessionDownloadTask) {
            lock.withLock {
                self.task = task
            }
        }

        func cancel() {
            lock.withLock {
                task?.cancel()
            }
        }
    }

    private let lock = NSLock()
    private var statesByTaskID: [Int: DownloadState] = [:]

    func download(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        let downloadTaskBox = DownloadTaskBox()
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let task = session.downloadTask(with: sourceURL)
                let state = DownloadState(
                    destinationURL: destinationURL,
                    progressHandler: progressHandler,
                    continuation: continuation
                )
                lock.withLock {
                    statesByTaskID[task.taskIdentifier] = state
                }
                downloadTaskBox.set(task)
                task.resume()
            }
        } onCancel: {
            downloadTaskBox.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        lock.withLock {
            statesByTaskID[downloadTask.taskIdentifier]
        }?.progressHandler(progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let state = lock.withLock {
            statesByTaskID[downloadTask.taskIdentifier]
        }

        guard let state else { return }

        do {
            let fileManager = FileManager.default
            let destinationDirectory = state.destinationURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

            let temporaryDestination = state.destinationURL
                .deletingLastPathComponent()
                .appendingPathComponent(".\(state.destinationURL.lastPathComponent).download", isDirectory: false)
            if fileManager.fileExists(atPath: temporaryDestination.path) {
                try fileManager.removeItem(at: temporaryDestination)
            }
            try fileManager.moveItem(at: location, to: temporaryDestination)

            let attributes = try fileManager.attributesOfItem(atPath: temporaryDestination.path)
            let fileSize = attributes[.size] as? NSNumber
            guard fileSize?.int64Value ?? 0 > 0 else {
                try? fileManager.removeItem(at: temporaryDestination)
                throw CocoaError(.fileWriteUnknown)
            }

            if fileManager.fileExists(atPath: state.destinationURL.path) {
                try fileManager.removeItem(at: state.destinationURL)
            }
            try fileManager.moveItem(at: temporaryDestination, to: state.destinationURL)
            state.didMoveDownloadedFile = true
            state.progressHandler(1)
        } catch {
            state.continuation?.resume(throwing: error)
            state.continuation = nil
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let state = lock.withLock {
            statesByTaskID.removeValue(forKey: task.taskIdentifier)
        }

        guard let state, let continuation = state.continuation else { return }

        if let error {
            continuation.resume(throwing: error)
        } else if state.didMoveDownloadedFile {
            continuation.resume()
        } else {
            continuation.resume(throwing: CocoaError(.fileWriteUnknown))
        }
    }
}

final class TranscriptionModelLibrary {
    private let bundle: Bundle
    private let fileManager: FileManager
    private let modelsDirectoryOverride: URL?
    private let downloader: any TranscriptionModelDownloading

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        modelsDirectoryURL: URL? = nil,
        downloader: any TranscriptionModelDownloading = URLSessionTranscriptionModelDownloader()
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        self.modelsDirectoryOverride = modelsDirectoryURL
        self.downloader = downloader
    }

    func statuses(
        selectedModelID: String,
        downloadingProgress: [String: Double],
        failures: [String: String]
    ) -> [TranscriptionModelStatus] {
        TranscriptionModelPreset.allPresets.map { preset in
            let availability: TranscriptionModelStatus.Availability
            if let progress = downloadingProgress[preset.id] {
                availability = .downloading(progress)
            } else if let failure = failures[preset.id] {
                availability = .failed(failure)
            } else if preset.isBundled {
                availability = .bundled
            } else if isInstalled(preset) {
                availability = .installed
            } else {
                availability = .missing
            }

            return TranscriptionModelStatus(
                preset: preset,
                availability: availability,
                isSelected: preset.id == selectedModelID
            )
        }
    }

    func resolveModelURL(for modelID: String) throws -> URL {
        let selectedPreset = TranscriptionModelPreset(storedValue: modelID)

        if selectedPreset.isBundled {
            return try bundledModelURL()
        }

        let installedURL = localModelURL(for: selectedPreset)
        if fileManager.fileExists(atPath: installedURL.path) {
            return installedURL
        }

        return try bundledModelURL()
    }

    func isInstalled(_ preset: TranscriptionModelPreset) -> Bool {
        preset.isBundled || fileManager.fileExists(atPath: localModelURL(for: preset).path)
    }

    func download(
        _ preset: TranscriptionModelPreset,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let downloadURL = preset.downloadURL else { return }
        try await downloader.download(
            from: downloadURL,
            to: localModelURL(for: preset),
            progressHandler: progressHandler
        )
    }

    func remove(_ preset: TranscriptionModelPreset) throws {
        guard !preset.isBundled else { return }
        let modelURL = localModelURL(for: preset)
        if fileManager.fileExists(atPath: modelURL.path) {
            try fileManager.removeItem(at: modelURL)
        }
    }

    func localModelURL(for preset: TranscriptionModelPreset) -> URL {
        modelsDirectoryURL().appendingPathComponent(preset.filename, isDirectory: false)
    }

    private func bundledModelURL() throws -> URL {
        guard let url = bundle.url(forResource: "ggml-base", withExtension: "bin") else {
            throw WhisperBridgeError.missingBundledResource(name: "ggml-base", ext: "bin")
        }
        return url
    }

    private func modelsDirectoryURL() -> URL {
        if let modelsDirectoryOverride {
            return modelsDirectoryOverride
        }

        let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return applicationSupportURL
            .appendingPathComponent("Meetless", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }
}

@MainActor
final class GeminiSettingsViewModel: ObservableObject {
    enum KeyStatus: Equatable {
        case unknown
        case configured
        case notConfigured
        case error(String)

        var title: String {
            switch self {
            case .unknown:
                return "Checking"
            case .configured:
                return "Configured"
            case .notConfigured:
                return "Not configured"
            case .error:
                return "Needs attention"
            }
        }

        var detail: String {
            switch self {
            case .unknown:
                return "Checking the saved Gemini key."
            case .configured:
                return "A Gemini API key is saved in Keychain."
            case .notConfigured:
                return "Add a Gemini API key before generating session notes."
            case .error(let message):
                return message
            }
        }
    }

    @Published private(set) var keyStatus: KeyStatus = .unknown
    @Published private(set) var openAIKeyStatus: KeyStatus = .unknown
    @Published private(set) var googleTranslateKeyStatus: KeyStatus = .unknown
    @Published private(set) var feedbackMessage: String?
    @Published private(set) var transcriptionModelStatuses: [TranscriptionModelStatus] = []
    @Published var transcriptionLanguage: TranscriptionLanguage {
        didSet {
            guard transcriptionLanguage != oldValue else { return }
            transcriptionSettingsStore.transcriptionLanguage = transcriptionLanguage
        }
    }
    @Published var transcriptionModelID: String {
        didSet {
            guard transcriptionModelID != oldValue else { return }
            let preset = TranscriptionModelPreset(storedValue: transcriptionModelID)
            guard transcriptionModelLibrary.isInstalled(preset) else {
                transcriptionModelID = oldValue
                return
            }
            transcriptionSettingsStore.transcriptionModelID = preset.id
            refreshTranscriptionModelStatuses()
        }
    }
    @Published var transcriptOutputLanguage: TranscriptOutputLanguage {
        didSet {
            guard transcriptOutputLanguage != oldValue else { return }
            transcriptionSettingsStore.transcriptOutputLanguage = transcriptOutputLanguage
        }
    }
    @Published var transcriptTranslationProvider: TranscriptTranslationProvider {
        didSet {
            guard transcriptTranslationProvider != oldValue else { return }
            transcriptionSettingsStore.transcriptTranslationProvider = transcriptTranslationProvider
            loadProviderPreset()
        }
    }
    @Published var transcriptTranslationDomain: TranscriptTranslationDomain {
        didSet {
            guard transcriptTranslationDomain != oldValue else { return }
            transcriptionSettingsStore.transcriptTranslationDomain = transcriptTranslationDomain
        }
    }
    @Published var translationModel: String {
        didSet {
            guard translationModel != oldValue else { return }
            transcriptionSettingsStore.setTranslationModel(translationModel, for: transcriptTranslationProvider)
        }
    }
    @Published var translationBaseURL: String {
        didSet {
            guard translationBaseURL != oldValue else { return }
            guard let url = Self.normalizedBaseURL(from: translationBaseURL) else { return }
            transcriptionSettingsStore.setTranslationBaseURL(url, for: transcriptTranslationProvider)
        }
    }
    @Published var apiKeyInput = ""
    @Published var openAIAPIKeyInput = ""
    @Published var googleTranslateAPIKeyInput = ""

    private let apiKeyStore: any GeminiAPIKeyStoring
    private let openAIAPIKeyStore: any OpenAIAPIKeyStoring
    private let googleTranslateAPIKeyStore: any GoogleTranslateAPIKeyStoring
    private let transcriptionSettingsStore: any TranscriptionSettingsStoring
    private let transcriptionModelLibrary: TranscriptionModelLibrary
    private var modelDownloadProgress: [String: Double] = [:]
    private var modelDownloadFailures: [String: String] = [:]
    private var modelDownloadTasks: [String: Task<Void, Never>] = [:]

    init(
        apiKeyStore: any GeminiAPIKeyStoring,
        openAIAPIKeyStore: any OpenAIAPIKeyStoring = KeychainOpenAIAPIKeyStore(),
        googleTranslateAPIKeyStore: any GoogleTranslateAPIKeyStoring = KeychainGoogleTranslateAPIKeyStore(),
        transcriptionSettingsStore: any TranscriptionSettingsStoring = UserDefaultsTranscriptionSettingsStore(),
        transcriptionModelLibrary: TranscriptionModelLibrary = TranscriptionModelLibrary()
    ) {
        self.apiKeyStore = apiKeyStore
        self.openAIAPIKeyStore = openAIAPIKeyStore
        self.googleTranslateAPIKeyStore = googleTranslateAPIKeyStore
        self.transcriptionSettingsStore = transcriptionSettingsStore
        self.transcriptionModelLibrary = transcriptionModelLibrary
        self.transcriptionLanguage = transcriptionSettingsStore.transcriptionLanguage
        self.transcriptionModelID = transcriptionSettingsStore.transcriptionModelID
        self.transcriptOutputLanguage = transcriptionSettingsStore.transcriptOutputLanguage
        let provider = transcriptionSettingsStore.transcriptTranslationProvider
        self.transcriptTranslationProvider = provider
        self.transcriptTranslationDomain = transcriptionSettingsStore.transcriptTranslationDomain
        self.translationModel = transcriptionSettingsStore.translationModel(for: provider)
        self.translationBaseURL = transcriptionSettingsStore.translationBaseURL(for: provider).absoluteString
        refreshTranscriptionModelStatuses()
        refreshStatus()
    }

    var canSave: Bool {
        !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSaveOpenAIAPIKey: Bool {
        !openAIAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSaveGoogleTranslateAPIKey: Bool {
        !googleTranslateAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isConfigured: Bool {
        keyStatus == .configured
    }

    var isOpenAIConfigured: Bool {
        openAIKeyStatus == .configured
    }

    var isGoogleTranslateConfigured: Bool {
        googleTranslateKeyStatus == .configured
    }

    var selectedProviderUsesLLMPromptContext: Bool {
        transcriptTranslationProvider.usesLLMPromptContext
    }

    var translationPromptPreview: String {
        TranscriptTranslationService.previewPrompt(
            context: TranscriptTranslationContext(domain: transcriptTranslationDomain)
        )
    }

    var translationModelPresets: [TranscriptTranslationModelPreset] {
        transcriptTranslationProvider.modelPresets
    }

    var selectedTranslationModelPresetID: String {
        let normalizedModel = translationModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return translationModelPresets.first { $0.id == normalizedModel }?.id ?? Self.customTranslationModelPresetID
    }

    static let customTranslationModelPresetID = "custom"

    func refreshStatus() {
        let storedLanguage = transcriptionSettingsStore.transcriptionLanguage
        if transcriptionLanguage != storedLanguage {
            transcriptionLanguage = storedLanguage
        }
        let storedModelID = transcriptionSettingsStore.transcriptionModelID
        if transcriptionModelID != storedModelID {
            transcriptionModelID = storedModelID
        } else {
            refreshTranscriptionModelStatuses()
        }
        let storedOutputLanguage = transcriptionSettingsStore.transcriptOutputLanguage
        if transcriptOutputLanguage != storedOutputLanguage {
            transcriptOutputLanguage = storedOutputLanguage
        }
        let storedProvider = transcriptionSettingsStore.transcriptTranslationProvider
        if transcriptTranslationProvider != storedProvider {
            transcriptTranslationProvider = storedProvider
        } else {
            loadProviderPreset()
        }
        let storedDomain = transcriptionSettingsStore.transcriptTranslationDomain
        if transcriptTranslationDomain != storedDomain {
            transcriptTranslationDomain = storedDomain
        }

        do {
            let savedKey = try apiKeyStore.loadAPIKey()
            keyStatus = savedKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? .configured
                : .notConfigured
        } catch {
            keyStatus = .error(Self.safeMessage(for: error))
        }

        do {
            let savedKey = try openAIAPIKeyStore.loadAPIKey()
            openAIKeyStatus = savedKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? .configured
                : .notConfigured
        } catch {
            openAIKeyStatus = .error(Self.safeOpenAIMessage(for: error))
        }

        do {
            let savedKey = try googleTranslateAPIKeyStore.loadAPIKey()
            googleTranslateKeyStatus = savedKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? .configured
                : .notConfigured
        } catch {
            googleTranslateKeyStatus = .error(Self.safeGoogleTranslateMessage(for: error))
        }
    }

    func selectTranscriptionModel(_ modelID: String) {
        let preset = TranscriptionModelPreset(storedValue: modelID)
        guard transcriptionModelLibrary.isInstalled(preset) else { return }
        transcriptionModelID = preset.id
    }

    func selectTranslationModelPreset(_ presetID: String) {
        guard presetID != Self.customTranslationModelPresetID else { return }
        guard let preset = translationModelPresets.first(where: { $0.id == presetID }) else { return }
        translationModel = preset.id
    }

    func downloadTranscriptionModel(_ modelID: String) {
        let preset = TranscriptionModelPreset(storedValue: modelID)
        guard preset.downloadURL != nil, modelDownloadTasks[preset.id] == nil else { return }

        modelDownloadFailures[preset.id] = nil
        modelDownloadProgress[preset.id] = 0
        refreshTranscriptionModelStatuses()

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                try await transcriptionModelLibrary.download(preset) { progress in
                    Task { @MainActor [weak self] in
                        self?.modelDownloadProgress[preset.id] = progress
                        self?.refreshTranscriptionModelStatuses()
                    }
                }
                modelDownloadProgress[preset.id] = nil
                modelDownloadFailures[preset.id] = nil
                modelDownloadTasks[preset.id] = nil
                transcriptionModelID = preset.id
                feedbackMessage = "\(preset.displayName) transcription model downloaded."
            } catch is CancellationError {
                modelDownloadProgress[preset.id] = nil
                modelDownloadTasks[preset.id] = nil
            } catch {
                modelDownloadProgress[preset.id] = nil
                modelDownloadTasks[preset.id] = nil
                modelDownloadFailures[preset.id] = "Try downloading \(preset.displayName) again."
                feedbackMessage = "The \(preset.displayName) model could not be downloaded."
            }
            refreshTranscriptionModelStatuses()
        }

        modelDownloadTasks[preset.id] = task
    }

    func cancelTranscriptionModelDownload(_ modelID: String) {
        modelDownloadTasks[modelID]?.cancel()
        modelDownloadTasks[modelID] = nil
        modelDownloadProgress[modelID] = nil
        refreshTranscriptionModelStatuses()
    }

    func removeTranscriptionModel(_ modelID: String) {
        let preset = TranscriptionModelPreset(storedValue: modelID)
        do {
            try transcriptionModelLibrary.remove(preset)
            modelDownloadFailures[preset.id] = nil
            if transcriptionModelID == preset.id {
                transcriptionModelID = TranscriptionModelPreset.defaultID
                transcriptionSettingsStore.transcriptionModelID = TranscriptionModelPreset.defaultID
            }
            feedbackMessage = "\(preset.displayName) transcription model removed."
        } catch {
            feedbackMessage = "The \(preset.displayName) model could not be removed."
        }
        refreshTranscriptionModelStatuses()
    }

    func saveAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            feedbackMessage = "Enter a Gemini API key before saving."
            return
        }

        do {
            try apiKeyStore.saveAPIKey(trimmedKey)
            apiKeyInput = ""
            keyStatus = .configured
            feedbackMessage = "Gemini API key saved."
        } catch {
            keyStatus = .error(Self.safeMessage(for: error))
            feedbackMessage = "The Gemini API key could not be saved."
        }
    }

    func deleteAPIKey() {
        do {
            try apiKeyStore.deleteAPIKey()
            apiKeyInput = ""
            keyStatus = .notConfigured
            feedbackMessage = "Gemini API key removed."
        } catch {
            keyStatus = .error(Self.safeMessage(for: error))
            feedbackMessage = "The Gemini API key could not be removed."
        }
    }

    func saveOpenAIAPIKey() {
        let trimmedKey = openAIAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            feedbackMessage = "Enter an OpenAI API key before saving."
            return
        }

        do {
            try openAIAPIKeyStore.saveAPIKey(trimmedKey)
            openAIAPIKeyInput = ""
            openAIKeyStatus = .configured
            feedbackMessage = "OpenAI API key saved."
        } catch {
            openAIKeyStatus = .error(Self.safeOpenAIMessage(for: error))
            feedbackMessage = "The OpenAI API key could not be saved."
        }
    }

    func deleteOpenAIAPIKey() {
        do {
            try openAIAPIKeyStore.deleteAPIKey()
            openAIAPIKeyInput = ""
            openAIKeyStatus = .notConfigured
            feedbackMessage = "OpenAI API key removed."
        } catch {
            openAIKeyStatus = .error(Self.safeOpenAIMessage(for: error))
            feedbackMessage = "The OpenAI API key could not be removed."
        }
    }

    func saveGoogleTranslateAPIKey() {
        let trimmedKey = googleTranslateAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            feedbackMessage = "Enter a Google Translate API key before saving."
            return
        }

        do {
            try googleTranslateAPIKeyStore.saveAPIKey(trimmedKey)
            googleTranslateAPIKeyInput = ""
            googleTranslateKeyStatus = .configured
            feedbackMessage = "Google Translate API key saved."
        } catch {
            googleTranslateKeyStatus = .error(Self.safeGoogleTranslateMessage(for: error))
            feedbackMessage = "The Google Translate API key could not be saved."
        }
    }

    func deleteGoogleTranslateAPIKey() {
        do {
            try googleTranslateAPIKeyStore.deleteAPIKey()
            googleTranslateAPIKeyInput = ""
            googleTranslateKeyStatus = .notConfigured
            feedbackMessage = "Google Translate API key removed."
        } catch {
            googleTranslateKeyStatus = .error(Self.safeGoogleTranslateMessage(for: error))
            feedbackMessage = "The Google Translate API key could not be removed."
        }
    }

    private func refreshTranscriptionModelStatuses() {
        transcriptionModelStatuses = transcriptionModelLibrary.statuses(
            selectedModelID: transcriptionModelID,
            downloadingProgress: modelDownloadProgress,
            failures: modelDownloadFailures
        )
    }

    private func loadProviderPreset() {
        let model = transcriptionSettingsStore.translationModel(for: transcriptTranslationProvider)
        if translationModel != model {
            translationModel = model
        }

        let baseURL = transcriptionSettingsStore.translationBaseURL(for: transcriptTranslationProvider).absoluteString
        if translationBaseURL != baseURL {
            translationBaseURL = baseURL
        }
    }

    private static func normalizedBaseURL(from value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedValue.isEmpty,
            let url = URL(string: trimmedValue),
            url.scheme != nil,
            url.host != nil
        else {
            return nil
        }

        return url
    }

    private static func safeMessage(for error: Error) -> String {
        if let storeError = error as? GeminiAPIKeyStoreError {
            switch storeError {
            case .invalidStoredData:
                return "The saved Gemini key could not be read. Remove it and save a new key."
            case .keychainFailure:
                return "Keychain could not complete the request. Check macOS access and try again."
            }
        }

        return "Gemini key settings could not be updated. Try again."
    }

    private static func safeOpenAIMessage(for error: Error) -> String {
        if let storeError = error as? GeminiAPIKeyStoreError {
            switch storeError {
            case .invalidStoredData:
                return "The saved OpenAI key could not be read. Remove it and save a new key."
            case .keychainFailure:
                return "Keychain could not complete the request. Check macOS access and try again."
            }
        }

        return "OpenAI key settings could not be updated. Try again."
    }

    private static func safeGoogleTranslateMessage(for error: Error) -> String {
        if let storeError = error as? GeminiAPIKeyStoreError {
            switch storeError {
            case .invalidStoredData:
                return "The saved Google Translate key could not be read. Remove it and save a new key."
            case .keychainFailure:
                return "Keychain could not complete the request. Check macOS access and try again."
            }
        }

        return "Google Translate key settings could not be updated. Try again."
    }
}
