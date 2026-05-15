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
            transcriptionSettingsStore: transcriptionSettingsStore
        )
        self.recordingViewModel = RecordingViewModel(
            coordinator: recordingCoordinator
                ?? MeetlessRecordingCoordinator(
                    geminiAPIKeyStore: geminiAPIKeyStore,
                    openAIAPIKeyStore: openAIAPIKeyStore,
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
    var transcriptOutputLanguage: TranscriptOutputLanguage { get set }
    var transcriptTranslationProvider: TranscriptTranslationProvider { get set }
    func translationModel(for provider: TranscriptTranslationProvider) -> String
    func setTranslationModel(_ model: String, for provider: TranscriptTranslationProvider)
    func translationBaseURL(for provider: TranscriptTranslationProvider) -> URL
    func setTranslationBaseURL(_ baseURL: URL, for provider: TranscriptTranslationProvider)
}

final class UserDefaultsTranscriptionSettingsStore: TranscriptionSettingsStoring {
    private let userDefaults: UserDefaults
    private let languageKey: String
    private let outputLanguageKey: String
    private let providerKey: String

    init(
        userDefaults: UserDefaults = .standard,
        languageKey: String = "meetless.transcriptionLanguage",
        outputLanguageKey: String = "meetless.transcriptOutputLanguage",
        providerKey: String = "meetless.transcriptTranslationProvider"
    ) {
        self.userDefaults = userDefaults
        self.languageKey = languageKey
        self.outputLanguageKey = outputLanguageKey
        self.providerKey = providerKey
    }

    var transcriptionLanguage: TranscriptionLanguage {
        get {
            TranscriptionLanguage(storedValue: userDefaults.string(forKey: languageKey))
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: languageKey)
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
    @Published private(set) var feedbackMessage: String?
    @Published var transcriptionLanguage: TranscriptionLanguage {
        didSet {
            guard transcriptionLanguage != oldValue else { return }
            transcriptionSettingsStore.transcriptionLanguage = transcriptionLanguage
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

    private let apiKeyStore: any GeminiAPIKeyStoring
    private let openAIAPIKeyStore: any OpenAIAPIKeyStoring
    private let transcriptionSettingsStore: any TranscriptionSettingsStoring

    init(
        apiKeyStore: any GeminiAPIKeyStoring,
        openAIAPIKeyStore: any OpenAIAPIKeyStoring = KeychainOpenAIAPIKeyStore(),
        transcriptionSettingsStore: any TranscriptionSettingsStoring = UserDefaultsTranscriptionSettingsStore()
    ) {
        self.apiKeyStore = apiKeyStore
        self.openAIAPIKeyStore = openAIAPIKeyStore
        self.transcriptionSettingsStore = transcriptionSettingsStore
        self.transcriptionLanguage = transcriptionSettingsStore.transcriptionLanguage
        self.transcriptOutputLanguage = transcriptionSettingsStore.transcriptOutputLanguage
        let provider = transcriptionSettingsStore.transcriptTranslationProvider
        self.transcriptTranslationProvider = provider
        self.translationModel = transcriptionSettingsStore.translationModel(for: provider)
        self.translationBaseURL = transcriptionSettingsStore.translationBaseURL(for: provider).absoluteString
        refreshStatus()
    }

    var canSave: Bool {
        !apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSaveOpenAIAPIKey: Bool {
        !openAIAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isConfigured: Bool {
        keyStatus == .configured
    }

    var isOpenAIConfigured: Bool {
        openAIKeyStatus == .configured
    }

    func refreshStatus() {
        let storedLanguage = transcriptionSettingsStore.transcriptionLanguage
        if transcriptionLanguage != storedLanguage {
            transcriptionLanguage = storedLanguage
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
}
