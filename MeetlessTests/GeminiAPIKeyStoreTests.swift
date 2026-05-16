import Security
import XCTest
@testable import Meetless

final class GeminiAPIKeyStoreTests: XCTestCase {
    func testTranscriptionSettingsDefaultLanguageIsEnglish() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        XCTAssertEqual(store.transcriptionLanguage, .english)
        XCTAssertEqual(store.transcriptionLanguage.whisperCode, "en")
        XCTAssertEqual(store.transcriptionModelID, "base")
        XCTAssertEqual(store.transcriptOutputLanguage, .english)
        XCTAssertEqual(store.transcriptTranslationProvider, .gemini)
        XCTAssertEqual(store.transcriptTranslationDomain, .general)
        XCTAssertEqual(store.translationModel(for: .gemini), "gemini-2.5-flash")
        XCTAssertEqual(store.translationModel(for: .openAI), "gpt-5.4-mini")
        XCTAssertEqual(store.translationModel(for: .googleTranslate), "nmt")
        XCTAssertEqual(store.translationBaseURL(for: .googleTranslate).absoluteString, "https://translation.googleapis.com")
    }

    func testTranscriptionSettingsPersistsKoreanLanguage() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        store.transcriptionLanguage = .korean
        store.transcriptionModelID = "small"

        let reopenedStore = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reopenedStore.transcriptionLanguage, .korean)
        XCTAssertEqual(reopenedStore.transcriptionLanguage.whisperCode, "ko")
        XCTAssertEqual(reopenedStore.transcriptionModelID, "small")
    }

    func testTranscriptionSettingsFallsBackToEnglishForInvalidStoredValue() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        userDefaults.set("fr", forKey: "meetless.transcriptionLanguage")
        userDefaults.set("unknown-model", forKey: "meetless.transcriptionModelID")
        userDefaults.set("fr", forKey: "meetless.transcriptOutputLanguage")
        userDefaults.set("anthropic", forKey: "meetless.transcriptTranslationProvider")
        userDefaults.set("unknown-domain", forKey: "meetless.transcriptTranslation.domain")
        userDefaults.set("", forKey: "meetless.transcriptTranslation.gemini.model")
        userDefaults.set("not a url", forKey: "meetless.transcriptTranslation.openai.baseURL")
        userDefaults.set("not a url", forKey: "meetless.transcriptTranslation.google_translate.baseURL")
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        XCTAssertEqual(store.transcriptionLanguage, .english)
        XCTAssertEqual(store.transcriptionLanguage.whisperCode, "en")
        XCTAssertEqual(store.transcriptionModelID, "base")
        XCTAssertEqual(store.transcriptOutputLanguage, .english)
        XCTAssertEqual(store.transcriptTranslationProvider, .gemini)
        XCTAssertEqual(store.transcriptTranslationDomain, .general)
        XCTAssertEqual(store.translationModel(for: .gemini), "gemini-2.5-flash")
        XCTAssertEqual(store.translationBaseURL(for: .openAI).absoluteString, "https://api.openai.com")
        XCTAssertEqual(store.translationBaseURL(for: .googleTranslate).absoluteString, "https://translation.googleapis.com")
    }

    func testTranscriptionSettingsPersistsVietnameseOutputAndOpenAIProviderPreset() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        store.transcriptOutputLanguage = .vietnamese
        store.transcriptTranslationProvider = .openAI
        store.setTranslationModel("gpt-test-translation", for: .openAI)
        store.setTranslationBaseURL(URL(string: "https://openai.test")!, for: .openAI)

        let reopenedStore = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reopenedStore.transcriptOutputLanguage, .vietnamese)
        XCTAssertEqual(reopenedStore.transcriptTranslationProvider, .openAI)
        XCTAssertEqual(reopenedStore.translationModel(for: .openAI), "gpt-test-translation")
        XCTAssertEqual(reopenedStore.translationBaseURL(for: .openAI).absoluteString, "https://openai.test")
    }

    func testTranscriptionSettingsPersistsGoogleTranslateProvider() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        store.transcriptOutputLanguage = .vietnamese
        store.transcriptTranslationProvider = .googleTranslate
        store.setTranslationBaseURL(URL(string: "https://translation.test")!, for: .googleTranslate)

        let reopenedStore = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reopenedStore.transcriptOutputLanguage, .vietnamese)
        XCTAssertEqual(reopenedStore.transcriptTranslationProvider, .googleTranslate)
        XCTAssertEqual(reopenedStore.translationModel(for: .googleTranslate), "nmt")
        XCTAssertEqual(reopenedStore.translationBaseURL(for: .googleTranslate).absoluteString, "https://translation.test")
    }

    func testGeminiTranslationProviderExposesMoreModelPresets() {
        let presets = TranscriptTranslationProvider.gemini.modelPresets
        let presetIDs = presets.map(\.id)

        XCTAssertEqual(
            presetIDs,
            [
                "gemini-2.5-flash",
                "gemini-2.5-flash-lite",
                "gemini-2.5-pro",
                "gemini-3-flash-preview",
                "gemini-3-pro-preview",
                "gemini-flash-latest",
                "gemini-pro-latest",
                "gemini-2.0-flash-lite"
            ]
        )
        XCTAssertTrue(presets.allSatisfy { !$0.displayName.isEmpty })
        XCTAssertTrue(presets.allSatisfy { !$0.detail.isEmpty })
        XCTAssertTrue(TranscriptTranslationProvider.openAI.modelPresets.isEmpty)
        XCTAssertTrue(TranscriptTranslationProvider.googleTranslate.modelPresets.isEmpty)
        XCTAssertFalse(TranscriptTranslationProvider.googleTranslate.usesLLMPromptContext)
    }

    @MainActor
    func testSettingsViewModelSelectsGeminiTranslationModelPresetAndPreservesCustomModel() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let settingsStore = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)
        let viewModel = GeminiSettingsViewModel(
            apiKeyStore: KeychainGeminiAPIKeyStore(keychain: FakeKeychainItemAccessor()),
            transcriptionSettingsStore: settingsStore
        )

        XCTAssertEqual(viewModel.selectedTranslationModelPresetID, "gemini-2.5-flash")

        viewModel.selectTranslationModelPreset("gemini-3-flash-preview")
        XCTAssertEqual(viewModel.translationModel, "gemini-3-flash-preview")
        XCTAssertEqual(settingsStore.translationModel(for: .gemini), "gemini-3-flash-preview")
        XCTAssertEqual(viewModel.selectedTranslationModelPresetID, "gemini-3-flash-preview")

        viewModel.translationModel = "gemini-custom-preview"
        XCTAssertEqual(viewModel.selectedTranslationModelPresetID, GeminiSettingsViewModel.customTranslationModelPresetID)
        viewModel.selectTranslationModelPreset(GeminiSettingsViewModel.customTranslationModelPresetID)
        XCTAssertEqual(viewModel.translationModel, "gemini-custom-preview")
    }

    func testTranscriptionSettingsPersistsTranslationContextDomain() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let store = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)

        store.transcriptTranslationDomain = .informationTechnology

        let reopenedStore = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)
        XCTAssertEqual(reopenedStore.transcriptTranslationDomain, .informationTechnology)
    }

    func testWhisperBridgeDefaultsToMultilingualBaseModel() {
        let assets = WhisperBridgeAssets(bundle: Bundle(for: Self.self))

        XCTAssertEqual(assets.modelBasename, "ggml-base")
        XCTAssertEqual(assets.bundledModelFilename, "ggml-base.bin")
    }

    func testTranscriptionModelCatalogUsesBalancedOfficialPresets() {
        let modelIDs = TranscriptionModelPreset.allPresets.map(\.id)

        XCTAssertEqual(
            modelIDs,
            [
                "tiny",
                "tiny.en",
                "base",
                "base.en",
                "small",
                "small.en",
                "medium",
                "medium.en",
                "large-v3-turbo",
                "large-v3-turbo-q5_0"
            ]
        )
        XCTAssertTrue(TranscriptionModelPreset(storedValue: "base").isBundled)
        XCTAssertEqual(TranscriptionModelPreset(storedValue: "base").diskSizeLabel, "142 MiB")
        XCTAssertEqual(TranscriptionModelPreset(storedValue: "base").resourceLabel, "Low")
        XCTAssertEqual(TranscriptionModelPreset(storedValue: "base").languageLabel, "Multilingual")
        XCTAssertTrue(TranscriptionModelPreset(storedValue: "base").recommendation.contains("Default"))
        XCTAssertEqual(TranscriptionModelPreset(storedValue: "base.en").languageLabel, "English only")
        XCTAssertEqual(TranscriptionModelPreset(storedValue: "large-v3-turbo-q5_0").diskSizeLabel, "547 MiB")
        XCTAssertTrue(TranscriptionModelPreset(storedValue: "large-v3-turbo-q5_0").languageLabel.contains("quantized"))
        XCTAssertEqual(
            TranscriptionModelPreset(storedValue: "small").downloadURL?.absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
        )
    }

    func testTranscriptionModelLibraryDownloadsModelIntoApplicationSupportModelDirectory() async throws {
        let scratchDirectory = try MeetlessTestSupport.makeTemporaryDirectory(prefix: "TranscriptionModelLibraryTests")
        defer { try? FileManager.default.removeItem(at: scratchDirectory) }
        let downloader = FakeTranscriptionModelDownloader(result: .success(Data("model-bytes".utf8)))
        let library = TranscriptionModelLibrary(
            bundle: Bundle(for: Self.self),
            modelsDirectoryURL: scratchDirectory,
            downloader: downloader
        )
        let preset = TranscriptionModelPreset(storedValue: "small")
        var progressValues: [Double] = []

        try await library.download(preset) { progress in
            progressValues.append(progress)
        }

        let modelURL = scratchDirectory.appendingPathComponent("ggml-small.bin", isDirectory: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelURL.path))
        XCTAssertEqual(try Data(contentsOf: modelURL), Data("model-bytes".utf8))
        XCTAssertEqual(progressValues, [0.5, 1])
        XCTAssertTrue(library.isInstalled(preset))
    }

    func testTranscriptionModelLibraryCleansFailedDownloadAndReportsMissingStatus() async throws {
        let scratchDirectory = try MeetlessTestSupport.makeTemporaryDirectory(prefix: "TranscriptionModelLibraryTests")
        defer { try? FileManager.default.removeItem(at: scratchDirectory) }
        let downloader = FakeTranscriptionModelDownloader(result: .failure(CocoaError(.fileReadNoSuchFile)))
        let library = TranscriptionModelLibrary(
            bundle: Bundle(for: Self.self),
            modelsDirectoryURL: scratchDirectory,
            downloader: downloader
        )
        let preset = TranscriptionModelPreset(storedValue: "small")

        do {
            try await library.download(preset) { _ in }
            XCTFail("Expected download to fail.")
        } catch {
            XCTAssertFalse(FileManager.default.fileExists(atPath: library.localModelURL(for: preset).path))
        }

        let status = try XCTUnwrap(
            library.statuses(selectedModelID: "base", downloadingProgress: [:], failures: [:])
                .first { $0.id == "small" }
        )
        XCTAssertEqual(status.availability, .missing)
        XCTAssertFalse(status.canSelect)
    }

    func testTranscriptionLanguageMapsKoreanToWhisperCode() {
        XCTAssertEqual(TranscriptionLanguage.korean.whisperCode, "ko")
    }

    func testLoadAPIKeyReturnsNilWhenKeyIsMissing() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        let apiKey = try store.loadAPIKey()

        XCTAssertNil(apiKey)
    }

    func testSaveAPIKeyStoresValueForLaterReads() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("gemini-secret")

        XCTAssertEqual(try store.loadAPIKey(), "gemini-secret")
        XCTAssertEqual(keychain.recordedValues, ["gemini-secret"])
    }

    func testOpenAIKeychainStoreUsesSeparateKeychainPath() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainOpenAIAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("openai-secret")

        XCTAssertEqual(try store.loadAPIKey(), "openai-secret")
        XCTAssertEqual(keychain.recordedValues, ["openai-secret"])
    }

    func testGoogleTranslateKeychainStoreUsesSeparateKeychainPath() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGoogleTranslateAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("google-secret")

        XCTAssertEqual(try store.loadAPIKey(), "google-secret")
        XCTAssertEqual(keychain.recordedValues, ["google-secret"])
    }

    func testSaveAPIKeyUpdatesExistingValue() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("old-secret")
        try store.saveAPIKey("new-secret")

        XCTAssertEqual(try store.loadAPIKey(), "new-secret")
        XCTAssertEqual(keychain.recordedValues, ["old-secret", "new-secret"])
    }

    func testDeleteAPIKeyRemovesValueForLaterReads() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        try store.saveAPIKey("gemini-secret")
        try store.deleteAPIKey()

        XCTAssertNil(try store.loadAPIKey())
    }

    func testDeleteAPIKeySucceedsWhenValueIsAlreadyMissing() {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertNoThrow(try store.deleteAPIKey())
    }

    func testLoadMapsKeychainFailure() {
        let keychain = FakeKeychainItemAccessor(copyMatchingStatusOverride: errSecAuthFailed)
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertThrowsError(try store.loadAPIKey()) { error in
            XCTAssertEqual(
                error as? GeminiAPIKeyStoreError,
                .keychainFailure(operation: .copyMatching, status: errSecAuthFailed)
            )
        }
    }

    func testSaveMapsAddFailure() {
        let keychain = FakeKeychainItemAccessor(addStatusOverride: errSecNotAvailable)
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertThrowsError(try store.saveAPIKey("gemini-secret")) { error in
            XCTAssertEqual(
                error as? GeminiAPIKeyStoreError,
                .keychainFailure(operation: .add, status: errSecNotAvailable)
            )
        }
    }

    func testSaveMapsUpdateFailure() {
        let keychain = FakeKeychainItemAccessor(updateStatusOverride: errSecInteractionNotAllowed)
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertNoThrow(try store.saveAPIKey("old-secret"))
        XCTAssertThrowsError(try store.saveAPIKey("new-secret")) { error in
            XCTAssertEqual(
                error as? GeminiAPIKeyStoreError,
                .keychainFailure(operation: .update, status: errSecInteractionNotAllowed)
            )
        }
    }

    func testDeleteMapsFailure() {
        let keychain = FakeKeychainItemAccessor(deleteStatusOverride: errSecAuthFailed)
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertThrowsError(try store.deleteAPIKey()) { error in
            XCTAssertEqual(
                error as? GeminiAPIKeyStoreError,
                .keychainFailure(operation: .delete, status: errSecAuthFailed)
            )
        }
    }

    func testLoadMapsInvalidStoredData() {
        let keychain = FakeKeychainItemAccessor(copyMatchingItemOverride: "not-data")
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)

        XCTAssertThrowsError(try store.loadAPIKey()) { error in
            XCTAssertEqual(error as? GeminiAPIKeyStoreError, .invalidStoredData)
        }
    }

    @MainActor
    func testSettingsViewModelShowsNotConfiguredWhenKeyIsMissing() {
        let store = KeychainGeminiAPIKeyStore(keychain: FakeKeychainItemAccessor())
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        XCTAssertEqual(viewModel.keyStatus, .notConfigured)
        XCTAssertFalse(viewModel.isConfigured)
    }

    @MainActor
    func testSettingsViewModelSavesTrimmedKeyWithoutDisplayingSecret() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        viewModel.apiKeyInput = "  gemini-secret  "
        viewModel.saveAPIKey()

        XCTAssertEqual(try store.loadAPIKey(), "gemini-secret")
        XCTAssertEqual(keychain.recordedValues, ["gemini-secret"])
        XCTAssertEqual(viewModel.keyStatus, .configured)
        XCTAssertEqual(viewModel.apiKeyInput, "")
        XCTAssertFalse(viewModel.keyStatus.detail.contains("gemini-secret"))
        XCTAssertFalse(viewModel.feedbackMessage?.contains("gemini-secret") ?? false)
    }

    @MainActor
    func testSettingsViewModelSavesTrimmedGoogleTranslateKeyWithoutDisplayingSecret() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGoogleTranslateAPIKeyStore(keychain: keychain)
        let viewModel = GeminiSettingsViewModel(
            apiKeyStore: KeychainGeminiAPIKeyStore(keychain: FakeKeychainItemAccessor()),
            googleTranslateAPIKeyStore: store
        )

        viewModel.googleTranslateAPIKeyInput = "  google-secret  "
        viewModel.saveGoogleTranslateAPIKey()

        XCTAssertEqual(try store.loadAPIKey(), "google-secret")
        XCTAssertEqual(keychain.recordedValues, ["google-secret"])
        XCTAssertEqual(viewModel.googleTranslateKeyStatus, .configured)
        XCTAssertEqual(viewModel.googleTranslateAPIKeyInput, "")
        XCTAssertFalse(viewModel.feedbackMessage?.contains("google-secret") ?? false)
    }

    @MainActor
    func testSettingsViewModelHidesPromptControlsForGoogleTranslateProvider() throws {
        let userDefaults = try makeIsolatedUserDefaults()
        let settingsStore = UserDefaultsTranscriptionSettingsStore(userDefaults: userDefaults)
        settingsStore.transcriptTranslationProvider = .googleTranslate
        let viewModel = GeminiSettingsViewModel(
            apiKeyStore: KeychainGeminiAPIKeyStore(keychain: FakeKeychainItemAccessor()),
            transcriptionSettingsStore: settingsStore
        )

        XCTAssertFalse(viewModel.selectedProviderUsesLLMPromptContext)

        viewModel.transcriptTranslationProvider = .gemini
        XCTAssertTrue(viewModel.selectedProviderUsesLLMPromptContext)
    }

    @MainActor
    func testSettingsViewModelRejectsBlankKey() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        viewModel.apiKeyInput = "   "
        viewModel.saveAPIKey()

        XCTAssertNil(try store.loadAPIKey())
        XCTAssertEqual(viewModel.keyStatus, .notConfigured)
        XCTAssertEqual(viewModel.feedbackMessage, "Enter a Gemini API key before saving.")
    }

    @MainActor
    func testSettingsViewModelDeletesSavedKey() throws {
        let keychain = FakeKeychainItemAccessor()
        let store = KeychainGeminiAPIKeyStore(keychain: keychain)
        try store.saveAPIKey("gemini-secret")
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        viewModel.deleteAPIKey()

        XCTAssertNil(try store.loadAPIKey())
        XCTAssertEqual(viewModel.keyStatus, .notConfigured)
        XCTAssertEqual(viewModel.feedbackMessage, "Gemini API key removed.")
    }

    @MainActor
    func testSettingsViewModelMapsKeychainErrorsToSafeCopy() {
        let store = KeychainGeminiAPIKeyStore(
            keychain: FakeKeychainItemAccessor(copyMatchingStatusOverride: errSecAuthFailed)
        )
        let viewModel = GeminiSettingsViewModel(apiKeyStore: store)

        XCTAssertEqual(
            viewModel.keyStatus,
            .error("Keychain could not complete the request. Check macOS access and try again.")
        )
    }
}

private func makeIsolatedUserDefaults() throws -> UserDefaults {
    let suiteName = "MeetlessTests-\(UUID().uuidString)"
    let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
}

private final class FakeKeychainItemAccessor: KeychainItemAccessing {
    private var storedData: Data?
    private let addStatusOverride: OSStatus?
    private let copyMatchingStatusOverride: OSStatus?
    private let copyMatchingItemOverride: Any?
    private let updateStatusOverride: OSStatus?
    private let deleteStatusOverride: OSStatus?

    private(set) var recordedValues: [String] = []

    init(
        addStatusOverride: OSStatus? = nil,
        copyMatchingStatusOverride: OSStatus? = nil,
        copyMatchingItemOverride: Any? = nil,
        updateStatusOverride: OSStatus? = nil,
        deleteStatusOverride: OSStatus? = nil
    ) {
        self.addStatusOverride = addStatusOverride
        self.copyMatchingStatusOverride = copyMatchingStatusOverride
        self.copyMatchingItemOverride = copyMatchingItemOverride
        self.updateStatusOverride = updateStatusOverride
        self.deleteStatusOverride = deleteStatusOverride
    }

    func add(_ query: [String: Any]) -> OSStatus {
        if let addStatusOverride {
            return addStatusOverride
        }

        guard storedData == nil else {
            return errSecDuplicateItem
        }

        storedData = query[kSecValueData as String] as? Data
        recordStoredValue()
        return errSecSuccess
    }

    func copyMatching(_ query: [String: Any]) -> (status: OSStatus, item: Any?) {
        if let copyMatchingStatusOverride {
            return (copyMatchingStatusOverride, nil)
        }

        if let copyMatchingItemOverride {
            return (errSecSuccess, copyMatchingItemOverride)
        }

        guard let storedData else {
            return (errSecItemNotFound, nil)
        }

        return (errSecSuccess, storedData)
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        if let updateStatusOverride {
            return updateStatusOverride
        }

        guard storedData != nil else {
            return errSecItemNotFound
        }

        storedData = attributes[kSecValueData as String] as? Data
        recordStoredValue()
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        if let deleteStatusOverride {
            return deleteStatusOverride
        }

        guard storedData != nil else {
            return errSecItemNotFound
        }

        storedData = nil
        return errSecSuccess
    }

    private func recordStoredValue() {
        guard let storedData, let value = String(data: storedData, encoding: .utf8) else {
            return
        }

        recordedValues.append(value)
    }
}

private final class FakeTranscriptionModelDownloader: TranscriptionModelDownloading {
    private let result: Result<Data, Error>

    init(result: Result<Data, Error>) {
        self.result = result
    }

    func download(
        from sourceURL: URL,
        to destinationURL: URL,
        progressHandler: @escaping @Sendable (Double) -> Void
    ) async throws {
        progressHandler(0.5)

        switch result {
        case .success(let data):
            try FileManager.default.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destinationURL, options: .atomic)
            progressHandler(1)
        case .failure(let error):
            try? FileManager.default.removeItem(at: destinationURL)
            throw error
        }
    }
}
